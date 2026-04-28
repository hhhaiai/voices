//! Audio file upload processing
//!
//! Handles transcription of uploaded audio files, applying the same
//! transcription and post-processing pipeline as voice recordings.

use std::sync::Arc;
use std::time::Instant;

use serde::{Deserialize, Serialize};
use tauri::{command, AppHandle, Emitter, State};
use tauri_plugin_store::StoreExt;
use tokio::sync::Mutex;
use ts_rs::TS;

use crate::features::models::LocalModelManager;
use crate::features::recordings::metadata::{
    ApplicationContext, PromptContext, RecordingMetadata, SourceType, SystemContext,
};
use crate::features::recordings::storage::{
    create_recording_folder, save_audio_file, save_metadata,
};
use crate::utils::logger;

use super::orchestrator_helpers::apply_ai_post_processing;
use super::providers::{assemblyai, azure, deepgram, elevenlabs, google, local_whisper, openai};
use super::vocabulary::get_transcription_context;

/// Request for uploading and transcribing an audio file
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct UploadAudioRequest {
    /// Audio file data as bytes
    pub audio_data: Vec<u8>,
    /// Original filename
    pub filename: String,
    /// Optional language code (e.g., "en")
    pub language: Option<String>,
}

/// Response from upload transcription
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct UploadTranscriptionResponse {
    pub success: bool,
    pub id: Option<String>,
    pub text: Option<String>,
    pub error: Option<String>,
}

