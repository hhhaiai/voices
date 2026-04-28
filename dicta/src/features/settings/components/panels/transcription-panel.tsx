import { AlertTriangle } from 'lucide-react'
import { useState } from 'react'

import { Switch } from '@/components/ui/switch'
import { useModelsStore } from '@/features/models/store'

import { getLanguageByCode } from '../../data/languages'
import { useSettingsStore } from '../../store'
import { LanguageSelector } from '../language-selector'
import { SettingsInfoTooltip } from '../settings-info-tooltip'
import { SettingsPanel, SettingItem, SettingsSection } from './settings-panel'

export function TranscriptionPanel() {
  const {
    settings,
    setAutoPaste,
    setAutoCopyToClipboard,
    setAiProcessingEnabled,
    setTranslateToEnglish,
    setAutoDetectLanguage,
  } = useSettingsStore()
  const { models } = useModelsStore()

  const [autoPasteLoading, setAutoPasteLoading] = useState(false)
  const [autoCopyLoading, setAutoCopyLoading] = useState(false)
  const [aiProcessingLoading, setAiProcessingLoading] = useState(false)

  // Language settings logic
  const selectedLanguage = getLanguageByCode(settings.transcription.language)
  const languageDescription = settings.transcription.autoDetectLanguage
    ? 'Auto-detect (Whisper will identify the language)'
    : selectedLanguage
      ? `${selectedLanguage.name} (${selectedLanguage.nativeName})`
      : 'English'

  // Check if the selected STT model supports the selected language
  const selectedSttModel = models.find(
    m => m.purpose === 'speech-to-text' && m.isSelected
  )
  const isEnglishOnly = selectedSttModel?.languageSupport === 'english_only'
  const isNonEnglishLanguage = settings.transcription.language !== 'en'
  const isAutoDetect = settings.transcription.autoDetectLanguage
  const hasLanguageCompatibilityIssue =
    isEnglishOnly && isNonEnglishLanguage && !isAutoDetect

  const handleAutoPasteToggle = async (checked: boolean) => {
    setAutoPasteLoading(true)
    try {
      await setAutoPaste(checked)
    } catch (error) {
      console.error('Failed to toggle auto-paste:', error)
    } finally {
      setAutoPasteLoading(false)
    }
  }

  const handleAutoCopyToggle = async (checked: boolean) => {
    setAutoCopyLoading(true)
    try {
      await setAutoCopyToClipboard(checked)
    } catch (error) {
      console.error('Failed to toggle auto-copy:', error)
    } finally {
      setAutoCopyLoading(false)
    }
  }

  const handleAiProcessingToggle = async (checked: boolean) => {
    setAiProcessingLoading(true)
    try {
      await setAiProcessingEnabled(checked)
    } catch (error) {
      console.error('Failed to toggle AI processing:', error)
    } finally {
      setAiProcessingLoading(false)
    }
  }

  return (
    <SettingsPanel
      title="Transcription"
      description="Customize how your transcriptions are processed and saved"
    >
      <SettingsSection title="Language">
        <SettingItem
          title="Transcription language"
          description={languageDescription}
          action={<LanguageSelector disabled={isAutoDetect} />}
          disabled={isAutoDetect}
          info={
            <SettingsInfoTooltip content="Select the language you'll be speaking. Make sure your speech-to-text model supports multiple languages if you want to use non-English languages." />
          }
        />

        <SettingItem
          title="Auto-detect language"
          description={
            isEnglishOnly
              ? 'Requires a multilingual model'
              : 'Automatically identify the spoken language'
          }
          action={
            <Switch
              checked={settings.transcription.autoDetectLanguage}
              onCheckedChange={setAutoDetectLanguage}
              disabled={isEnglishOnly}
            />
          }
          disabled={isEnglishOnly}
          info={
            <SettingsInfoTooltip content="Let the app automatically detect which language you're speaking. This requires a multilingual speech-to-text model - check the Models page to see which models support multiple languages." />
          }
        />

        <SettingItem
          title="Translate to English"
          description={
            isAutoDetect
              ? 'Disabled when auto-detect is enabled'
              : !isNonEnglishLanguage
                ? 'Select a non-English language to enable'
                : isEnglishOnly
                  ? 'Requires a multilingual model'
                  : 'Transcribe in your language and output English text'
          }
          action={
            <Switch
              checked={settings.transcription.translateToEnglish}
              onCheckedChange={setTranslateToEnglish}
              disabled={isEnglishOnly || !isNonEnglishLanguage || isAutoDetect}
            />
          }
          disabled={isEnglishOnly || !isNonEnglishLanguage || isAutoDetect}
          info={
            <SettingsInfoTooltip content="Speak in any supported language and get English text as output. Great for multilingual users who want their transcriptions in English. Note: This only translates TO English, not from English to other languages." />
          }
        />

        {isEnglishOnly && settings.transcription.translateToEnglish && (
          <div className="flex items-start gap-2 rounded-md border border-yellow-500/50 bg-yellow-500/10 p-3 text-sm">
            <AlertTriangle className="h-4 w-4 text-yellow-500 shrink-0 mt-0.5" />
            <div>
              <p className="font-medium text-yellow-500">
                Translation requires a multilingual model
              </p>
              <p className="text-muted-foreground mt-1">
                Your current model ({selectedSttModel?.name}) only supports
                English. Please select a multilingual model like Whisper Base,
                Small, Medium, or Large for translation.
              </p>
            </div>
          </div>
        )}

        {hasLanguageCompatibilityIssue && (
          <div className="flex items-start gap-2 rounded-md border border-yellow-500/50 bg-yellow-500/10 p-3 text-sm">
            <AlertTriangle className="h-4 w-4 text-yellow-500 shrink-0 mt-0.5" />
            <div>
              <p className="font-medium text-yellow-500">
                Model not compatible with {selectedLanguage?.name}
              </p>
              <p className="text-muted-foreground mt-1">
                Your current model ({selectedSttModel?.name}) only supports
                English. Please select a multilingual model like Whisper Base,
                Small, Medium, or Large for {selectedLanguage?.name}{' '}
                transcription.
              </p>
            </div>
          </div>
        )}
      </SettingsSection>

      <SettingsSection title="Behavior">
        <SettingItem
          title="Auto-paste where cursor is active"
          description="Automatically paste transcription text at cursor position"
          action={
            <Switch
              checked={settings.transcription.autoPaste}
              onCheckedChange={handleAutoPasteToggle}
              disabled={autoPasteLoading}
            />
          }
          info={
            <SettingsInfoTooltip content="After transcription completes, the text is automatically pasted wherever your cursor is - great for writing emails, documents, or chat messages hands-free." />
          }
        />

        <SettingItem
          title="Auto-copy to clipboard"
          description="Copy transcription text to clipboard after completion"
          action={
            <Switch
              checked={settings.transcription.autoCopyToClipboard}
              onCheckedChange={handleAutoCopyToggle}
              disabled={autoCopyLoading}
            />
          }
        />
      </SettingsSection>

      <SettingsSection title="AI Post-Processing">
        <SettingItem
          title="Enable AI post-processing"
          description="Enhance transcriptions with AI-powered formatting and refinement"
          action={
            <Switch
              checked={settings.aiProcessing.enabled}
              onCheckedChange={handleAiProcessingToggle}
              disabled={aiProcessingLoading}
            />
          }
          info={
            <SettingsInfoTooltip content="Uses AI to clean up your transcription - fixing grammar, adding punctuation, and applying styles based on context. Requires a post-processing model to be selected and started in the Models page." />
          }
        />
      </SettingsSection>
    </SettingsPanel>
  )
}
