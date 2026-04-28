//! Deepgram transcription provider
//!
//! Uses Deepgram's Nova-2 model for fast, accurate transcription.
//! Supports keywords for vocabulary hints.

use serde::Deserialize;
use std::time::Duration;
use tauri::command;

use super::TranscriptionResponse;

/// HTTP request timeout for transcription API calls
const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);
/// HTTP connection timeout
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Deserialize)]
struct DeepgramResponse {
    results: Option<DeepgramResults>,
}

#[derive(Debug, Deserialize)]
struct DeepgramResults {
    channels: Vec<DeepgramChannel>,
}

#[derive(Debug, Deserialize)]
struct DeepgramChannel {
    alternatives: Vec<DeepgramAlternative>,
}

#[derive(Debug, Deserialize)]
struct DeepgramAlternative {
    transcript: String,
    confidence: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct DeepgramError {
    err_msg: Option<String>,
    err_code: Option<String>,
}

/// Transcribe audio using Deepgram API
///
/// # Arguments
/// * `audio_data` - Raw audio bytes (WAV format)
/// * `api_key` - Deepgram API key
/// * `language` - Optional language code (e.g., "en")
/// * `keywords` - Optional list of keywords to boost recognition
#[command]
pub async fn transcribe_with_deepgram(
    audio_data: Vec<u8>,
    api_key: String,
    language: Option<String>,
    keywords: Option<Vec<String>>,
) -> Result<TranscriptionResponse, String> {
    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .connect_timeout(CONNECT_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    // Build URL with query parameters
    let mut url =
        "https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true"
            .to_string();

    // Add language if specified
    if let Some(ref lang) = language {
        url.push_str(&format!("&language={}", lang));
    }

    // Add keywords for vocabulary hints
    // Deepgram uses keywords=word:intensifier format
    if let Some(ref words) = keywords {
        if !words.is_empty() {
            log::debug!("Adding {} keywords to Deepgram request", words.len());
            // Join keywords with intensifier (2.0 = strong boost)
            let keywords_param: Vec<String> = words.iter().map(|w| format!("{}:2", w)).collect();
            url.push_str(&format!("&keywords={}", keywords_param.join(",")));
        }
    }

    let response = client
        .post(&url)
        .header("Authorization", format!("Token {}", api_key))
        .header("Content-Type", "audio/wav")
        .body(audio_data)
        .send()
        .await
        .map_err(|e| format!("Failed to send request: {}", e))?;

    let status = response.status();
    let response_text = response
        .text()
        .await
        .map_err(|e| format!("Failed to read response: {}", e))?;

    if !status.is_success() {
        if let Ok(error) = serde_json::from_str::<DeepgramError>(&response_text) {
            let msg = error.err_msg.unwrap_or_else(|| "Unknown error".to_string());
            return Err(format!("Deepgram API error: {}", msg));
        }
        return Err(format!(
            "Deepgram API request failed with status {}: {}",
            status, response_text
        ));
    }

    let deepgram_response: DeepgramResponse = serde_json::from_str(&response_text)
        .map_err(|e| format!("Failed to parse response: {}", e))?;

    let text = deepgram_response
        .results
        .and_then(|r| r.channels.into_iter().next())
        .and_then(|c| c.alternatives.into_iter().next())
        .map(|a| a.transcript)
        .unwrap_or_default();

    Ok(TranscriptionResponse {
        text,
        language,
        segments: None,
    })
}
