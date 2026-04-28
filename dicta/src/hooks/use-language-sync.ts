import { useCallback } from 'react'

import { useSettingsStore } from '@/features/settings/store'

import { useTauriEvent } from './use-tauri-event'

interface LanguageChangedPayload {
  language: string
}

/**
 * Hook to sync language changes from tray menu with settings store
 *
 * This hook automatically listens for the 'language-changed' event
 * emitted by the backend when a user selects a different language from the
 * tray menu. It updates the settings store to keep the frontend in sync.
 */
export const useLanguageSync = () => {
  const setTranscriptionLanguage = useSettingsStore(
    state => state.setTranscriptionLanguage
  )

  const handleLanguageChange = useCallback(
    (event: { payload: LanguageChangedPayload }) => {
      const { language } = event.payload

      console.log('Transcription language changed from tray menu:', language)

      // Update the settings store with the new language
      // This will sync the UI (e.g., settings panel) with the tray menu selection
      setTranscriptionLanguage(language)
    },
    [setTranscriptionLanguage]
  )

  // Listen for language changes from the backend
  useTauriEvent<LanguageChangedPayload>(
    'language-changed',
    handleLanguageChange
  )
}
