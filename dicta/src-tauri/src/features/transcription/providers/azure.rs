//! Azure Speech Services transcription provider
//!
//! Uses Microsoft Azure Cognitive Services Speech-to-Text API.
//! Supports phrase lists for vocabulary hints.

use serde::Deserialize;
use std::time::Duration;
use tauri::command;

use super::TranscriptionResponse;

/// HTTP request timeout for transcription API calls
const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);
/// HTTP connection timeout
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AzureTranscriptionResponse {
    combined_phrases: Option<Vec<AzureCombinedPhrase>>,
    phrases: Option<Vec<AzurePhrase>>,
    duration_milliseconds: Option<u64>,
}

#[derive(Debug, Deserialize)]
struct AzureCombinedPhrase {
    text: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AzurePhrase {
    text: String,
    confidence: Option<f64>,
    offset_milliseconds: Option<u64>,
    duration_milliseconds: Option<u64>,
}

#[derive(Debug, Deserialize)]
struct AzureError {
    error: Option<AzureErrorDetail>,
}

#[derive(Debug, Deserialize)]
struct AzureErrorDetail {
    code: Option<String>,
    message: Option<String>,
}

/// Transcribe audio using Azure Speech Services
///
/// # Arguments
/// * `audio_data` - Raw audio bytes (WAV format)
/// * `api_key` - Azure subscription key
/// * `region` - Azure region (e.g., "eastus", "westus2")
/// * `language` - Optional language code (e.g., "en-US")
/// * `phrases` - Optional list of phrases to boost recognition
#[command]
pub async fn transcribe_with_azure(
    audio_data: Vec<u8>,
    api_key: String,
    region: Option<String>,
    language: Option<String>,
    phrases: Option<Vec<String>>,
) -> Result<TranscriptionResponse, String> {
    let region = region.unwrap_or_else(|| "eastus".to_string());
    let language = language.unwrap_or_else(|| "en-US".to_string());

    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .connect_timeout(CONNECT_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    // Azure Fast Transcription API endpoint
    let url = format!(
        "https://{}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language={}",
        region, language
    );

    // Build request
    let mut request = client
        .post(&url)
        .header("Ocp-Apim-Subscription-Key", &api_key)
        .header("Content-Type", "audio/wav");

    // Add phrase list if provided
    // Note: Azure REST API supports phrases via query parameter for simple cases
    // For complex phrase lists, the SDK is recommended
    if let Some(ref phrase_list) = phrases {
        if !phrase_list.is_empty() {
            log::debug!("Adding {} phrases to Azure request", phrase_list.len());
            // Azure accepts phrases as semicolon-separated list in header
            let phrases_str = phrase_list.join(";");
            request = request.header("X-Microsoft-Speech-Phrases", phrases_str);
        }
    }

    let response = request
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
        if let Ok(error) = serde_json::from_str::<AzureError>(&response_text) {
            if let Some(detail) = error.error {
                let msg = detail
                    .message
                    .unwrap_or_else(|| "Unknown error".to_string());
                return Err(format!("Azure Speech API error: {}", msg));
            }
        }
        return Err(format!(
            "Azure Speech API request failed with status {}: {}",
            status, response_text
        ));
    }

    // Azure returns different response formats depending on the endpoint
    // Try parsing as the fast transcription format first
    if let Ok(azure_response) = serde_json::from_str::<AzureTranscriptionResponse>(&response_text) {
        let text = azure_response
            .combined_phrases
            .and_then(|p| p.into_iter().next())
            .map(|p| p.text)
            .or_else(|| {
                azure_response.phrases.and_then(|p| {
                    Some(
                        p.into_iter()
                            .map(|phrase| phrase.text)
                            .collect::<Vec<_>>()
                            .join(" "),
                    )
                })
            })
            .unwrap_or_default();

        return Ok(TranscriptionResponse {
            text,
            language: Some(language),
            segments: None,
        });
    }

    // Fallback: try simple recognition response format
    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "PascalCase")]
    struct SimpleRecognitionResponse {
        display_text: Option<String>,
        recognition_status: Option<String>,
    }

    if let Ok(simple_response) = serde_json::from_str::<SimpleRecognitionResponse>(&response_text) {
        if simple_response.recognition_status.as_deref() == Some("Success") {
            return Ok(TranscriptionResponse {
                text: simple_response.display_text.unwrap_or_default(),
                language: Some(language),
                segments: None,
            });
        }
    }

    // If we can't parse either format, return empty
    log::warn!("Could not parse Azure response: {}", response_text);
    Ok(TranscriptionResponse {
        text: String::new(),
        language: Some(language),
        segments: None,
    })
}
