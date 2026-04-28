use crate::types::settings::VoiceInputDisplayMode;
use tauri::AppHandle;

#[cfg(target_os = "macos")]
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(target_os = "macos")]
use std::sync::Arc;

#[cfg(target_os = "macos")]
static MONITOR_ACTIVE: std::sync::OnceLock<Arc<AtomicBool>> = std::sync::OnceLock::new();

/// Position type for the pill window
#[derive(Debug, Clone, Copy)]
pub enum PillPosition {
    BottomCenter { offset: f64 },
    TopCenter { offset: f64 },
}

/// Window configuration per display mode
#[derive(Debug, Clone, Copy)]
pub struct PillWindowConfig {
    pub width: f64,
    pub height: f64,
    pub position: PillPosition,
}

impl PillWindowConfig {
    /// Get window configuration for a specific display mode
    pub fn for_mode(mode: &VoiceInputDisplayMode) -> Self {
        match mode {
            VoiceInputDisplayMode::Standard => Self {
                width: 240.0,
                height: 40.0,
                position: PillPosition::BottomCenter { offset: 16.0 },
            },
            VoiceInputDisplayMode::Minimal => Self {
                width: 160.0,
                height: 40.0,
                position: PillPosition::BottomCenter { offset: 16.0 },
            },
        }
    }
}

/// Screen frame data extracted from NSScreen
#[cfg(target_os = "macos")]
#[derive(Debug, Clone, Copy)]
pub(crate) struct ScreenFrame {
    pub origin_x: f64,
    pub origin_y: f64,
    pub width: f64,
    pub height: f64,
}

#[cfg(target_os = "macos")]
impl ScreenFrame {
    fn contains_point(&self, x: f64, y: f64) -> bool {
        x >= self.origin_x
            && x < self.origin_x + self.width
            && y >= self.origin_y
            && y < self.origin_y + self.height
    }
}

/// Result of screen query operations
#[cfg(target_os = "macos")]
pub(crate) struct ScreenQueryResult {
    pub main_screen_frame: ScreenFrame,
    pub target_visible_frame: ScreenFrame,
    pub mouse_x: f64,
    pub mouse_y: f64,
}

/// Safely query screen information on the main thread.
///
/// Returns None if called from a non-main thread or if screen access fails.
/// IMPORTANT: We return None instead of using new_unchecked() because:
/// - new_unchecked() violates safety contract when not on main thread
/// - Callers must handle None gracefully (use default position)
#[cfg(target_os = "macos")]
pub(crate) fn query_screen_info_for_mouse() -> Option<ScreenQueryResult> {
    use objc2::MainThreadMarker;
    use objc2_app_kit::{NSEvent, NSScreen};

    // Try to get main thread marker - returns None if not on main thread
    // NEVER use new_unchecked() - it can cause undefined behavior
    let mtm = MainThreadMarker::new()?;

    let mouse_location = NSEvent::mouseLocation();
    let screens = NSScreen::screens(mtm);
    let main_screen = NSScreen::mainScreen(mtm)?;
    let main_frame = main_screen.frame();

    let main_screen_frame = ScreenFrame {
        origin_x: main_frame.origin.x,
        origin_y: main_frame.origin.y,
        width: main_frame.size.width,
        height: main_frame.size.height,
    };

    // Find screen containing mouse cursor
    let screen_count = screens.len();
    let mut target_visible_frame = main_screen.visibleFrame();

    for i in 0..screen_count {
        let screen = screens.objectAtIndex(i);
        let frame = screen.frame();

        if mouse_location.x >= frame.origin.x
            && mouse_location.x < frame.origin.x + frame.size.width
            && mouse_location.y >= frame.origin.y
            && mouse_location.y < frame.origin.y + frame.size.height
        {
            target_visible_frame = screen.visibleFrame();
            break;
        }
    }

    Some(ScreenQueryResult {
        main_screen_frame,
        target_visible_frame: ScreenFrame {
            origin_x: target_visible_frame.origin.x,
            origin_y: target_visible_frame.origin.y,
            width: target_visible_frame.size.width,
            height: target_visible_frame.size.height,
        },
        mouse_x: mouse_location.x,
        mouse_y: mouse_location.y,
    })
}

