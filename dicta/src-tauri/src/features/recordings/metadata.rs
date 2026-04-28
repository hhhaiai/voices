use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Comprehensive metadata for each recording
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct RecordingMetadata {
    // Core transcription data
    pub result: String,                        // Final processed text
    pub raw_result: String,                    // Original transcription text
    pub post_processed_result: Option<String>, // AI post-processed text (if applied)

    // Timing information
    pub datetime: String,     // ISO 8601 timestamp
    pub duration: f64,        // Duration in milliseconds
    pub processing_time: u64, // Time taken to process in ms

    // Speech-to-text model information
    pub model_key: String,  // Model ID used for transcription
    pub model_name: String, // Human-readable model name
    pub provider: String,   // Provider (openai, google, local-whisper, etc.)

    // Post-processing model information
    pub post_processing_model_id: Option<String>, // Post-processing model ID (if used)
    pub post_processing_model_name: Option<String>, // Post-processing model name (if used)
    pub post_processing_provider: Option<String>, // Post-processing provider (if used)

    // Language
    pub language_selected: String, // Language code (e.g., "en")
    #[serde(default)]
    pub translated_to_english: bool, // Whether output was translated to English

    // Device information
    pub recording_device: String, // Microphone device ID/name

    // Post-processing context
    pub post_processing_enabled: bool,
    pub style_applied: Option<String>, // Which vibe/style was applied
    pub style_category: Option<String>, // Category (personal/work/email/other)

    // Application context
    pub focused_app_name: String,     // Name of the focused application
    pub focused_app_category: String, // Categorized type (personal/work/email/other)

    // Prompt context (for AI post-processing)
    pub prompt_context: PromptContext,

    // App version
    pub app_version: String,

    // Audio file status
    #[serde(default)]
    pub has_audio: bool, // Whether audio file was saved (based on saveAudioRecordings setting)

    // Source type - distinguishes between recorded and uploaded audio
    #[serde(default = "default_source_type")]
    pub source_type: SourceType,

    // Original filename (for uploaded files)
    #[serde(default)]
    pub original_filename: Option<String>,

    // Command mode: the generated content (instruction is stored in raw_result)
    #[serde(default)]
    pub command_result: Option<String>,
}

fn default_source_type() -> SourceType {
    SourceType::Recording
}

/// Source type for transcriptions
#[derive(Debug, Clone, Default, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "lowercase")]
pub enum SourceType {
    #[default]
    Recording, // Voice recording from microphone
    Upload,  // Uploaded audio file
    Command, // Command mode (voice command → generated content)
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct PromptContext {
    pub vocabulary_used: Vec<String>,
    pub snippets_used: Vec<SnippetInfo>,
    pub vibe_prompt: Option<String>,
    pub system_context: SystemContext,
    pub application_context: ApplicationContext,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct SnippetInfo {
    pub trigger: String,
    pub expansion: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct SystemContext {
    pub language: String,
    pub time: String, // Current time when recording was made
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(
    export,
    export_to = "../../src/features/transcriptions/types/generated/"
)]
#[serde(rename_all = "camelCase")]
pub struct ApplicationContext {
    pub name: String,
    pub category: String,
}

impl RecordingMetadata {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        raw_result: String,
        final_result: String,
        post_processed_result: Option<String>,
        timestamp: i64,
        duration: f64,
        processing_time: u64,
        model_key: String,
        model_name: String,
        provider: String,
        post_processing_model_id: Option<String>,
        post_processing_model_name: Option<String>,
        post_processing_provider: Option<String>,
        language: String,
        translated_to_english: bool,
        recording_device: String,
        focused_app_name: String,
        focused_app_category: String,
        post_processing_enabled: bool,
        style_applied: Option<String>,
        style_category: Option<String>,
        prompt_context: PromptContext,
        has_audio: bool,
    ) -> Self {
        Self::with_source(
            raw_result,
            final_result,
            post_processed_result,
            timestamp,
            duration,
            processing_time,
            model_key,
            model_name,
            provider,
            post_processing_model_id,
            post_processing_model_name,
            post_processing_provider,
            language,
            translated_to_english,
            recording_device,
            focused_app_name,
            focused_app_category,
            post_processing_enabled,
            style_applied,
            style_category,
            prompt_context,
            has_audio,
            SourceType::Recording,
            None,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn with_source(
        raw_result: String,
        final_result: String,
        post_processed_result: Option<String>,
        timestamp: i64,
        duration: f64,
        processing_time: u64,
        model_key: String,
        model_name: String,
        provider: String,
        post_processing_model_id: Option<String>,
        post_processing_model_name: Option<String>,
        post_processing_provider: Option<String>,
        language: String,
        translated_to_english: bool,
        recording_device: String,
        focused_app_name: String,
        focused_app_category: String,
        post_processing_enabled: bool,
        style_applied: Option<String>,
        style_category: Option<String>,
        prompt_context: PromptContext,
        has_audio: bool,
        source_type: SourceType,
        original_filename: Option<String>,
    ) -> Self {
        use chrono::prelude::*;

        // Convert timestamp to ISO 8601
        let datetime = DateTime::from_timestamp(timestamp / 1000, 0)
            .unwrap_or_else(|| Utc::now())
            .format("%Y-%m-%dT%H:%M:%S")
            .to_string();

        Self {
            result: final_result,
            raw_result,
            post_processed_result,
            datetime,
            duration,
            processing_time,
            model_key,
            model_name,
            provider,
            post_processing_model_id,
            post_processing_model_name,
            post_processing_provider,
            language_selected: language,
            translated_to_english,
            recording_device,
            post_processing_enabled,
            style_applied,
            style_category,
            focused_app_name,
            focused_app_category,
            prompt_context,
            app_version: env!("CARGO_PKG_VERSION").to_string(),
            has_audio,
            source_type,
            original_filename,
            command_result: None,
        }
    }

    /// Create metadata for a command mode entry
    #[allow(clippy::too_many_arguments)]
    pub fn for_command(
        instruction: String,
        generated_content: String,
        timestamp: i64,
        duration: f64,
        processing_time: u64,
        model_key: String,
        model_name: String,
        provider: String,
        post_processing_model_id: String,
        post_processing_model_name: String,
        post_processing_provider: String,
        recording_device: String,
    ) -> Self {
        use chrono::prelude::*;

        let datetime = DateTime::from_timestamp(timestamp / 1000, 0)
            .unwrap_or_else(|| Utc::now())
            .format("%Y-%m-%dT%H:%M:%S")
            .to_string();

        Self {
            result: instruction.clone(), // The instruction shown in list
            raw_result: instruction,
            post_processed_result: None,
            datetime: datetime.clone(),
            duration,
            processing_time,
            model_key,
            model_name,
            provider,
            post_processing_model_id: Some(post_processing_model_id),
            post_processing_model_name: Some(post_processing_model_name),
            post_processing_provider: Some(post_processing_provider),
            language_selected: "en".to_string(),
            translated_to_english: false,
            recording_device,
            post_processing_enabled: true,
            style_applied: None,
            style_category: None,
            focused_app_name: String::new(),
            focused_app_category: String::new(),
            prompt_context: PromptContext {
                vocabulary_used: vec![],
                snippets_used: vec![],
                vibe_prompt: None,
                system_context: SystemContext {
                    language: "en".to_string(),
                    time: datetime,
                },
                application_context: ApplicationContext {
                    name: String::new(),
                    category: String::new(),
                },
            },
            app_version: env!("CARGO_PKG_VERSION").to_string(),
            has_audio: false,
            source_type: SourceType::Command,
            original_filename: None,
            command_result: Some(generated_content),
        }
    }
}
