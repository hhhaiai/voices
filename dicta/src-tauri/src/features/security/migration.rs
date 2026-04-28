use serde_json::Value;
use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

use super::keychain;
use super::legacy;

const MIGRATION_FLAG_KEY: &str = "keychain_migration_completed";

/// Check if migration has already been completed
pub fn is_migration_completed(app: &AppHandle) -> bool {
    let store = match app.store(".secrets") {
        Ok(store) => store,
        Err(_) => return false,
    };

    store
        .get(MIGRATION_FLAG_KEY)
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

/// Mark migration as completed
fn mark_migration_completed(app: &AppHandle) -> Result<(), String> {
    let store = app
        .store(".secrets")
        .map_err(|e| format!("Failed to access secrets store: {}", e))?;

    store.set(MIGRATION_FLAG_KEY, Value::Bool(true));
    store
        .save()
        .map_err(|e| format!("Failed to save migration flag: {}", e))?;

    Ok(())
}

/// Result of migration process
#[derive(Debug)]
pub struct MigrationResult {
    pub migrated_count: usize,
    pub failed_count: usize,
    pub skipped_count: usize,
}

/// Migrate API keys from legacy AES-GCM encrypted storage to system keychain
///
/// This function:
/// 1. Checks if migration has already been completed
/// 2. Finds all models with encrypted API keys in models.json
/// 3. Decrypts them using the legacy method
/// 4. Stores them in the system keychain
/// 5. Removes the apiKey field from models.json (keeps hasApiKey flag)
/// 6. Sets migration complete flag
pub async fn migrate_legacy_api_keys(app: &AppHandle) -> Result<MigrationResult, String> {
    // Check if already migrated
    if is_migration_completed(app) {
        log::debug!("API key migration already completed, skipping");
        return Ok(MigrationResult {
            migrated_count: 0,
            failed_count: 0,
            skipped_count: 0,
        });
    }

    log::info!("Starting API key migration from encrypted storage to keychain...");

    let models_store = app
        .store("models.json")
        .map_err(|e| format!("Failed to access models store: {}", e))?;

    // Get all models
    let mut models = models_store
        .get("models")
        .and_then(|v| v.as_array().cloned())
        .unwrap_or_default();

    if models.is_empty() {
        log::info!("No models found, marking migration as complete");
        mark_migration_completed(app)?;
        return Ok(MigrationResult {
            migrated_count: 0,
            failed_count: 0,
            skipped_count: 0,
        });
    }

    let mut migrated_count = 0;
    let mut failed_count = 0;
    let mut skipped_count = 0;

    // Try to get encryption key for decryption (might not exist if no keys were ever stored)
    let encryption_key = match legacy::get_encryption_key(app) {
        Ok(key) => Some(key),
        Err(e) => {
            log::debug!(
                "No encryption key found (likely no keys were ever stored): {}",
                e
            );
            None
        }
    };

    for model in models.iter_mut() {
        if let Some(obj) = model.as_object_mut() {
            let model_id = obj
                .get("id")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown")
                .to_string();

            // Check if this model has an encrypted API key
            if let Some(encrypted_key) = obj.get("apiKey").and_then(|v| v.as_str()) {
                if encrypted_key.is_empty() {
                    skipped_count += 1;
                    continue;
                }

                // Try to decrypt and migrate
                if let Some(ref key) = encryption_key {
                    match legacy::decrypt_string(key, encrypted_key) {
                        Ok(plaintext_key) => {
                            // Store in keychain
                            match keychain::store_api_key_keychain(&model_id, &plaintext_key) {
                                Ok(()) => {
                                    log::info!("Migrated API key for model '{}'", model_id);
                                    migrated_count += 1;

                                    // Remove encrypted key from model (keep hasApiKey flag)
                                    obj.remove("apiKey");
                                }
                                Err(e) => {
                                    log::error!(
                                        "Failed to store API key in keychain for '{}': {}",
                                        model_id,
                                        e
                                    );
                                    failed_count += 1;
                                }
                            }
                        }
                        Err(e) => {
                            log::error!("Failed to decrypt API key for '{}': {}", model_id, e);
                            failed_count += 1;
                        }
                    }
                } else {
                    log::warn!(
                        "Cannot decrypt API key for '{}' - no encryption key available",
                        model_id
                    );
                    failed_count += 1;
                }
            } else {
                skipped_count += 1;
            }
        }
    }

    // Save updated models (with apiKey fields removed)
    models_store.set("models", Value::Array(models));
    models_store
        .save()
        .map_err(|e| format!("Failed to save models after migration: {}", e))?;

    // Mark migration as completed
    mark_migration_completed(app)?;

    let result = MigrationResult {
        migrated_count,
        failed_count,
        skipped_count,
    };

    log::info!(
        "API key migration completed: {} migrated, {} failed, {} skipped",
        result.migrated_count,
        result.failed_count,
        result.skipped_count
    );

    Ok(result)
}