/// Calculate pill window position from screen info using default config.
#[cfg(target_os = "macos")]
fn calculate_pill_position(screen_info: &ScreenQueryResult) -> (f64, f64) {
    calculate_pill_position_with_config(
        screen_info,
        &PillWindowConfig::for_mode(&VoiceInputDisplayMode::Standard),
    )
}

/// Calculate pill window position from screen info with custom config.
#[cfg(target_os = "macos")]
fn calculate_pill_position_with_config(
    screen_info: &ScreenQueryResult,
    config: &PillWindowConfig,
) -> (f64, f64) {
    let visible = &screen_info.target_visible_frame;
    let main = &screen_info.main_screen_frame;

    // Center horizontally on visible area
    let x = visible.origin_x + (visible.width - config.width) / 2.0;

    // Calculate vertical position based on mode
    let y = match config.position {
        PillPosition::BottomCenter { offset } => {
            // Position at bottom of visible area (above dock if present)
            let macos_window_top_y = visible.origin_y + offset + config.height;
            main.height - macos_window_top_y
        }
        PillPosition::TopCenter { offset } => {
            // Position at top of visible area (below menu bar)
            let macos_window_top_y = visible.origin_y + visible.height - offset;
            main.height - macos_window_top_y
        }
    };

    log::debug!(
        "Pill position: mouse=({:.0}, {:.0}), visible={}x{} at ({:.0}, {:.0}), result=({:.0}, {:.0}), mode={:?}",
        screen_info.mouse_x,
        screen_info.mouse_y,
        visible.width,
        visible.height,
        visible.origin_x,
        visible.origin_y,
        x,
        y,
        config.position
    );

    (x, y)
}

/// Sets whether the pill window monitor should actively poll for screen changes.
/// When active (during recording), polls every 500ms.
/// When inactive (idle), polls every 2000ms to reduce CPU usage.
#[cfg(target_os = "macos")]
pub fn set_pill_monitor_active(active: bool) {
    let flag = MONITOR_ACTIVE.get_or_init(|| Arc::new(AtomicBool::new(false)));
    flag.store(active, Ordering::SeqCst);
    log::debug!("Pill window monitor active: {}", active);
}

#[cfg(target_os = "macos")]
fn is_monitor_active() -> bool {
    MONITOR_ACTIVE
        .get()
        .map(|flag| flag.load(Ordering::SeqCst))
        .unwrap_or(false)
}

#[cfg(target_os = "macos")]
/// Positions the voice input window on the screen containing the mouse cursor.
///
/// Uses safe screen query helpers to avoid crashes from objc2 thread safety issues.
/// If not on main thread, silently skips positioning (window keeps current position).
pub fn position_pill_window_on_current_screen(app: &AppHandle) -> tauri::Result<()> {
    use tauri::Manager;

    let window = app
        .get_webview_window("voice-input")
        .ok_or_else(|| tauri::Error::WindowNotFound)?;

    // Query screen info safely - returns None if not on main thread
    let Some(screen_info) = query_screen_info_for_mouse() else {
        // Not on main thread - skip positioning, window keeps current position
        // This is safe because window operations are still thread-safe in Tauri
        log::debug!("position_pill_window: not on main thread, skipping reposition");
        return Ok(());
    };

    // Calculate position using extracted data (no unsafe code needed here)
    let (pos_x, pos_y) = calculate_pill_position(&screen_info);

    window.set_position(tauri::Position::Logical(tauri::LogicalPosition {
        x: pos_x,
        y: pos_y,
    }))?;

    Ok(())
}

