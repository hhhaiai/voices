import { useAudioDevices } from '@/hooks/use-audio-devices'

import { useSettingsStore } from '../../store'
import { MicrophoneSelector } from '../microphone-selector'
import { VisualDisplayModeSelector } from '../visual-display-mode-selector'
import { VisualThemeSelector } from '../visual-theme-selector'
import { SettingsPanel, SettingItem, SettingsSection } from './settings-panel'

export function GeneralPanel() {
  const { settings } = useSettingsStore()
  const { devices } = useAudioDevices()

  // Get the currently selected microphone name for description
  const selectedDeviceId = settings.voiceInput.microphoneDeviceId
  const selectedDevice = selectedDeviceId
    ? devices.find(d => d.deviceId === selectedDeviceId)
    : null
  const defaultDevice = devices.find(d => d.isDefault || d.isRecommended)
  const microphoneDescription = selectedDevice
    ? `Currently using: ${selectedDevice.label || `Microphone ${selectedDevice.deviceId.substring(0, 8)}`}`
    : defaultDevice
      ? `Currently using: Auto-detect (${defaultDevice.label})`
      : 'Select your preferred microphone device'

  return (
    <SettingsPanel
      title="General"
      description="Manage your general application preferences"
    >
      <SettingsSection>
        <SettingItem
          title="Microphone"
          description={microphoneDescription}
          action={<MicrophoneSelector />}
        />
      </SettingsSection>

      <SettingsSection title="Appearance">
        <SettingItem
          title="Voice input display"
          description="Choose how the voice input window appears during recording"
          action={<VisualDisplayModeSelector />}
          layout="stacked"
        />

        <SettingItem
          title="Theme"
          description="Choose your preferred color theme"
          action={<VisualThemeSelector />}
          layout="stacked"
        />
      </SettingsSection>
    </SettingsPanel>
  )
}
