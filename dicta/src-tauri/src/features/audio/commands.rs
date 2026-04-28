use super::player::{play_error_sound, play_recording_start_sound, play_recording_stop_sound};
use super::recorder::AudioRecorder;
use super::state::{RecordingState, RecordingStateManager};
use crate::types::settings::VoiceInputDisplayMode;
use parking_lot::Mutex;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tauri::{command, AppHandle, Emitter, Manager, State};
use tauri_plugin_store::StoreExt;
use ts_rs::TS;

// Debounce duration to prevent rapid toggling
const COMMAND_DEBOUNCE_MS: u64 = 300;

// Lock timeout duration
const LOCK_TIMEOUT: Duration = Duration::from_secs(2);

// Global debounce state using parking_lot for faster locking
static LAST_COMMAND_TIME: parking_lot::Mutex<Option<Instant>> = parking_lot::Mutex::new(None);

/// Try to acquire a parking_lot mutex with timeout
fn try_lock_with_timeout<T>(
    mutex: &Mutex<T>,
    timeout: Duration,
) -> Result<parking_lot::MutexGuard<'_, T>, String> {
    mutex
        .try_lock_for(timeout)
        .ok_or_else(|| "Lock acquisition timed out - operation in progress".to_string())
}

/// Hide the recording window
#[cfg(target_os = "macos")]
fn hide_recording_window(app: &AppHandle) {
    use tauri::Manager;

    if let Some(window) = app.get_webview_window("voice-input") {
        let _ = window.hide();
    }

    crate::features::window::set_pill_monitor_active(false);
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/voice-input/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct RecordingResponse {
    pub success: bool,
    pub state: RecordingState,
    pub error: Option<String>,
    pub file_path: Option<String>,
}

/// Payload for voice-input-mode event sent to React
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VoiceInputModePayload {
    pub display_mode: VoiceInputDisplayMode,
}

#[command]
pub async fn start_recording(
    app: AppHandle,
    recorder: State<'_, Arc<Mutex<AudioRecorder>>>,
    state_manager: State<'_, Arc<RecordingStateManager>>,
) -> Result<RecordingResponse, String> {
    log::info!("Start recording command called");

    // Debounce rapid commands
    {
        let mut last_time = LAST_COMMAND_TIME.lock();
        let now = Instant::now();
        if let Some(last) = *last_time {
            if now.duration_since(last) < Duration::from_millis(COMMAND_DEBOUNCE_MS) {
                log::warn!("Command debounced - too rapid");
                return Ok(RecordingResponse {
                    success: false,
                    state: state_manager.get_state(),
                    error: Some("Please wait before toggling again".to_string()),
                    file_path: None,
                });
            }
        }
        *last_time = Some(now);
    }

    // Hide any existing toast window immediately
    if let Err(e) = crate::features::window::toast_window::hide_toast(&app) {
        log::warn!("Failed to hide toast: {}", e);
    }

    // Check current state - reject if in transition
    let current_state = state_manager.get_state();
    if matches!(
        current_state,
        RecordingState::Starting | RecordingState::Stopping | RecordingState::Transcribing
    ) {
        log::warn!(
            "Cannot start recording - operation in progress: {:?}",
            current_state
        );
        return Ok(RecordingResponse {
            success: false,
            state: current_state,
            error: Some("Operation in progress, please wait".to_string()),
            file_path: None,
        });
    }

    // Check if already recording
    if state_manager.is_recording() {
        log::warn!("Already recording");
        return Ok(RecordingResponse {
            success: false,
            state: state_manager.get_state(),
            error: Some("Already recording".to_string()),
            file_path: None,
        });
    }

    // Check if a speech-to-text model is selected and downloaded
    if let Err(e) = check_model_available(&app) {
        log::warn!("Model not available: {}", e);
        log::info!("Skipping recording - model not downloaded or selected");
        // Show error toast to inform user
        let _ = crate::features::window::toast_window::show_toast(
            &app,
            &e,
            crate::features::window::toast_window::ToastType::Error,
            1.0,
        );
        return Ok(RecordingResponse {
            success: false,
            state: state_manager.get_state(),
            error: Some(e),
            file_path: None,
        });
    }

    // Validate API keys for cloud models before starting recording
    if let Err(e) = super::validation::validate_pre_recording(&app).await {
        let error_message = e.user_message();
        log::warn!("Pre-recording validation failed: {}", error_message);
        // Show error toast to inform user
        let _ = crate::features::window::toast_window::show_toast(
            &app,
            &error_message,
            crate::features::window::toast_window::ToastType::Error,
            1.0,
        );
        return Ok(RecordingResponse {
            success: false,
            state: state_manager.get_state(),
            error: Some(error_message),
            file_path: None,
        });
    }

    // Get settings from cache (faster) with fallback to direct store access
    let (device_id, play_sound, display_mode) = if let Some(cache) =
        app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>()
    {
        (
            cache.get_microphone_device_id(),
            cache.get_play_sound_on_recording().unwrap_or(true),
            cache.get_display_mode(),
        )
    } else {
        // Fallback to direct store access if cache not available
        let store = app
            .store("settings")
            .map_err(|e| format!("Failed to get settings: {}", e))?;
        let settings = store.get("settings");

        let device_id = settings
            .as_ref()
            .and_then(|s| s.as_object())
            .and_then(|obj| obj.get("voiceInput").and_then(|v| v.as_object()))
            .and_then(|obj| obj.get("microphoneDeviceId"))
            .and_then(|d| d.as_str())
            .map(String::from);

        let play_sound = settings
            .as_ref()
            .and_then(|s| s.as_object())
            .and_then(|obj| obj.get("system").and_then(|sys| sys.as_object()))
            .and_then(|obj| obj.get("playSoundOnRecording"))
            .and_then(|p| p.as_bool())
            .unwrap_or(true);

        let display_mode = settings
            .as_ref()
            .and_then(|s| s.as_object())
            .and_then(|obj| obj.get("voiceInput").and_then(|v| v.as_object()))
            .and_then(|obj| obj.get("displayMode"))
            .and_then(|d| d.as_str())
            .and_then(|s| match s {
                "standard" => Some(VoiceInputDisplayMode::Standard),
                "minimal" => Some(VoiceInputDisplayMode::Minimal),
                _ => None,
            })
            .unwrap_or(VoiceInputDisplayMode::Standard);

        (device_id, play_sound, display_mode)
    };

    // Transition to Starting state
    state_manager
        .set_state(RecordingState::Starting)
        .map_err(|e| format!("State transition failed: {}", e))?;

    // Emit state change
    let _ = app.emit("recording-state-changed", RecordingState::Starting);

    let timestamp = chrono::Local::now().timestamp_millis();
    let recording_folder =
        crate::features::recordings::storage::create_recording_folder(&app, timestamp)?;
    let file_path = recording_folder.join("audio.wav");

    state_manager.set_current_file(Some(file_path.clone()));
    state_manager.set_start_time(Some(timestamp));
    state_manager.set_recording_device(device_id.clone());

    if play_sound {
        let _ = play_recording_start_sound();
    }

    // Try to acquire recorder lock with timeout to prevent deadlocks
    let mut recorder_guard = try_lock_with_timeout(&recorder, LOCK_TIMEOUT)?;

    // Set app handle for emitting audio levels
    recorder_guard.set_app_handle(app.clone());

    // Show the voice input window with appropriate display mode
    #[cfg(target_os = "macos")]
    {
        use tauri::Manager;

        if let Some(window) = app.get_webview_window("voice-input") {
            // Emit display mode to React BEFORE showing window to avoid button flash
            let _ = app.emit(
                "voice-input-mode",
                VoiceInputModePayload {
                    display_mode: display_mode.clone(),
                },
            );

            // Configure window size and position based on display mode
            if let Err(e) =
                crate::features::window::configure_pill_window_for_mode(&app, &display_mode)
            {
                log::warn!("Failed to configure pill window for mode: {:?}", e);
                if let Err(e) =
                    crate::features::window::position_pill_window_on_current_screen(&app)
                {
                    log::warn!("Failed to position pill window: {:?}", e);
                }
            }

            let _ = window.show();

            log::info!(
                "Voice input window shown with mode {:?} before recording start",
                display_mode
            );
        }
    }

    match recorder_guard.start_recording(&file_path, device_id) {
        Ok(_) => {
            state_manager
                .set_state(RecordingState::Recording)
                .map_err(|e| format!("State transition failed: {}", e))?;

            let _ = app.emit("recording-state-changed", RecordingState::Recording);

            // Enable active pill window monitoring during recording
            #[cfg(target_os = "macos")]
            crate::features::window::set_pill_monitor_active(true);

            // Register Escape shortcut for canceling recording
            if app
                .try_state::<crate::features::shortcuts::ShortcutManager>()
                .is_some()
            {
                let app_clone = app.clone();
                tauri::async_runtime::spawn(async move {
                    if let Err(e) = crate::features::shortcuts::register_escape_shortcut(
                        app_clone.clone(),
                        app_clone.state(),
                    )
                    .await
                    {
                        log::error!("Failed to register Escape shortcut: {}", e);
                    }
                });
            } else {
                log::warn!("ShortcutManager not available, cannot register Escape");
            }

            log::info!("Recording started successfully");
            Ok(RecordingResponse {
                success: true,
                state: RecordingState::Recording,
                error: None,
                file_path: Some(file_path.to_string_lossy().to_string()),
            })
        }
        Err(e) => {
            log::error!("Failed to start recording: {}", e);

            state_manager.force_set_state(RecordingState::Error);
            state_manager.set_error(Some(e.clone()));

            // Clean up the recording folder since recording failed
            if let Some(parent) = file_path.parent() {
                if parent.exists() {
                    if let Err(cleanup_err) = std::fs::remove_dir_all(parent) {
                        log::warn!(
                            "Failed to cleanup recording folder after error: {}",
                            cleanup_err
                        );
                    } else {
                        log::info!("Cleaned up recording folder after recording failure");
                    }
                }
            }
            state_manager.set_current_file(None);
            state_manager.set_start_time(None);
            state_manager.set_recording_device(None);

            if play_sound {
                let _ = play_error_sound();
            }

            let _ = app.emit("recording-state-changed", RecordingState::Error);

            #[cfg(target_os = "macos")]
            hide_recording_window(&app);

            Err(e)
        }
    }
}

/// Stop recording command
#[command]
pub async fn stop_recording(
    app: AppHandle,
    recorder: State<'_, Arc<Mutex<AudioRecorder>>>,
    state_manager: State<'_, Arc<RecordingStateManager>>,
) -> Result<RecordingResponse, String> {
    log::info!("Stop recording command called");

    // Debounce rapid commands
    {
        let mut last_time = LAST_COMMAND_TIME.lock();
        let now = Instant::now();
        if let Some(last) = *last_time {
            if now.duration_since(last) < Duration::from_millis(COMMAND_DEBOUNCE_MS) {
                log::warn!("Stop command debounced - too rapid");
                return Ok(RecordingResponse {
                    success: false,
                    state: state_manager.get_state(),
                    error: Some("Please wait before toggling again".to_string()),
                    file_path: None,
                });
            }
        }
        *last_time = Some(now);
    }

    // Check current state - if already stopping/transcribing, don't interrupt
    let current_state = state_manager.get_state();
    if matches!(
        current_state,
        RecordingState::Stopping | RecordingState::Transcribing
    ) {
        log::warn!("Already stopping/transcribing: {:?}", current_state);
        return Ok(RecordingResponse {
            success: false,
            state: current_state,
            error: Some("Already processing, please wait".to_string()),
            file_path: None,
        });
    }

    // Check if not recording
    if !state_manager.is_recording() {
        log::warn!("Not currently recording");
        return Ok(RecordingResponse {
            success: false,
            state: state_manager.get_state(),
            error: Some("Not recording".to_string()),
            file_path: None,
        });
    }

    // Get play sound setting from cache (faster) with fallback
    let play_sound = if let Some(cache) =
        app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>()
    {
        cache.get_play_sound_on_recording().unwrap_or(true)
    } else {
        let store = app.store("settings").map_err(|e| e.to_string())?;
        let settings = store.get("settings");
        settings
            .as_ref()
            .and_then(|s| s.as_object())
            .and_then(|obj| obj.get("system").and_then(|sys| sys.as_object()))
            .and_then(|obj| obj.get("playSoundOnRecording"))
            .and_then(|p| p.as_bool())
            .unwrap_or(true)
    };

    // Transition to Stopping state
    state_manager
        .set_state(RecordingState::Stopping)
        .map_err(|e| format!("State transition failed: {}", e))?;

    // Emit state change
    let _ = app.emit("recording-state-changed", RecordingState::Stopping);

    // Unregister Escape shortcut
    if app
        .try_state::<crate::features::shortcuts::ShortcutManager>()
        .is_some()
    {
        let app_clone = app.clone();
        tauri::async_runtime::spawn(async move {
            if let Err(e) = crate::features::shortcuts::unregister_escape_shortcut(
                app_clone.clone(),
                app_clone.state(),
            )
            .await
            {
                log::error!("Failed to unregister Escape shortcut: {}", e);
            }
        });
    } else {
        log::warn!("ShortcutManager not available, cannot unregister Escape");
    }

    // Stop recording - use timeout to prevent deadlocks
    let mut recorder_guard = try_lock_with_timeout(&recorder, LOCK_TIMEOUT)?;

    match recorder_guard.stop_recording() {
        Ok(_) => {
            let file_path = state_manager.get_current_file();

            if play_sound {
                let _ = play_recording_stop_sound();
            }

            drop(recorder_guard);

            if let Some(ref audio_path) = file_path {
                let app_clone = app.clone();
                let state_manager_clone = state_manager.inner().clone();
                let audio_path_clone = audio_path.clone();

                // Get recording metadata
                let recording_device = state_manager.get_recording_device();
                let start_time = state_manager.get_start_time();

                tokio::spawn(async move {
                    state_manager_clone.force_set_state(RecordingState::Transcribing);
                    let _ = app_clone.emit("recording-state-changed", RecordingState::Transcribing);

                    // Extract timestamp from the folder path (folder name is the timestamp)
                    let timestamp = audio_path_clone
                        .parent()
                        .and_then(|p| p.file_name())
                        .and_then(|n| n.to_str())
                        .and_then(|s| s.parse::<i64>().ok())
                        .unwrap_or_else(|| chrono::Local::now().timestamp_millis());

                    // Calculate duration in seconds
                    let duration = start_time.map(|start| {
                        let end_time = chrono::Local::now().timestamp_millis();
                        ((end_time - start) as f64) / 1000.0
                    });

                    match crate::utils::async_fs::read_file(&audio_path_clone).await {
                        Ok(audio_data) => {
                            let transcription_settings = get_transcription_settings(&app_clone);

                            let request =
                                crate::features::transcription::orchestrator::TranscribeRequest {
                                    audio_data,
                                    timestamp,
                                    duration,
                                    language: transcription_settings.language,
                                    recording_device,
                                    translate: transcription_settings.translate_to_english,
                                };

                            if let Some(local_model_state) =
                                app_clone.try_state::<Arc<
                                    tokio::sync::Mutex<crate::features::models::LocalModelManager>,
                                >>()
                            {
                                match crate::features::transcription::orchestrator::transcribe_and_process(
                                    request,
                                    app_clone.clone(),
                                    local_model_state,
                                ).await {
                                    Ok(_) => {
                                        log::info!("Transcription completed successfully");
                                    }
                                    Err(e) => {
                                        log::error!("Transcription failed: {}", e);

                                        // Show error toast
                                        let _ = crate::features::window::show_toast(
                                            &app_clone,
                                            &format!("Transcription failed: {}", e),
                                            crate::features::window::ToastType::Error,
                                            1.0, // Always show errors
                                        );

                                        // Clean up the recording folder since transcription failed
                                        if let Some(parent) = audio_path_clone.parent() {
                                            if crate::utils::async_fs::exists(parent).await {
                                                if let Err(cleanup_err) = crate::utils::async_fs::remove_dir_all(parent).await {
                                                    log::warn!("Failed to cleanup recording folder after transcription error: {}", cleanup_err);
                                                } else {
                                                    log::info!("Cleaned up recording folder after transcription failure");
                                                }
                                            }
                                        }

                                        state_manager_clone.force_set_state(RecordingState::Error);
                                        state_manager_clone.set_error(Some(format!("Transcription failed: {}", e)));
                                        let _ = app_clone.emit("recording-state-changed", RecordingState::Error);
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            log::error!("Failed to read audio file: {}", e);

                            // Show error toast
                            let _ = crate::features::window::show_toast(
                                &app_clone,
                                "Failed to read audio file",
                                crate::features::window::ToastType::Error,
                                1.0, // Always show errors
                            );

                            // Clean up the recording folder since we couldn't read the audio
                            if let Some(parent) = audio_path_clone.parent() {
                                if crate::utils::async_fs::exists(parent).await {
                                    if let Err(cleanup_err) =
                                        crate::utils::async_fs::remove_dir_all(parent).await
                                    {
                                        log::warn!("Failed to cleanup recording folder after read error: {}", cleanup_err);
                                    } else {
                                        log::info!(
                                            "Cleaned up recording folder after read failure"
                                        );
                                    }
                                }
                            }

                            state_manager_clone.force_set_state(RecordingState::Error);
                            state_manager_clone
                                .set_error(Some(format!("Failed to read audio file: {}", e)));
                            let _ =
                                app_clone.emit("recording-state-changed", RecordingState::Error);
                        }
                    }

                    // Only transition to Idle if we're not in Error state
                    if state_manager_clone.get_state() != RecordingState::Error {
                        state_manager_clone.force_set_state(RecordingState::Idle);
                        state_manager_clone.set_current_file(None);
                        state_manager_clone.set_start_time(None);
                        state_manager_clone.set_recording_device(None);
                        let _ = app_clone.emit("recording-state-changed", RecordingState::Idle);
                    }

                    // Hide all recording windows
                    #[cfg(target_os = "macos")]
                    hide_recording_window(&app_clone);
                });
            }

            log::info!("Recording stopped successfully");

            Ok(RecordingResponse {
                success: true,
                state: RecordingState::Stopping,
                error: None,
                file_path: file_path.map(|p| p.to_string_lossy().to_string()),
            })
        }
        Err(e) => {
            log::error!("Failed to stop recording: {}", e);

            state_manager.force_set_state(RecordingState::Error);
            state_manager.set_error(Some(e.clone()));

            // Clean up the recording folder since stopping failed
            if let Some(audio_path) = state_manager.get_current_file() {
                if let Some(parent) = audio_path.parent() {
                    if parent.exists() {
                        if let Err(cleanup_err) = std::fs::remove_dir_all(parent) {
                            log::warn!(
                                "Failed to cleanup recording folder after stop error: {}",
                                cleanup_err
                            );
                        } else {
                            log::info!("Cleaned up recording folder after stop failure");
                        }
                    }
                }
            }
            state_manager.set_current_file(None);
            state_manager.set_start_time(None);
            state_manager.set_recording_device(None);

            if play_sound {
                let _ = play_error_sound();
            }

            let _ = app.emit("recording-state-changed", RecordingState::Error);

            // Show error toast (always show errors)
            let _ = crate::features::window::show_toast(
                &app,
                &format!("Recording failed: {}", e),
                crate::features::window::ToastType::Error,
                1.0, // Always show errors
            );

            // Unregister Escape shortcut on error
            if app
                .try_state::<crate::features::shortcuts::ShortcutManager>()
                .is_some()
            {
                let app_clone = app.clone();
                tauri::async_runtime::spawn(async move {
                    if let Err(err) = crate::features::shortcuts::unregister_escape_shortcut(
                        app_clone.clone(),
                        app_clone.state(),
                    )
                    .await
                    {
                        log::error!("Failed to unregister Escape shortcut on error: {}", err);
                    }
                });
            } else {
                log::warn!("ShortcutManager not available, cannot unregister Escape on error");
            }

            // Hide all recording windows on error
            #[cfg(target_os = "macos")]
            hide_recording_window(&app);

            Err(e)
        }
    }
}

/// Cancel recording command (stops recording without transcription)
#[command]
pub async fn cancel_recording(
    app: AppHandle,
    recorder: State<'_, Arc<Mutex<AudioRecorder>>>,
    state_manager: State<'_, Arc<RecordingStateManager>>,
) -> Result<RecordingResponse, String> {
    log::info!("Cancel recording command called");

    // Debounce rapid commands
    {
        let mut last_time = LAST_COMMAND_TIME.lock();
        let now = Instant::now();
        if let Some(last) = *last_time {
            if now.duration_since(last) < Duration::from_millis(COMMAND_DEBOUNCE_MS) {
                log::warn!("Cancel command debounced - too rapid");
                return Ok(RecordingResponse {
                    success: false,
                    state: state_manager.get_state(),
                    error: Some("Please wait before toggling again".to_string()),
                    file_path: None,
                });
            }
        }
        *last_time = Some(now);
    }

    let current_state = state_manager.get_state();

    // Only allow cancel from active states
    if !matches!(
        current_state,
        RecordingState::Recording | RecordingState::Starting
    ) {
        log::warn!("Cannot cancel from state: {:?}", current_state);
        return Ok(RecordingResponse {
            success: false,
            state: current_state,
            error: Some("Not in a cancellable state".to_string()),
            file_path: None,
        });
    }

    // Stop the recorder if recording - use timeout to prevent deadlocks
    if state_manager.is_recording() {
        let mut recorder_guard = try_lock_with_timeout(&recorder, LOCK_TIMEOUT)?;

        if let Err(e) = recorder_guard.stop_recording() {
            log::warn!("Error stopping recorder during cancel: {}", e);
        }
    }

    // Clean up the entire recording folder
    if let Some(file_path) = state_manager.get_current_file() {
        if let Some(parent) = file_path.parent() {
            if parent.exists() {
                if let Err(e) = std::fs::remove_dir_all(parent) {
                    log::warn!("Failed to remove cancelled recording folder: {}", e);
                } else {
                    log::info!("Cleaned up cancelled recording folder");
                }
            }
        }
    }

    state_manager.set_current_file(None);
    state_manager.set_start_time(None);
    state_manager.set_recording_device(None);

    state_manager.force_set_state(RecordingState::Idle);

    let _ = app.emit("recording-state-changed", RecordingState::Idle);

    // Disable active pill window monitoring when not recording
    #[cfg(target_os = "macos")]
    crate::features::window::set_pill_monitor_active(false);

    // Unregister Escape shortcut
    if app
        .try_state::<crate::features::shortcuts::ShortcutManager>()
        .is_some()
    {
        let app_clone = app.clone();
        tauri::async_runtime::spawn(async move {
            if let Err(e) = crate::features::shortcuts::unregister_escape_shortcut(
                app_clone.clone(),
                app_clone.state(),
            )
            .await
            {
                log::error!("Failed to unregister Escape shortcut: {}", e);
            }
        });
    } else {
        log::warn!("ShortcutManager not available, cannot unregister Escape");
    }

    // Get play sound setting from cache (faster) with fallback
    let play_sound = if let Some(cache) =
        app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>()
    {
        cache.get_play_sound_on_recording().unwrap_or(true)
    } else {
        let store = app.store("settings").ok();
        let settings = store.as_ref().and_then(|s| s.get("settings"));
        settings
            .as_ref()
            .and_then(|s| s.as_object())
            .and_then(|obj| obj.get("system").and_then(|sys| sys.as_object()))
            .and_then(|obj| obj.get("playSoundOnRecording"))
            .and_then(|p| p.as_bool())
            .unwrap_or(true)
    };

    if play_sound {
        let _ = play_error_sound();
    }

    // Show toast notification for cancelled recording (always show)
    let _ = crate::features::window::show_toast(
        &app,
        "Recording cancelled",
        crate::features::window::ToastType::Info,
        1.0,
    );

    // Hide recording window immediately, not delayed
    // A delayed hide can race with a new recording starting and hide the new window
    #[cfg(target_os = "macos")]
    hide_recording_window(&app);

    log::info!("Recording cancelled successfully");

    Ok(RecordingResponse {
        success: true,
        state: RecordingState::Idle,
        error: None,
        file_path: None,
    })
}

/// Get current recording state
#[command]
pub async fn get_recording_state(
    state_manager: State<'_, Arc<RecordingStateManager>>,
) -> Result<RecordingResponse, String> {
    Ok(RecordingResponse {
        success: true,
        state: state_manager.get_state(),
        error: state_manager.get_error(),
        file_path: state_manager
            .get_current_file()
            .map(|p| p.to_string_lossy().to_string()),
    })
}

/// Force reset recording state (emergency recovery)
/// Use this when the recording gets stuck in a bad state
#[command]
pub async fn force_reset_recording(
    app: AppHandle,
    state_manager: State<'_, Arc<RecordingStateManager>>,
) -> Result<RecordingResponse, String> {
    log::warn!("Force reset recording called - emergency recovery");

    // Force state back to idle
    state_manager.force_set_state(RecordingState::Idle);
    state_manager.set_current_file(None);
    state_manager.set_start_time(None);
    state_manager.set_recording_device(None);
    state_manager.set_error(None);

    // Reset debounce timer
    *LAST_COMMAND_TIME.lock() = None;

    // Hide all recording windows
    #[cfg(target_os = "macos")]
    hide_recording_window(&app);

    // Emit state change
    let _ = app.emit("recording-state-changed", RecordingState::Idle);

    log::info!("Recording state force reset to Idle");

    Ok(RecordingResponse {
        success: true,
        state: RecordingState::Idle,
        error: None,
        file_path: None,
    })
}

struct TranscriptionSettings {
    language: Option<String>,
    translate_to_english: bool,
}

fn get_transcription_settings(app: &AppHandle) -> TranscriptionSettings {
    let settings = app
        .store("settings")
        .ok()
        .and_then(|store| store.get("settings"));

    let transcription = settings.as_ref().and_then(|s| s.get("transcription"));

    // Check if auto-detect language is enabled
    let auto_detect_language = transcription
        .and_then(|t| t.get("autoDetectLanguage"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    // Check if the selected model is English-only
    let is_english_only_model = is_selected_model_english_only(app);

    // Get selected model ID for logging
    let selected_model_id = transcription
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    log::info!(
        "Transcription settings - Model: {}, AutoDetect: {}, EnglishOnly: {}",
        selected_model_id,
        auto_detect_language,
        is_english_only_model
    );

    // If auto-detect is enabled AND model supports multiple languages, don't pass a language
    // If model is English-only, always use "en" regardless of auto-detect setting
    let language = if is_english_only_model {
        // English-only models can't auto-detect, always use "en"
        log::info!("Using 'en' language (English-only model)");
        Some("en".to_string())
    } else if auto_detect_language {
        // Multilingual model with auto-detect enabled - let Whisper detect the language
        log::info!("Using auto-detect (language=None)");
        None
    } else {
        // Multilingual model without auto-detect - use the selected language
        let lang = transcription
            .and_then(|t| t.get("language"))
            .and_then(|l| l.as_str())
            .map(String::from)
            .or(Some("en".to_string()));
        log::info!("Using selected language: {:?}", lang);
        lang
    };

    // Translate to English is disabled when auto-detect is enabled or model is English-only
    let translate_to_english = if auto_detect_language || is_english_only_model {
        false
    } else {
        transcription
            .and_then(|t| t.get("translateToEnglish"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
    };

    log::info!(
        "Final transcription settings - Language: {:?}, Translate: {}",
        language,
        translate_to_english
    );

    TranscriptionSettings {
        language,
        translate_to_english,
    }
}

/// Check if the currently selected speech-to-text model is English-only
fn is_selected_model_english_only(app: &AppHandle) -> bool {
    // Get selected model ID from settings
    let settings_store = match app.store("settings") {
        Ok(store) => store,
        Err(_) => return false,
    };

    let settings = match settings_store.get("settings") {
        Some(s) => s,
        None => return false,
    };

    let selected_model_id = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str());

    let selected_model_id = match selected_model_id {
        Some(id) => id,
        None => return false,
    };

    // Get models store
    let models_store = match app.store("models.json") {
        Ok(store) => store,
        Err(_) => return false,
    };

    let models_value = match models_store.get("models") {
        Some(v) => v,
        None => return false,
    };

    let models = match models_value.as_array() {
        Some(arr) => arr,
        None => return false,
    };

    // Find the selected model and check its language support
    for model_value in models {
        if let Some(model) = model_value.as_object() {
            let id = model.get("id").and_then(|v| v.as_str()).unwrap_or("");

            if id == selected_model_id {
                // Check languageSupport field
                if let Some(language_support) =
                    model.get("languageSupport").and_then(|v| v.as_str())
                {
                    return language_support == "english_only";
                }

                // Fallback: check if model ID ends with ".en" (English-only indicator)
                return selected_model_id.contains(".en");
            }
        }
    }

    false
}

fn check_model_available(app: &AppHandle) -> Result<(), String> {
    // Get settings to find selected model
    let settings_store = app
        .store("settings")
        .map_err(|e| format!("Failed to get settings store: {}", e))?;

    let settings = settings_store
        .get("settings")
        .ok_or("No settings found in store")?;

    // Get selected model ID
    let selected_model_id = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
        .ok_or("No speech-to-text model selected. Please select a model in settings.")?;

    // Get models store to check if model exists and is downloaded
    let models_store = app
        .store("models.json")
        .map_err(|e| format!("Failed to get models store: {}", e))?;

    let models_value = models_store
        .get("models")
        .ok_or("No models found in store")?;

    let models = models_value.as_array().ok_or("Models is not an array")?;

    // Find the selected model
    for model_value in models {
        let model = model_value.as_object().ok_or("Model is not an object")?;

        let id = model.get("id").and_then(|v| v.as_str()).unwrap_or("");

        if id == selected_model_id {
            let provider = model.get("provider").and_then(|v| v.as_str()).unwrap_or("");

            // For local models, check if downloaded
            if provider == "local-whisper" {
                let is_downloaded = model
                    .get("isDownloaded")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);

                if !is_downloaded {
                    return Err(format!(
                        "Model '{}' is not downloaded. Please download it in the Models page.",
                        id
                    ));
                }
            }

            // Model found and available
            return Ok(());
        }
    }

    Err(format!(
        "Selected model '{}' not found in models store",
        selected_model_id
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_recording_response_serialization() {
        let response = RecordingResponse {
            success: true,
            state: RecordingState::Recording,
            error: None,
            file_path: Some("/path/to/file.wav".to_string()),
        };

        let json = serde_json::to_string(&response).unwrap();
        assert!(json.contains("recording"));
    }
}
