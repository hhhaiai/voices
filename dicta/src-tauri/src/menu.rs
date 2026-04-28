use crate::features::audio::enumerate_audio_devices;
use crate::features::audio::state::RecordingStateManager;
use crate::features::models::LocalModelManager;
use crate::utils::logger;
use serde_json::json;
use std::sync::Arc;
use tauri::menu::{MenuBuilder, MenuItem, PredefinedMenuItem, SubmenuBuilder};
use tauri::tray::TrayIconBuilder;
use tauri::{App, AppHandle, Emitter, Manager, Result};
use tauri_plugin_store::StoreExt;
use tokio::sync::Mutex;

// Popular languages for tray menu (top 7)
const TRAY_LANGUAGES: &[(&str, &str)] = &[
    ("en", "English"),
    ("es", "Spanish"),
    ("fr", "French"),
    ("de", "German"),
    ("pt", "Portuguese"),
    ("zh", "Chinese"),
    ("hi", "Hindi"),
];

/// Sets up the system tray icon and menu
pub fn setup_tray(app: &App, model_manager_cleanup: Arc<Mutex<LocalModelManager>>) -> Result<()> {
    // Get available audio devices
    // IMPORTANT: We use a separate thread to avoid nested runtime issues.
    // Creating a tokio::runtime::Runtime::new().block_on() inside Tauri's
    // existing runtime can cause deadlocks/hangs.
    let devices = std::thread::spawn(|| {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .ok();
        rt.and_then(|rt| rt.block_on(enumerate_audio_devices()).ok())
            .unwrap_or_default()
    })
    .join()
    .unwrap_or_default();

    // Get current microphone device from settings
    let store = app.store("settings").map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to get store: {}", e),
        ))
    })?;
    let current_device_id = store.get("settings").and_then(|settings| {
        settings
            .get("voiceInput")
            .and_then(|voice_input| voice_input.get("microphoneDeviceId"))
            .and_then(|device_id| device_id.as_str().map(|s| s.to_string()))
    });

    // Build microphone submenu dynamically
    let mut microphone_submenu_builder = SubmenuBuilder::new(app, "Microphone");

    // Add "Auto-detect" option with tick if selected
    let auto_detect_label = if current_device_id.is_none() {
        "✓ Auto-detect"
    } else {
        "Auto-detect"
    };
    microphone_submenu_builder = microphone_submenu_builder.item(&MenuItem::with_id(
        app,
        "mic-auto-detect",
        auto_detect_label,
        true,
        None::<&str>,
    )?);

    // Add separator if we have devices
    if !devices.is_empty() {
        microphone_submenu_builder = microphone_submenu_builder.separator();
    }

    // Add each device with tick if selected
    for device in &devices {
        let menu_id = format!("mic-{}", device.device_id);
        let is_selected = current_device_id.as_ref() == Some(&device.device_id);

        let mut label = String::new();
        if is_selected {
            label.push_str("✓ ");
        }
        label.push_str(&device.label);
        if device.is_recommended {
            label.push_str(" (Recommended)");
        }

        microphone_submenu_builder = microphone_submenu_builder.item(&MenuItem::with_id(
            app,
            menu_id.as_str(),
            label.as_str(),
            true,
            None::<&str>,
        )?);
    }

    let microphone_submenu = microphone_submenu_builder.build()?;

    // Get current language and model compatibility for language submenu
    let current_language = store.get("settings").and_then(|settings| {
        settings
            .get("transcription")
            .and_then(|transcription| transcription.get("language"))
            .and_then(|language| language.as_str().map(|s| s.to_string()))
    });

    let is_english_only_model = check_model_is_english_only(app);

    // Build language submenu
    let mut language_submenu_builder = SubmenuBuilder::new(app, "Language");

    for (code, name) in TRAY_LANGUAGES {
        let menu_id = format!("lang-{}", code);
        let is_selected = current_language.as_deref() == Some(*code);

        let mut label = String::new();
        if is_selected {
            label.push_str("✓ ");
        }
        // Show warning for non-English languages when using English-only model
        if is_english_only_model && *code != "en" {
            label.push_str("⚠️ ");
        }
        label.push_str(name);

        language_submenu_builder = language_submenu_builder.item(&MenuItem::with_id(
            app,
            menu_id.as_str(),
            label.as_str(),
            true,
            None::<&str>,
        )?);
    }

    // Add separator and "More Languages..." option
    language_submenu_builder = language_submenu_builder
        .separator()
        .item(&MenuItem::with_id(
            app,
            "lang-more",
            "More Languages...",
            true,
            None::<&str>,
        )?);

    let language_submenu = language_submenu_builder.build()?;

    // Build quick actions submenu
    let quick_actions_submenu = SubmenuBuilder::new(app, "Quick Actions")
        .item(&MenuItem::with_id(
            app,
            "paste-last",
            "Paste Last Transcript",
            true,
            Some("CmdOrCtrl+Shift+V"),
        )?)
        .build()?;

    // Build help submenu
    let help_submenu = SubmenuBuilder::new(app, "Help")
        .item(&MenuItem::with_id(
            app,
            "general-feedback",
            "Send Feedback...",
            true,
            None::<&str>,
        )?)
        .item(&MenuItem::with_id(
            app,
            "report-issue",
            "Report Issue...",
            true,
            None::<&str>,
        )?)
        .separator()
        .item(&MenuItem::with_id(
            app,
            "check-updates",
            "Check for Updates...",
            true,
            None::<&str>,
        )?)
        .build()?;

    let tray_menu = MenuBuilder::new(app)
        // Primary action
        .item(&MenuItem::with_id(app, "home", "Open Dicta", true, None::<&str>)?)
        .separator()
        // Quick actions
        .item(&quick_actions_submenu)
        .separator()
        // Input configuration
        .item(&microphone_submenu)
        .item(&language_submenu)
        .separator()
        // Settings & configuration
        .item(&MenuItem::with_id(
            app,
            "shortcuts",
            "Keyboard Shortcuts...",
            true,
            None::<&str>,
        )?)
        .item(&MenuItem::with_id(
            app,
            "settings-tray",
            "Preferences...",
            true,
            Some("CmdOrCtrl+,"),
        )?)
        .separator()
        // Help & updates
        .item(&help_submenu)
        .separator()
        // Exit
        .item(&MenuItem::with_id(
            app,
            "quit",
            "Quit Dicta",
            true,
            Some("CmdOrCtrl+Q"),
        )?)
        .build()?;

    // Create tray icon with menu
    let _tray = TrayIconBuilder::with_id("main")
        .icon(app.default_window_icon().unwrap().clone())
        .icon_as_template(true)
        .menu(&tray_menu)
        // .show_menu_on_left_click(false)
        .on_menu_event(move |app, event| {
            handle_tray_event(app, event.id().as_ref(), model_manager_cleanup.clone());
        })
        .build(app)?;

    Ok(())
}

