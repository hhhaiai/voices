//! Legacy AES-256-GCM encryption functions
//!
//! These functions are kept for migrating existing encrypted API keys
//! to the new keychain-based storage. Do not use for new code.

use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose, Engine as _};
use serde_json::Value;
use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

const NONCE: &[u8; 12] = b"unique nonce";

/// Get or create encryption key (legacy)
pub fn get_encryption_key(app: &AppHandle) -> Result<[u8; 32], String> {
    let store = app
        .store(".secrets")
        .map_err(|e| format!("Failed to access secrets store: {}", e))?;

    // Try to get existing key
    if let Some(key_value) = store.get("encryption_key") {
        if let Some(key_str) = key_value.as_str() {
            let key_bytes = general_purpose::STANDARD
                .decode(key_str)
                .map_err(|e| format!("Failed to decode encryption key: {}", e))?;

            if key_bytes.len() == 32 {
                let mut key = [0u8; 32];
                key.copy_from_slice(&key_bytes);
                return Ok(key);
            }
        }
    }

    // Generate new key (shouldn't happen during migration, but just in case)
    let key = Aes256Gcm::generate_key(&mut OsRng);
    let key_bytes: &[u8] = key.as_ref();
    let key_b64 = general_purpose::STANDARD.encode(key_bytes);

    store.set("encryption_key", Value::String(key_b64));
    store
        .save()
        .map_err(|e| format!("Failed to save encryption key: {}", e))?;

    let mut key_array = [0u8; 32];
    key_array.copy_from_slice(key_bytes);
    Ok(key_array)
}

/// Decrypt a string (legacy)
pub fn decrypt_string(key: &[u8; 32], ciphertext: &str) -> Result<String, String> {
    let cipher = Aes256Gcm::new(key.into());
    let nonce = Nonce::from_slice(NONCE);

    let ciphertext_bytes = general_purpose::STANDARD
        .decode(ciphertext)
        .map_err(|e| format!("Failed to decode ciphertext: {}", e))?;

    let plaintext = cipher
        .decrypt(nonce, ciphertext_bytes.as_ref())
        .map_err(|e| format!("Decryption failed: {}", e))?;

    String::from_utf8(plaintext).map_err(|e| format!("Failed to decode plaintext: {}", e))
}
