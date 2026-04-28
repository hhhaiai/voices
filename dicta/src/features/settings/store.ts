import { invoke } from '@tauri-apps/api/core'
import { Store, load } from '@tauri-apps/plugin-store'
import { create } from 'zustand'

import { storeAnalytics } from '@/lib/analytics'

import {
  AiProcessingSettings,
  defaultSettings,
  type Settings,
  type VoiceInputDisplayMode,
} from './schema'

import type { SettingsStore } from './types'

let tauriStore: Store | null = null

const getTauriStore = async () => {
  if (!tauriStore) {
    tauriStore = await load('settings')
  }
  return tauriStore
}

export const useSettingsStore = create<SettingsStore>((set, get) => ({
  settings: defaultSettings,
  initialized: false,

  initialize: async () => {
    try {
      const store = await getTauriStore()
      const storedSettings = await store.get<Settings>('settings')

      // Check if analytics migration has been done (v1 = enable analytics by default)
      const analyticsMigrationDone = await store.get<boolean>(
        'analytics_v1_migrated'
      )

      // Determine analytics value:
      // - If migration not done yet (existing user updating), enable analytics
      // - If migration done, respect stored value
      // - If new user (no stored settings), default to true
      let analyticsEnabled = true
      if (analyticsMigrationDone) {
        // Migration already done, respect user's choice
        analyticsEnabled = storedSettings?.privacy?.analytics ?? true
      }
      // If migration not done, we force enable analytics (analyticsEnabled stays true)

      const settings: Settings = {
        onboarding: {
          completed: storedSettings?.onboarding?.completed ?? false,
        },
        voiceInput: {
          shortcut: storedSettings?.voiceInput?.shortcut ?? 'Alt+Space',
          microphoneDeviceId:
            storedSettings?.voiceInput?.microphoneDeviceId ?? null,
          enablePushToTalk:
            storedSettings?.voiceInput?.enablePushToTalk ?? false,
          pushToTalkShortcut:
            storedSettings?.voiceInput?.pushToTalkShortcut ?? 'Alt+R',
          displayMode: storedSettings?.voiceInput?.displayMode ?? 'standard',
        },
        transcription: {
          language: storedSettings?.transcription?.language ?? 'en',
          autoPaste: storedSettings?.transcription?.autoPaste ?? false,
          autoCopyToClipboard:
            storedSettings?.transcription?.autoCopyToClipboard ?? false,
          speechToTextModelId:
            storedSettings?.transcription?.speechToTextModelId ?? null,
          translateToEnglish:
            storedSettings?.transcription?.translateToEnglish ?? false,
          autoDetectLanguage:
            storedSettings?.transcription?.autoDetectLanguage ?? false,
        },
        shortcuts: {
          pasteLastTranscript:
            storedSettings?.shortcuts?.pasteLastTranscript ??
            'CmdOrCtrl+Shift+V',
          globalShortcutsEnabled:
            storedSettings?.shortcuts?.globalShortcutsEnabled ?? true,
          enableCommandMode:
            storedSettings?.shortcuts?.enableCommandMode ?? false,
          commandModeShortcut:
            storedSettings?.shortcuts?.commandModeShortcut ??
            'CmdOrCtrl+Shift+Space',
        },
        system: {
          showInDock: storedSettings?.system?.showInDock ?? true,
          saveAudioRecordings:
            storedSettings?.system?.saveAudioRecordings ?? false,
          playSoundOnRecording:
            storedSettings?.system?.playSoundOnRecording ?? true,
        },
        privacy: {
          analytics: analyticsEnabled,
        },
        aiProcessing: {
          enabled: storedSettings?.aiProcessing?.enabled ?? false,
          postProcessingModelId:
            storedSettings?.aiProcessing?.postProcessingModelId ?? null,
        },
      }

      // Mark analytics migration as done and save settings
      if (!analyticsMigrationDone) {
        await store.set('analytics_v1_migrated', true)
        await store.set('settings', settings)
        await store.save()
      }

      set({ settings, initialized: true })
      // Analytics initialization is handled by AnalyticsProvider
    } catch (error) {
      console.error('Error initializing settings store:', error)
      set({ settings: defaultSettings, initialized: true })
    }
  },

  setOnboardingComplete: async (completed: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        onboarding: { completed },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
    } catch (error) {
      console.error('Error saving onboarding status:', error)
    }
  },

  setVoiceInputShortcut: async (shortcut: string) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        voiceInput: {
          ...get().settings.voiceInput,
          shortcut,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Update the global shortcut registration
      await invoke('update_voice_input_shortcut', { shortcutStr: shortcut })
      storeAnalytics.trackSettingChange('voiceInputShortcut', shortcut)
    } catch (error) {
      console.error('Error saving voice input shortcut:', error)
    }
  },

  setMicrophoneDevice: async (deviceId: string | null) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        voiceInput: {
          ...get().settings.voiceInput,
          microphoneDeviceId: deviceId,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Rebuild tray menu to reflect the microphone change
      console.log(
        '[Settings] Rebuilding tray menu after microphone change:',
        deviceId
      )
      await invoke('rebuild_tray_menu_command')
      console.log('[Settings] Tray menu rebuild complete')
      storeAnalytics.trackSettingChange(
        'microphoneDevice',
        deviceId ? 'changed' : 'default'
      )
    } catch (error) {
      console.error('Error saving microphone device:', error)
    }
  },

  setVoiceInputDisplayMode: async (mode: VoiceInputDisplayMode) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        voiceInput: {
          ...get().settings.voiceInput,
          displayMode: mode,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Invalidate Rust cache so the new mode is used on next recording
      await invoke('invalidate_settings_cache')
      storeAnalytics.trackSettingChange('voiceInputDisplayMode', mode)
    } catch (error) {
      console.error('Error saving voice input display mode:', error)
    }
  },

  setTranscriptionLanguage: async (language: string) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        transcription: {
          ...get().settings.transcription,
          language,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Rebuild tray menu to reflect the language change
      console.log(
        '[Settings] Rebuilding tray menu after language change:',
        language
      )
      await invoke('rebuild_tray_menu_command')
      console.log('[Settings] Tray menu rebuild complete')
      storeAnalytics.trackSettingChange('transcriptionLanguage', language)
    } catch (error) {
      console.error('Error saving transcription language:', error)
    }
  },

  setPasteShortcut: async (shortcut: string) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        shortcuts: {
          ...get().settings.shortcuts,
          pasteLastTranscript: shortcut,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Update the global shortcut registration
      await invoke('update_paste_shortcut', { shortcutStr: shortcut })
      storeAnalytics.trackSettingChange('pasteShortcut', shortcut)
    } catch (error) {
      console.error('Error saving paste shortcut:', error)
    }
  },

  setCommandModeShortcut: async (shortcut: string) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        shortcuts: {
          ...get().settings.shortcuts,
          commandModeShortcut: shortcut,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Update the global shortcut registration if command mode is enabled
      if (newSettings.shortcuts.enableCommandMode) {
        await invoke('update_command_mode_shortcut', { shortcutStr: shortcut })
      }
      storeAnalytics.trackSettingChange('commandModeShortcut', shortcut)
    } catch (error) {
      console.error('Error saving command mode shortcut:', error)
    }
  },

  setEnableCommandMode: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        shortcuts: {
          ...get().settings.shortcuts,
          enableCommandMode: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Invalidate Rust cache
      await invoke('invalidate_settings_cache')

      // Register or unregister command mode shortcut
      if (enabled) {
        await invoke('register_command_mode_shortcut', {
          shortcutStr: newSettings.shortcuts.commandModeShortcut,
        })
      } else {
        await invoke('unregister_command_mode_shortcut')
      }
      storeAnalytics.trackSettingChange('enableCommandMode', enabled)
    } catch (error) {
      console.error('Error toggling command mode:', error)
    }
  },

  setGlobalShortcutsEnabled: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        shortcuts: {
          ...get().settings.shortcuts,
          globalShortcutsEnabled: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Enable or disable global shortcuts
      if (enabled) {
        await invoke('enable_global_shortcuts')
      } else {
        await invoke('disable_global_shortcuts')
      }
      storeAnalytics.trackSettingChange('globalShortcutsEnabled', enabled)
    } catch (error) {
      console.error('Error toggling global shortcuts:', error)
    }
  },

  setShowInDock: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        system: {
          ...get().settings.system,
          showInDock: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Update dock visibility
      await invoke('set_show_in_dock', { show: enabled })
      storeAnalytics.trackSettingChange('showInDock', enabled)
    } catch (error) {
      console.error('Error toggling show in dock:', error)
    }
  },

  setSaveAudioRecordings: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        system: {
          ...get().settings.system,
          saveAudioRecordings: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackSettingChange('saveAudioRecordings', enabled)
    } catch (error) {
      console.error('Error toggling save audio recordings:', error)
    }
  },

  setAutoPaste: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        transcription: {
          ...get().settings.transcription,
          autoPaste: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackSettingChange('autoPaste', enabled)
    } catch (error) {
      console.error('Error toggling auto-paste:', error)
    }
  },

  setAutoCopyToClipboard: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        transcription: {
          ...get().settings.transcription,
          autoCopyToClipboard: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackSettingChange('autoCopyToClipboard', enabled)
    } catch (error) {
      console.error('Error toggling auto-copy to clipboard:', error)
    }
  },

  setAnalytics: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        privacy: {
          ...get().settings.privacy,
          analytics: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      // AnalyticsProvider listens to settings and handles opt-in/opt-out
      storeAnalytics.trackSettingChange('analytics', enabled)
    } catch (error) {
      console.error('Error toggling analytics:', error)
    }
  },

  resetSettings: async () => {
    try {
      const store = await getTauriStore()
      await store.set('settings', defaultSettings)
      await store.save()
      set({ settings: defaultSettings })
      storeAnalytics.trackSettingChange('resetSettings', true)
    } catch (error) {
      console.error('Error resetting settings:', error)
    }
  },

  setAiProcessingEnabled: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        aiProcessing: {
          ...get().settings.aiProcessing,
          enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackSettingChange('aiProcessingEnabled', enabled)
    } catch (error) {
      console.error('Error toggling AI processing:', error)
    }
  },

  setSpeechToTextModel: async (modelId: string | null) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        transcription: {
          ...get().settings.transcription,
          speechToTextModelId: modelId,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackModelAction('selected', {
        modelId: modelId || 'none',
        modelType: 'stt',
      })
    } catch (error) {
      console.error('Error setting speech-to-text model:', error)
    }
  },

  setPostProcessingModel: async (modelId: string | null) => {
    console.log('📝 setPostProcessingModel called with:', modelId)
    try {
      const store = await getTauriStore()
      const currentSettings = get().settings
      console.log(
        '   Current settings before update:',
        currentSettings.aiProcessing
      )

      const newSettings = {
        ...currentSettings,
        aiProcessing: {
          ...currentSettings.aiProcessing,
          postProcessingModelId: modelId,
        },
      }
      console.log('   New settings to save:', newSettings.aiProcessing)

      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Verify by reading back from store
      const verifyStore = await store.get('settings')
      console.log(
        '   ✅ Verified store contents:',
        (verifyStore as unknown as { aiProcessing: AiProcessingSettings })
          ?.aiProcessing
      )
      storeAnalytics.trackModelAction('selected', {
        modelId: modelId || 'none',
        modelType: 'post-processing',
      })
    } catch (error) {
      console.error('❌ Error setting post-processing model:', error)
    }
  },

  setEnablePushToTalk: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        voiceInput: {
          ...get().settings.voiceInput,
          enablePushToTalk: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Update PTT shortcut registration
      if (enabled) {
        await invoke('register_ptt_shortcut', {
          shortcutStr: newSettings.voiceInput.pushToTalkShortcut,
        })
      } else {
        await invoke('unregister_ptt_shortcut')
      }
      storeAnalytics.trackSettingChange('enablePushToTalk', enabled)
    } catch (error) {
      console.error('Error toggling push-to-talk:', error)
    }
  },

  setPushToTalkShortcut: async (shortcut: string) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        voiceInput: {
          ...get().settings.voiceInput,
          pushToTalkShortcut: shortcut,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // If PTT is enabled, update the shortcut registration
      if (newSettings.voiceInput.enablePushToTalk) {
        await invoke('update_ptt_shortcut', { shortcutStr: shortcut })
      }
      storeAnalytics.trackSettingChange('pushToTalkShortcut', shortcut)
    } catch (error) {
      console.error('Error saving push-to-talk shortcut:', error)
    }
  },

  setTranslateToEnglish: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const newSettings = {
        ...get().settings,
        transcription: {
          ...get().settings.transcription,
          translateToEnglish: enabled,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })
      storeAnalytics.trackSettingChange('translateToEnglish', enabled)
    } catch (error) {
      console.error('Error saving translate to English setting:', error)
    }
  },

  setAutoDetectLanguage: async (enabled: boolean) => {
    try {
      const store = await getTauriStore()
      const currentSettings = get().settings
      const newSettings = {
        ...currentSettings,
        transcription: {
          ...currentSettings.transcription,
          autoDetectLanguage: enabled,
          // When enabling auto-detect, disable translate to English
          translateToEnglish: enabled
            ? false
            : currentSettings.transcription.translateToEnglish,
        },
      }
      await store.set('settings', newSettings)
      await store.save()
      set({ settings: newSettings })

      // Rebuild tray menu to reflect the auto-detect change
      await invoke('rebuild_tray_menu_command')
      storeAnalytics.trackSettingChange('autoDetectLanguage', enabled)
    } catch (error) {
      console.error('Error saving auto-detect language setting:', error)
    }
  },
}))

export const initializeSettings = async () => {
  await useSettingsStore.getState().initialize()
}