/// Rebuilds the tray menu with updated microphone selection
async fn rebuild_tray_menu(
    app: &AppHandle,
    _model_manager: Arc<Mutex<LocalModelManager>>,
) -> Result<()> {
    // Get available audio devices
    let devices = enumerate_audio_devices().await.unwrap_or_default();

    // Get current microphone device from settings
    // IMPORTANT: Do NOT call store.reload() here!
    // The store already has the latest data in memory.
    // Calling reload() is blocking I/O and can cause deadlocks during recording.
    let store = app.store("settings").map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to get store: {}", e),
        ))
    })?;

    let current_device_id = store.get("settings").and_then(|settings| {
        settings
            .get("voiceInput")
            .and_then(|voice_input| voice_input.get("microphoneDeviceId"))
            .and_then(|device_id| device_id.as_str().map(|s| s.to_string()))
    });

    log::info!(
        "Rebuilding tray menu - current microphone device ID: {:?}",
        current_device_id
    );

    // Get current language for language submenu
    let current_language = store.get("settings").and_then(|settings| {
        settings
            .get("transcription")
            .and_then(|transcription| transcription.get("language"))
            .and_then(|language| language.as_str().map(|s| s.to_string()))
    });

    log::info!(
        "Rebuilding tray menu - current language: {:?}",
        current_language
    );

    // Build microphone submenu dynamically
    let mut microphone_submenu_builder = SubmenuBuilder::new(app, "Microphone");

    // Add "Auto-detect" option with tick if selected
    let auto_detect_label = if current_device_id.is_none() {
        "✓ Auto-detect"
    } else {
        "Auto-detect"
    };
    microphone_submenu_builder = microphone_submenu_builder.item(&MenuItem::with_id(
        app,
        "mic-auto-detect",
        auto_detect_label,
        true,
        None::<&str>,
    )?);

    // Add separator if we have devices
    if !devices.is_empty() {
        microphone_submenu_builder = microphone_submenu_builder.separator();
    }

    // Add each device with tick if selected
    for device in &devices {
        let menu_id = format!("mic-{}", device.device_id);
        let is_selected = current_device_id.as_ref() == Some(&device.device_id);

        let mut label = String::new();
        if is_selected {
            label.push_str("✓ ");
        }
        label.push_str(&device.label);
        if device.is_recommended {
            label.push_str(" (Recommended)");
        }

        microphone_submenu_builder = microphone_submenu_builder.item(&MenuItem::with_id(
            app,
            menu_id.as_str(),
            label.as_str(),
            true,
            None::<&str>,
        )?);
    }

    let microphone_submenu = microphone_submenu_builder.build()?;

    let is_english_only_model = check_model_is_english_only(app);

    // Build language submenu
    let mut language_submenu_builder = SubmenuBuilder::new(app, "Language");

    for (code, name) in TRAY_LANGUAGES {
        let menu_id = format!("lang-{}", code);
        let is_selected = current_language.as_deref() == Some(*code);

        let mut label = String::new();
        if is_selected {
            label.push_str("✓ ");
        }
        // Show warning for non-English languages when using English-only model
        if is_english_only_model && *code != "en" {
            label.push_str("⚠️ ");
        }
        label.push_str(name);

        language_submenu_builder = language_submenu_builder.item(&MenuItem::with_id(
            app,
            menu_id.as_str(),
            label.as_str(),
            true,
            None::<&str>,
        )?);
    }

    // Add separator and "More Languages..." option
    language_submenu_builder = language_submenu_builder
        .separator()
        .item(&MenuItem::with_id(
            app,
            "lang-more",
            "More Languages...",
            true,
            None::<&str>,
        )?);

    let language_submenu = language_submenu_builder.build()?;

    // Build quick actions submenu
    let quick_actions_submenu = SubmenuBuilder::new(app, "Quick Actions")
        .item(&MenuItem::with_id(
            app,
            "paste-last",
            "Paste Last Transcript",
            true,
            Some("CmdOrCtrl+Shift+V"),
        )?)
        .build()?;

    // Build help submenu
    let help_submenu = SubmenuBuilder::new(app, "Help")
        .item(&MenuItem::with_id(
            app,
            "general-feedback",
            "Send Feedback...",
            true,
            None::<&str>,
        )?)
        .item(&MenuItem::with_id(
            app,
            "report-issue",
            "Report Issue...",
            true,
            None::<&str>,
        )?)
        .separator()
        .item(&MenuItem::with_id(
            app,
            "check-updates",
            "Check for Updates...",
            true,
            None::<&str>,
        )?)
        .build()?;

    // Rebuild the entire tray menu
    let tray_menu = MenuBuilder::new(app)
        // Primary action
        .item(&MenuItem::with_id(app, "home", "Open Dicta", true, None::<&str>)?)
        .separator()
        // Quick actions
        .item(&quick_actions_submenu)
        .separator()
        // Input configuration
        .item(&microphone_submenu)
        .item(&language_submenu)
        .separator()
        // Settings & configuration
        .item(&MenuItem::with_id(
            app,
            "shortcuts",
            "Keyboard Shortcuts...",
            true,
            None::<&str>,
        )?)
        .item(&MenuItem::with_id(
            app,
            "settings-tray",
            "Preferences...",
            true,
            Some("CmdOrCtrl+,"),
        )?)
        .separator()
        // Help & updates
        .item(&help_submenu)
        .separator()
        // Exit
        .item(&MenuItem::with_id(
            app,
            "quit",
            "Quit Dicta",
            true,
            Some("CmdOrCtrl+Q"),
        )?)
        .build()?;

    // Update the tray icon's menu
    if let Some(tray) = app.tray_by_id("main") {
        tray.set_menu(Some(tray_menu))?;
    }

    Ok(())
}