#[cfg(target_os = "macos")]
/// Configure and position the pill window for a specific display mode.
///
/// This resizes the window and positions it according to the mode's configuration.
/// If not on main thread, still resizes but skips repositioning.
pub fn configure_pill_window_for_mode(
    app: &AppHandle,
    mode: &VoiceInputDisplayMode,
) -> tauri::Result<()> {
    use tauri::Manager;

    let window = app
        .get_webview_window("voice-input")
        .ok_or_else(|| tauri::Error::WindowNotFound)?;

    let config = PillWindowConfig::for_mode(mode);

    // Resize window - this is thread-safe in Tauri
    window.set_size(tauri::Size::Logical(tauri::LogicalSize {
        width: config.width,
        height: config.height,
    }))?;

    // Query screen info safely - returns None if not on main thread
    let Some(screen_info) = query_screen_info_for_mouse() else {
        // Not on main thread - skip positioning, window keeps current position
        log::debug!(
            "configure_pill_window: not on main thread, skipping position (size: {}x{})",
            config.width,
            config.height
        );
        return Ok(());
    };

    // Calculate position using mode-specific config
    let (pos_x, pos_y) = calculate_pill_position_with_config(&screen_info, &config);

    window.set_position(tauri::Position::Logical(tauri::LogicalPosition {
        x: pos_x,
        y: pos_y,
    }))?;

    log::debug!(
        "Configured pill window for mode {:?}: {}x{} at ({:.0}, {:.0})",
        mode,
        config.width,
        config.height,
        pos_x,
        pos_y
    );

    Ok(())
}

/// Resize the pill window for expanded state (Command Mode).
///
/// When expanded=true, the window expands to show the transcription and generating indicator.
/// The bottom edge stays stable (anchored) and the window grows upward.
/// When expanded=false, the window returns to the recording size.
#[cfg(target_os = "macos")]
pub fn resize_pill_window_expanded(app: &AppHandle, expanded: bool) -> tauri::Result<()> {
    use tauri::Manager;

    let window = app
        .get_webview_window("voice-input")
        .ok_or_else(|| tauri::Error::WindowNotFound)?;

    // Sizes for expanded and recording states
    let (width, height) = if expanded {
        (320.0, 200.0) // Expanded: show transcription + generating indicator
    } else {
        (240.0, 40.0) // Recording: standard pill size
    };

    // Query screen info to calculate position (if on main thread)
    if let Some(screen_info) = query_screen_info_for_mouse() {
        // Calculate position to keep bottom stable
        // The visible_frame.origin_y is the bottom of the visible area (above dock)
        // We want the window bottom to be at origin_y + 16 (padding above dock)
        let bottom_padding = 16.0;
        let target_bottom_y = screen_info.target_visible_frame.origin_y + bottom_padding;

        // In macOS coordinate system (origin at bottom-left), window y is the bottom of the window
        // But Tauri uses top-left origin, so we need to convert
        // The main_screen_frame gives us the full screen height for conversion
        let screen_height = screen_info.main_screen_frame.height;

        // Convert from Cocoa (bottom-left) to Tauri (top-left) coordinates
        // In Tauri: y = 0 is at top of screen
        // pos_y should be where the TOP of the window is
        // We want: window_bottom = target_bottom_y (in Cocoa coords)
        // window_top = window_bottom + height (in Cocoa coords)
        // In Tauri coords: pos_y = screen_height - window_top
        let window_top_cocoa = target_bottom_y + height;
        let pos_y = screen_height - window_top_cocoa;

        let pos_x = screen_info.target_visible_frame.origin_x
            + (screen_info.target_visible_frame.width - width) / 2.0;

        // First move the window to the new position, then resize
        // This creates the illusion of the bottom staying stable
        window.set_position(tauri::Position::Logical(tauri::LogicalPosition {
            x: pos_x,
            y: pos_y,
        }))?;
    }

    // Resize window
    window.set_size(tauri::Size::Logical(tauri::LogicalSize { width, height }))?;

    log::debug!(
        "Resized pill window to {} state: {}x{}",
        if expanded { "expanded" } else { "recording" },
        width,
        height
    );

    Ok(())
}

