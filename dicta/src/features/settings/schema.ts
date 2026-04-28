// Import and re-export generated types from Rust
import type { Settings } from './types/generated'

export type {
  Settings,
  OnboardingSettings,
  VoiceInputSettings,
  VoiceInputDisplayMode,
  TranscriptionSettings,
  ShortcutsSettings,
  SystemSettings,
  PrivacySettings,
  AiProcessingSettings,
} from './types/generated'

export const defaultSettings: Settings = {
  onboarding: {
    completed: false,
  },
  voiceInput: {
    shortcut: 'Alt+Space',
    microphoneDeviceId: null,
    enablePushToTalk: false,
    pushToTalkShortcut: 'Alt+R',
    displayMode: 'standard',
  },
  transcription: {
    language: 'en',
    autoPaste: false,
    autoCopyToClipboard: false,
    speechToTextModelId: null,
    translateToEnglish: false,
    autoDetectLanguage: false,
  },
  shortcuts: {
    pasteLastTranscript: 'CmdOrCtrl+Shift+V',
    globalShortcutsEnabled: true,
    enableCommandMode: false,
    commandModeShortcut: 'CmdOrCtrl+Shift+Space',
  },
  system: {
    showInDock: false,
    saveAudioRecordings: false,
    playSoundOnRecording: true,
  },
  privacy: {
    analytics: true,
  },
  aiProcessing: {
    enabled: false,
    postProcessingModelId: null,
  },
}
