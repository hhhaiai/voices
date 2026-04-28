use crate::features::shortcuts::utils::parse_shortcut;
use crate::utils::logger;
use parking_lot::Mutex;
use std::sync::Arc;
use tauri::{command, App, AppHandle, Manager, Result, State};
use tauri_plugin_global_shortcut::{
    Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutEvent, ShortcutState,
};
use tauri_plugin_store::StoreExt;

/// ShortcutManager uses parking_lot::Mutex instead of std::sync::Mutex because:
/// - No lock poisoning on panic (more resilient)
/// - Faster locking operations
/// - Consistent with other locks in the codebase
pub struct ShortcutManager {
    pub voice_input_shortcut: Arc<Mutex<Option<Shortcut>>>,
    pub push_to_talk_shortcut: Arc<Mutex<Option<Shortcut>>>,
    pub paste_shortcut: Arc<Mutex<Option<Shortcut>>>,
    pub escape_shortcut: Arc<Mutex<Option<Shortcut>>>,
    pub command_mode_shortcut: Arc<Mutex<Option<Shortcut>>>,
    pub shortcuts_enabled: Arc<Mutex<bool>>,
}

impl ShortcutManager {
    pub fn new() -> Self {
        Self {
            voice_input_shortcut: Arc::new(Mutex::new(None)),
            push_to_talk_shortcut: Arc::new(Mutex::new(None)),
            paste_shortcut: Arc::new(Mutex::new(None)),
            escape_shortcut: Arc::new(Mutex::new(None)),
            command_mode_shortcut: Arc::new(Mutex::new(None)),
            shortcuts_enabled: Arc::new(Mutex::new(true)),
        }
    }
}

/// Registers the voice input, PTT, command mode, and paste shortcuts
pub fn register_voice_input_shortcut(app: &App) -> Result<()> {
    let voice_input_shortcut_str = get_voice_input_shortcut_from_settings(app.handle());
    let paste_shortcut_str = get_paste_shortcut_from_settings(app.handle());
    let enable_ptt = get_enable_push_to_talk_from_settings(app.handle());
    let enable_command_mode = get_enable_command_mode_from_settings(app.handle());

    let voice_shortcut = parse_shortcut(&voice_input_shortcut_str)
        .unwrap_or(Shortcut::new(Some(Modifiers::ALT), Code::Space));

    let paste_shortcut = parse_shortcut(&paste_shortcut_str).unwrap_or(Shortcut::new(
        Some(Modifiers::SUPER | Modifiers::SHIFT),
        Code::KeyV,
    ));

    // Conditionally register PTT and Command Mode shortcuts
    // Note: Escape shortcut is registered dynamically when recording starts
    let mut shortcuts_to_register = vec![voice_shortcut.clone(), paste_shortcut.clone()];

    // Conditionally add command mode shortcut
    let command_mode_shortcut_opt = if enable_command_mode {
        let command_mode_shortcut_str = get_command_mode_shortcut_from_settings(app.handle());
        let cmd_shortcut = parse_shortcut(&command_mode_shortcut_str).unwrap_or(Shortcut::new(
            Some(Modifiers::SUPER | Modifiers::SHIFT),
            Code::Space,
        ));
        shortcuts_to_register.push(cmd_shortcut.clone());
        Some(cmd_shortcut)
    } else {
        None
    };

    let ptt_shortcut_opt = if enable_ptt {
        let ptt_shortcut_str = get_ptt_shortcut_from_settings(app.handle());
        let ptt = parse_shortcut(&ptt_shortcut_str)
            .unwrap_or(Shortcut::new(Some(Modifiers::ALT), Code::KeyR));
        shortcuts_to_register.push(ptt.clone());
        Some(ptt)
    } else {
        None
    };

    let ptt_shortcut_for_handler = ptt_shortcut_opt.clone();
    let command_mode_for_handler = command_mode_shortcut_opt.clone();

    app.handle().plugin(
        tauri_plugin_global_shortcut::Builder::new()
            .with_shortcuts(shortcuts_to_register)
            .expect("Failed to register shortcut")
            .with_handler(move |app, shortcut, event| {
                if shortcut.id() == voice_shortcut.id() {
                    handle_voice_input_shortcut(app, shortcut, event);
                } else if let Some(ref cmd) = command_mode_for_handler {
                    if shortcut.id() == cmd.id() {
                        handle_command_mode_shortcut(app, shortcut, event);
                    }
                }
                if let Some(ref ptt) = ptt_shortcut_for_handler {
                    if shortcut.id() == ptt.id() {
                        handle_ptt_shortcut(app, shortcut, event);
                    }
                }
                if shortcut.id() == paste_shortcut.id() {
                    handle_paste_shortcut(app, shortcut, event);
                }
            })
            .build(),
    )?;

    // Store shortcuts in state
    // parking_lot::Mutex never poisons, so lock() always succeeds
    let shortcut_state = app.state::<ShortcutManager>();
    *shortcut_state.voice_input_shortcut.lock() = Some(voice_shortcut);
    *shortcut_state.push_to_talk_shortcut.lock() = ptt_shortcut_opt;
    *shortcut_state.paste_shortcut.lock() = Some(paste_shortcut);
    *shortcut_state.command_mode_shortcut.lock() = command_mode_shortcut_opt;
    // Escape shortcut is not registered here - it's registered dynamically when recording starts
    *shortcut_state.escape_shortcut.lock() = None;

    Ok(())
}

