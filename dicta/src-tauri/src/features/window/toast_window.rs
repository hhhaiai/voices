use rand::Rng;
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter, Manager};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ToastType {
    Info,
    Success,
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToastMessage {
    pub message: String,
    #[serde(rename = "type")]
    pub toast_type: ToastType,
}

/// Shows a toast notification with optional probability
/// probability: 0.0 to 1.0 (1.0 = always show, 0.3 = 30% chance)
pub fn show_toast(
    app: &AppHandle,
    message: &str,
    toast_type: ToastType,
    probability: f64,
) -> Result<(), String> {
    // Check probability
    if probability < 1.0 {
        let mut rng = rand::rng();
        let roll: f64 = rng.random();
        if roll > probability {
            log::debug!(
                "Toast skipped due to probability (roll: {:.2}, threshold: {:.2})",
                roll,
                probability
            );
            return Ok(());
        }
    }

    // Position the toast window above the pill
    if let Err(e) = position_toast_window(app) {
        log::warn!("Failed to position toast window: {}", e);
    }

    // Show the toast window
    if let Some(window) = app.get_webview_window("toast") {
        let _ = window.show();
    }

    // Emit the toast message
    let payload = ToastMessage {
        message: message.to_string(),
        toast_type,
    };

    app.emit("show_toast", payload)
        .map_err(|e| format!("Failed to emit toast: {}", e))?;

    log::debug!("Toast shown: {}", message);
    Ok(())
}

/// Hides the toast window
pub fn hide_toast(app: &AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("toast") {
        let _ = window.hide();
    }

    app.emit("hide_toast", ())
        .map_err(|e| format!("Failed to emit hide_toast: {}", e))?;

    Ok(())
}

/// Positions the toast window above the pill window
#[cfg(target_os = "macos")]
fn position_toast_window(app: &AppHandle) -> tauri::Result<()> {
    use objc2::MainThreadMarker;
    use objc2_app_kit::{NSEvent, NSScreen};

    let window = app
        .get_webview_window("toast")
        .ok_or_else(|| tauri::Error::WindowNotFound)?;

    // Safely get MainThreadMarker - don't use unchecked version
    // If we're not on the main thread, fall back to default position
    let Some(mtm) = MainThreadMarker::new() else {
        log::warn!("position_toast_window called from non-main thread, using default position");
        return Ok(());
    };

    let (pos_x, pos_y) = {
        // No longer need unsafe block since we verified main thread

        // Get the mouse location to find current screen
        let mouse_location = NSEvent::mouseLocation();

        // Find the screen containing the mouse cursor
        let screens = NSScreen::screens(mtm);
        let main_screen = NSScreen::mainScreen(mtm).expect("Failed to get main screen");
        let main_screen_frame = main_screen.frame();
        let mut target_screen = main_screen.clone();

        for i in 0..screens.len() {
            let screen = screens.objectAtIndex(i);
            let frame = screen.frame();
            if mouse_location.x >= frame.origin.x
                && mouse_location.x < frame.origin.x + frame.size.width
                && mouse_location.y >= frame.origin.y
                && mouse_location.y < frame.origin.y + frame.size.height
            {
                target_screen = screen;
                break;
            }
        }

        let visible_frame = target_screen.visibleFrame();

        let toast_width = 360.0;
        let toast_height = 72.0;
        let _pill_width = 240.0; // Used for layout reference
        let pill_height = 40.0;
        let bottom_offset = 16.0;
        let gap = 12.0; // Gap between pill and toast

        // Center horizontally on the visible area
        let x = visible_frame.origin.x + (visible_frame.size.width - toast_width) / 2.0;

        // Position above the pill window
        // Pill is at: visible_frame.origin.y + bottom_offset (bottom of pill in macOS coords)
        // Toast should be above pill: pill_bottom + pill_height + gap
        let pill_top_macos_y = visible_frame.origin.y + bottom_offset + pill_height;
        let toast_bottom_macos_y = pill_top_macos_y + gap;
        let toast_top_macos_y = toast_bottom_macos_y + toast_height;

        // Convert to Tauri coordinates (origin at top-left of main screen)
        let y = main_screen_frame.size.height - toast_top_macos_y;

        (x, y)
    };

    window.set_position(tauri::Position::Logical(tauri::LogicalPosition {
        x: pos_x,
        y: pos_y,
    }))?;

    Ok(())
}

#[cfg(target_os = "macos")]
pub fn setup_toast_window(app: &AppHandle) -> tauri::Result<()> {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSScreen;
    use tauri::{WebviewUrl, WebviewWindowBuilder};

    log::info!("Setting up toast window");

    // Safely get MainThreadMarker - setup should always be on main thread
    // but we check to be safe and avoid crashes
    let mtm = MainThreadMarker::new().ok_or_else(|| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            "setup_toast_window must be called from main thread",
        ))
    })?;

    let (toast_x, toast_y) = {
        let screen = NSScreen::mainScreen(mtm).expect("Failed to get main screen");
        let screen_frame = screen.frame();
        let visible_frame = screen.visibleFrame();

        let toast_width = 360.0;
        let toast_height = 72.0;
        let _pill_width = 240.0; // Used for layout calculations
        let pill_height = 40.0;
        let bottom_offset = 16.0;
        let gap = 12.0;

        // Center horizontally
        let x = visible_frame.origin.x + (visible_frame.size.width - toast_width) / 2.0;

        // Position above pill
        let pill_top_macos_y = visible_frame.origin.y + bottom_offset + pill_height;
        let toast_bottom_macos_y = pill_top_macos_y + gap;
        let toast_top_macos_y = toast_bottom_macos_y + toast_height;
        let y = screen_frame.size.height - toast_top_macos_y;

        (x, y)
    };

    let toast_builder =
        WebviewWindowBuilder::new(app, "toast", WebviewUrl::App("toast.html".into()))
            .title("Toast")
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
            .inner_size(360.0, 72.0)
            .position(toast_x, toast_y)
            .visible(false)
            .focused(false);

    #[cfg(not(debug_assertions))]
    let toast_builder = toast_builder.initialization_script(
        "document.addEventListener('contextmenu', e => e.preventDefault());",
    );

    #[cfg(debug_assertions)]
    let toast_builder = toast_builder;

    log::info!(
        "Building toast window at position ({}, {})",
        toast_x,
        toast_y
    );
    let toast_window = toast_builder.build()?;
    log::info!("Toast window built successfully");

    // Set ignoresMouseEvents BEFORE converting to panel
    // This ensures the toast never blocks mouse clicks (even when hidden)
    // The toast is display-only and doesn't need mouse interaction
    use tauri_nspanel::WebviewWindowExt;
    if let Ok(ns_window) = toast_window.ns_window() {
        unsafe {
            use objc2::msg_send;
            use objc2::runtime::Bool;
            let ns_window: *mut objc2::runtime::AnyObject = ns_window.cast();
            let _: () = msg_send![ns_window, setIgnoresMouseEvents: Bool::from(true)];
            log::info!("Toast window set to ignore mouse events");
        }
    }

    // Convert to NSPanel and configure

    match toast_window.to_panel() {
        Ok(panel) => {
            log::info!("Toast window converted to NSPanel");

            // Set window level HIGHER than pill window (pill is 1000)
            // Toast should appear above the pill
            panel.set_level(1001);

            // Set collection behavior for full-screen support
            use tauri_nspanel::cocoa::appkit::NSWindowCollectionBehavior;
            panel.set_collection_behaviour(
                NSWindowCollectionBehavior::NSWindowCollectionBehaviorCanJoinAllSpaces
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorFullScreenAuxiliary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorStationary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorIgnoresCycle,
            );

            // Make it a floating panel
            panel.set_floating_panel(true);
            panel.set_hides_on_deactivate(false);

            log::info!("Toast panel configured for full-screen and multi-monitor support");
        }
        Err(e) => log::error!("Failed to convert toast to NSPanel: {:?}", e),
    }

    log::info!("Toast window ready at ({}, {})", toast_x, toast_y);

    Ok(())
}