/// Sets the microphone device in settings and rebuilds tray menu
fn set_microphone_device(
    app: &AppHandle,
    device_id: Option<String>,
    model_manager: Arc<Mutex<LocalModelManager>>,
) -> Result<()> {
    let store = app.store("settings").map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to get store: {}", e),
        ))
    })?;

    // Get current settings
    let mut settings = store
        .get("settings")
        .ok_or_else(|| {
            tauri::Error::Io(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "No settings found in store",
            ))
        })?
        .clone();

    // Update microphone device
    if let Some(settings_obj) = settings.as_object_mut() {
        if let Some(voice_input) = settings_obj.get_mut("voiceInput") {
            if let Some(voice_input_obj) = voice_input.as_object_mut() {
                voice_input_obj.insert(
                    "microphoneDeviceId".to_string(),
                    device_id
                        .as_ref()
                        .map(|id| json!(id))
                        .unwrap_or(json!(null)),
                );
            }
        }
    }

    // Save updated settings
    store.set("settings", settings);
    store.save().map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to save store: {}", e),
        ))
    })?;

    // Invalidate settings cache to ensure it stays in sync
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Err(e) = cache.invalidate(app) {
            log::warn!("Failed to invalidate settings cache: {}", e);
        }
    }

    // Emit event to notify frontend
    let _ = app.emit(
        "microphone-device-changed",
        json!({
            "microphoneDeviceId": device_id
        }),
    );

    // Rebuild tray menu to update checkmarks (spawn async task)
    let app_clone = app.clone();
    tauri::async_runtime::spawn(async move {
        if let Err(e) = rebuild_tray_menu(&app_clone, model_manager).await {
            log::error!(
                "Failed to rebuild tray menu after microphone change: {:?}",
                e
            );
        }
    });

    Ok(())
}

