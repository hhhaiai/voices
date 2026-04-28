//! Settings cache for reducing disk I/O during recording cycles.
//!
//! This module provides an in-memory cache for frequently accessed settings,
//! eliminating redundant disk reads. The cache is initialized on app startup
//! and invalidated when settings change.
//!
//! CRITICAL: This cache is designed to be LOCK-FREE for reads during recording.
//! The audio thread reads settings frequently, and any lock contention can cause
//! the app to hang. We use atomic operations and copy-on-write semantics.
//!
//! Uses parking_lot::RwLock instead of std::sync::RwLock because:
//! - No lock poisoning on panic (more resilient)
//! - Faster locking operations
//! - Consistent with other locks in the codebase

use crate::types::settings::VoiceInputDisplayMode;
use parking_lot::RwLock;
use serde_json::Value;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

/// Snapshot of cached settings - immutable once created.
/// This allows lock-free reads by swapping Arc pointers atomically.
#[derive(Debug, Clone)]
struct CachedSettings {
    settings: Option<Value>,
    microphone_device_id: Option<String>,
    play_sound_on_recording: Option<bool>,
    voice_input_shortcut: Option<String>,
    ptt_shortcut: Option<String>,
    enable_push_to_talk: Option<bool>,
    paste_shortcut: Option<String>,
    command_mode_shortcut: Option<String>,
    enable_command_mode: Option<bool>,
    global_shortcuts_enabled: Option<bool>,
    display_mode: Option<VoiceInputDisplayMode>,
}

impl Default for CachedSettings {
    fn default() -> Self {
        Self {
            settings: None,
            microphone_device_id: None,
            play_sound_on_recording: None,
            voice_input_shortcut: None,
            ptt_shortcut: None,
            enable_push_to_talk: None,
            paste_shortcut: None,
            command_mode_shortcut: None,
            enable_command_mode: None,
            global_shortcuts_enabled: None,
            display_mode: None,
        }
    }
}

/// Thread-safe settings cache with fast lock-free read path.
///
/// The cache uses a single RwLock protecting an Arc<CachedSettings>.
/// Reads acquire a read lock briefly to clone the Arc (cheap), then release.
/// Writes create a new CachedSettings, wrap in Arc, and swap atomically.
///
/// This design ensures:
/// - Reads never block for more than an Arc clone (nanoseconds)
/// - Writes don't block active readers
/// - No deadlocks possible
pub struct SettingsCache {
    /// The current cached settings snapshot
    cached: RwLock<Arc<CachedSettings>>,
    /// Flag to track if cache has been initialized
    initialized: AtomicBool,
}

impl SettingsCache {
    pub fn new() -> Self {
        Self {
            cached: RwLock::new(Arc::new(CachedSettings::default())),
            initialized: AtomicBool::new(false),
        }
    }

    /// Get a snapshot of the current cached settings.
    /// This is extremely fast - just clones an Arc pointer.
    #[inline]
    fn get_snapshot(&self) -> Arc<CachedSettings> {
        self.cached.read().clone()
    }

    /// Initialize the cache from the settings store.
    ///
    /// Call this during app startup after the store is available.
    pub fn initialize(&self, app: &AppHandle) -> Result<(), String> {
        let store = app
            .store("settings")
            .map_err(|e| format!("Failed to get settings store: {}", e))?;

        let settings = store.get("settings");

        if let Some(settings_value) = settings {
            self.update_from_value(&settings_value);
        }

        self.initialized.store(true, Ordering::Release);
        log::debug!("Settings cache initialized");
        Ok(())
    }

    /// Invalidate the cache and reload from the in-memory store.
    ///
    /// IMPORTANT: This does NOT call store.reload() because:
    /// 1. store.reload() is synchronous and can block for disk I/O
    /// 2. The frontend writes to the store first, then calls invalidate
    /// 3. The in-memory store already has the latest data
    ///
    /// This design prevents deadlocks when settings dialog opens during recording.
    pub fn invalidate(&self, app: &AppHandle) -> Result<(), String> {
        let store = app
            .store("settings")
            .map_err(|e| format!("Failed to get settings store: {}", e))?;

        // DO NOT call store.reload() here!
        // The store already has the latest data in memory from the frontend write.
        // Calling reload() would:
        // 1. Block for disk I/O
        // 2. Potentially cause deadlock if called while recording thread is reading

        let settings = store.get("settings");

        if let Some(settings_value) = settings {
            self.update_from_value(&settings_value);
            log::debug!("Settings cache invalidated from in-memory store");
        } else {
            // Clear cache if no settings found
            self.clear();
            log::debug!("Settings cache cleared (no settings found)");
        }

        Ok(())
    }

