//! Speech Recognition Permission Commands
//!
//! Commands to check and request macOS Speech Recognition permission
//! required for Apple Speech transcription engine.

use serde::{Deserialize, Serialize};
use tauri::command;
use ts_rs::TS;

/// Speech recognition authorization status
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/lib/generated/")]
#[serde(rename_all = "camelCase")]
pub enum SpeechRecognitionAuthStatus {
    /// User has not yet made a choice
    NotDetermined,
    /// User denied access
    Denied,
    /// Access is restricted (parental controls, etc.)
    Restricted,
    /// User has granted access
    Authorized,
}

/// Check the current speech recognition authorization status
#[command]
pub async fn check_speech_recognition_permission() -> Result<SpeechRecognitionAuthStatus, String> {
    #[cfg(target_os = "macos")]
    {
        use objc2_speech::{SFSpeechRecognizer, SFSpeechRecognizerAuthorizationStatus};

        let status = unsafe { SFSpeechRecognizer::authorizationStatus() };

        let result = match status {
            SFSpeechRecognizerAuthorizationStatus::NotDetermined => {
                SpeechRecognitionAuthStatus::NotDetermined
            }
            SFSpeechRecognizerAuthorizationStatus::Denied => SpeechRecognitionAuthStatus::Denied,
            SFSpeechRecognizerAuthorizationStatus::Restricted => {
                SpeechRecognitionAuthStatus::Restricted
            }
            SFSpeechRecognizerAuthorizationStatus::Authorized => {
                SpeechRecognitionAuthStatus::Authorized
            }
            _ => SpeechRecognitionAuthStatus::NotDetermined,
        };

        log::info!("Speech recognition authorization status: {:?}", result);
        Ok(result)
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("Speech recognition is only available on macOS".to_string())
    }
}

/// Request speech recognition authorization from the user
/// This will show a system dialog asking for permission
#[command]
pub async fn request_speech_recognition_permission() -> Result<SpeechRecognitionAuthStatus, String>
{
    #[cfg(target_os = "macos")]
    {
        use block2::RcBlock;
        use objc2_speech::{SFSpeechRecognizer, SFSpeechRecognizerAuthorizationStatus};
        use std::sync::mpsc;
        use std::time::Duration;

        log::info!("Requesting speech recognition authorization...");

        // Check if already authorized
        let current_status = unsafe { SFSpeechRecognizer::authorizationStatus() };
        if matches!(
            current_status,
            SFSpeechRecognizerAuthorizationStatus::Authorized
        ) {
            log::info!("Speech recognition already authorized");
            return Ok(SpeechRecognitionAuthStatus::Authorized);
        }

        // Create channel for result communication
        let (tx, rx) = mpsc::channel::<SFSpeechRecognizerAuthorizationStatus>();

        // Create the handler block
        let handler = RcBlock::new(move |status: SFSpeechRecognizerAuthorizationStatus| {
            log::info!("Speech recognition authorization callback: {:?}", status);
            let _ = tx.send(status);
        });

        // Request authorization - this will show the system dialog
        unsafe {
            SFSpeechRecognizer::requestAuthorization(&handler);
        }

        // Wait for the callback with a timeout
        match rx.recv_timeout(Duration::from_secs(60)) {
            Ok(status) => {
                let result = match status {
                    SFSpeechRecognizerAuthorizationStatus::NotDetermined => {
                        SpeechRecognitionAuthStatus::NotDetermined
                    }
                    SFSpeechRecognizerAuthorizationStatus::Denied => {
                        SpeechRecognitionAuthStatus::Denied
                    }
                    SFSpeechRecognizerAuthorizationStatus::Restricted => {
                        SpeechRecognitionAuthStatus::Restricted
                    }
                    SFSpeechRecognizerAuthorizationStatus::Authorized => {
                        SpeechRecognitionAuthStatus::Authorized
                    }
                    _ => SpeechRecognitionAuthStatus::NotDetermined,
                };
                log::info!("Speech recognition authorization result: {:?}", result);
                Ok(result)
            }
            Err(_) => {
                log::warn!("Speech recognition authorization request timed out");
                // Check the status anyway - user might have responded
                let final_status = unsafe { SFSpeechRecognizer::authorizationStatus() };
                let result = match final_status {
                    SFSpeechRecognizerAuthorizationStatus::Authorized => {
                        SpeechRecognitionAuthStatus::Authorized
                    }
                    SFSpeechRecognizerAuthorizationStatus::Denied => {
                        SpeechRecognitionAuthStatus::Denied
                    }
                    _ => SpeechRecognitionAuthStatus::NotDetermined,
                };
                Ok(result)
            }
        }
    }

    #[cfg(not(target_os = "macos"))]
    {
        Err("Speech recognition is only available on macOS".to_string())
    }
}
