//! Unified error types for the Dicta application.
//!
//! This module provides structured error handling across the entire application,
//! replacing ad-hoc string-based errors with typed variants that can be properly
//! matched, logged, and converted to user-friendly messages.

use std::time::Duration;
use thiserror::Error;

/// Top-level application error type
#[derive(Error, Debug)]
pub enum DictaError {
    #[error("Recording error: {0}")]
    Recording(#[from] RecordingError),

    #[error("Transcription error: {0}")]
    Transcription(#[from] TranscriptionError),

    #[error("Model error: {0}")]
    Model(#[from] ModelError),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Internal error: {0}")]
    Internal(String),
}

/// Errors related to audio recording
#[derive(Error, Debug)]
pub enum RecordingError {
    #[error("No audio input device available")]
    NoDevice,

    #[error("Audio device '{0}' not found")]
    DeviceNotFound(String),

    #[error("Already recording")]
    AlreadyRecording,

    #[error("Not currently recording")]
    NotRecording,

    #[error("Lock acquisition timed out after {0:?}")]
    LockTimeout(Duration),

    #[error("Lock poisoned - previous operation panicked")]
    LockPoisoned,

    #[error("Audio stream error: {0}")]
    StreamError(String),

    #[error("Invalid state transition: {from:?} -> {to:?}")]
    InvalidStateTransition {
        from: RecordingStateKind,
        to: RecordingStateKind,
    },

    #[error("Operation in progress, please wait")]
    OperationInProgress,

    #[error("Failed to create audio file: {0}")]
    FileCreationFailed(String),

    #[error("Failed to write audio data: {0}")]
    WriteError(String),

    #[error("Device configuration error: {0}")]
    ConfigError(String),

    #[error("Ring buffer overflow - audio data dropped")]
    BufferOverflow,
}

/// Recording state kinds for error reporting
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecordingStateKind {
    Idle,
    Starting,
    Recording,
    Stopping,
    Transcribing,
    Error,
}

/// Errors related to transcription
#[derive(Error, Debug)]
pub enum TranscriptionError {
    #[error("No transcription model selected")]
    NoModelSelected,

    #[error("Model '{0}' not found")]
    ModelNotFound(String),

    #[error("Model '{0}' not downloaded")]
    ModelNotDownloaded(String),

    #[error("API key not configured for provider '{0}'")]
    ApiKeyMissing(String),

    #[error("API request failed: {0}")]
    ApiError(String),

    #[error("Failed to process audio: {0}")]
    AudioProcessingError(String),

    #[error("Network error: {0}")]
    NetworkError(String),

    #[error("Transcription timed out after {0:?}")]
    Timeout(Duration),

    #[error("Invalid audio format: {0}")]
    InvalidAudioFormat(String),

    #[error("Empty audio data")]
    EmptyAudio,
}

/// Errors related to model management
#[derive(Error, Debug)]
pub enum ModelError {
    #[error("Model '{0}' not found in registry")]
    NotFound(String),

    #[error("Download failed for model '{0}': {1}")]
    DownloadFailed(String, String),

    #[error("Model '{0}' already downloading")]
    AlreadyDownloading(String),

    #[error("Failed to load model '{0}': {1}")]
    LoadFailed(String, String),

    #[error("Model '{0}' not loaded")]
    NotLoaded(String),

    #[error("Invalid model configuration: {0}")]
    InvalidConfig(String),

    #[error("Insufficient disk space for model '{0}'")]
    InsufficientSpace(String),

    #[error("Model file corrupted: {0}")]
    Corrupted(String),
}

// Implement conversion to String for Tauri command compatibility
impl From<DictaError> for String {
    fn from(err: DictaError) -> String {
        err.to_string()
    }
}

impl From<RecordingError> for String {
    fn from(err: RecordingError) -> String {
        err.to_string()
    }
}

impl From<TranscriptionError> for String {
    fn from(err: TranscriptionError) -> String {
        err.to_string()
    }
}

impl From<ModelError> for String {
    fn from(err: ModelError) -> String {
        err.to_string()
    }
}

/// Result type alias for operations that can fail with DictaError
pub type DictaResult<T> = Result<T, DictaError>;

/// Result type alias for recording operations
pub type RecordingResult<T> = Result<T, RecordingError>;

/// Result type alias for transcription operations
pub type TranscriptionResult<T> = Result<T, TranscriptionError>;

/// Result type alias for model operations
pub type ModelResult<T> = Result<T, ModelError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_display() {
        let err = RecordingError::DeviceNotFound("Microphone".to_string());
        assert_eq!(err.to_string(), "Audio device 'Microphone' not found");
    }

    #[test]
    fn test_error_conversion() {
        let err = RecordingError::AlreadyRecording;
        let dicta_err: DictaError = err.into();
        assert!(matches!(dicta_err, DictaError::Recording(_)));
    }

    #[test]
    fn test_string_conversion() {
        let err = RecordingError::LockTimeout(Duration::from_secs(2));
        let s: String = err.into();
        assert!(s.contains("timed out"));
    }
}
