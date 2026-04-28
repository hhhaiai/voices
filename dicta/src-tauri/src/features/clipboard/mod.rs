use crate::utils::logger;
use std::time::Duration;
use tauri::command;

#[cfg(target_os = "macos")]
use tokio::process::Command;

#[cfg(target_os = "macos")]
use serde::{Deserialize, Serialize};

#[cfg(target_os = "macos")]
use std::process::Stdio;

use ts_rs::TS;

/// Timeout for paste operations - if target app is unresponsive
const PASTE_TIMEOUT: Duration = Duration::from_secs(5);
/// Timeout for getting focused app info
const GET_APP_TIMEOUT: Duration = Duration::from_secs(3);

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct FocusedApp {
    pub name: String,
    pub bundle_id: String,
}

/// Get the currently focused application (macOS only)
#[command]
pub async fn get_focused_app() -> Result<FocusedApp, String> {
    #[cfg(target_os = "macos")]
    {
        // Use AppleScript to get frontmost application info with timeout
        let script = r#"
            tell application "System Events"
                set frontApp to first application process whose frontmost is true
                set appName to name of frontApp
                set appBundleID to bundle identifier of frontApp
                return appName & "|" & appBundleID
            end tell
        "#;

        let output = tokio::time::timeout(GET_APP_TIMEOUT, async {
            Command::new("osascript")
                .arg("-e")
                .arg(script)
                .output()
                .await
                .map_err(|e| format!("Failed to get focused app: {}", e))
        })
        .await
        .map_err(|_| {
            "Timed out getting focused app - System Events may be unresponsive".to_string()
        })??;

        let result = String::from_utf8_lossy(&output.stdout);
        let parts: Vec<&str> = result.trim().split('|').collect();

        if parts.len() >= 2 {
            Ok(FocusedApp {
                name: parts[0].to_string(),
                bundle_id: parts[1].to_string(),
            })
        } else {
            Err("Failed to parse focused app info".to_string())
        }
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("get_focused_app is only supported on macOS".to_string())
    }
}

#[cfg(target_os = "macos")]
fn check_accessibility_trusted() -> bool {
    unsafe {
        #[link(name = "ApplicationServices", kind = "framework")]
        extern "C" {
            fn AXIsProcessTrusted() -> u8;
        }
        AXIsProcessTrusted() != 0
    }
}

#[command]
pub fn check_accessibility_permission() -> bool {
    #[cfg(target_os = "macos")]
    {
        check_accessibility_trusted()
    }

    #[cfg(not(target_os = "macos"))]
    {
        true
    }
}

/// Copy text to clipboard and simulate paste at cursor position
#[command]
pub async fn copy_and_paste(text: String) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        if !check_accessibility_trusted() {
            logger::warn("Accessibility permission not granted - paste may fail");
        }

        // DEBUG: Check which app is focused before pasting
        let focused_app = match get_focused_app().await {
            Ok(app) => {
                logger::debug("=== PASTE DEBUG ===");
                logger::debug(&format!("Focused app: {} ({})", app.name, app.bundle_id));
                logger::debug(&format!("Text to paste: {}", &text[..text.len().min(50)]));
                app
            }
            Err(e) => {
                logger::debug("=== PASTE DEBUG ===");
                logger::error(&format!("ERROR: Could not get focused app: {}", e));
                return Err(e);
            }
        };

        // Copy to clipboard using pbcopy
        let mut pbcopy = Command::new("pbcopy")
            .stdin(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Failed to spawn pbcopy: {}", e))?;

        use tokio::io::AsyncWriteExt;
        if let Some(mut stdin) = pbcopy.stdin.take() {
            stdin
                .write_all(text.as_bytes())
                .await
                .map_err(|e| format!("Failed to write to pbcopy: {}", e))?;
        }

        pbcopy
            .wait()
            .await
            .map_err(|e| format!("Failed to wait for pbcopy: {}", e))?;

        logger::debug("Clipboard updated, waiting before paste...");

        // Wait for clipboard to be ready (async, non-blocking)
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;

        // Combined script: Activate app, wait, then paste
        // This reduces 2 osascript calls to 1, saving ~50ms process spawn overhead
        let combined_script = format!(
            r#"
            tell application "{app_name}"
                activate
            end tell
            tell application "System Events"
                tell process "{app_name}"
                    set frontmost to true
                end tell
                delay 0.15
                keystroke "v" using command down
            end tell
            "#,
            app_name = focused_app.name
        );

        logger::debug(&format!(
            "Activating {} and pasting in single script...",
            focused_app.name
        ));

        // Execute paste with timeout to prevent hanging on unresponsive apps
        let output = tokio::time::timeout(PASTE_TIMEOUT, async {
            Command::new("osascript")
                .arg("-e")
                .arg(&combined_script)
                .output()
                .await
                .map_err(|e| format!("Failed to execute paste command: {}", e))
        })
        .await
        .map_err(|_| format!("Paste timed out - {} may be unresponsive", focused_app.name))??;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            logger::error(&format!("Paste failed: {}", stderr));

            if stderr.contains("not allowed")
                || stderr.contains("assistive")
                || stderr.contains("1002")
            {
                return Err("Accessibility permission not granted. Enable Dicta in System Settings → Privacy & Security → Accessibility".to_string());
            }
            return Err(format!("Paste failed: {}", stderr));
        }

        Ok(())
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("Auto-paste is only supported on macOS".to_string())
    }
}
