//! macOS Keychain storage for API keys
//!
//! Uses the system keychain via the `keyring` crate with apple-native backend.

use keyring::Entry;

/// Service name for keychain entries - matches the app's bundle identifier
const SERVICE_NAME: &str = "com.nitintf.dicta";

/// Get the keyring account name for a model's API key
fn get_account_name(model_id: &str) -> String {
    format!("api_key_{}", model_id)
}

/// Store an API key in the system keychain
pub fn store_api_key_keychain(model_id: &str, api_key: &str) -> Result<(), String> {
    let account = get_account_name(model_id);

    let entry = Entry::new(SERVICE_NAME, &account)
        .map_err(|e| format!("Failed to create keychain entry: {}", e))?;

    entry
        .set_password(api_key)
        .map_err(|e| format!("Failed to store API key in keychain: {}", e))?;

    log::info!("Stored API key for model '{}' in keychain", model_id);
    Ok(())
}

/// Retrieve an API key from the system keychain
pub fn get_api_key_keychain(model_id: &str) -> Result<String, String> {
    let account = get_account_name(model_id);

    let entry = Entry::new(SERVICE_NAME, &account)
        .map_err(|e| format!("Failed to create keychain entry: {}", e))?;

    entry
        .get_password()
        .map_err(|e| format!("Failed to retrieve API key: {}", e))
}

/// Delete an API key from the system keychain
pub fn delete_api_key_keychain(model_id: &str) -> Result<(), String> {
    let account = get_account_name(model_id);

    let entry = Entry::new(SERVICE_NAME, &account)
        .map_err(|e| format!("Failed to create keychain entry: {}", e))?;

    match entry.delete_credential() {
        Ok(()) => {
            log::info!("Deleted API key for model '{}' from keychain", model_id);
            Ok(())
        }
        Err(keyring::Error::NoEntry) => {
            // Key doesn't exist - that's fine
            Ok(())
        }
        Err(e) => Err(format!("Failed to delete API key: {}", e)),
    }
}

/// Check if an API key exists in the system keychain
pub fn has_api_key_keychain(model_id: &str) -> bool {
    let account = get_account_name(model_id);

    match Entry::new(SERVICE_NAME, &account) {
        Ok(entry) => match entry.get_password() {
            Ok(_) => true,
            Err(keyring::Error::NoEntry) => false,
            Err(e) => {
                log::warn!("Error checking keychain for model '{}': {}", model_id, e);
                false
            }
        },
        Err(e) => {
            log::warn!("Failed to create keychain entry: {}", e);
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore] // Requires real keychain
    fn test_store_and_retrieve_api_key() {
        let model_id = "test-model-123";
        let api_key = "sk-test-key-12345";

        store_api_key_keychain(model_id, api_key).unwrap();
        assert!(has_api_key_keychain(model_id));

        let retrieved = get_api_key_keychain(model_id).unwrap();
        assert_eq!(retrieved, api_key);

        delete_api_key_keychain(model_id).unwrap();
        assert!(!has_api_key_keychain(model_id));
    }
}
