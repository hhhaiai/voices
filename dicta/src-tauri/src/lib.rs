use tauri::Manager;

#[cfg(target_os = "macos")]
use tauri::ActivationPolicy;

use tauri_plugin_posthog::{PostHogConfig, PostHogOptions};
use tauri_plugin_store::StoreExt;

mod commands;
mod error;
mod features;
mod menu;
mod types;
mod utils;

#[cfg(target_os = "macos")]
use commands::{check_speech_recognition_permission, request_speech_recognition_permission};
use menu::rebuild_tray_menu_command;

use features::ai_processing::post_process_transcript;
use features::audio::{
    cancel_recording, enumerate_audio_devices, force_reset_recording, get_recording_state,
    start_recording, stop_recording, AudioRecorder, RecordingStateManager,
};
use features::cache::SettingsCache;
use features::data::{export_all_data, import_all_data, import_from_json};
use features::models::{
    auto_start_selected_models, debug_ai_settings, delete_local_model, download_local_model,
    get_all_models, get_local_model_status, start_local_model, stop_local_model, LocalModelManager,
};
use features::recordings::{delete_recording, get_all_transcriptions, get_recording_audio_path};
use features::security::{get_api_key, has_api_key, remove_api_key, store_api_key};
use features::shortcuts::{
    disable_global_shortcuts, enable_global_shortcuts, register_command_mode_shortcut,
    register_escape_shortcut, register_ptt_shortcut, unregister_command_mode_shortcut,
    unregister_escape_shortcut, unregister_ptt_shortcut, update_command_mode_shortcut,
    update_paste_shortcut, update_ptt_shortcut, update_voice_input_shortcut,
    RecordingShortcutHandler, ShortcutManager,
};
use features::transcription::{
    get_last_transcript, paste_last_transcript, transcribe_and_process, transcribe_uploaded_file,
};
use features::updates::{check_for_updates, download_and_install_update};
use utils::logger;

use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Mutex;

pub const SPOTLIGHT_LABEL: &str = "voice-input";

#[cfg(target_os = "macos")]
#[tauri::command]
fn set_show_in_dock(_app: tauri::AppHandle, _show: bool) -> Result<(), String> {
    // Always use Accessory mode to ensure voice input pill works on:
    // - Full-screen apps
    // - All monitors/screens
    // - All desktop spaces
    // This means the app never shows in the dock, which is typical for menubar apps
    log::info!("set_show_in_dock called but app always runs in Accessory mode");
    Ok(())
}

/// Get a persistent device ID that survives app reinstalls
/// Uses the machine's hardware UUID
#[tauri::command]
fn get_device_id() -> Result<String, String> {
    machine_uid::get().map_err(|e| format!("Failed to get device ID: {}", e))
}

