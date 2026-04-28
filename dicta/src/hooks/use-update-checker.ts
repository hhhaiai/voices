import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { open } from '@tauri-apps/plugin-shell'
import { useEffect, useState, useCallback } from 'react'
import { toast } from 'sonner'

import { useAnalytics } from '@/lib/analytics'

import type { UpdateStatus } from '@/lib/generated/UpdateStatus'

export type UpdateModalStatus = 'available' | 'downloading' | 'ready'

export interface UpdateState {
  showModal: boolean
  version: string
  releaseNotes?: string
  status: UpdateModalStatus
  downloadProgress: number
}

const initialState: UpdateState = {
  showModal: false,
  version: '',
  releaseNotes: undefined,
  status: 'available',
  downloadProgress: 0,
}

export function useUpdateChecker() {
  const [updateState, setUpdateState] = useState<UpdateState>(initialState)
  const { capture, events, trackError } = useAnalytics()

  const setShowModal = useCallback((show: boolean) => {
    setUpdateState(prev => ({ ...prev, showModal: show }))
  }, [])

  // Listen for update status events
  useEffect(() => {
    const unlisten = listen<UpdateStatus>('update-status', event => {
      const status = event.payload

      switch (status.status) {
        case 'checking':
          // Silent check, no UI feedback
          break

        case 'available': {
          const update = status.update
          setUpdateState({
            showModal: true,
            version: update.version,
            releaseNotes: update.body || undefined,
            status: 'available',
            downloadProgress: 0,
          })
          capture(events.UPDATE_CHECKED, {
            update_available: true,
            version: update.version,
          })
          break
        }

        case 'notAvailable':
          capture(events.UPDATE_CHECKED, {
            update_available: false,
          })
          break

        case 'downloading': {
          const percent = status.progress.percent ?? 0
          setUpdateState(prev => ({
            ...prev,
            status: 'downloading',
            downloadProgress: percent,
          }))
          break
        }

        case 'downloaded':
          setUpdateState(prev => ({
            ...prev,
            status: 'downloading',
            downloadProgress: 100,
          }))
          break

        case 'installing':
          setUpdateState(prev => ({
            ...prev,
            status: 'ready',
            downloadProgress: 100,
          }))
          capture(events.UPDATE_INSTALLED)
          break

        case 'error':
          // Close modal and show error toast
          setUpdateState(prev => ({ ...prev, showModal: false }))
          toast.error('Update failed', {
            description: 'Please try again later or download manually.',
            action: {
              label: 'Report Issue',
              onClick: () => {
                open('https://github.com/nitintf/dicta/issues/new')
              },
            },
            duration: 8000,
          })
          trackError(status.message, { context: 'update' })
          break
      }
    })

    return () => {
      unlisten.then(fn => fn())
    }
  }, [capture, events, trackError])

  // Auto-check for updates on startup (silent - only notify if update available)
  useEffect(() => {
    const timer = setTimeout(() => {
      invoke('check_for_updates', { silent: true }).catch(() => {})
    }, 10000)

    return () => clearTimeout(timer)
  }, [])

  return {
    updateState,
    setShowModal,
  }
}