/// Check if the currently selected model only supports English
fn check_model_is_english_only<M: Manager<tauri::Wry>>(app: &M) -> bool {
    let settings_store = match app.store("settings") {
        Ok(store) => store,
        Err(_) => return false,
    };

    // Get selected model ID - clone the settings to avoid lifetime issues
    let settings = match settings_store.get("settings") {
        Some(s) => s.clone(),
        None => return false,
    };

    let selected_model_id = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
        .map(String::from);

    let Some(selected_id) = selected_model_id else {
        return false;
    };

    let models_store = match app.store("models.json") {
        Ok(store) => store,
        Err(_) => return false,
    };

    // Find model and check language support - clone the models to avoid lifetime issues
    let models_value = match models_store.get("models") {
        Some(m) => m.clone(),
        None => return false,
    };

    let models = match models_value.as_array() {
        Some(m) => m,
        None => return false,
    };

    for model_value in models {
        if let Some(model) = model_value.as_object() {
            let id = model.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if id == selected_id {
                let language_support = model
                    .get("languageSupport")
                    .and_then(|v| v.as_str())
                    .unwrap_or("multilingual");
                return language_support == "english_only";
            }
        }
    }
    false
}

/// Sets the transcription language in settings and rebuilds tray menu
fn set_transcription_language(
    app: &AppHandle,
    language: String,
    model_manager: Arc<Mutex<LocalModelManager>>,
) -> Result<()> {
    let store = app.store("settings").map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to get store: {}", e),
        ))
    })?;

    // Get current settings
    let mut settings = store
        .get("settings")
        .ok_or_else(|| {
            tauri::Error::Io(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "No settings found in store",
            ))
        })?
        .clone();

    // Update language
    if let Some(settings_obj) = settings.as_object_mut() {
        if let Some(transcription) = settings_obj.get_mut("transcription") {
            if let Some(transcription_obj) = transcription.as_object_mut() {
                transcription_obj.insert("language".to_string(), json!(language));
            }
        }
    }

    // Save updated settings
    store.set("settings", settings);
    store.save().map_err(|e| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to save store: {}", e),
        ))
    })?;

    // Invalidate settings cache
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Err(e) = cache.invalidate(app) {
            log::warn!("Failed to invalidate settings cache: {}", e);
        }
    }

    // Emit event to notify frontend
    let _ = app.emit(
        "language-changed",
        json!({
            "language": language
        }),
    );

    // Rebuild tray menu to update checkmarks (spawn async task)
    let app_clone = app.clone();
    tauri::async_runtime::spawn(async move {
        if let Err(e) = rebuild_tray_menu(&app_clone, model_manager).await {
            log::error!("Failed to rebuild tray menu after language change: {:?}", e);
        }
    });

    Ok(())
}