/// Stub for non-macOS platforms
#[cfg(not(target_os = "macos"))]
pub fn resize_pill_window_expanded(_app: &AppHandle, _expanded: bool) -> tauri::Result<()> {
    Ok(())
}

/// Hide the pill window and deactivate the position monitor.
pub fn hide_pill_window(app: &AppHandle) {
    use tauri::Manager;

    if let Some(window) = app.get_webview_window("voice-input") {
        let _ = window.hide();
        log::debug!("Pill window hidden");
    }

    set_pill_monitor_active(false);
}

/// Query all screen visible frames safely.
/// Returns empty vec if not on main thread (graceful degradation).
#[cfg(target_os = "macos")]
fn query_all_screen_frames() -> Vec<ScreenFrame> {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSScreen;

    // Return empty if not on main thread - never use new_unchecked()
    let Some(mtm) = MainThreadMarker::new() else {
        log::debug!("query_all_screen_frames: not on main thread, returning empty");
        return Vec::new();
    };

    let screens = NSScreen::screens(mtm);
    let mut frames = Vec::with_capacity(screens.len());

    for i in 0..screens.len() {
        let screen = screens.objectAtIndex(i);
        let visible = screen.visibleFrame();
        frames.push(ScreenFrame {
            origin_x: visible.origin.x,
            origin_y: visible.origin.y,
            width: visible.size.width,
            height: visible.size.height,
        });
    }
    frames
}

/// Check if screen frames have changed significantly.
#[cfg(target_os = "macos")]
fn frames_changed(current: &[ScreenFrame], last: &[ScreenFrame]) -> bool {
    if current.len() != last.len() {
        return true;
    }

    const THRESHOLD: f64 = 1.0;

    current.iter().zip(last.iter()).any(|(c, l)| {
        (c.origin_x - l.origin_x).abs() > THRESHOLD
            || (c.origin_y - l.origin_y).abs() > THRESHOLD
            || (c.width - l.width).abs() > THRESHOLD
            || (c.height - l.height).abs() > THRESHOLD
    })
}

#[cfg(target_os = "macos")]
/// Starts monitoring dock/screen changes and repositions pill window when needed.
///
/// Uses polling with adaptive intervals:
/// - 500ms when actively recording (responsive to screen changes)
/// - 2000ms when idle (reduced CPU usage)
pub fn start_pill_window_monitor(app: AppHandle) {
    static MONITOR_RUNNING: std::sync::OnceLock<Arc<AtomicBool>> = std::sync::OnceLock::new();
    let running = MONITOR_RUNNING.get_or_init(|| Arc::new(AtomicBool::new(false)));

    if running.swap(true, Ordering::SeqCst) {
        log::debug!("Pill window monitor already running");
        return;
    }

    log::info!("Starting pill window position monitor");

    tauri::async_runtime::spawn(async move {
        use tauri::Manager;

        let mut last_visible_frames: Vec<ScreenFrame> = Vec::new();

        loop {
            // Adaptive polling interval based on recording state
            let poll_interval = if is_monitor_active() { 500 } else { 2000 };
            tokio::time::sleep(tokio::time::Duration::from_millis(poll_interval)).await;

            // Check if window exists before querying screens
            if app.get_webview_window("voice-input").is_none() {
                continue;
            }

            // Query current screen frames
            let current_frames = query_all_screen_frames();

            // Check for changes
            if frames_changed(&current_frames, &last_visible_frames)
                && !last_visible_frames.is_empty()
            {
                log::debug!("Screen visible frames changed, checking pill window");

                if let Some(window) = app.get_webview_window("voice-input") {
                    if window.is_visible().unwrap_or(false) {
                        log::debug!("Repositioning visible pill window after screen change");
                        if let Err(e) = position_pill_window_on_current_screen(&app) {
                            log::warn!("Failed to reposition pill window: {:?}", e);
                        }
                    }
                }
            }

            last_visible_frames = current_frames;
        }
    });
}

