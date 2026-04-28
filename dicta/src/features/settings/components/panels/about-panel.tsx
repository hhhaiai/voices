import { invoke } from '@tauri-apps/api/core'
import { open } from '@tauri-apps/plugin-shell'
import { Loader2 } from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { appConfig } from '@/config'

import { SettingsPanel, SettingItem, SettingsSection } from './settings-panel'

export function AboutPanel() {
  const [isCheckingUpdate, setIsCheckingUpdate] = useState(false)

  const handleCheckForUpdates = async () => {
    setIsCheckingUpdate(true)
    try {
      await invoke('check_for_updates', { silent: false })
    } catch (error) {
      console.error('Failed to check for updates:', error)
    } finally {
      setIsCheckingUpdate(false)
    }
  }

  const handlePrivacyPolicy = async () => {
    try {
      await open('https://github.com/nitintf/dicta/blob/main/PRIVACY.md')
    } catch (error) {
      toast.error(`Failed to open privacy policy: ${error}`)
    }
  }

  const handleContact = async () => {
    try {
      await open('https://github.com/nitintf/dicta/issues')
    } catch (error) {
      toast.error(`Failed to open support page: ${error}`)
    }
  }

  return (
    <SettingsPanel title="About" description="Information about Dicta">
      <SettingsSection title="Application">
        <SettingItem
          title="Version"
          description={`Dicta ${appConfig.version}`}
        />

        <SettingItem
          title="Check for updates"
          description="Stay up to date with the latest features and fixes"
          action={
            <Button
              variant="outline"
              onClick={handleCheckForUpdates}
              disabled={isCheckingUpdate}
            >
              {isCheckingUpdate ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Checking...
                </>
              ) : (
                'Check now'
              )}
            </Button>
          }
        />
      </SettingsSection>

      <SettingsSection title="Resources">
        <SettingItem
          title="Support"
          description="Get help and report issues"
          action={
            <Button variant="outline" onClick={handleContact}>
              Contact
            </Button>
          }
        />

        <SettingItem
          title="Privacy policy"
          description="How we handle your data"
          action={
            <Button variant="outline" onClick={handlePrivacyPolicy}>
              View
            </Button>
          }
        />
      </SettingsSection>
    </SettingsPanel>
  )
}