/// Retrieves the voice input shortcut from settings
fn get_voice_input_shortcut_from_settings(app: &AppHandle) -> String {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(shortcut) = cache.get_voice_input_shortcut() {
            return shortcut;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("voiceInput"))
                .and_then(|t| t.get("shortcut"))
                .and_then(|m| m.as_str().map(String::from))
        })
        .unwrap_or("Alt+Space".to_string())
}

/// Retrieves the PTT shortcut from settings
fn get_ptt_shortcut_from_settings(app: &AppHandle) -> String {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(shortcut) = cache.get_ptt_shortcut() {
            return shortcut;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("voiceInput"))
                .and_then(|t| t.get("pushToTalkShortcut"))
                .and_then(|m| m.as_str().map(String::from))
        })
        .unwrap_or("Alt+R".to_string())
}

/// Retrieves the enable push-to-talk setting
fn get_enable_push_to_talk_from_settings(app: &AppHandle) -> bool {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(enabled) = cache.get_enable_push_to_talk() {
            return enabled;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("voiceInput"))
                .and_then(|t| t.get("enablePushToTalk"))
                .and_then(|m| m.as_bool())
        })
        .unwrap_or(false)
}

/// Retrieves the command mode shortcut from settings
fn get_command_mode_shortcut_from_settings(app: &AppHandle) -> String {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(shortcut) = cache.get_command_mode_shortcut() {
            return shortcut;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("shortcuts"))
                .and_then(|t| t.get("commandModeShortcut"))
                .and_then(|m| m.as_str().map(String::from))
        })
        .unwrap_or("CmdOrCtrl+Shift+Space".to_string())
}

/// Retrieves the enable command mode setting
fn get_enable_command_mode_from_settings(app: &AppHandle) -> bool {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(enabled) = cache.get_enable_command_mode() {
            return enabled;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("shortcuts"))
                .and_then(|t| t.get("enableCommandMode"))
                .and_then(|m| m.as_bool())
        })
        .unwrap_or(false)
}

fn handle_voice_input_shortcut(app: &tauri::AppHandle, shortcut: &Shortcut, event: ShortcutEvent) {
    if event.id == shortcut.id() {
        let handler =
            app.state::<std::sync::Arc<crate::features::shortcuts::RecordingShortcutHandler>>();
        let handler_clone = handler.inner().clone();
        let app_clone = app.clone();
        let event_clone = event.clone();

        // Voice input shortcut always uses toggle mode
        tauri::async_runtime::spawn(async move {
            if let Err(e) = handler_clone
                .handle_toggle_mode(&app_clone, &event_clone)
                .await
            {
                log::error!("Failed to handle toggle mode shortcut: {}", e);
            }
        });
    }
}

fn handle_ptt_shortcut(app: &tauri::AppHandle, shortcut: &Shortcut, event: ShortcutEvent) {
    if event.id == shortcut.id() {
        let handler =
            app.state::<std::sync::Arc<crate::features::shortcuts::RecordingShortcutHandler>>();
        let handler_clone = handler.inner().clone();
        let app_clone = app.clone();
        let event_clone = event.clone();

        tauri::async_runtime::spawn(async move {
            if let Err(e) = handler_clone
                .handle_ptt_mode(&app_clone, &event_clone)
                .await
            {
                log::error!("Failed to handle PTT shortcut: {}", e);
            }
        });
    }
}