/// Handles tray menu events
fn handle_tray_event(
    app: &AppHandle,
    event_id: &str,
    model_manager_cleanup: Arc<Mutex<LocalModelManager>>,
) {
    match event_id {
        "home" => {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }
        "check-updates" => {
            logger::info("Check for updates clicked");
            let app_clone = app.clone();
            tauri::async_runtime::spawn(async move {
                if let Err(e) = crate::features::updates::check_for_updates(app_clone, false).await
                {
                    logger::error(&format!("Failed to check for updates: {}", e));
                }
            });
        }
        "report-issue" => {
            logger::info("Report issue clicked");
            let issue_url = "https://github.com/nitintf/dicta/issues/new";
            if let Err(e) = open::that(issue_url) {
                logger::error_with("Failed to open issues page", &[("error", &e.to_string())]);
            }
        }
        "paste-last" => {
            logger::info("Paste last transcript clicked");
            let app_clone = app.clone();
            tauri::async_runtime::spawn(async move {
                if let Err(e) =
                    crate::features::transcription::paste_last_transcript(app_clone).await
                {
                    logger::error(&format!("Failed to paste last transcript: {}", e));
                }
            });
        }
        "mic-auto-detect" => {
            // Check if recording is active - don't allow microphone changes during recording
            if let Some(state_manager) = app.try_state::<Arc<RecordingStateManager>>() {
                if state_manager.is_active() {
                    logger::warn("Cannot change microphone while recording is active");
                    return;
                }
            }
            // Set microphone to auto-detect (null)
            if let Err(e) = set_microphone_device(app, None, model_manager_cleanup.clone()) {
                logger::error(&format!("Failed to set microphone to auto-detect: {}", e));
            } else {
                logger::info("Microphone set to auto-detect");
            }
        }
        event_id if event_id.starts_with("mic-") => {
            // Check if recording is active - don't allow microphone changes during recording
            if let Some(state_manager) = app.try_state::<Arc<RecordingStateManager>>() {
                if state_manager.is_active() {
                    logger::warn("Cannot change microphone while recording is active");
                    return;
                }
            }
            // Handle specific microphone selection
            let device_id = event_id.strip_prefix("mic-").unwrap().to_string();
            if let Err(e) =
                set_microphone_device(app, Some(device_id.clone()), model_manager_cleanup.clone())
            {
                logger::error(&format!("Failed to set microphone to {}: {}", device_id, e));
            } else {
                logger::info(&format!("Microphone set to: {}", device_id));
            }
        }
        "lang-more" => {
            // Open settings to language selection
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                let _ = app.emit("open-settings", serde_json::json!({ "section": "general" }));
            }
        }
        event_id if event_id.starts_with("lang-") => {
            // Check if recording is active - don't allow language changes during recording
            if let Some(state_manager) = app.try_state::<Arc<RecordingStateManager>>() {
                if state_manager.is_active() {
                    logger::warn("Cannot change language while recording is active");
                    return;
                }
            }
            // Handle language selection
            let language_code = event_id.strip_prefix("lang-").unwrap().to_string();
            if let Err(e) = set_transcription_language(
                app,
                language_code.clone(),
                model_manager_cleanup.clone(),
            ) {
                logger::error(&format!(
                    "Failed to set transcription language to {}: {}",
                    language_code, e
                ));
            } else {
                logger::info(&format!("Transcription language set to: {}", language_code));
            }
        }
        "shortcuts" => {
            // Open shortcuts settings panel
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                let _ = app.emit(
                    "open-settings",
                    serde_json::json!({ "section": "shortcuts" }),
                );
            }
        }
        "settings-tray" => {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                // Emit event to open settings dialog
                let _ = app.emit("open-settings", serde_json::json!({ "section": null }));
            }
        }
        "general-feedback" => {
            logger::info("General feedback clicked");
            // Open mailto link with pre-filled support email
            let mailto_url = "mailto:support@dicta.app?subject=Dicta%20Feedback";
            if let Err(e) = open::that(mailto_url) {
                logger::error_with("Failed to open email client", &[("error", &e.to_string())]);
            }
        }
        "quit" => {
            // Cleanup local model before exit using a separate thread
            // to avoid nested runtime issues
            let model_manager = model_manager_cleanup.clone();
            std::thread::spawn(move || {
                if let Ok(rt) = tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                {
                    rt.block_on(async {
                        if let Ok(mut manager) = tokio::time::timeout(
                            std::time::Duration::from_secs(2),
                            model_manager.lock(),
                        )
                        .await
                        {
                            manager.unload_model();
                            logger::info("Local model stopped on app exit");
                        }
                    });
                }
            })
            .join()
            .ok();
            app.exit(0);
        }
        _ => {}
    }
}

