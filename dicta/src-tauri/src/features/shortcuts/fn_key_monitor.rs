//! FN Key Monitor for Push-to-Talk
//!
//! Uses macOS CGEventTap to capture the Fn key press/release events.
//! This allows using the Fn key alone (without any other key) for PTT.

#[cfg(target_os = "macos")]
use core_foundation::runloop::{kCFRunLoopCommonModes, CFRunLoop};
#[cfg(target_os = "macos")]
use core_graphics::event::{
    CGEvent, CGEventFlags, CGEventTap, CGEventTapLocation, CGEventTapOptions,
    CGEventTapPlacement, CGEventType,
};
#[cfg(target_os = "macos")]
use std::sync::atomic::{AtomicBool, Ordering};
#[cfg(target_os = "macos")]
use std::sync::Arc;
#[cfg(target_os = "macos")]
use tauri::{AppHandle, Emitter};

#[cfg(target_os = "macos")]
static FN_KEY_PRESSED: AtomicBool = AtomicBool::new(false);

#[cfg(target_os = "macos")]
pub struct FnKeyMonitor {
    running: Arc<AtomicBool>,
    app_handle: Option<AppHandle>,
}

#[cfg(target_os = "macos")]
impl FnKeyMonitor {
    pub fn new() -> Self {
        Self {
            running: Arc::new(AtomicBool::new(false)),
            app_handle: None,
        }
    }

    pub fn set_app_handle(&mut self, app: AppHandle) {
        self.app_handle = Some(app);
    }

    /// Starts monitoring the Fn key
    /// Returns Ok(()) if successfully started, Err if failed
    pub fn start(&self) -> Result<(), String> {
        if self.running.load(Ordering::SeqCst) {
            return Ok(()); // Already running
        }

        let running = self.running.clone();
        let app_handle = self.app_handle.clone();

        std::thread::spawn(move || {
            running.store(true, Ordering::SeqCst);

            // Create event tap for flags changed events (modifier keys)
            let event_tap = CGEventTap::new(
                CGEventTapLocation::HID,
                CGEventTapPlacement::HeadInsertEventTap,
                CGEventTapOptions::ListenOnly,
                vec![CGEventType::FlagsChanged],
                move |_proxy, _event_type, event| {
                    let flags = event.get_flags();
                    let fn_pressed = flags.contains(CGEventFlags::CGEventFlagSecondaryFn);

                    let was_pressed = FN_KEY_PRESSED.load(Ordering::SeqCst);

                    if fn_pressed && !was_pressed {
                        // Fn key just pressed
                        FN_KEY_PRESSED.store(true, Ordering::SeqCst);
                        log::info!("Fn key pressed");

                        if let Some(ref app) = app_handle {
                            let _ = app.emit("fn-key-pressed", ());
                        }
                    } else if !fn_pressed && was_pressed {
                        // Fn key just released
                        FN_KEY_PRESSED.store(false, Ordering::SeqCst);
                        log::info!("Fn key released");

                        if let Some(ref app) = app_handle {
                            let _ = app.emit("fn-key-released", ());
                        }
                    }

                    None // Don't modify the event
                },
            );

            match event_tap {
                Ok(tap) => {
                    // Enable the tap
                    unsafe {
                        tap.enable();
                    }

                    // Add to run loop
                    let source = tap
                        .mach_port()
                        .create_runloop_source(0)
                        .expect("Failed to create run loop source");

                    let run_loop = CFRunLoop::get_current();
                    run_loop.add_source(&source, unsafe { kCFRunLoopCommonModes });

                    log::info!("Fn key monitor started successfully");

                    // Run the loop (blocks until stopped)
                    CFRunLoop::run_current();
                }
                Err(e) => {
                    log::error!("Failed to create event tap: {:?}", e);
                    log::error!(
                        "Make sure the app has Accessibility permissions in System Preferences"
                    );
                }
            }

            running.store(false, Ordering::SeqCst);
        });

        Ok(())
    }

    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
        // Note: To properly stop, we'd need to signal the run loop to stop
        // This is a simplified implementation
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::SeqCst)
    }
}

#[cfg(target_os = "macos")]
impl Default for FnKeyMonitor {
    fn default() -> Self {
        Self::new()
    }
}

// Stub for non-macOS platforms
#[cfg(not(target_os = "macos"))]
pub struct FnKeyMonitor;

#[cfg(not(target_os = "macos"))]
impl FnKeyMonitor {
    pub fn new() -> Self {
        Self
    }

    pub fn set_app_handle(&mut self, _app: tauri::AppHandle) {}

    pub fn start(&self) -> Result<(), String> {
        Err("Fn key monitoring is only supported on macOS".to_string())
    }

    pub fn stop(&self) {}

    pub fn is_running(&self) -> bool {
        false
    }
}

#[cfg(not(target_os = "macos"))]
impl Default for FnKeyMonitor {
    fn default() -> Self {
        Self::new()
    }
}