    /// Update cache from a settings Value using atomic swap.
    ///
    /// This creates a new CachedSettings snapshot, populates it completely,
    /// then atomically swaps it in. This ensures:
    /// - Readers always see a consistent snapshot
    /// - No partial updates are visible
    /// - Write lock is held for minimum time (just the swap)
    fn update_from_value(&self, settings: &Value) {
        // Build the new snapshot WITHOUT holding any locks
        let mut new_cache = CachedSettings {
            settings: Some(settings.clone()),
            ..Default::default()
        };

        // Extract and cache frequently accessed values
        if let Some(obj) = settings.as_object() {
            // voiceInput settings
            if let Some(voice_input) = obj.get("voiceInput").and_then(|v| v.as_object()) {
                new_cache.microphone_device_id = voice_input
                    .get("microphoneDeviceId")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                new_cache.voice_input_shortcut = voice_input
                    .get("shortcut")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                new_cache.ptt_shortcut = voice_input
                    .get("pushToTalkShortcut")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                new_cache.enable_push_to_talk = voice_input
                    .get("enablePushToTalk")
                    .and_then(|v| v.as_bool());

                new_cache.display_mode = voice_input
                    .get("displayMode")
                    .and_then(|v| v.as_str())
                    .and_then(|s| match s {
                        "standard" => Some(VoiceInputDisplayMode::Standard),
                        "minimal" => Some(VoiceInputDisplayMode::Minimal),
                        _ => None,
                    });
            }

            // system settings
            if let Some(system) = obj.get("system").and_then(|v| v.as_object()) {
                new_cache.play_sound_on_recording =
                    system.get("playSoundOnRecording").and_then(|v| v.as_bool());
            }

            // shortcuts settings
            if let Some(shortcuts) = obj.get("shortcuts").and_then(|v| v.as_object()) {
                new_cache.paste_shortcut = shortcuts
                    .get("pasteLastTranscript")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                new_cache.command_mode_shortcut = shortcuts
                    .get("commandModeShortcut")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                new_cache.enable_command_mode =
                    shortcuts.get("enableCommandMode").and_then(|v| v.as_bool());

                new_cache.global_shortcuts_enabled = shortcuts
                    .get("globalShortcutsEnabled")
                    .and_then(|v| v.as_bool());
            }
        }

        // Atomic swap - write lock held only for pointer swap
        *self.cached.write() = Arc::new(new_cache);
        self.initialized.store(true, Ordering::Release);
    }

    /// Clear all cached values using atomic swap.
    fn clear(&self) {
        *self.cached.write() = Arc::new(CachedSettings::default());
        self.initialized.store(false, Ordering::Release);
    }

    /// Get the full cached settings value.
    pub fn get_settings(&self) -> Option<Value> {
        self.get_snapshot().settings.clone()
    }

    /// Get cached microphone device ID.
    /// Returns None if auto-detect is selected or cache is not initialized.
    #[inline]
    pub fn get_microphone_device_id(&self) -> Option<String> {
        self.get_snapshot().microphone_device_id.clone()
    }

    /// Get cached play sound on recording setting.
    /// Returns None if cache is not initialized.
    #[inline]
    pub fn get_play_sound_on_recording(&self) -> Option<bool> {
        self.get_snapshot().play_sound_on_recording
    }

    /// Get cached voice input shortcut.
    #[inline]
    pub fn get_voice_input_shortcut(&self) -> Option<String> {
        self.get_snapshot().voice_input_shortcut.clone()
    }

    /// Get cached push-to-talk shortcut.
    #[inline]
    pub fn get_ptt_shortcut(&self) -> Option<String> {
        self.get_snapshot().ptt_shortcut.clone()
    }

    /// Get cached enable push-to-talk setting.
    #[inline]
    pub fn get_enable_push_to_talk(&self) -> Option<bool> {
        self.get_snapshot().enable_push_to_talk
    }

    /// Get cached paste last transcript shortcut.
    #[inline]
    pub fn get_paste_shortcut(&self) -> Option<String> {
        self.get_snapshot().paste_shortcut.clone()
    }

    /// Get cached command mode shortcut.
    #[inline]
    pub fn get_command_mode_shortcut(&self) -> Option<String> {
        self.get_snapshot().command_mode_shortcut.clone()
    }

    /// Get cached global shortcuts enabled setting.
    #[inline]
    pub fn get_global_shortcuts_enabled(&self) -> Option<bool> {
        self.get_snapshot().global_shortcuts_enabled
    }

    /// Get cached enable command mode setting.
    #[inline]
    pub fn get_enable_command_mode(&self) -> Option<bool> {
        self.get_snapshot().enable_command_mode
    }

    /// Get cached voice input display mode.
    /// Returns Standard if cache is not initialized or no mode is set.
    #[inline]
    pub fn get_display_mode(&self) -> VoiceInputDisplayMode {
        self.get_snapshot()
            .display_mode
            .clone()
            .unwrap_or(VoiceInputDisplayMode::Standard)
    }

    /// Check if the cache has been initialized.
    #[inline]
    pub fn is_initialized(&self) -> bool {
        self.initialized.load(Ordering::Acquire)
    }
}