/// Get initial pill window position on main screen.
/// Returns None if not on main thread (should only be called during setup on main thread).
#[cfg(target_os = "macos")]
fn get_initial_pill_position() -> Option<(f64, f64)> {
    use objc2::MainThreadMarker;
    use objc2_app_kit::NSScreen;

    const PILL_WIDTH: f64 = 240.0;
    const PILL_HEIGHT: f64 = 40.0;
    const BOTTOM_OFFSET: f64 = 16.0;

    // Must be on main thread - never use new_unchecked()
    let mtm = MainThreadMarker::new()?;

    let screen = NSScreen::mainScreen(mtm)?;
    let screen_frame = screen.frame();
    let visible_frame = screen.visibleFrame();

    let x = visible_frame.origin.x + (visible_frame.size.width - PILL_WIDTH) / 2.0;
    let macos_y = visible_frame.origin.y + BOTTOM_OFFSET;
    let y = screen_frame.size.height - macos_y - PILL_HEIGHT;

    Some((x, y))
}

#[cfg(target_os = "macos")]
pub fn setup_pill_window(app: &AppHandle) -> tauri::Result<()> {
    use tauri::{WebviewUrl, WebviewWindowBuilder};

    log::info!("Setting up pill window");

    // Get initial position safely
    let (pos_x, pos_y) = get_initial_pill_position().ok_or_else(|| {
        tauri::Error::Io(std::io::Error::new(
            std::io::ErrorKind::Other,
            "Failed to get main screen for pill window positioning",
        ))
    })?;

    let pill_builder = WebviewWindowBuilder::new(
        app,
        "voice-input",
        WebviewUrl::App("voice-input.html".into()),
    )
    .title("Voice Input")
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
    .inner_size(240.0, 40.0)
    .position(pos_x, pos_y)
    .visible(false)
    .focused(false);

    #[cfg(not(debug_assertions))]
    let pill_builder = pill_builder.initialization_script(
        "document.addEventListener('contextmenu', e => e.preventDefault());",
    );

    #[cfg(debug_assertions)]
    let pill_builder = pill_builder;

    let pill_window = pill_builder.build()?;
    log::info!("Pill window built successfully");

    // Convert to NSPanel and configure using direct Cocoa APIs
    use tauri_nspanel::WebviewWindowExt;

    match pill_window.to_panel() {
        Ok(panel) => {
            log::info!("Pill window converted to NSPanel");

            // Configure panel for Raycast-like behavior using tauri-nspanel's built-in methods
            // These wrap the underlying objc calls safely

            // Set window level high enough to appear above full-screen apps
            // Level 1000 is kCGScreenSaverWindowLevel
            panel.set_level(1000);

            // Set collection behavior for full-screen support
            use tauri_nspanel::cocoa::appkit::NSWindowCollectionBehavior;
            panel.set_collection_behaviour(
                NSWindowCollectionBehavior::NSWindowCollectionBehaviorCanJoinAllSpaces
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorFullScreenAuxiliary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorStationary
                    | NSWindowCollectionBehavior::NSWindowCollectionBehaviorIgnoresCycle,
            );

            // Make it a floating panel that doesn't hide when app is not active
            panel.set_floating_panel(true);
            panel.set_hides_on_deactivate(false);

            log::info!("Pill panel configured for full-screen and multi-monitor support");
        }
        Err(e) => log::error!("Failed to convert pill to NSPanel: {:?}", e),
    }

    log::info!("Pill window ready at ({}, {})", pos_x, pos_y);

    Ok(())
}