/// Sets up the macOS menu bar
pub fn setup_menu_bar(app: &App) -> Result<()> {
    let handle = app.app_handle().clone();

    let app_menu = SubmenuBuilder::new(app, "Dicta")
        .item(&MenuItem::with_id(
            app,
            "about-dicta",
            "About Dicta",
            true,
            None::<&str>,
        )?)
        .separator()
        .item(&MenuItem::with_id(
            app,
            "settings",
            "Settings",
            true,
            Some("CmdOrCtrl+,"),
        )?)
        .separator()
        .item(&PredefinedMenuItem::hide(app, None)?)
        .item(&PredefinedMenuItem::hide_others(app, None)?)
        .item(&PredefinedMenuItem::show_all(app, None)?)
        .separator()
        .item(&PredefinedMenuItem::quit(app, None)?)
        .build()?;

    // Create Edit menu with native copy/paste
    let edit_menu = SubmenuBuilder::new(app, "Edit")
        .item(&PredefinedMenuItem::undo(app, None)?)
        .item(&PredefinedMenuItem::redo(app, None)?)
        .separator()
        .item(&PredefinedMenuItem::cut(app, None)?)
        .item(&PredefinedMenuItem::copy(app, None)?)
        .item(&PredefinedMenuItem::paste(app, None)?)
        .item(&PredefinedMenuItem::select_all(app, None)?)
        .build()?;

    // Create View menu
    let view_menu = SubmenuBuilder::new(app, "View")
        .item(&PredefinedMenuItem::fullscreen(app, None)?)
        .build()?;

    // Create Window menu
    let window_menu = SubmenuBuilder::new(app, "Window")
        .item(&PredefinedMenuItem::minimize(app, None)?)
        .item(&PredefinedMenuItem::maximize(app, None)?)
        .separator()
        .item(&PredefinedMenuItem::close_window(app, None)?)
        .build()?;

    // Create Updates menu
    let updates_menu = SubmenuBuilder::new(app, "Updates")
        .item(&MenuItem::with_id(
            app,
            "changelog",
            "Changelog",
            true,
            None::<&str>,
        )?)
        .build()?;

    // Build the complete menu
    let menu = MenuBuilder::new(app)
        .item(&app_menu)
        .item(&edit_menu)
        .item(&view_menu)
        .item(&window_menu)
        .item(&updates_menu)
        .build()?;

    // Set as app menu
    app.set_menu(menu)?;

    // Handle menu bar events
    app.on_menu_event(move |_app, event| {
        handle_menu_bar_event(&handle, event.id().as_ref());
    });

    Ok(())
}

/// Handles menu bar events
fn handle_menu_bar_event(app: &AppHandle, event_id: &str) {
    match event_id {
        "settings" => {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                // Emit event to open settings dialog
                let _ = app.emit("open-settings", serde_json::json!({ "section": null }));
            }
        }
        "about-dicta" => {
            // Open settings with "about" section
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
                let _ = app.emit("open-settings", serde_json::json!({ "section": "about" }));
            }
        }
        "changelog" => {
            // TODO: Open changelog
            logger::info("Changelog clicked");
        }
        _ => {}
    }
}

#[tauri::command]
pub async fn rebuild_tray_menu_command(app: AppHandle) -> Result<()> {
    log::info!("rebuild_tray_menu_command called from frontend");
    let model_manager = app.state::<Arc<Mutex<LocalModelManager>>>();
    let result = rebuild_tray_menu(&app, model_manager.inner().clone()).await;
    match &result {
        Ok(_) => log::info!("Tray menu rebuilt successfully"),
        Err(e) => log::error!("Failed to rebuild tray menu: {:?}", e),
    }
    result
}
