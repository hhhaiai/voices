import { Switch } from '@/components/ui/switch'

import { useSettingsStore } from '../../store'
import { SettingsInfoTooltip } from '../settings-info-tooltip'
import { ShortcutRecorder } from '../shortcut-recorder'
import { SettingsPanel, SettingItem, SettingsSection } from './settings-panel'

export function ShortcutsPanel() {
  const {
    settings,
    setVoiceInputShortcut,
    setPushToTalkShortcut,
    setPasteShortcut,
    setCommandModeShortcut,
    setEnableCommandMode,
    setGlobalShortcutsEnabled,
    setEnablePushToTalk,
  } = useSettingsStore()

  return (
    <SettingsPanel
      title="Keyboard Shortcuts"
      description="Configure keyboard shortcuts for quick access"
    >
      <SettingsSection>
        <SettingItem
          title="Global shortcuts"
          description="Enable or disable all global keyboard shortcuts"
          action={
            <Switch
              checked={settings.shortcuts.globalShortcutsEnabled}
              onCheckedChange={setGlobalShortcutsEnabled}
            />
          }
          info={
            <SettingsInfoTooltip content="Global shortcuts work from any app, even when Dicta is in the background. Disable if they conflict with shortcuts in other applications." />
          }
        />

        <SettingItem
          title="Voice input activation (Toggle)"
          description={
            settings.shortcuts.globalShortcutsEnabled
              ? 'Click once to start recording, click again to stop'
              : 'Global shortcuts are disabled'
          }
          action={
            <ShortcutRecorder
              value={settings.voiceInput.shortcut}
              onChange={setVoiceInputShortcut}
              placeholder="Not set"
              disabled={!settings.shortcuts.globalShortcutsEnabled}
            />
          }
        />

        <SettingItem
          title="Enable Command Mode"
          description={
            settings.shortcuts.globalShortcutsEnabled
              ? 'Speak instructions to generate content with AI'
              : 'Global shortcuts are disabled'
          }
          action={
            <Switch
              checked={settings.shortcuts.enableCommandMode}
              onCheckedChange={setEnableCommandMode}
              disabled={!settings.shortcuts.globalShortcutsEnabled}
            />
          }
          info={
            <SettingsInfoTooltip content="Command Mode lets you speak an instruction (e.g., 'Write an email to John') and AI will generate the content for you. Different from dictation which transcribes what you say." />
          }
        />

        {settings.shortcuts.enableCommandMode && (
          <SettingItem
            title="Command Mode shortcut"
            description={
              settings.shortcuts.globalShortcutsEnabled
                ? 'Press to start Command Mode recording'
                : 'Global shortcuts are disabled'
            }
            action={
              <ShortcutRecorder
                value={settings.shortcuts.commandModeShortcut}
                onChange={setCommandModeShortcut}
                placeholder="Not set"
                disabled={!settings.shortcuts.globalShortcutsEnabled}
              />
            }
          />
        )}

        <SettingItem
          title="Enable Push-to-Talk"
          description={
            settings.voiceInput.enablePushToTalk
              ? 'Hold shortcut to record, release to stop'
              : 'Toggle mode is active - click shortcut to start/stop'
          }
          action={
            <Switch
              checked={settings.voiceInput.enablePushToTalk}
              onCheckedChange={setEnablePushToTalk}
            />
          }
          info={
            <SettingsInfoTooltip content="Push-to-Talk: Hold the shortcut key to record, release to stop. Toggle mode: Press once to start, press again to stop. Use Push-to-Talk for quick, hands-on recording." />
          }
        />

        {settings.voiceInput.enablePushToTalk && (
          <SettingItem
            title="Push-to-Talk shortcut"
            description={
              settings.shortcuts.globalShortcutsEnabled
                ? 'Hold to record, release to stop'
                : 'Global shortcuts are disabled'
            }
            action={
              <ShortcutRecorder
                value={settings.voiceInput.pushToTalkShortcut}
                onChange={setPushToTalkShortcut}
                placeholder="Not set"
                disabled={!settings.shortcuts.globalShortcutsEnabled}
              />
            }
          />
        )}

        <SettingItem
          title="Paste last transcript"
          description={
            settings.shortcuts.globalShortcutsEnabled
              ? 'Quickly paste your most recent transcription'
              : 'Global shortcuts are disabled'
          }
          action={
            <ShortcutRecorder
              value={settings.shortcuts.pasteLastTranscript}
              onChange={setPasteShortcut}
              placeholder="Not set"
              disabled={!settings.shortcuts.globalShortcutsEnabled}
            />
          }
        />
      </SettingsSection>
    </SettingsPanel>
  )
}
