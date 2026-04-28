use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tauri::{command, AppHandle, Emitter, Manager, State};
use tauri_plugin_store::StoreExt;
use tokio::sync::Mutex;

use crate::features::ai_processing::{generate_from_command, CommandModeRequest};
use crate::features::audio::{RecordingMode, RecordingState, RecordingStateManager};
use crate::features::clipboard;
use crate::features::models::LocalModelManager;
use crate::features::security;
use crate::utils::app_categorization::categorize_app;
use crate::utils::logger;

use super::orchestrator_helpers::{
    apply_ai_post_processing, create_empty_prompt_context, get_model_name,
};
use super::providers::{assemblyai, azure, deepgram, elevenlabs, google, local_whisper, openai};
use super::vocabulary::get_transcription_context;
use crate::features::recordings::metadata::RecordingMetadata;
use crate::features::recordings::storage::{
    create_recording_folder, get_all_recordings, read_metadata, save_metadata,
};

// Global state for debouncing paste operations (using parking_lot for faster locking)
static LAST_PASTE_TIME: parking_lot::Mutex<Option<Instant>> = parking_lot::Mutex::new(None);

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TranscriptionRecord {
    pub id: String,
    pub text: String,
    pub timestamp: i64,
    pub duration: Option<f64>,
    pub word_count: usize,
    pub model_id: String,
    pub provider: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TranscribeRequest {
    pub audio_data: Vec<u8>,
    pub timestamp: i64,
    pub duration: Option<f64>,
    pub language: Option<String>, // ISO 639-1 language code (e.g., "en", "es", "fr")
    pub recording_device: Option<String>,
    #[serde(default)]
    pub translate: bool, // If true, translate to English (Whisper-specific)
}

/// Unified transcription command that handles the entire flow:
/// 1. Get selected model and focused app
/// 2. Transcribe using appropriate provider
/// 3. Apply AI post-processing if enabled
/// 4. Save to recordings/TIMESTAMP/ folder
/// 5. Copy and paste text
/// 6. Emit events for UI updates
#[command]
pub async fn transcribe_and_process(
    request: TranscribeRequest,
    app: AppHandle,
    local_model_state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<Option<TranscriptionRecord>, String> {
    let start_time = Instant::now();

    // Step 1: Get selected transcription model
    let selected_model = get_selected_model(&app)?;

    // Step 2: Get focused application
    let focused_app =
        clipboard::get_focused_app()
            .await
            .unwrap_or_else(|_| clipboard::FocusedApp {
                name: "Unknown".to_string(),
                bundle_id: "".to_string(),
            });
    let focused_app_name = focused_app.name.clone();

    if is_audio_silent(&request.audio_data)? {
        logger::debug("Audio is silent, skipping transcription");

        // Show toast for silent audio
        let _ = crate::features::window::show_toast(
            &app,
            "No speech detected",
            crate::features::window::ToastType::Info,
            1.0,
        );

        // Clean up the recording folder since audio is silent
        let recordings_dir = crate::features::recordings::get_recordings_dir(&app)?;
        let recording_folder = recordings_dir.join(request.timestamp.to_string());

        if crate::utils::async_fs::exists(&recording_folder).await {
            if let Err(e) = crate::utils::async_fs::remove_dir_all(&recording_folder).await {
                log::warn!(
                    "Failed to cleanup recording folder after silent audio detection: {}",
                    e
                );
            } else {
                log::info!("Cleaned up recording folder for silent audio");
            }
        }

        return Ok(None);
    }

    // Step 4: Transcribe using appropriate provider
    let raw_transcription = transcribe_with_provider(
        &app,
        request.audio_data.clone(),
        &selected_model,
        request.language.clone(),
        request.translate,
        local_model_state,
    )
    .await?;

    // Skip if transcription is empty
    if raw_transcription.trim().is_empty() {
        logger::debug("Transcription is empty, skipping");
        return Ok(None);
    }

    // Step 4.5: Check recording mode (Command Mode or Dictation Mode)
    let state_manager = app.state::<Arc<RecordingStateManager>>();
    let recording_mode = state_manager.get_recording_mode();

    // Handle Command Mode
    if recording_mode == RecordingMode::Command {
        use crate::features::ai_processing::CommandModeResult;

        log::info!("Command Mode: Processing transcription as instruction");

        // Hide pill window first
        crate::features::window::hide_pill_window(&app);

        // Show command result window with transcription
        if let Err(e) =
            crate::features::window::show_command_result_window(&app, &raw_transcription)
        {
            log::warn!("Failed to show command result window: {}", e);
        }

        // Transition to Generating state
        if let Err(e) = state_manager.set_state(RecordingState::Generating) {
            log::warn!("Failed to transition to Generating state: {}", e);
        }
        app.emit("recording-state-changed", "generating")
            .map_err(|e| format!("Failed to emit state change: {}", e))?;

        // Get the post-processing model for command generation
        let settings = get_settings(&app)?;
        let post_processing_model_id = settings
            .get("aiProcessing")
            .and_then(|a| a.get("postProcessingModelId"))
            .and_then(|v| v.as_str())
            .ok_or("Command Mode requires AI processing to be enabled with a model selected")?;

        // Generate content using transcription as instruction
        let command_result = generate_from_command(
            CommandModeRequest {
                instruction: raw_transcription.clone(),
                model_id: post_processing_model_id.to_string(),
            },
            app.clone(),
        )
        .await?;

        // Reset recording mode back to Dictation for next use
        state_manager.set_recording_mode(RecordingMode::Dictation);

        // Reset state to Idle and emit state change
        if let Err(e) = state_manager.set_state(RecordingState::Idle) {
            log::warn!("Failed to reset state to Idle: {}", e);
            state_manager.force_set_state(RecordingState::Idle);
        }
        app.emit("recording-state-changed", "idle")
            .map_err(|e| format!("Failed to emit state change: {}", e))?;

        // Handle the command result
        match command_result {
            CommandModeResult::InvalidRequest => {
                log::info!("Command Mode: Invalid request detected, showing error");

                // Emit error event to command result window
                app.emit("command-result-error", "This doesn't look like a content request. Try asking me to write, draft, or create something.")
                    .map_err(|e| format!("Failed to emit error: {}", e))?;

                // Keep window open for 3 seconds to show error, then hide
                let app_clone = app.clone();
                std::thread::spawn(move || {
                    std::thread::sleep(std::time::Duration::from_millis(5000));
                    if let Err(e) = crate::features::window::hide_command_result_window(&app_clone)
                    {
                        log::warn!("Failed to hide command result window: {}", e);
                    }
                });

                // Return None - no content was generated
                return Ok(None);
            }
            CommandModeResult::Success(generated_content) => {
                // Calculate processing time
                let processing_time = start_time.elapsed().as_millis() as u64;

                // Create recording folder for command mode entry
                let recording_folder = create_recording_folder(&app, request.timestamp)?;

                // Use model ID as name (simplified - could be enhanced later)
                let post_processing_model_name = post_processing_model_id.to_string();

                // Determine post-processing provider from model_id
                let post_processing_provider = if post_processing_model_id.starts_with("claude-") {
                    "anthropic"
                } else if post_processing_model_id.starts_with("gpt-") {
                    "openai"
                } else {
                    "local-llm"
                };

                // Create and save metadata for command mode
                let metadata = RecordingMetadata::for_command(
                    raw_transcription.clone(),
                    generated_content.clone(),
                    request.timestamp,
                    request.duration.unwrap_or(0.0) * 1000.0,
                    processing_time,
                    selected_model.id.clone(),
                    get_model_name(&selected_model),
                    selected_model.provider.clone(),
                    post_processing_model_id.to_string(),
                    post_processing_model_name,
                    post_processing_provider.to_string(),
                    request
                        .recording_device
                        .clone()
                        .unwrap_or_else(|| "Unknown".to_string()),
                );

                // Save metadata
                if let Err(e) = save_metadata(&recording_folder, &metadata) {
                    log::warn!("Failed to save command mode metadata: {}", e);
                }

                // Handle auto-paste for command mode
                let auto_paste = settings
                    .get("transcription")
                    .and_then(|t| t.get("autoPaste"))
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);

                // Hide command result window
                if let Err(e) = crate::features::window::hide_command_result_window(&app) {
                    log::warn!("Failed to hide command result window: {}", e);
                }

                if auto_paste {
                    if let Err(e) = clipboard::copy_and_paste(generated_content.clone()).await {
                        logger::error(&format!("Failed to copy and paste: {}", e));
                    }
                } else {
                    // Copy to clipboard
                    use tauri_plugin_clipboard_manager::ClipboardExt;
                    if let Err(e) = app.clipboard().write_text(generated_content.clone()) {
                        logger::error(&format!("Failed to copy to clipboard: {}", e));
                    }
                }

                // Show success toast
                let _ = crate::features::window::show_toast(
                    &app,
                    "Content generated",
                    crate::features::window::ToastType::Success,
                    0.4,
                );

                // Emit event for UI updates
                app.emit("transcriptions-changed", ())
                    .map_err(|e| format!("Failed to emit sync event: {}", e))?;

                // Return record
                return Ok(Some(TranscriptionRecord {
                    id: request.timestamp.to_string(),
                    text: generated_content,
                    timestamp: request.timestamp,
                    duration: request.duration,
                    word_count: raw_transcription.split_whitespace().count(),
                    model_id: selected_model.id,
                    provider: selected_model.provider,
                }));
            }
        }
    }

    // --- Dictation Mode (default) ---

    // Step 5: Get the existing recording folder (already created during start_recording)
    let recordings_dir = crate::features::recordings::get_recordings_dir(&app)?;
    let recording_folder = recordings_dir.join(request.timestamp.to_string());

    // Verify the folder exists (it should have been created during recording)
    if !crate::utils::async_fs::exists(&recording_folder).await {
        return Err(format!(
            "Recording folder does not exist: {}",
            recording_folder.display()
        ));
    }

    // Step 6: Check if AI post-processing is enabled
    let settings = get_settings(&app)?;
    let ai_processing_enabled = settings
        .get("aiProcessing")
        .and_then(|a| a.get("enabled"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    // Log AI processing configuration for debugging
    if ai_processing_enabled {
        let post_processing_model_id = settings
            .get("aiProcessing")
            .and_then(|a| a.get("postProcessingModelId"))
            .and_then(|v| v.as_str());
        log::info!(
            "AI post-processing enabled. Model ID: {:?}",
            post_processing_model_id
        );
    } else {
        log::debug!("AI post-processing is disabled");
    }

    // Track if we showed a warning/error toast (to skip success toast later)
    let mut showed_warning_toast = false;

    let (
        final_text,
        post_processed_text,
        style_applied,
        style_category,
        prompt_context,
        post_processing_model_id,
        post_processing_model_name,
        post_processing_provider,
    ) = if ai_processing_enabled {
        // Try to apply AI post-processing
        match apply_ai_post_processing(&app, &raw_transcription, &focused_app.name, &settings).await
        {
            Ok(result) => (
                result.final_text,
                Some(result.post_processed_text),
                result.style_applied,
                result.style_category,
                result.prompt_context,
                Some(result.model_id),
                result.model_name,
                result.provider,
            ),
            Err(e) => {
                // Post-processing failed (likely no model selected) - continue without it
                logger::warn(&format!(
                    "Post-processing failed: {}. Continuing with raw transcription.",
                    e
                ));

                // Show toast to user (warning takes precedence over success)
                let _ = crate::features::window::show_toast(
                    &app,
                    "Post-processing skipped: No model selected",
                    crate::features::window::ToastType::Warning,
                    1.0,
                );
                showed_warning_toast = true;

                // Use raw transcription
                (
                    raw_transcription.clone(),
                    None,
                    None,
                    None,
                    create_empty_prompt_context(),
                    None,
                    None,
                    None,
                )
            }
        }
    } else {
        // No post-processing
        (
            raw_transcription.clone(),
            None,
            None,
            None,
            create_empty_prompt_context(),
            None,
            None,
            None,
        )
    };

    // Step 8: Calculate processing time
    let processing_time = start_time.elapsed().as_millis() as u64;

    // Step 9: Determine app category
    let app_category = categorize_app(&focused_app.name);

    // Step 10: Check if audio recordings should be saved
    let save_audio_recordings = settings
        .get("system")
        .and_then(|s| s.get("saveAudioRecordings"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    // Step 11: Handle audio file based on setting
    let audio_path = recording_folder.join("audio.wav");
    let has_audio = if save_audio_recordings {
        // Audio file exists (was created during recording)
        crate::utils::async_fs::exists(&audio_path).await
    } else {
        // Delete the audio file if save is disabled
        if crate::utils::async_fs::exists(&audio_path).await {
            if let Err(e) = crate::utils::async_fs::remove_file(&audio_path).await {
                logger::warn(&format!("Failed to delete audio file: {}", e));
            } else {
                logger::debug("Audio file deleted (saveAudioRecordings disabled)");
            }
        }
        false
    };

    // Step 12: Create comprehensive metadata
    let metadata = RecordingMetadata::new(
        raw_transcription.clone(),
        final_text.clone(),
        post_processed_text,
        request.timestamp,
        request.duration.unwrap_or(0.0) * 1000.0, // Convert to ms
        processing_time,
        selected_model.id.clone(),
        get_model_name(&selected_model),
        selected_model.provider.clone(),
        post_processing_model_id,
        post_processing_model_name,
        post_processing_provider,
        request.language.unwrap_or_else(|| "en".to_string()),
        request.translate,
        request
            .recording_device
            .unwrap_or_else(|| "Unknown".to_string()),
        focused_app_name,
        app_category.as_str().to_string(),
        ai_processing_enabled,
        style_applied,
        style_category,
        prompt_context,
        has_audio,
    );

    // Step 13: Save metadata
    save_metadata(&recording_folder, &metadata)?;

    // Step 14: Handle auto-paste/copy (do this BEFORE showing success toast)
    let auto_paste = settings
        .get("transcription")
        .and_then(|t| t.get("autoPaste"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let auto_copy_to_clipboard = settings
        .get("transcription")
        .and_then(|t| t.get("autoCopyToClipboard"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    if auto_paste {
        app.emit("hide_voice_input", ())
            .map_err(|e| format!("Failed to emit hide event: {}", e))?;

        if let Err(e) = clipboard::copy_and_paste(final_text.clone()).await {
            logger::error(&format!("Failed to copy and paste: {}", e));
        }
    } else if auto_copy_to_clipboard {
        use tauri_plugin_clipboard_manager::ClipboardExt;
        if let Err(e) = app.clipboard().write_text(final_text.clone()) {
            logger::error(&format!("Failed to copy to clipboard: {}", e));
        }
    }

    // Step 15: Show success toast AFTER paste/copy step - skip if warning was shown
    if !showed_warning_toast {
        let _ = crate::features::window::show_toast(
            &app,
            "Transcription saved",
            crate::features::window::ToastType::Success,
            0.4,
        );
    }

    // Step 17: Emit events for UI updates
    app.emit("transcriptions-changed", ())
        .map_err(|e| format!("Failed to emit sync event: {}", e))?;

    // Return record for backward compatibility
    Ok(Some(TranscriptionRecord {
        id: request.timestamp.to_string(),
        text: final_text,
        timestamp: request.timestamp,
        duration: request.duration,
        word_count: raw_transcription.split_whitespace().count(),
        model_id: selected_model.id,
        provider: selected_model.provider,
    }))
}

/// Get settings from the settings store
fn get_settings(app: &AppHandle) -> Result<Value, String> {
    let store = app
        .store("settings")
        .map_err(|e| format!("Failed to get settings store: {}", e))?;

    let mut settings = store
        .get("settings")
        .ok_or("No settings found in store")?
        .clone();

    // Ensure aiProcessing exists with defaults if missing
    if settings.get("aiProcessing").is_none() {
        if let Some(obj) = settings.as_object_mut() {
            obj.insert(
                "aiProcessing".to_string(),
                serde_json::json!({
                    "enabled": false,
                    "postProcessingModelId": null
                }),
            );
        }
    }

    Ok(settings)
}

/// Get the selected speech-to-text model from settings
fn get_selected_model(app: &AppHandle) -> Result<SelectedModel, String> {
    // Get selected model ID from settings
    let settings = get_settings(app)?;
    let selected_model_id = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
        .ok_or("No speech-to-text model selected in settings")?;

    // Get the model details from models store
    let models_store = app
        .store("models.json")
        .map_err(|e| format!("Failed to get models store: {}", e))?;

    let models_value = models_store
        .get("models")
        .ok_or("No models found in store")?;
    let models = models_value.as_array().ok_or("Models is not an array")?;

    // Find the model by ID
    for model_value in models {
        let model = model_value.as_object().ok_or("Model is not an object")?;

        let id = model.get("id").and_then(|v| v.as_str()).unwrap_or("");

        if id == selected_model_id {
            let provider = model
                .get("provider")
                .and_then(|v| v.as_str())
                .ok_or("Model provider not found")?
                .to_string();

            let path = model.get("path").and_then(|v| v.as_str()).map(String::from);

            return Ok(SelectedModel {
                id: id.to_string(),
                provider,
                path,
            });
        }
    }

    Err(format!(
        "Model '{}' not found in models store",
        selected_model_id
    ))
}

/// Get the last (most recent) transcript from the new recordings storage
#[command]
pub async fn get_last_transcript(app: AppHandle) -> Result<String, String> {
    // Get all recordings sorted by timestamp (newest first)
    let recordings = get_all_recordings(&app)?;

    if recordings.is_empty() {
        return Err("No recordings found".to_string());
    }

    // Get the first (most recent) recording
    let last_recording = recordings.first().ok_or("No recordings available")?;

    // Read metadata from the recording
    let metadata = read_metadata(last_recording)?;

    Ok(metadata.result)
}

/// Paste the last transcript using the clipboard
#[command]
pub async fn paste_last_transcript(app: AppHandle) -> Result<(), String> {
    // Debounce: prevent rapid repeated calls (within 500ms)
    const DEBOUNCE_DURATION: Duration = Duration::from_millis(500);

    {
        let mut last_time = LAST_PASTE_TIME.lock();
        let now = Instant::now();

        if let Some(last) = *last_time {
            if now.duration_since(last) < DEBOUNCE_DURATION {
                logger::debug("Paste triggered too soon, debouncing");
                return Ok(());
            }
        }

        *last_time = Some(now);
    }

    logger::info("Pasting last transcript");

    // Get the last transcript
    let text = get_last_transcript(app).await?;

    // Copy and paste it
    clipboard::copy_and_paste(text)
        .await
        .map_err(|e| format!("Failed to paste transcript: {}", e))?;

    Ok(())
}

/// Route transcription to the appropriate provider
async fn transcribe_with_provider(
    app: &AppHandle,
    audio_data: Vec<u8>,
    model: &SelectedModel,
    language: Option<String>,
    translate: bool,
    local_model_state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<String, String> {
    // Get vocabulary and snippets context for transcription providers
    let vocab_context = get_transcription_context(app);
    let prompt = vocab_context.to_prompt();
    let word_list = if vocab_context.is_empty() {
        None
    } else {
        Some(vocab_context.to_word_list())
    };

    if prompt.is_some() {
        log::debug!(
            "Using vocabulary context with {} words/phrases for transcription",
            vocab_context.vocabulary_words.len()
                + vocab_context.snippet_triggers.len()
                + vocab_context.snippet_expansions.len()
        );
    }

    let response = match model.provider.as_str() {
        "openai" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "OpenAI API key not found. Please add your API key in settings.")?;

            // OpenAI Whisper supports prompt parameter for vocabulary hints
            openai::transcribe_with_openai(
                audio_data,
                api_key,
                Some(model.id.clone()),
                language.clone(),
                None,
                prompt.clone(),
            )
            .await?
        }
        "google" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Google API key not found. Please add your API key in settings.")?;

            // Convert ISO 639-1 code to Google's format (e.g., "en" -> "en-US")
            // Note: Google API doesn't support translation in transcription
            let google_language = language
                .clone()
                .map(|lang| format!("{}-US", lang.to_uppercase()))
                .or(Some("en-US".to_string()));

            // Google Speech supports speechContexts for phrase hints
            google::transcribe_with_google(audio_data, api_key, google_language, word_list.clone())
                .await?
        }
        "local-whisper" => {
            // Local Whisper (whisper.cpp) supports initial_prompt
            local_whisper::transcribe_with_local_whisper(
                audio_data,
                Some(model.id.clone()),
                language.clone(),
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        "elevenlabs" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| {
                    "ElevenLabs API key not found. Please add your API key in settings."
                })?;

            elevenlabs::transcribe_with_elevenlabs(
                audio_data,
                api_key,
                Some(model.id.clone()),
                None,
            )
            .await?
        }
        // Candle engine (Pure Rust with Metal GPU)
        "candle" => {
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "candle",
                model.path.clone(),
                Some(model.id.clone()),
                language.clone(),
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        // WhisperKit engine (CoreML/Neural Engine)
        "whisperkit" => {
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "whisperkit",
                model.path.clone(),
                Some(model.id.clone()),
                language.clone(),
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        // Apple Speech Recognition (built-in macOS)
        "apple-speech" => {
            // Apple Speech doesn't support vocabulary hints
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "apple-speech",
                model.path.clone(),
                Some(model.id.clone()),
                language.clone(),
                translate,
                None, // Apple Speech doesn't use prompt
                local_model_state,
            )
            .await?
        }
        // AssemblyAI - supports word_boost for vocabulary
        "assemblyai" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| {
                    "AssemblyAI API key not found. Please add your API key in settings."
                })?;

            assemblyai::transcribe_with_assemblyai(
                audio_data,
                api_key,
                language.clone(),
                word_list.clone(),
            )
            .await?
        }
        // Deepgram - supports keywords for vocabulary
        "deepgram" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Deepgram API key not found. Please add your API key in settings.")?;

            deepgram::transcribe_with_deepgram(
                audio_data,
                api_key,
                language.clone(),
                word_list.clone(),
            )
            .await?
        }
        // Azure Speech Services - supports phrase lists
        "azure" => {
            let api_key = security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Azure API key not found. Please add your API key in settings.")?;

            // Azure language codes use format like "en-US"
            let azure_language = language.clone().map(|lang| {
                if lang.contains('-') {
                    lang
                } else {
                    format!("{}-US", lang)
                }
            });

            azure::transcribe_with_azure(
                audio_data,
                api_key,
                None, // Use default region (eastus)
                azure_language,
                word_list.clone(),
            )
            .await?
        }
        _ => return Err(format!("Unsupported provider: {}", model.provider)),
    };

    Ok(response.text)
}

#[derive(Debug, Clone)]
pub struct SelectedModel {
    pub id: String,
    pub provider: String,
    pub path: Option<String>,
}

/// Detects if audio is silent by analyzing the waveform
/// Returns true if audio is mostly silent (no speech detected)
fn is_audio_silent(audio_data: &[u8]) -> Result<bool, String> {
    use hound::WavReader;
    use std::io::Cursor;

    // Parse WAV file
    let cursor = Cursor::new(audio_data);
    let mut reader =
        WavReader::new(cursor).map_err(|e| format!("Failed to parse WAV audio: {}", e))?;

    let spec = reader.spec();

    // Read all samples and calculate RMS (Root Mean Square)
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => reader
            .samples::<f32>()
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| format!("Failed to read samples: {}", e))?,
        hound::SampleFormat::Int => {
            // Convert i16 samples to f32
            let max_val = i16::MAX as f32;
            reader
                .samples::<i16>()
                .map(|s| s.map(|v| v as f32 / max_val))
                .collect::<Result<Vec<_>, _>>()
                .map_err(|e| format!("Failed to read samples: {}", e))?
        }
    };

    if samples.is_empty() {
        return Ok(true); // Empty audio is considered silent
    }

    // Calculate RMS
    let sum_squares: f32 = samples.iter().map(|&s| s * s).sum();
    let rms = (sum_squares / samples.len() as f32).sqrt();

    // Also check peak amplitude
    let peak = samples.iter().map(|&s| s.abs()).fold(0.0f32, f32::max);

    // Thresholds for silence detection
    const RMS_THRESHOLD: f32 = 0.01; // Very low RMS indicates silence
    const PEAK_THRESHOLD: f32 = 0.02; // Very low peak indicates silence

    // Audio is considered silent if both RMS and peak are below thresholds
    let is_silent = rms < RMS_THRESHOLD && peak < PEAK_THRESHOLD;

    logger::debug(&format!(
        "Audio analysis - RMS: {:.4}, Peak: {:.4}, Silent: {}",
        rms, peak, is_silent
    ));

    Ok(is_silent)
}
