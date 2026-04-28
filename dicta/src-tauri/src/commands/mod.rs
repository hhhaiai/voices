pub mod logs;
#[cfg(target_os = "macos")]
pub mod speech_recognition;

pub use logs::clear_old_logs;
#[cfg(target_os = "macos")]
pub use speech_recognition::{
    check_speech_recognition_permission, request_speech_recognition_permission,
};
