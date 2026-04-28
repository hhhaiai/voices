use serde::{Deserialize, Serialize};
use ts_rs::TS;

/// Onboarding settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct OnboardingSettings {
    pub completed: bool,
}

/// Voice input display mode
#[derive(Debug, Clone, Serialize, Deserialize, TS, Default, PartialEq)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "lowercase")]
pub enum VoiceInputDisplayMode {
    #[default]
    Standard,
    Minimal,
}

/// Voice input settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct VoiceInputSettings {
    pub shortcut: String,
    pub microphone_device_id: Option<String>,
    pub enable_push_to_talk: bool,
    pub push_to_talk_shortcut: String,
    #[serde(default)]
    pub display_mode: VoiceInputDisplayMode,
}

/// Transcription settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct TranscriptionSettings {
    pub language: String,
    pub auto_paste: bool,
    pub auto_copy_to_clipboard: bool,
    pub speech_to_text_model_id: Option<String>,
    #[serde(default)]
    pub translate_to_english: bool,
    #[serde(default)]
    pub auto_detect_language: bool,
}

/// Shortcuts settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct ShortcutsSettings {
    pub paste_last_transcript: String,
    pub global_shortcuts_enabled: bool,
    #[serde(default)]
    pub enable_command_mode: bool,
    #[serde(default = "default_command_mode_shortcut")]
    pub command_mode_shortcut: String,
}

fn default_command_mode_shortcut() -> String {
    "CmdOrCtrl+Shift+Space".to_string()
}

/// System settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct SystemSettings {
    pub show_in_dock: bool,
    pub save_audio_recordings: bool,
    pub play_sound_on_recording: bool,
}

/// Privacy settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct PrivacySettings {
    pub analytics: bool,
}

/// AI Processing settings
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct AiProcessingSettings {
    pub enabled: bool,
    pub post_processing_model_id: Option<String>,
}

/// Root settings object
#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/features/settings/types/generated/")]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub onboarding: OnboardingSettings,
    pub voice_input: VoiceInputSettings,
    pub transcription: TranscriptionSettings,
    pub shortcuts: ShortcutsSettings,
    pub system: SystemSettings,
    pub privacy: PrivacySettings,
    pub ai_processing: AiProcessingSettings,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            onboarding: OnboardingSettings { completed: false },
            voice_input: VoiceInputSettings {
                shortcut: "Alt+Space".to_string(),
                microphone_device_id: None,
                enable_push_to_talk: false,
                push_to_talk_shortcut: "Alt+R".to_string(),
                display_mode: VoiceInputDisplayMode::default(),
            },
            transcription: TranscriptionSettings {
                language: "en".to_string(),
                auto_paste: false,
                auto_copy_to_clipboard: false,
                speech_to_text_model_id: None,
                translate_to_english: false,
                auto_detect_language: false,
            },
            shortcuts: ShortcutsSettings {
                paste_last_transcript: "CmdOrCtrl+Shift+V".to_string(),
                global_shortcuts_enabled: true,
                enable_command_mode: false,
                command_mode_shortcut: default_command_mode_shortcut(),
            },
            system: SystemSettings {
                show_in_dock: true,
                save_audio_recordings: false,
                play_sound_on_recording: true,
            },
            privacy: PrivacySettings { analytics: true },
            ai_processing: AiProcessingSettings {
                enabled: false,
                post_processing_model_id: None,
            },
        }
    }
}
