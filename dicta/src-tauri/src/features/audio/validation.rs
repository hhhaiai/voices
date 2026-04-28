//! Pre-recording validation module
//!
//! This module validates that all required API keys are configured
//! before starting a recording, to prevent wasted recording time.

use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

use crate::features::security;

/// Validation errors that can occur before recording starts
#[derive(Debug)]
pub enum ValidationError {
    /// Speech-to-text cloud model is missing its API key
    SttModelApiKeyMissing {
        model_id: String,
        model_name: String,
        provider: String,
    },
    /// Post-processing cloud model is missing its API key
    PostProcessingApiKeyMissing {
        model_id: String,
        model_name: String,
        provider: String,
    },
    /// Internal error accessing stores
    InternalError(String),
}

impl ValidationError {
    /// Get a user-friendly error message
    pub fn user_message(&self) -> String {
        match self {
            Self::SttModelApiKeyMissing {
                model_name,
                provider,
                ..
            } => {
                let provider_display = match provider.as_str() {
                    "openai" => "OpenAI",
                    "google" => "Google Cloud",
                    "elevenlabs" => "ElevenLabs",
                    "assemblyai" => "AssemblyAI",
                    _ => provider,
                };
                format!(
                    "API key required for {}. Please add your {} API key in Settings > Models.",
                    model_name, provider_display
                )
            }
            Self::PostProcessingApiKeyMissing {
                model_name,
                provider,
                ..
            } => {
                let provider_display = match provider.as_str() {
                    "anthropic" => "Anthropic",
                    "openai" => "OpenAI",
                    _ => provider,
                };
                format!(
                    "Post-processing requires API key for {}. Add your {} API key or disable AI processing in Settings.",
                    model_name, provider_display
                )
            }
            Self::InternalError(msg) => format!("Validation error: {}", msg),
        }
    }
}

/// Check if a provider requires an API key for speech-to-text
fn stt_provider_requires_api_key(provider: &str) -> bool {
    matches!(provider, "openai" | "google" | "elevenlabs" | "assemblyai")
}

/// Check if a provider requires an API key for post-processing
fn post_processing_provider_requires_api_key(provider: &str) -> bool {
    matches!(provider, "anthropic" | "openai")
}

/// Validate all required API keys before starting a recording
///
/// This checks:
/// 1. If the selected STT model is a cloud model, verify it has an API key
/// 2. If AI processing is enabled, verify the post-processing model has an API key
pub async fn validate_pre_recording(app: &AppHandle) -> Result<(), ValidationError> {
    log::info!("=== PRE-RECORDING VALIDATION ===");

    // Get settings
    let settings_store = app.store("settings").map_err(|e| {
        ValidationError::InternalError(format!("Failed to get settings store: {}", e))
    })?;

    let settings = settings_store
        .get("settings")
        .ok_or_else(|| ValidationError::InternalError("No settings found".to_string()))?;

    // Get models store
    let models_store = app.store("models.json").map_err(|e| {
        ValidationError::InternalError(format!("Failed to get models store: {}", e))
    })?;

    let models_value = models_store.get("models");
    let models = models_value
        .as_ref()
        .and_then(|v| v.as_array())
        .ok_or_else(|| ValidationError::InternalError("No models found".to_string()))?;

    // 1. Validate STT model API key
    if let Some(stt_model_id) = settings
        .get("transcription")
        .and_then(|t| t.get("speechToTextModelId"))
        .and_then(|v| v.as_str())
    {
        log::info!("Validating STT model: {}", stt_model_id);

        // Find the model
        if let Some(model) = models.iter().find(|m| {
            m.as_object()
                .and_then(|obj| obj.get("id"))
                .and_then(|v| v.as_str())
                == Some(stt_model_id)
        }) {
            if let Some(model_obj) = model.as_object() {
                let provider = model_obj
                    .get("provider")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                let model_name = model_obj
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or(stt_model_id);
                let has_api_key_flag = model_obj
                    .get("hasApiKey")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);

                log::info!(
                    "STT model: {} (provider: {}, hasApiKey flag: {})",
                    model_name,
                    provider,
                    has_api_key_flag
                );

                // Check if this provider requires an API key
                if stt_provider_requires_api_key(provider) {
                    // Check if API key exists in keychain
                    let has_key_in_keychain = security::has_api_key_internal(stt_model_id);
                    log::info!(
                        "Provider {} requires API key. Keychain check: {}",
                        provider,
                        has_key_in_keychain
                    );

                    if !has_key_in_keychain {
                        log::warn!("API key missing for STT model: {}", stt_model_id);
                        return Err(ValidationError::SttModelApiKeyMissing {
                            model_id: stt_model_id.to_string(),
                            model_name: model_name.to_string(),
                            provider: provider.to_string(),
                        });
                    }
                }
            }
        } else {
            log::warn!("STT model not found in models list: {}", stt_model_id);
        }
    }

    // 2. Validate post-processing model API key (if AI processing is enabled)
    let ai_processing_enabled = settings
        .get("aiProcessing")
        .and_then(|ai| ai.get("enabled"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    if ai_processing_enabled {
        if let Some(post_processing_model_id) = settings
            .get("aiProcessing")
            .and_then(|ai| ai.get("postProcessingModelId"))
            .and_then(|v| v.as_str())
        {
            // Find the model
            if let Some(model) = models.iter().find(|m| {
                m.as_object()
                    .and_then(|obj| obj.get("id"))
                    .and_then(|v| v.as_str())
                    == Some(post_processing_model_id)
            }) {
                if let Some(model_obj) = model.as_object() {
                    let provider = model_obj
                        .get("provider")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let model_name = model_obj
                        .get("name")
                        .and_then(|v| v.as_str())
                        .unwrap_or(post_processing_model_id);
                    let model_type = model_obj.get("type").and_then(|v| v.as_str()).unwrap_or("");

                    // Only check API key for cloud models
                    if model_type == "cloud" && post_processing_provider_requires_api_key(provider)
                    {
                        // Check if API key exists
                        if !security::has_api_key_internal(post_processing_model_id) {
                            return Err(ValidationError::PostProcessingApiKeyMissing {
                                model_id: post_processing_model_id.to_string(),
                                model_name: model_name.to_string(),
                                provider: provider.to_string(),
                            });
                        }
                    }
                }
            }
        }
    }

    Ok(())
}
