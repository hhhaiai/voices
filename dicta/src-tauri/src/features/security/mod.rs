//! Security module for API key management
//!
//! Provides secure storage of API keys using the macOS system keychain.
//! Includes in-memory caching to minimize keychain access and password prompts.
//!
//! Uses parking_lot::RwLock instead of std::sync::RwLock because:
//! - No lock poisoning on panic (more resilient)
//! - Faster locking operations
//! - Consistent with other locks in the codebase

pub mod keychain;
pub mod legacy;
pub mod migration;

use parking_lot::RwLock;
use serde_json::Value;
use std::collections::HashMap;
use tauri::{command, AppHandle};
use tauri_plugin_store::StoreExt;

/// In-memory cache for API keys to reduce keychain access
/// This minimizes password prompts during a session
/// Key: model_id, Value: API key (None means "checked but not found")
///
/// Uses parking_lot::RwLock which never poisons, avoiding potential panics
/// if a thread crashes while holding the lock.
static API_KEY_CACHE: RwLock<Option<HashMap<String, Option<String>>>> = RwLock::new(None);

/// Initialize the cache
fn ensure_cache_initialized() {
    let mut cache = API_KEY_CACHE.write();
    if cache.is_none() {
        *cache = Some(HashMap::new());
    }
}

/// Check if we've already checked this model's key (regardless of result)
fn is_cached(model_id: &str) -> bool {
    let cache = API_KEY_CACHE.read();
    cache
        .as_ref()
        .map(|c| c.contains_key(model_id))
        .unwrap_or(false)
}

/// Get API key from cache (returns None if not cached OR if cached as "no key")
fn get_cached_key(model_id: &str) -> Option<String> {
    let cache = API_KEY_CACHE.read();
    cache
        .as_ref()
        .and_then(|c| c.get(model_id).cloned())
        .flatten()
}

/// Check if API key exists in cache
fn has_cached_key(model_id: &str) -> Option<bool> {
    let cache = API_KEY_CACHE.read();
    cache
        .as_ref()
        .and_then(|c| c.get(model_id).map(|v| v.is_some()))
}

/// Store API key in cache
fn cache_key(model_id: &str, api_key: &str) {
    ensure_cache_initialized();
    let mut cache = API_KEY_CACHE.write();
    if let Some(c) = cache.as_mut() {
        c.insert(model_id.to_string(), Some(api_key.to_string()));
    }
}

/// Mark that we checked and there's no key
fn cache_no_key(model_id: &str) {
    ensure_cache_initialized();
    let mut cache = API_KEY_CACHE.write();
    if let Some(c) = cache.as_mut() {
        c.insert(model_id.to_string(), None);
    }
}

/// Remove API key from cache
fn uncache_key(model_id: &str) {
    let mut cache = API_KEY_CACHE.write();
    if let Some(c) = cache.as_mut() {
        c.remove(model_id);
    }
}

/// Store an API key securely in the system keychain
#[command]
pub async fn store_api_key(
    app: AppHandle,
    model_id: String,
    api_key: String,
) -> Result<(), String> {
    // Store in system keychain
    keychain::store_api_key_keychain(&model_id, &api_key)?;

    // Cache in memory for this session
    cache_key(&model_id, &api_key);

    // Update hasApiKey flag in models.json for frontend
    update_has_api_key_flag(&app, &model_id, true)?;

    Ok(())
}

/// Retrieve an API key from the system keychain
#[command]
pub async fn get_api_key(app: AppHandle, model_id: String) -> Result<String, String> {
    get_api_key_internal(&app, &model_id).await
}

/// Remove an API key from the system keychain
#[command]
pub async fn remove_api_key(app: AppHandle, model_id: String) -> Result<(), String> {
    keychain::delete_api_key_keychain(&model_id)?;
    uncache_key(&model_id);
    update_has_api_key_flag(&app, &model_id, false)?;
    Ok(())
}

/// Check if an API key exists for a model
#[command]
pub async fn has_api_key(_app: AppHandle, model_id: String) -> Result<bool, String> {
    Ok(has_api_key_internal(&model_id))
}