/// Invalidate the settings cache to reload from in-memory store.
///
/// IMPORTANT: This does NOT reload from disk. The frontend writes to the store
/// first, then calls this to update the cache. This design prevents deadlocks
/// when settings are changed while recording is active.
///
/// The cache uses atomic swap semantics, so this operation is very fast and
/// won't block readers (e.g., the audio thread reading settings).
#[tauri::command]
async fn invalidate_settings_cache(app: tauri::AppHandle) -> Result<(), String> {
    // Run on blocking thread pool to avoid any potential main thread blocking
    let result = tokio::task::spawn_blocking(move || {
        if let Some(cache) =
            app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>()
        {
            cache.invalidate(&app)?;
            log::debug!("Settings cache invalidated via command");
        }
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("Task failed: {}", e))?;

    result
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_version = env!("CARGO_PKG_VERSION");

    #[cfg(debug_assertions)]
    let devtools = tauri_plugin_devtools::init();

    let local_model_manager = Arc::new(Mutex::new(LocalModelManager::new()));
    let shortcut_manager = ShortcutManager::new();

    // Audio recording state (using parking_lot for faster locking)
    let audio_recorder = Arc::new(parking_lot::Mutex::new(AudioRecorder::new()));
    let recording_state_manager = Arc::new(RecordingStateManager::new());
    let recording_shortcut_handler = Arc::new(RecordingShortcutHandler::new());

    // Settings cache for reducing disk I/O
    let settings_cache = Arc::new(SettingsCache::new());

    let mut builder = tauri::Builder::default()
        .manage(local_model_manager)
        .manage(shortcut_manager)
        .manage(audio_recorder)
        .manage(recording_state_manager)
        .manage(recording_shortcut_handler)
        .manage(settings_cache)
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_autostart::Builder::new().build())
        .plugin(tauri_plugin_mic_recorder::init())
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            // When a second instance is launched, bring the existing window to focus
            if let Some(win) = app.get_webview_window("main") {
                let _ = win.show();
                let _ = win.set_focus();
            }
        }))
        .plugin(tauri_plugin_posthog::init(PostHogConfig {
            api_key: "phc_JbGCteuLKzFMg8YYUTMPNvup2iRyytw2DAqET76DUIM".to_string(),
            api_host: "https://us.i.posthog.com".to_string(),
            options: Some(PostHogOptions {
                disable_session_recording: Some(true),
                capture_pageview: Some(false),
                capture_pageleave: Some(false),
                ..Default::default()
            }),
        }));

    // Only initialize logging plugin if devtools is not enabled
    // Devtools plugin initializes logging automatically, so we skip it in debug mode
    #[cfg(not(debug_assertions))]
    {
        builder = builder.plugin(logger::setup_logging().build());
    }

    #[cfg(target_os = "macos")]
    {
        builder = builder
            .plugin(tauri_nspanel::init())
            .plugin(tauri_plugin_macos_permissions::init());
    }

    #[cfg(debug_assertions)]
    {
        builder = builder.plugin(devtools);
    }

    #[cfg(target_os = "macos")]
    let setup_fn = move |app: &mut tauri::App| {
        // Setup panic handler
        logger::info("🚀 PANIC_HANDLER_SETUP STARTING");
        logger::debug_with(
            "Setting up panic handler",
            &[("component", "panic_handler")],
        );

        std::panic::set_hook(Box::new(|panic_info| {
            let location = panic_info
                .location()
                .map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()))
                .unwrap_or_else(|| "unknown location".to_string());

            let message = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
                s.clone()
            } else {
                "Unknown panic payload".to_string()
            };

            log::error!("💥 CRITICAL PANIC at {}: {}", location, message);
            logger::error("❌ PANIC FAILED: Application panic occurred");
            logger::error_with(
                "Panic details",
                &[
                    ("panic_location", &location),
                    ("panic_message", &message),
                    ("severity", "critical"),
                ],
            );
            logger::error(&format!("Application panic at {}: {}", location, message));

            // Try to save panic info to a crash file for debugging
            if let Ok(home_dir) = std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")) {
                let crash_file = std::path::Path::new(&home_dir).join(".dicta_crash.log");
                let _ = std::fs::write(
                    &crash_file,
                    format!(
                        "Panic at {}: {}\nFull info: {:?}\nTime: {:?}",
                        location,
                        message,
                        panic_info,
                        chrono::Local::now()
                    ),
                );
            }
        }));

        log::info!("✅ Panic handler configured");
        logger::info(&format!(
            "🚀 LIFECYCLE APPLICATION_START - Version: {}",
            app_version
        ));

        let store = app
            .store("settings")
            .map_err(|e| format!("Failed to get settings store: {}", e))?;

        // Initialize settings cache
        if let Some(cache) = app.try_state::<Arc<SettingsCache>>() {
            if let Err(e) = cache.initialize(&app.handle()) {
                log::warn!("Failed to initialize settings cache: {}", e);
            } else {
                log::debug!("Settings cache initialized successfully");
            }
        }

        // Migrate API keys from legacy encrypted storage to system keychain
        // and sync hasApiKey flags with actual keychain state
        let app_handle_migration = app.app_handle().clone();
        tauri::async_runtime::spawn(async move {
            // First, migrate any legacy keys
            match features::security::migration::migrate_legacy_api_keys(&app_handle_migration)
                .await
            {
                Ok(result) => {
                    if result.migrated_count > 0 {
                        log::info!(
                            "API key migration completed: {} keys migrated to keychain",
                            result.migrated_count
                        );
                    }
                }
                Err(e) => {
                    log::error!("API key migration failed: {}", e);
                }
            }

            // Then, sync hasApiKey flags with keychain state
            // This ensures flags are accurate even if models.json is out of sync
            if let Err(e) = features::security::sync_api_key_flags(&app_handle_migration).await {
                log::error!("Failed to sync API key flags: {}", e);
            }
        });

        // Always use Accessory mode to ensure voice input pill works on:
        // - Full-screen apps
        // - All monitors/screens
        // - All desktop spaces
        // This means the app never shows in the dock (menubar app behavior)
        app.set_activation_policy(ActivationPolicy::Accessory);
        logger::info("App running in Accessory mode (no dock icon)");

        // Check onboarding completion status
        let onboarding_complete = if let Some(settings) = store.get("settings") {
            settings
                .get("onboarding")
                .and_then(|onboarding| onboarding.get("completed"))
                .and_then(|v| v.as_bool())
                .unwrap_or(false)
        } else {
            false // Default to not completed if no settings found
        };

        let handle = app.app_handle();

        let model_manager_state = app.state::<Arc<Mutex<LocalModelManager>>>();
        let model_manager_cleanup = model_manager_state.inner().clone();

        menu::setup_tray(app, model_manager_cleanup.clone())?;
        menu::setup_menu_bar(app)?;

        if let Some(window) = app.get_webview_window("main") {
            let window_clone = window.clone();
            window.on_window_event(move |event| {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                    let _ = window_clone.hide();
                }
            });

            // Disable context menu in production
            #[cfg(not(debug_assertions))]
            {
                let _ = window
                    .eval("document.addEventListener('contextmenu', e => e.preventDefault());");
            }

            // Show window if onboarding is not complete (user needs to complete onboarding)
            if !onboarding_complete {
                let _ = window.show();
                let _ = window.set_focus();
                log::info!("Showing main window for onboarding (onboarding not complete)");
            }
        }

        features::window::setup_pill_window(&handle)?;
        features::window::setup_toast_window(&handle)?;
        features::window::setup_command_result_window(&handle)?;

        // Start pill window position monitor (tracks screen changes)
        #[cfg(target_os = "macos")]
        features::window::start_pill_window_monitor(handle.clone());

        features::shortcuts::register_voice_input_shortcut(app)?;

        let app_handle = app.app_handle().clone();
        let model_manager_clone = model_manager_cleanup.clone();
        tauri::async_runtime::spawn(async move {
            if let Err(e) = auto_start_selected_models(&app_handle, model_manager_clone).await {
                logger::error(&format!("Failed to auto-start models on startup: {}", e));
            }
        });

        logger::info("🚀 LOG_CLEANUP STARTING");
        logger::debug_with("Cleaning up old logs", &[("retention_days", "30")]);

        let app_handle_cleanup = app.app_handle().clone();
        tauri::async_runtime::spawn(async move {
            let cleanup_start = Instant::now();
            match commands::clear_old_logs(app_handle_cleanup, 30).await {
                Ok(deleted) => {
                    let duration_ms = cleanup_start.elapsed().as_millis() as u64;
                    logger::info(&format!("✅ LOG_CLEANUP COMPLETE in {}ms", duration_ms));
                    logger::debug_with(
                        "Log cleanup complete",
                        &[("files_deleted", &deleted.to_string())],
                    );
                    if deleted > 0 {
                        log::info!("🧹 Cleaned up {} old log files", deleted);
                    }
                }
                Err(e) => {
                    logger::error(&format!("❌ LOG_CLEANUP FAILED: {}", e));
                    logger::debug_with("Log cleanup failed", &[("retention_days", "30")]);
                    log::warn!("Failed to clean up old logs: {}", e);
                }
            }
        });

        Ok(())
    };

    let app = builder
        .invoke_handler(tauri::generate_handler![
            transcribe_and_process,
            post_process_transcript,
            get_all_models,
            // Local model download commands
            download_local_model,
            delete_local_model,
            // Local model lifecycle commands
            start_local_model,
            stop_local_model,
            get_local_model_status,
            debug_ai_settings,
            // Secure API key storage
            store_api_key,
            get_api_key,
            remove_api_key,
            has_api_key,
            // Audio devices
            enumerate_audio_devices,
            // Audio recording
            start_recording,
            stop_recording,
            cancel_recording,
            get_recording_state,
            force_reset_recording,
            // Clipboard utilities
            features::clipboard::get_focused_app,
            features::clipboard::check_accessibility_permission,
            // Shortcuts management
            update_voice_input_shortcut,
            update_paste_shortcut,
            update_command_mode_shortcut,
            register_command_mode_shortcut,
            unregister_command_mode_shortcut,
            register_ptt_shortcut,
            unregister_ptt_shortcut,
            update_ptt_shortcut,
            register_escape_shortcut,
            unregister_escape_shortcut,
            enable_global_shortcuts,
            disable_global_shortcuts,
            // Transcription utilities
            get_last_transcript,
            paste_last_transcript,
            transcribe_uploaded_file,
            // Recordings management
            get_all_transcriptions,
            delete_recording,
            get_recording_audio_path,
            // System preferences
            set_show_in_dock,
            invalidate_settings_cache,
            // Data export/import
            export_all_data,
            import_all_data,
            import_from_json,
            // Haptic feedback
            utils::haptic::trigger_haptic_feedback,
            // Tray menu
            rebuild_tray_menu_command,
            // Speech recognition permissions (macOS)
            #[cfg(target_os = "macos")]
            check_speech_recognition_permission,
            #[cfg(target_os = "macos")]
            request_speech_recognition_permission,
            // Updates
            check_for_updates,
            download_and_install_update,
            // Analytics
            get_device_id,
        ])
        .setup(setup_fn)
        .build(tauri::generate_context!())
        .expect("error while building tauri application");

    // Get local model manager for cleanup on exit
    let local_model_manager_cleanup = app.state::<Arc<Mutex<LocalModelManager>>>().inner().clone();

    app.run(move |_app_handle, event| {
        if let tauri::RunEvent::ExitRequested { .. } = event {
            // Cleanup local model before app exits using Tauri's async runtime
            // IMPORTANT: Don't create a new tokio runtime here - use tauri's spawned task
            // to avoid "Cannot start a runtime from within a runtime" panic
            cleanup_on_exit(local_model_manager_cleanup.clone());
        }
    });
}