fn handle_escape_shortcut(app: &tauri::AppHandle, shortcut: &Shortcut, event: ShortcutEvent) {
    // Only handle key press (not release) for Escape
    if event.state == ShortcutState::Pressed && event.id == shortcut.id() {
        log::info!("Escape shortcut triggered");

        let handler =
            app.state::<std::sync::Arc<crate::features::shortcuts::RecordingShortcutHandler>>();
        let handler_clone = handler.inner().clone();
        let app_clone = app.clone();

        tauri::async_runtime::spawn(async move {
            if let Err(e) = handler_clone.handle_escape_shortcut(&app_clone).await {
                log::error!("Failed to handle escape shortcut: {}", e);
            }
        });
    }
}

fn handle_command_mode_shortcut(app: &tauri::AppHandle, shortcut: &Shortcut, event: ShortcutEvent) {
    if event.id == shortcut.id() {
        let handler =
            app.state::<std::sync::Arc<crate::features::shortcuts::RecordingShortcutHandler>>();
        let handler_clone = handler.inner().clone();
        let app_clone = app.clone();
        let event_clone = event.clone();

        // Command mode shortcut uses toggle mode with Command recording mode
        tauri::async_runtime::spawn(async move {
            if let Err(e) = handler_clone
                .handle_command_mode(&app_clone, &event_clone)
                .await
            {
                log::error!("Failed to handle command mode shortcut: {}", e);
            }
        });
    }
}

/// Command to update the voice input shortcut
#[command]
pub async fn update_voice_input_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!(
        "Updating voice input shortcut to: {}",
        shortcut_str
    ));

    // Check if shortcuts are enabled
    // parking_lot::Mutex never fails, so we can access directly
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping registration");
        return Ok(());
    }

    // Parse the new shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse shortcut: {}", shortcut_str))?;

    // Unregister old shortcut if it exists
    {
        let mut old_shortcut = shortcut_state.voice_input_shortcut.lock();
        if let Some(old) = old_shortcut.take() {
            logger::info("Unregistering old voice input shortcut");
            let _ = app.global_shortcut().unregister(old);
        }
    }

    // Register new shortcut
    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_voice_input_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register voice input shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.voice_input_shortcut.lock() = Some(shortcut_clone);

    logger::info("Voice input shortcut updated successfully");
    Ok(())
}

/// Command to update the paste last transcript shortcut
#[command]
pub async fn update_paste_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!("Updating paste shortcut to: {}", shortcut_str));

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping registration");
        return Ok(());
    }

    // Parse the new shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse shortcut: {}", shortcut_str))?;

    // Unregister old shortcut if it exists
    {
        let mut old_shortcut = shortcut_state.paste_shortcut.lock();
        if let Some(old) = old_shortcut.take() {
            logger::info("Unregistering old paste shortcut");
            let _ = app.global_shortcut().unregister(old);
        }
    }

    // Register new shortcut
    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_paste_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register paste shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.paste_shortcut.lock() = Some(shortcut_clone);

    logger::info("Paste shortcut updated successfully");
    Ok(())
}

/// Handles the paste last transcript shortcut
fn handle_paste_shortcut(app: &AppHandle, shortcut: &Shortcut, event: ShortcutEvent) {
    if event.state == ShortcutState::Pressed && event.id == shortcut.id() {
        logger::info("Paste shortcut triggered");

        // Trigger paste in async runtime
        let app_clone = app.clone();
        tauri::async_runtime::spawn(async move {
            if let Err(e) = crate::features::transcription::paste_last_transcript(app_clone).await {
                logger::error(&format!("Failed to paste last transcript: {}", e));
            }
        });
    }
}

/// Command to update the command mode shortcut
#[command]
pub async fn update_command_mode_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!(
        "Updating command mode shortcut to: {}",
        shortcut_str
    ));

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping registration");
        return Ok(());
    }

    // Parse the new shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse shortcut: {}", shortcut_str))?;

    // Unregister old shortcut if it exists
    {
        let mut old_shortcut = shortcut_state.command_mode_shortcut.lock();
        if let Some(old) = old_shortcut.take() {
            logger::info("Unregistering old command mode shortcut");
            let _ = app.global_shortcut().unregister(old);
        }
    }

    // Register new shortcut
    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_command_mode_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register command mode shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.command_mode_shortcut.lock() = Some(shortcut_clone);

    logger::info("Command mode shortcut updated successfully");
    Ok(())
}

