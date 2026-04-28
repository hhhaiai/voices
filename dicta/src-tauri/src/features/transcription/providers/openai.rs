use reqwest::multipart::{Form, Part};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tauri::command;

use super::TranscriptionResponse;

/// HTTP request timeout for transcription API calls
const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);
/// HTTP connection timeout
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Serialize, Deserialize)]
struct OpenAIError {
    error: OpenAIErrorDetail,
}

#[derive(Debug, Serialize, Deserialize)]
struct OpenAIErrorDetail {
    message: String,
    #[serde(rename = "type")]
    error_type: String,
}

/// Get MIME type from filename extension
fn get_mime_type(filename: &str) -> &'static str {
    let ext = filename.rsplit('.').next().unwrap_or("wav").to_lowercase();
    match ext.as_str() {
        "mp3" => "audio/mpeg",
        "mp4" | "m4a" => "audio/mp4",
        "mpeg" | "mpga" => "audio/mpeg",
        "ogg" => "audio/ogg",
        "webm" => "audio/webm",
        "flac" => "audio/flac",
        _ => "audio/wav",
    }
}

/// Transcribe audio using OpenAI Whisper API
///
/// # Arguments
/// * `audio_data` - Raw audio bytes
/// * `api_key` - OpenAI API key
/// * `model` - Model ID (default: "whisper-1")
/// * `language` - Optional language code
/// * `filename` - Optional filename for MIME type detection
/// * `prompt` - Optional prompt with vocabulary/context to improve accuracy
#[command]
pub async fn transcribe_with_openai(
    audio_data: Vec<u8>,
    api_key: String,
    model: Option<String>,
    language: Option<String>,
    filename: Option<String>,
    prompt: Option<String>,
) -> Result<TranscriptionResponse, String> {
    let model = model.unwrap_or_else(|| "whisper-1".to_string());
    let filename = filename.unwrap_or_else(|| "audio.wav".to_string());
    let mime_type = get_mime_type(&filename);

    // Create multipart form
    let audio_part = Part::bytes(audio_data)
        .file_name(filename)
        .mime_str(mime_type)
        .map_err(|e| format!("Failed to create audio part: {}", e))?;

    let mut form = Form::new()
        .part("file", audio_part)
        .text("model", model)
        .text("response_format", "verbose_json");

    if let Some(lang) = language {
        form = form.text("language", lang);
    }

    // Add prompt for vocabulary/context hints
    // This helps Whisper recognize specific terms, names, and jargon
    if let Some(prompt_text) = prompt {
        if !prompt_text.is_empty() {
            log::debug!(
                "Adding vocabulary prompt to OpenAI request: {} chars",
                prompt_text.len()
            );
            form = form.text("prompt", prompt_text);
        }
    }

    // Make request to OpenAI API with timeouts to prevent hangs
    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .connect_timeout(CONNECT_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    let response = client
        .post("https://api.openai.com/v1/audio/transcriptions")
        .header("Authorization", format!("Bearer {}", api_key))
        .multipart(form)
        .send()
        .await
        .map_err(|e| format!("Failed to send request: {}", e))?;

    let status = response.status();
    let response_text = response
        .text()
        .await
        .map_err(|e| format!("Failed to read response: {}", e))?;

    if !status.is_success() {
        // Try to parse error response
        if let Ok(error) = serde_json::from_str::<OpenAIError>(&response_text) {
            return Err(format!(
                "OpenAI API error ({}): {}",
                status, error.error.message
            ));
        }
        return Err(format!(
            "OpenAI API request failed with status {}: {}",
            status, response_text
        ));
    }

    // Parse successful response
    let transcription: TranscriptionResponse = serde_json::from_str(&response_text)
        .map_err(|e| format!("Failed to parse transcription response: {}", e))?;

    Ok(transcription)
}