/// Safely cleanup resources on app exit without creating nested runtimes.
///
/// Uses a blocking approach with timeout to ensure cleanup completes
/// without hanging indefinitely.
fn cleanup_on_exit(model_manager: Arc<Mutex<LocalModelManager>>) {
    use std::time::Duration;

    // Try to unload the model with a timeout to prevent hanging
    let cleanup_timeout = Duration::from_secs(3);

    // Use std::thread to avoid runtime conflicts
    let handle = std::thread::spawn(move || {
        // Create a minimal runtime just for this cleanup
        // This is safe because we're in a new thread, not inside an async context
        if let Ok(rt) = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
        {
            let result = rt.block_on(async {
                // Use timeout to prevent indefinite waiting
                match tokio::time::timeout(Duration::from_secs(2), model_manager.lock()).await {
                    Ok(mut manager) => {
                        manager.unload_model();
                        log::info!("Local model stopped on app exit");
                        Ok(())
                    }
                    Err(_) => {
                        log::warn!("Timeout waiting for model manager lock during exit cleanup");
                        Err("Timeout")
                    }
                }
            });

            if let Err(e) = result {
                log::warn!("Exit cleanup failed: {}", e);
            }
        } else {
            log::warn!("Failed to create cleanup runtime - skipping model unload");
        }
    });

    // Wait for cleanup thread with timeout
    match handle.join() {
        Ok(_) => log::debug!("Exit cleanup completed"),
        Err(_) => log::warn!("Exit cleanup thread panicked"),
    }

    // Give a brief moment for cleanup to finalize
    std::thread::sleep(std::time::Duration::from_millis(100));
}