/// Command to register command mode shortcut (called when user enables Command Mode)
#[command]
pub async fn register_command_mode_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!(
        "Registering command mode shortcut: {}",
        shortcut_str
    ));

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping command mode registration");
        return Ok(());
    }

    // Parse the shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse command mode shortcut: {}", shortcut_str))?;

    // Register new shortcut
    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_command_mode_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register command mode shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.command_mode_shortcut.lock() = Some(shortcut_clone);

    logger::info("Command mode shortcut registered successfully");
    Ok(())
}

/// Command to unregister command mode shortcut (called when user disables Command Mode)
#[command]
pub async fn unregister_command_mode_shortcut(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info("Unregistering command mode shortcut");

    // Unregister command mode shortcut
    {
        let mut cmd_shortcut = shortcut_state.command_mode_shortcut.lock();
        if let Some(shortcut) = cmd_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    logger::info("Command mode shortcut unregistered");
    Ok(())
}

/// Command to disable all global shortcuts
#[command]
pub async fn disable_global_shortcuts(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info("Disabling all global shortcuts");

    // Unregister voice input shortcut
    {
        let mut voice_shortcut = shortcut_state.voice_input_shortcut.lock();
        if let Some(shortcut) = voice_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    // Unregister paste shortcut
    {
        let mut paste_shortcut = shortcut_state.paste_shortcut.lock();
        if let Some(shortcut) = paste_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    // Unregister command mode shortcut
    {
        let mut command_mode_shortcut = shortcut_state.command_mode_shortcut.lock();
        if let Some(shortcut) = command_mode_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    // Unregister escape shortcut
    {
        let mut escape_shortcut = shortcut_state.escape_shortcut.lock();
        if let Some(shortcut) = escape_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    // Set shortcuts as disabled
    *shortcut_state.shortcuts_enabled.lock() = false;

    logger::info("All global shortcuts disabled");
    Ok(())
}

/// Command to enable all global shortcuts
#[command]
pub async fn enable_global_shortcuts(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info("Enabling all global shortcuts");

    // Set shortcuts as enabled
    *shortcut_state.shortcuts_enabled.lock() = true;

    // Re-register voice input shortcut from settings
    let voice_input_shortcut = get_voice_input_shortcut_from_settings(&app);
    if let Some(parsed) = parse_shortcut(&voice_input_shortcut) {
        let shortcut_clone = parsed.clone();
        app.global_shortcut()
            .on_shortcut(parsed.clone(), move |app, shortcut, event| {
                handle_voice_input_shortcut(app, shortcut, event);
            })
            .map_err(|e| format!("Failed to register voice input shortcut: {}", e))?;

        *shortcut_state.voice_input_shortcut.lock() = Some(shortcut_clone);
    }

    // Re-register paste shortcut from settings
    let paste_shortcut_str = get_paste_shortcut_from_settings(&app);
    if let Some(parsed) = parse_shortcut(&paste_shortcut_str) {
        let shortcut_clone = parsed.clone();
        app.global_shortcut()
            .on_shortcut(parsed.clone(), move |app, shortcut, event| {
                handle_paste_shortcut(app, shortcut, event);
            })
            .map_err(|e| format!("Failed to register paste shortcut: {}", e))?;

        *shortcut_state.paste_shortcut.lock() = Some(shortcut_clone);
    }

    // Re-register command mode shortcut from settings (only if command mode is enabled)
    let enable_command_mode = get_enable_command_mode_from_settings(&app);
    if enable_command_mode {
        let command_mode_shortcut_str = get_command_mode_shortcut_from_settings(&app);
        if let Some(parsed) = parse_shortcut(&command_mode_shortcut_str) {
            let shortcut_clone = parsed.clone();
            app.global_shortcut()
                .on_shortcut(parsed.clone(), move |app, shortcut, event| {
                    handle_command_mode_shortcut(app, shortcut, event);
                })
                .map_err(|e| format!("Failed to register command mode shortcut: {}", e))?;

            *shortcut_state.command_mode_shortcut.lock() = Some(shortcut_clone);
        }
    }

    // Re-register Escape shortcut
    let escape_shortcut = Shortcut::new(None, Code::Escape);
    let escape_clone = escape_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(escape_shortcut, move |app, shortcut, event| {
            handle_escape_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register escape shortcut: {}", e))?;

    *shortcut_state.escape_shortcut.lock() = Some(escape_clone);

    logger::info("All global shortcuts enabled");
    Ok(())
}

/// Retrieves the paste shortcut from settings
fn get_paste_shortcut_from_settings(app: &AppHandle) -> String {
    // Try cache first for faster access
    if let Some(cache) = app.try_state::<std::sync::Arc<crate::features::cache::SettingsCache>>() {
        if let Some(shortcut) = cache.get_paste_shortcut() {
            return shortcut;
        }
    }
    // Fallback to direct store access
    let store = app.store("settings");
    store
        .ok()
        .and_then(|store| store.get("settings"))
        .and_then(|settings| {
            settings
                .as_object()
                .and_then(|s| s.get("shortcuts"))
                .and_then(|t| t.get("pasteLastTranscript"))
                .and_then(|m| m.as_str().map(String::from))
        })
        .unwrap_or("CmdOrCtrl+Shift+V".to_string())
}

/// Command to register PTT shortcut
#[command]
pub async fn register_ptt_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!("Registering PTT shortcut: {}", shortcut_str));

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping PTT registration");
        return Ok(());
    }

    // Parse the new shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse PTT shortcut: {}", shortcut_str))?;

    // Register new shortcut
    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_ptt_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register PTT shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.push_to_talk_shortcut.lock() = Some(shortcut_clone);

    logger::info("PTT shortcut registered successfully");
    Ok(())
}

/// Command to unregister PTT shortcut
#[command]
pub async fn unregister_ptt_shortcut(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info("Unregistering PTT shortcut");

    // Unregister PTT shortcut
    {
        let mut ptt_shortcut = shortcut_state.push_to_talk_shortcut.lock();
        if let Some(shortcut) = ptt_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }

    logger::info("PTT shortcut unregistered");
    Ok(())
}

/// Command to update PTT shortcut
#[command]
pub async fn update_ptt_shortcut(
    app: AppHandle,
    shortcut_str: String,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    logger::info(&format!("Updating PTT shortcut to: {}", shortcut_str));

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        logger::info("Shortcuts are disabled, skipping PTT update");
        return Ok(());
    }

    // Unregister old shortcut
    {
        let mut old_shortcut = shortcut_state.push_to_talk_shortcut.lock();
        if let Some(old) = old_shortcut.take() {
            logger::info("Unregistering old PTT shortcut");
            let _ = app.global_shortcut().unregister(old);
        }
    }

    // Parse and register new shortcut
    let new_shortcut = parse_shortcut(&shortcut_str)
        .ok_or_else(|| format!("Failed to parse PTT shortcut: {}", shortcut_str))?;

    let shortcut_clone = new_shortcut.clone();
    app.global_shortcut()
        .on_shortcut(new_shortcut.clone(), move |app, shortcut, event| {
            handle_ptt_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register PTT shortcut: {}", e))?;

    // Store the new shortcut
    *shortcut_state.push_to_talk_shortcut.lock() = Some(shortcut_clone);

    logger::info("PTT shortcut updated successfully");
    Ok(())
}

/// Command to register Escape shortcut (called when recording starts)
#[command]
pub async fn register_escape_shortcut(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    log::info!("Registering Escape shortcut for recording cancellation");

    // Check if shortcuts are enabled
    let shortcuts_enabled = *shortcut_state.shortcuts_enabled.lock();

    if !shortcuts_enabled {
        log::info!("Shortcuts are disabled, skipping Escape registration");
        return Ok(());
    }

    // Create Escape shortcut
    let escape_shortcut = Shortcut::new(None, Code::Escape);
    let escape_clone = escape_shortcut.clone();

    // Register the shortcut
    app.global_shortcut()
        .on_shortcut(escape_shortcut, move |app, shortcut, event| {
            handle_escape_shortcut(app, shortcut, event);
        })
        .map_err(|e| format!("Failed to register Escape shortcut: {}", e))?;

    // Store the shortcut
    *shortcut_state.escape_shortcut.lock() = Some(escape_clone);

    log::info!("Escape shortcut registered successfully");
    Ok(())
}

/// Command to unregister Escape shortcut (called when recording stops/cancels)
#[command]
pub async fn unregister_escape_shortcut(
    app: AppHandle,
    shortcut_state: State<'_, ShortcutManager>,
) -> std::result::Result<(), String> {
    log::info!("Unregistering Escape shortcut");

    // Unregister Escape shortcut
    {
        let mut escape_shortcut = shortcut_state.escape_shortcut.lock();
        if let Some(shortcut) = escape_shortcut.take() {
            let _ = app.global_shortcut().unregister(shortcut);
            log::info!("Escape shortcut unregistered");
        }
    }

    Ok(())
}
