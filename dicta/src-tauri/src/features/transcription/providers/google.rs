use serde::{Deserialize, Serialize};
use std::time::Duration;
use tauri::command;

use super::TranscriptionResponse;

/// HTTP request timeout for transcription API calls
const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);
/// HTTP connection timeout
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Serialize, Deserialize)]
struct GoogleSpeechRequest {
    config: GoogleSpeechConfig,
    audio: GoogleAudioContent,
}

/// Speech context for phrase hints (vocabulary boosting)
#[derive(Debug, Serialize, Deserialize)]
struct SpeechContext {
    /// List of phrases to boost recognition for
    phrases: Vec<String>,
    /// Boost value (0-20, higher = stronger boost)
    #[serde(skip_serializing_if = "Option::is_none")]
    boost: Option<f32>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleSpeechConfig {
    encoding: String,
    #[serde(rename = "sampleRateHertz")]
    sample_rate_hertz: i32,
    #[serde(rename = "languageCode")]
    language_code: String,
    #[serde(rename = "enableAutomaticPunctuation")]
    enable_automatic_punctuation: bool,
    /// Speech contexts for vocabulary/phrase hints
    #[serde(rename = "speechContexts", skip_serializing_if = "Option::is_none")]
    speech_contexts: Option<Vec<SpeechContext>>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleAudioContent {
    content: String, // base64 encoded audio
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleSpeechResponse {
    results: Option<Vec<GoogleRecognitionResult>>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleRecognitionResult {
    alternatives: Vec<GoogleSpeechAlternative>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleSpeechAlternative {
    transcript: String,
    confidence: Option<f64>,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleError {
    error: GoogleErrorDetail,
}

#[derive(Debug, Serialize, Deserialize)]
struct GoogleErrorDetail {
    message: String,
    code: i32,
}

/// Transcribe audio using Google Cloud Speech-to-Text API
///
/// # Arguments
/// * `audio_data` - Raw audio bytes
/// * `api_key` - Google Cloud API key
/// * `language` - Optional language code (e.g., "en-US")
/// * `vocabulary` - Optional list of words/phrases to boost recognition
#[command]
pub async fn transcribe_with_google(
    audio_data: Vec<u8>,
    api_key: String,
    language: Option<String>,
    vocabulary: Option<Vec<String>>,
) -> Result<TranscriptionResponse, String> {
    let language_code = language.unwrap_or_else(|| "en-US".to_string());

    // Encode audio to base64
    use base64::{engine::general_purpose::STANDARD, Engine};
    let audio_base64 = STANDARD.encode(&audio_data);

    // Build speech contexts for vocabulary/phrase hints
    let speech_contexts = vocabulary.and_then(|words| {
        if words.is_empty() {
            None
        } else {
            log::debug!(
                "Adding {} phrase hints to Google Speech request",
                words.len()
            );
            Some(vec![SpeechContext {
                phrases: words,
                boost: Some(10.0), // Strong boost for user-defined vocabulary
            }])
        }
    });

    let request_body = GoogleSpeechRequest {
        config: GoogleSpeechConfig {
            encoding: "LINEAR16".to_string(),
            sample_rate_hertz: 16000,
            language_code,
            enable_automatic_punctuation: true,
            speech_contexts,
        },
        audio: GoogleAudioContent {
            content: audio_base64,
        },
    };

    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .connect_timeout(CONNECT_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    let response = client
        .post(format!(
            "https://speech.googleapis.com/v1/speech:recognize?key={}",
            api_key
        ))
        .json(&request_body)
        .send()
        .await
        .map_err(|e| format!("Failed to send request: {}", e))?;

    let status = response.status();
    let response_text = response
        .text()
        .await
        .map_err(|e| format!("Failed to read response: {}", e))?;

    if !status.is_success() {
        if let Ok(error) = serde_json::from_str::<GoogleError>(&response_text) {
            return Err(format!(
                "Google API error ({}): {}",
                error.error.code, error.error.message
            ));
        }
        return Err(format!(
            "Google API request failed with status {}: {}",
            status, response_text
        ));
    }

    let speech_response: GoogleSpeechResponse = serde_json::from_str(&response_text)
        .map_err(|e| format!("Failed to parse response: {}", e))?;

    let text = speech_response
        .results
        .and_then(|results| results.into_iter().next())
        .and_then(|result| result.alternatives.into_iter().next())
        .map(|alt| alt.transcript)
        .unwrap_or_default();

    Ok(TranscriptionResponse {
        text,
        language: None,
        segments: None,
    })
}