/// Process an uploaded audio file for transcription
#[command]
pub async fn transcribe_uploaded_file(
    request: UploadAudioRequest,
    app: AppHandle,
    local_model_state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<UploadTranscriptionResponse, String> {
    let start_time = Instant::now();
    let timestamp = chrono::Local::now().timestamp_millis();

    logger::info(&format!(
        "Processing uploaded file: {} ({} bytes)",
        request.filename,
        request.audio_data.len()
    ));

    // Get selected transcription model
    let selected_model = get_selected_model(&app)?;

    // Get settings early for transcription options
    let settings = get_settings(&app)?;
    let translate_to_english = settings
        .get("transcription")
        .and_then(|t| t.get("translateToEnglish"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    // Create recording folder
    let recording_folder = create_recording_folder(&app, timestamp)?;

    // Save audio file (always save for uploaded files)
    save_audio_file(&recording_folder, &request.audio_data)?;

    // Calculate audio duration from WAV header
    let duration_ms = get_audio_duration(&request.audio_data).unwrap_or(0.0);

    // Transcribe using the selected provider
    let raw_transcription = transcribe_with_provider(
        &app,
        request.audio_data.clone(),
        &selected_model,
        request.language.clone(),
        translate_to_english,
        Some(request.filename.clone()),
        local_model_state,
    )
    .await?;

    // Skip if transcription is empty
    if raw_transcription.trim().is_empty() {
        // Clean up folder
        if let Err(e) = std::fs::remove_dir_all(&recording_folder) {
            logger::warn(&format!(
                "Failed to clean up empty transcription folder: {}",
                e
            ));
        }
        return Ok(UploadTranscriptionResponse {
            success: false,
            id: None,
            text: None,
            error: Some("No speech detected in the audio file".to_string()),
        });
    }

    // Check AI post-processing settings
    let ai_processing_enabled = settings
        .get("aiProcessing")
        .and_then(|a| a.get("enabled"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    // Apply AI post-processing if enabled
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
        match apply_ai_post_processing(&app, &raw_transcription, "File Upload", &settings).await {
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
                logger::warn(&format!("Post-processing failed for upload: {}", e));
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

    let processing_time = start_time.elapsed().as_millis() as u64;

    // Create metadata with SourceType::Upload
    let metadata = RecordingMetadata::with_source(
        raw_transcription.clone(),
        final_text.clone(),
        post_processed_text,
        timestamp,
        duration_ms,
        processing_time,
        selected_model.id.clone(),
        get_model_name(&selected_model),
        selected_model.provider.clone(),
        post_processing_model_id,
        post_processing_model_name,
        post_processing_provider,
        request.language.unwrap_or_else(|| "en".to_string()),
        translate_to_english,
        "File Upload".to_string(), // recording_device
        "File Upload".to_string(), // focused_app_name
        "other".to_string(),       // focused_app_category
        ai_processing_enabled,
        style_applied,
        style_category,
        prompt_context,
        true, // has_audio - always true for uploads
        SourceType::Upload,
        Some(request.filename),
    );

    // Save metadata
    save_metadata(&recording_folder, &metadata)?;

    // Emit event for UI update
    app.emit("transcriptions-changed", ())
        .map_err(|e| format!("Failed to emit event: {}", e))?;

    logger::info(&format!(
        "Upload transcription complete in {}ms",
        processing_time
    ));

    Ok(UploadTranscriptionResponse {
        success: true,
        id: Some(timestamp.to_string()),
        text: Some(final_text),
        error: None,
    })
}

/// Get the selected speech-to-text model from settings
fn get_selected_model(app: &AppHandle) -> Result<SelectedModel, String> {
    let settings = get_settings(app)?;
    let selected_model_id = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
        .ok_or("No speech-to-text model selected in settings")?;

    let models_store = app
        .store("models.json")
        .map_err(|e| format!("Failed to get models store: {}", e))?;

    let models_value = models_store
        .get("models")
        .ok_or("No models found in store")?;
    let models = models_value.as_array().ok_or("Models is not an array")?;

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

    Err(format!("Model '{}' not found", selected_model_id))
}

fn get_settings(app: &AppHandle) -> Result<serde_json::Value, String> {
    let store = app
        .store("settings")
        .map_err(|e| format!("Failed to get settings store: {}", e))?;

    store.get("settings").ok_or("No settings found".to_string())
}

/// Get human-readable model name from model ID
fn get_model_name(model: &SelectedModel) -> String {
    if model.id.starts_with("whisper-") {
        let variant = model.id.strip_prefix("whisper-").unwrap_or("unknown");
        format!(
            "Whisper {}",
            variant
                .chars()
                .next()
                .map(|c| c.to_uppercase().to_string())
                .unwrap_or_default()
                + &variant.get(1..).unwrap_or("")
        )
    } else if model.id.starts_with("claude-") {
        "Claude".to_string()
    } else if model.id.starts_with("gpt-") {
        "GPT".to_string()
    } else {
        model.id.clone()
    }
}

#[derive(Debug, Clone)]
struct SelectedModel {
    id: String,
    provider: String,
    path: Option<String>,
}

/// Check if the filename indicates a WAV file
fn is_wav_file(filename: &Option<String>) -> bool {
    filename
        .as_ref()
        .map(|f| f.to_lowercase().ends_with(".wav"))
        .unwrap_or(true) // Default to true for backwards compatibility
}

/// Check if the provider requires WAV format
fn requires_wav_format(provider: &str) -> bool {
    matches!(
        provider,
        "local-whisper" | "candle" | "whisperkit" | "apple-speech"
    )
}

/// Route transcription to the appropriate provider
async fn transcribe_with_provider(
    app: &AppHandle,
    audio_data: Vec<u8>,
    model: &SelectedModel,
    language: Option<String>,
    translate: bool,
    filename: Option<String>,
    local_model_state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<String, String> {
    // Check if local model and non-WAV file
    if requires_wav_format(&model.provider) && !is_wav_file(&filename) {
        return Err(format!(
            "Local models only support WAV format. Please use a cloud model (OpenAI, ElevenLabs) for {} files, or convert to WAV first.",
            filename.as_ref().and_then(|f| f.rsplit('.').next()).unwrap_or("this file type")
        ));
    }

    // Get vocabulary and snippets context for transcription providers
    let vocab_context = get_transcription_context(app);
    let prompt = vocab_context.to_prompt();
    let word_list = if vocab_context.is_empty() {
        None
    } else {
        Some(vocab_context.to_word_list())
    };

    let response = match model.provider.as_str() {
        "openai" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "OpenAI API key not found")?;

            openai::transcribe_with_openai(
                audio_data,
                api_key,
                Some(model.id.clone()),
                language,
                filename,
                prompt.clone(),
            )
            .await?
        }
        "google" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Google API key not found")?;

            let google_language = language
                .map(|lang| format!("{}-US", lang.to_uppercase()))
                .or(Some("en-US".to_string()));

            google::transcribe_with_google(audio_data, api_key, google_language, word_list.clone())
                .await?
        }
        "local-whisper" => {
            local_whisper::transcribe_with_local_whisper(
                audio_data,
                Some(model.id.clone()),
                language,
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        "elevenlabs" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "ElevenLabs API key not found")?;

            elevenlabs::transcribe_with_elevenlabs(
                audio_data,
                api_key,
                Some(model.id.clone()),
                filename,
            )
            .await?
        }
        "candle" => {
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "candle",
                model.path.clone(),
                Some(model.id.clone()),
                language,
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        "whisperkit" => {
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "whisperkit",
                model.path.clone(),
                Some(model.id.clone()),
                language,
                translate,
                prompt.clone(),
                local_model_state,
            )
            .await?
        }
        "apple-speech" => {
            // Apple Speech doesn't support vocabulary hints
            local_whisper::transcribe_with_local_engine(
                audio_data,
                "apple-speech",
                model.path.clone(),
                Some(model.id.clone()),
                language,
                translate,
                None, // Apple Speech doesn't use prompt
                local_model_state,
            )
            .await?
        }
        "assemblyai" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "AssemblyAI API key not found")?;

            assemblyai::transcribe_with_assemblyai(audio_data, api_key, language, word_list.clone())
                .await?
        }
        "deepgram" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Deepgram API key not found")?;

            deepgram::transcribe_with_deepgram(audio_data, api_key, language, word_list.clone())
                .await?
        }
        "azure" => {
            let api_key = crate::features::security::get_api_key_internal(app, &model.id)
                .await
                .map_err(|_| "Azure API key not found")?;

            let azure_language = language.map(|lang| {
                if lang.contains('-') {
                    lang
                } else {
                    format!("{}-US", lang)
                }
            });

            azure::transcribe_with_azure(
                audio_data,
                api_key,
                None,
                azure_language,
                word_list.clone(),
            )
            .await?
        }
        _ => return Err(format!("Unsupported provider: {}", model.provider)),
    };

    Ok(response.text)
}

/// Get audio duration from WAV file header
fn get_audio_duration(audio_data: &[u8]) -> Option<f64> {
    use hound::WavReader;
    use std::io::Cursor;

    let cursor = Cursor::new(audio_data);
    let reader = WavReader::new(cursor).ok()?;
    let spec = reader.spec();
    let num_samples = reader.len() as f64;
    let sample_rate = spec.sample_rate as f64;
    let channels = spec.channels as f64;

    // Duration in milliseconds
    Some((num_samples / channels / sample_rate) * 1000.0)
}

fn create_empty_prompt_context() -> PromptContext {
    PromptContext {
        vocabulary_used: vec![],
        snippets_used: vec![],
        vibe_prompt: None,
        system_context: SystemContext {
            language: "en".to_string(),
            time: chrono::Local::now().format("%H:%M").to_string(),
        },
        application_context: ApplicationContext {
            name: "File Upload".to_string(),
            category: "other".to_string(),
        },
    }
}
