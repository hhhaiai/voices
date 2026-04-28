import React, { useState, useCallback, useEffect } from 'react'

import { Dialog, DialogContent } from '@/components/ui/dialog'
import { useTauriEvent } from '@/hooks/use-tauri-event'
import { useAnalytics } from '@/lib/analytics'

import { AboutPanel } from './panels/about-panel'
import { GeneralPanel } from './panels/general-panel'
import { PrivacyPanel } from './panels/privacy-panel'
import { ShortcutsPanel } from './panels/shortcuts-panel'
import { SystemPanel } from './panels/system-panel'
import { TranscriptionPanel } from './panels/transcription-panel'
import { SettingsSidebar } from './settings-sidebar'
import { SettingsPanelId } from '../types/settings-navigation'

interface SettingsDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initialSection?: SettingsPanelId
}

interface OpenSettingsPayload {
  section?: SettingsPanelId
}

type PanelComponent =
  | React.ComponentType<{
      onNavigateToPanel: (section: SettingsPanelId) => void
    }>
  | React.ComponentType

const panelComponents: Record<SettingsPanelId, PanelComponent> = {
  general: GeneralPanel,
  shortcuts: ShortcutsPanel,
  transcription: TranscriptionPanel,
  system: SystemPanel,
  privacy: PrivacyPanel,
  about: AboutPanel,
}

export function SettingsDialog({
  open,
  onOpenChange,
  initialSection = 'general',
}: SettingsDialogProps) {
  const [activeSection, setActiveSection] =
    useState<SettingsPanelId>(initialSection)
  const { capture, events } = useAnalytics()

  useEffect(() => {
    setActiveSection(initialSection)
  }, [initialSection])

  // Track when settings dialog is opened
  useEffect(() => {
    if (open) {
      capture(events.SETTINGS_OPENED)
    }
  }, [open, capture, events])

  const handleSectionChange = useCallback(
    (section: SettingsPanelId) => {
      setActiveSection(section)
      capture(events.SETTINGS_SECTION_VIEWED, { section })
    },
    [capture, events]
  )

  const handleOpenSettings = useCallback(
    (event: { payload: OpenSettingsPayload }) => {
      const section = event.payload.section || 'general'
      setActiveSection(section)
      onOpenChange(true)
    },
    [onOpenChange]
  )

  useTauriEvent<OpenSettingsPayload>('open-settings', handleOpenSettings, [
    handleOpenSettings,
  ])

  const ActivePanel = panelComponents[activeSection]

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="min-w-[900px] max-w-[900px] h-[700px] p-0! overflow-hidden"
        showCloseButton={false}
      >
        <div className="flex h-full w-full overflow-hidden">
          <SettingsSidebar
            activeSection={activeSection}
            onSectionChange={handleSectionChange}
          />

          <div className="flex-1 h-full overflow-y-auto">
            <div className="p-8">
              <ActivePanel onNavigateToPanel={handleSectionChange} />
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
