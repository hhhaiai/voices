//! Command Result Window - Shows transcription and generating animation for Command Mode.
//!
//! This window appears when the user completes a Command Mode recording,
//! showing "I heard: [transcription]" with a Siri-like generating animation.

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter, Manager, WebviewUrl, WebviewWindowBuilder};

const WINDOW_WIDTH: f64 = 400.0;
const WINDOW_HEIGHT: f64 = 180.0;
const BOTTOM_OFFSET: f64 = 16.0;

/// Payload sent to frontend when showing command result
#[derive(Clone, Serialize, Deserialize)]
pub struct CommandResultPayload {
    pub transcription: String,
}

/// Setup the command result window during app initialization.
/// The window is created hidden and shown via show_command_result_window().
#[cfg(target_os = "macos")]
pub fn setup_command_result_window(app: &AppHandle) -> tauri::Result<()> {
    use tauri_nspanel::{cocoa::appkit::NSWindowCollectionBehavior, WebviewWindowExt};

    // Get initial position (will be updated when shown)
    let (pos_x, pos_y) = get_command_result_position().unwrap_or((100.0, 100.0));

    let builder = WebviewWindowBuilder::new(
        app,
        "command-result",
        WebviewUrl::App("command-result.html".into()),
    )
    .title("Command Result")
    .resizable(false)
    .maximizable(false)
    .minimizable(false)
    .decorations(false)
    .always_on_top(true)
    .visible_on_all_workspaces(true)
    .content_protected(true)
    .skip_taskbar(true)
    .transparent(true)
    .shadow(false)
    .inner_size(WINDOW_WIDTH, WINDOW_HEIGHT)
    .position(pos_x, pos_y)
    .visible(false)
    .focused(false);

    let window = builder.build()?;

    // Convert to NSPanel for proper overlay behavior (same pattern as toast_window.rs)
    #[allow(deprecated)]
    match window.to_panel() {
        Ok(panel) => {
            // Set level above pill window (1000) but same as toast (1001)
            panel.set_level(1001);
            panel.set_collection_behaviour(
                NSWindowCollectionBehavior::NSWindowCollectionBehaviorCanJoinAllSpaces
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorFullScreenAuxiliary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorStationary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorIgnoresCycle,
            );
            panel.set_floating_panel(true);
            panel.set_hides_on_deactivate(false);
            log::debug!("Command result window converted to NSPanel");
        }
        Err(e) => {
            log::error!(
                "Failed to convert command result window to NSPanel: {:?}",
                e
            );
        }
    }

    log::info!("Command result window setup complete");
    Ok(())
}

/// Non-macOS fallback - window not supported
#[cfg(not(target_os = "macos"))]
pub fn setup_command_result_window(_app: &AppHandle) -> tauri::Result<()> {
    log::warn!("Command result window not supported on this platform");
    Ok(())
}

/// Show the command result window with the given transcription.
/// Positions the window at bottom-center of the screen containing the mouse cursor.
pub fn show_command_result_window(app: &AppHandle, transcription: &str) -> tauri::Result<()> {
    // Position window at bottom-center of current screen
    if let Some((x, y)) = get_command_result_position() {
        if let Some(window) = app.get_webview_window("command-result") {
            window.set_position(tauri::Position::Logical(tauri::LogicalPosition { x, y }))?;
        }
    }

    // Emit event to frontend to show content
    app.emit(
        "show-command-result",
        CommandResultPayload {
            transcription: transcription.to_string(),
        },
    )?;

    // Show the window
    if let Some(window) = app.get_webview_window("command-result") {
        window.show()?;
        log::debug!("Command result window shown with transcription");
    }

    Ok(())
}

/// Hide the command result window.
/// Emits hide event first to allow frontend animation, then hides after delay.
pub fn hide_command_result_window(app: &AppHandle) -> tauri::Result<()> {
    // Emit hide event to trigger frontend fade-out animation
    app.emit("hide-command-result", ())?;

    // Wait for animation, then hide window
    let app_clone = app.clone();
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(300));
        if let Some(window) = app_clone.get_webview_window("command-result") {
            let _ = window.hide();
            log::debug!("Command result window hidden");
        }
    });

    Ok(())
}

/// Calculate position for command result window (bottom-center of current screen).
/// Uses the same screen query pattern as pill_window.
#[cfg(target_os = "macos")]
fn get_command_result_position() -> Option<(f64, f64)> {
    use super::pill_window::query_screen_info_for_mouse;

    let screen_info = query_screen_info_for_mouse()?;

    let visible = &screen_info.target_visible_frame;
    let main = &screen_info.main_screen_frame;

    // Center horizontally on visible area
    let x = visible.origin_x + (visible.width - WINDOW_WIDTH) / 2.0;

    // Position at bottom of visible area (above dock if present)
    // Convert from macOS coordinates (bottom-left origin) to Tauri (top-left origin)
    let macos_window_top_y = visible.origin_y + BOTTOM_OFFSET + WINDOW_HEIGHT;
    let y = main.height - macos_window_top_y;

    log::debug!(
        "Command result position: visible={}x{} at ({:.0}, {:.0}), result=({:.0}, {:.0})",
        visible.width,
        visible.height,
        visible.origin_x,
        visible.origin_y,
        x,
        y
    );

    Some((x, y))
}

/// Non-macOS fallback
#[cfg(not(target_os = "macos"))]
fn get_command_result_position() -> Option<(f64, f64)> {
    None
}
