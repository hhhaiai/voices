//! AssemblyAI transcription provider
//!
//! Uses AssemblyAI's Universal-2 model for high-accuracy transcription.
//! Supports word_boost for vocabulary hints.

use serde::{Deserialize, Serialize};
use std::time::Duration;
use tauri::command;

use super::TranscriptionResponse;

/// HTTP request timeout for transcription API calls
const REQUEST_TIMEOUT: Duration = Duration::from_secs(120);
/// HTTP connection timeout
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
/// Polling interval for checking transcription status
const POLL_INTERVAL: Duration = Duration::from_millis(500);
/// Maximum polling attempts (2 minutes total)
const MAX_POLL_ATTEMPTS: u32 = 240;

#[derive(Debug, Serialize)]
struct AssemblyAIUploadResponse {
    upload_url: String,
}

#[derive(Debug, Serialize)]
struct AssemblyAITranscriptRequest {
    audio_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    language_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    word_boost: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    boost_param: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AssemblyAITranscriptResponse {
    id: String,
    status: String,
    text: Option<String>,
    error: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AssemblyAIError {
    error: String,
}

/// Transcribe audio using AssemblyAI API
///
/// # Arguments
/// * `audio_data` - Raw audio bytes
/// * `api_key` - AssemblyAI API key
/// * `language` - Optional language code (e.g., "en")
/// * `vocabulary` - Optional list of words/phrases to boost recognition
#[command]
pub async fn transcribe_with_assemblyai(
    audio_data: Vec<u8>,
    api_key: String,
    language: Option<String>,
    vocabulary: Option<Vec<String>>,
) -> Result<TranscriptionResponse, String> {
    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .connect_timeout(CONNECT_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    // Step 1: Upload audio to AssemblyAI
    let upload_response = client
        .post("https://api.assemblyai.com/v2/upload")
        .header("Authorization", &api_key)
        .header("Content-Type", "application/octet-stream")
        .body(audio_data)
        .send()
        .await
        .map_err(|e| format!("Failed to upload audio: {}", e))?;

    if !upload_response.status().is_success() {
        let error_text = upload_response.text().await.unwrap_or_default();
        return Err(format!("Failed to upload audio: {}", error_text));
    }

    let upload_result: serde_json::Value = upload_response
        .json()
        .await
        .map_err(|e| format!("Failed to parse upload response: {}", e))?;

    let audio_url = upload_result
        .get("upload_url")
        .and_then(|v| v.as_str())
        .ok_or("Missing upload_url in response")?
        .to_string();

    // Step 2: Create transcription request
    let mut request_body = AssemblyAITranscriptRequest {
        audio_url,
        language_code: language.clone(),
        word_boost: None,
        boost_param: None,
    };

    // Add word boost if vocabulary is provided
    if let Some(words) = vocabulary {
        if !words.is_empty() {
            log::debug!(
                "Adding {} word boost terms to AssemblyAI request",
                words.len()
            );
            request_body.word_boost = Some(words);
            request_body.boost_param = Some("high".to_string());
        }
    }

    let transcript_response = client
        .post("https://api.assemblyai.com/v2/transcript")
        .header("Authorization", &api_key)
        .header("Content-Type", "application/json")
        .json(&request_body)
        .send()
        .await
        .map_err(|e| format!("Failed to create transcript: {}", e))?;

    if !transcript_response.status().is_success() {
        let error_text = transcript_response.text().await.unwrap_or_default();
        if let Ok(error) = serde_json::from_str::<AssemblyAIError>(&error_text) {
            return Err(format!("AssemblyAI API error: {}", error.error));
        }
        return Err(format!("Failed to create transcript: {}", error_text));
    }

    let transcript_result: AssemblyAITranscriptResponse = transcript_response
        .json()
        .await
        .map_err(|e| format!("Failed to parse transcript response: {}", e))?;

    let transcript_id = transcript_result.id;

    // Step 3: Poll for completion
    for _ in 0..MAX_POLL_ATTEMPTS {
        tokio::time::sleep(POLL_INTERVAL).await;

        let status_response = client
            .get(format!(
                "https://api.assemblyai.com/v2/transcript/{}",
                transcript_id
            ))
            .header("Authorization", &api_key)
            .send()
            .await
            .map_err(|e| format!("Failed to check transcript status: {}", e))?;

        let status_result: AssemblyAITranscriptResponse = status_response
            .json()
            .await
            .map_err(|e| format!("Failed to parse status response: {}", e))?;

        match status_result.status.as_str() {
            "completed" => {
                let text = status_result.text.unwrap_or_default();
                return Ok(TranscriptionResponse {
                    text,
                    language,
                    segments: None,
                });
            }
            "error" => {
                let error_msg = status_result
                    .error
                    .unwrap_or_else(|| "Unknown error".to_string());
                return Err(format!("Transcription failed: {}", error_msg));
            }
            _ => {
                // Still processing, continue polling
                continue;
            }
        }
    }

    Err("Transcription timed out".to_string())
}
