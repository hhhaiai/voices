import { LaunchAtStartup } from '../launch-at-startup'
import { SaveAudioRecordings } from '../save-audio-recordings'
import { SettingsInfoTooltip } from '../settings-info-tooltip'
import { SettingsPanel, SettingItem, SettingsSection } from './settings-panel'

export function SystemPanel() {
  return (
    <SettingsPanel
      title="System"
      description="Configure system-level application behavior"
    >
      <SettingsSection>
        <SettingItem
          title="Launch at startup"
          description="Automatically launch Dicta when you log in"
          action={<LaunchAtStartup />}
        />

        <SettingItem
          title="Save audio recordings"
          description="Automatically save audio files of your recordings"
          action={<SaveAudioRecordings />}
          info={
            <SettingsInfoTooltip content="When enabled, the original audio file is saved alongside your transcription. Useful for reviewing or re-transcribing later. Disable to save disk space." />
          }
        />
      </SettingsSection>
    </SettingsPanel>
  )
}