impl Default for SettingsCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_cache_new_is_empty() {
        let cache = SettingsCache::new();
        assert!(!cache.is_initialized());
        assert!(cache.get_settings().is_none());
        assert!(cache.get_microphone_device_id().is_none());
        assert!(cache.get_play_sound_on_recording().is_none());
    }

    #[test]
    fn test_update_from_value() {
        let cache = SettingsCache::new();

        let settings = json!({
            "voiceInput": {
                "microphoneDeviceId": "device-123",
                "shortcut": "Alt+Space",
                "pushToTalkShortcut": "Alt+R",
                "enablePushToTalk": true
            },
            "system": {
                "playSoundOnRecording": false
            },
            "shortcuts": {
                "pasteLastTranscript": "CmdOrCtrl+Shift+V",
                "globalShortcutsEnabled": true
            }
        });

        cache.update_from_value(&settings);

        assert!(cache.is_initialized());
        assert_eq!(
            cache.get_microphone_device_id(),
            Some("device-123".to_string())
        );
        assert_eq!(cache.get_play_sound_on_recording(), Some(false));
        assert_eq!(
            cache.get_voice_input_shortcut(),
            Some("Alt+Space".to_string())
        );
        assert_eq!(cache.get_ptt_shortcut(), Some("Alt+R".to_string()));
        assert_eq!(cache.get_enable_push_to_talk(), Some(true));
        assert_eq!(
            cache.get_paste_shortcut(),
            Some("CmdOrCtrl+Shift+V".to_string())
        );
        assert_eq!(cache.get_global_shortcuts_enabled(), Some(true));
    }

    #[test]
    fn test_clear() {
        let cache = SettingsCache::new();

        let settings = json!({
            "voiceInput": {
                "microphoneDeviceId": "device-123"
            },
            "system": {
                "playSoundOnRecording": true
            }
        });

        cache.update_from_value(&settings);
        assert!(cache.is_initialized());

        cache.clear();
        assert!(!cache.is_initialized());
        assert!(cache.get_microphone_device_id().is_none());
    }

    #[test]
    fn test_null_microphone_device_id() {
        let cache = SettingsCache::new();

        let settings = json!({
            "voiceInput": {
                "microphoneDeviceId": null,
                "shortcut": "Alt+Space"
            }
        });

        cache.update_from_value(&settings);

        // null should be treated as None (auto-detect)
        assert!(cache.get_microphone_device_id().is_none());
        assert_eq!(
            cache.get_voice_input_shortcut(),
            Some("Alt+Space".to_string())
        );
    }

    #[test]
    fn test_thread_safety() {
        use std::thread;

        let cache = Arc::new(SettingsCache::new());

        let settings = json!({
            "voiceInput": {
                "shortcut": "Alt+Space"
            },
            "system": {
                "playSoundOnRecording": true
            }
        });

        cache.update_from_value(&settings);

        // Spawn multiple reader threads - should never block
        let handles: Vec<_> = (0..10)
            .map(|_| {
                let cache_clone = Arc::clone(&cache);
                thread::spawn(move || {
                    for _ in 0..100 {
                        let _ = cache_clone.get_settings();
                        let _ = cache_clone.get_voice_input_shortcut();
                        let _ = cache_clone.get_play_sound_on_recording();
                    }
                })
            })
            .collect();

        for handle in handles {
            handle.join().unwrap();
        }

        // Cache should still be valid
        assert!(cache.is_initialized());
    }

    #[test]
    fn test_concurrent_read_write() {
        use std::thread;
        use std::time::Duration;

        let cache = Arc::new(SettingsCache::new());

        // Initial settings
        let settings1 = json!({
            "voiceInput": {
                "shortcut": "Alt+Space"
            }
        });
        cache.update_from_value(&settings1);

        // Spawn reader threads
        let reader_handles: Vec<_> = (0..5)
            .map(|_| {
                let cache_clone = Arc::clone(&cache);
                thread::spawn(move || {
                    for _ in 0..100 {
                        // These should never block even during writes
                        let _ = cache_clone.get_voice_input_shortcut();
                        let _ = cache_clone.get_display_mode();
                        thread::sleep(Duration::from_micros(10));
                    }
                })
            })
            .collect();

        // Spawn writer threads
        let writer_handles: Vec<_> = (0..2)
            .map(|i| {
                let cache_clone = Arc::clone(&cache);
                thread::spawn(move || {
                    for j in 0..10 {
                        let settings = json!({
                            "voiceInput": {
                                "shortcut": format!("Alt+{}-{}", i, j)
                            }
                        });
                        cache_clone.update_from_value(&settings);
                        thread::sleep(Duration::from_micros(50));
                    }
                })
            })
            .collect();

        // All threads should complete without deadlock
        for handle in reader_handles {
            handle.join().unwrap();
        }
        for handle in writer_handles {
            handle.join().unwrap();
        }

        assert!(cache.is_initialized());
    }
}
