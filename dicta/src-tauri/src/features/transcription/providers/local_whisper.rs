use std::sync::Arc;
use tauri::{command, State};
use tokio::sync::Mutex;

use super::TranscriptionResponse;
use crate::features::models::engines::ModelConfig;
use crate::features::models::LocalModelManager;

// TODO: This is not used anywhere, but we keep it here for reference
/// Converts WAV audio bytes to f32 samples for whisper-rs
///
/// This function parses the WAV header and converts 16-bit PCM samples
/// to normalized f32 values (-1.0 to 1.0)
fn _convert_audio_to_samples(audio_data: Vec<u8>) -> Result<Vec<f32>, String> {
    use hound::WavReader;
    use std::io::Cursor;

    // Create a cursor from the audio bytes
    let cursor = Cursor::new(audio_data);

    // Parse WAV file
    let reader = WavReader::new(cursor).map_err(|e| format!("Failed to parse WAV audio: {}", e))?;

    let spec = reader.spec();

    // Verify it's 16-bit PCM (most common format)
    if spec.bits_per_sample != 16 {
        return Err(format!(
            "Unsupported audio format: expected 16-bit, got {}-bit",
            spec.bits_per_sample
        ));
    }

    // Convert samples to f32
    let samples: Result<Vec<f32>, _> = reader
        .into_samples::<i16>()
        .map(|s| s.map(|sample| sample as f32 / 32768.0))
        .collect();

    samples.map_err(|e| format!("Failed to read audio samples: {}", e))
}

/// Transcribes audio using the loaded local model
///
/// This command uses the LocalModelManager to transcribe audio with the
/// currently loaded model. The model must be started first using
/// `start_local_model`.
///
/// # Arguments
/// * `audio_data` - Raw audio bytes in WAV format
/// * `model` - Model name (currently ignored, uses loaded model)
/// * `language` - Optional language code (e.g., "en", "es")
/// * `translate` - If true, translate output to English
/// * `initial_prompt` - Optional vocabulary/context prompt for better accuracy
/// * `state` - Shared LocalModelManager state
#[command]
pub async fn transcribe_with_local_whisper(
    audio_data: Vec<u8>,
    model: Option<String>,
    language: Option<String>,
    translate: bool,
    initial_prompt: Option<String>,
    state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<TranscriptionResponse, String> {
    // Note: The model parameter is kept for API compatibility but not used
    // The loaded model from LocalModelManager is used instead
    let _ = model;

    // Transcribe using the loaded model
    // The LocalModelManager handles audio conversion internally
    let mut manager = state.lock().await;
    let text = manager
        .transcribe(audio_data, language.clone(), translate, initial_prompt)
        .map_err(|e| e.to_string())?;

    Ok(TranscriptionResponse {
        text,
        language,
        segments: None, // Can be enhanced later to return segment information
    })
}

/// Transcribes audio using a specific local engine (candle, whisperkit, apple-speech)
///
/// This function loads the model if not already loaded with the correct engine,
/// then transcribes the audio.
///
/// # Arguments
/// * `audio_data` - Raw audio bytes in WAV format
/// * `engine_type` - Engine to use: "candle", "whisperkit", or "apple-speech"
/// * `model_path` - Path to the model file (optional for apple-speech)
/// * `model_id` - Model identifier
/// * `language` - Optional language code (e.g., "en", "es")
/// * `translate` - If true, translate output to English
/// * `initial_prompt` - Optional vocabulary/context prompt for better accuracy
/// * `state` - Shared LocalModelManager state
pub async fn transcribe_with_local_engine(
    audio_data: Vec<u8>,
    engine_type: &str,
    model_path: Option<String>,
    model_id: Option<String>,
    language: Option<String>,
    translate: bool,
    initial_prompt: Option<String>,
    state: State<'_, Arc<Mutex<LocalModelManager>>>,
) -> Result<TranscriptionResponse, String> {
    let mut manager = state.lock().await;

    // Check if we need to load a different engine or model
    let current_engine = manager.get_active_engine_type();
    let needs_load = match current_engine {
        Some(current) => current != engine_type,
        None => true,
    };

    if needs_load {
        // Load the model with the specified engine
        let config = ModelConfig {
            model_path: model_path.clone().unwrap_or_else(|| {
                // For apple-speech, use a placeholder path
                if engine_type == "apple-speech" {
                    "system://apple-speech".to_string()
                } else {
                    String::new()
                }
            }),
            model_name: model_id.clone().unwrap_or_else(|| engine_type.to_string()),
            language: language.clone(),
        };

        manager.load_model(engine_type, config)?;
    }

    // Transcribe using the loaded engine
    let text = manager
        .transcribe(audio_data, language.clone(), translate, initial_prompt)
        .map_err(|e| e.to_string())?;

    Ok(TranscriptionResponse {
        text,
        language,
        segments: None,
    })
}