/// Internal function to retrieve API key (for Rust-only usage)
/// Uses in-memory cache to minimize keychain access
pub async fn get_api_key_internal(_app: &AppHandle, model_id: &str) -> Result<String, String> {
    // Check cache first
    if let Some(cached) = get_cached_key(model_id) {
        return Ok(cached);
    }

    // If we've already checked and there's no key, return error without keychain access
    if is_cached(model_id) {
        return Err(format!("No API key found for model: {}", model_id));
    }

    // Fetch from keychain and cache it
    match keychain::get_api_key_keychain(model_id) {
        Ok(api_key) => {
            cache_key(model_id, &api_key);
            Ok(api_key)
        }
        Err(e) => {
            cache_no_key(model_id);
            Err(e)
        }
    }
}

/// Internal function to check if API key exists (synchronous, for Rust-only usage)
/// Uses in-memory cache to minimize keychain access
pub fn has_api_key_internal(model_id: &str) -> bool {
    // Check cache first
    if let Some(has_key) = has_cached_key(model_id) {
        return has_key;
    }

    // Check keychain and cache result
    let has_key = keychain::has_api_key_keychain(model_id);
    if has_key {
        // We know it exists, but we don't have the actual key yet
        // Don't cache the key itself - let get_api_key_internal do that
    } else {
        cache_no_key(model_id);
    }
    has_key
}

/// Sync hasApiKey flags in models.json with actual keychain state
/// Called on app startup to ensure flags are accurate
/// Also pre-caches API keys in memory to avoid repeated keychain access
pub async fn sync_api_key_flags(app: &AppHandle) -> Result<(), String> {
    log::info!("Syncing API key flags and pre-caching keys...");

    let store = app
        .store("models.json")
        .map_err(|e| format!("Failed to access models store: {}", e))?;

    let Some(models_value) = store.get("models") else {
        return Ok(());
    };

    let mut models = models_value.as_array().cloned().unwrap_or_default();

    let mut synced_count = 0;
    let mut cached_count = 0;

    for model in models.iter_mut() {
        if let Some(obj) = model.as_object_mut() {
            let model_id = obj.get("id").and_then(|v| v.as_str()).unwrap_or("");
            let requires_api_key = obj
                .get("requiresApiKey")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);

            if requires_api_key && !model_id.is_empty() {
                // Check keychain and pre-cache the result
                match keychain::get_api_key_keychain(model_id) {
                    Ok(api_key) => {
                        // Cache the API key in memory
                        cache_key(model_id, &api_key);
                        cached_count += 1;

                        // Update flag if needed
                        let has_key_flag = obj
                            .get("hasApiKey")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false);

                        if !has_key_flag {
                            obj.insert("hasApiKey".to_string(), Value::Bool(true));
                            synced_count += 1;
                        }
                    }
                    Err(_) => {
                        // Mark as no key in cache
                        cache_no_key(model_id);

                        // Update flag if needed
                        let has_key_flag = obj
                            .get("hasApiKey")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false);

                        if has_key_flag {
                            obj.insert("hasApiKey".to_string(), Value::Bool(false));
                            synced_count += 1;
                        }
                    }
                }
            }
        }
    }

    if synced_count > 0 {
        store.set("models", Value::Array(models));
        store.save().map_err(|e| format!("Failed to save: {}", e))?;
    }

    log::info!(
        "Pre-cached {} API keys, synced {} flags",
        cached_count,
        synced_count
    );

    Ok(())
}

/// Update the hasApiKey flag in models.json
fn update_has_api_key_flag(app: &AppHandle, model_id: &str, has_key: bool) -> Result<(), String> {
    let store = app
        .store("models.json")
        .map_err(|e| format!("Failed to access models store: {}", e))?;

    let mut models = store
        .get("models")
        .and_then(|v| v.as_array().cloned())
        .unwrap_or_default();

    let mut found = false;
    for model in models.iter_mut() {
        if let Some(obj) = model.as_object_mut() {
            if obj.get("id").and_then(|v| v.as_str()) == Some(model_id) {
                obj.insert("hasApiKey".to_string(), Value::Bool(has_key));
                obj.remove("apiKey"); // Remove legacy field if present
                found = true;
                break;
            }
        }
    }

    if !found {
        return Err(format!("Model '{}' not found", model_id));
    }

    store.set("models", Value::Array(models));
    store.save().map_err(|e| format!("Failed to save: {}", e))?;

    Ok(())
}
