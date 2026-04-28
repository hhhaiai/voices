//! Local LLM provider for post-processing using llama.cpp
//!
//! This provider routes post-processing requests to a local LLM model
//! loaded via the LocalModelManager's LLM engine.

use std::sync::Arc;
use tauri::{AppHandle, Manager};
use tokio::sync::Mutex;

use crate::features::models::engines::llm_trait::GenerationConfig;
use crate::features::models::engines::ModelConfig;
use crate::features::models::LocalModelManager;

/// Process text using a local LLM model
///
/// # Arguments
/// * `text` - The transcript text to process
/// * `system_prompt` - System instructions for the model
/// * `model_id` - The model ID (e.g., "llm-qwen2-0.5b-instruct")
/// * `app` - Tauri app handle for accessing state
pub async fn process_with_local_llm(
    text: String,
    system_prompt: String,
    model_id: String,
    app: AppHandle,
) -> Result<String, String> {
    log::info!("=== LOCAL LLM POST-PROCESSING STARTED ===");
    log::info!("Model ID: {}", model_id);
    log::info!("Input text: {}", text);
    log::debug!("System prompt: {}", system_prompt);

    // Get the local model manager
    let model_manager_state = app
        .try_state::<Arc<Mutex<LocalModelManager>>>()
        .ok_or("Local model manager not available")?;

    let mut manager = model_manager_state.lock().await;

    // Check if the correct LLM model is loaded
    let needs_load = match manager.get_loaded_llm_model_info() {
        Some(info) => {
            // Check if the loaded model matches the requested model
            // Model ID format: "llm-qwen2-0.5b-instruct"
            // Engine info name would be something like "Qwen2 0.5B Instruct"
            !model_id.contains(&info.name.to_lowercase().replace(" ", "-"))
                && !model_id.contains(&info.name.to_lowercase().replace(" ", ""))
        }
        None => true,
    };

    if needs_load {
        // Get model info from registry to find the path
        let model_path = get_model_path(&app, &model_id)?;
        let model_name = get_model_name(&model_id);

        log::info!("Loading LLM model: {} from {}", model_name, model_path);

        let config = ModelConfig {
            model_path,
            model_name,
            language: None,
        };

        manager.load_llm_model("llama", config)?;
    }

    // Generate the processed text
    let generation_config = GenerationConfig {
        max_tokens: 4096,
        temperature: 0.3, // Low for consistent formatting
        top_p: 0.9,
        top_k: 40,
        repeat_penalty: 1.1,
    };

    log::info!("Starting LLM generation...");
    let processed_text = match manager.generate(&system_prompt, &text, generation_config) {
        Ok(text) => {
            log::info!("=== LOCAL LLM POST-PROCESSING COMPLETE ===");
            log::info!("Output length: {} chars", text.len());
            text
        }
        Err(e) => {
            log::error!("=== LOCAL LLM POST-PROCESSING FAILED ===");
            log::error!("Error: {}", e);
            return Err(e);
        }
    };

    Ok(processed_text)
}

/// Get the model path by constructing it from the model ID
/// This matches the path logic in models_registry.rs
fn get_model_path(app: &AppHandle, model_id: &str) -> Result<String, String> {
    use crate::features::models::models_registry::LOCAL_LLM_MODELS;

    // Get app data directory
    let app_data_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;

    // LLM models are stored in local_models/llama/
    let llm_dir = app_data_dir.join("local_models").join("llama");

    // Extract the model name from the ID (e.g., "llm-qwen2-0.5b-instruct" -> "qwen2-0.5b-instruct")
    let model_name = model_id.strip_prefix("llm-").unwrap_or(model_id);

    // Find the model in the registry to get the download URL
    for (id, url, _, _, _) in LOCAL_LLM_MODELS {
        if *id == model_name {
            // Extract filename from URL
            let filename = url.split('/').last().unwrap_or("model.gguf");
            let model_path = llm_dir.join(filename);

            if model_path.exists() {
                return Ok(model_path.to_string_lossy().to_string());
            } else {
                return Err(format!(
                    "Model '{}' is not downloaded. Please download it first.",
                    model_id
                ));
            }
        }
    }

    Err(format!("Model '{}' not found in registry", model_id))
}

/// Get a display name from the model ID
fn get_model_name(model_id: &str) -> String {
    // Convert "llm-qwen2-0.5b-instruct" to "Qwen2 0.5B Instruct"
    model_id
        .strip_prefix("llm-")
        .unwrap_or(model_id)
        .split('-')
        .map(|part| {
            if part.chars().all(|c| c.is_numeric() || c == '.') {
                part.to_uppercase()
            } else {
                let mut chars = part.chars();
                match chars.next() {
                    None => String::new(),
                    Some(first) => first.to_uppercase().to_string() + chars.as_str(),
                }
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}
