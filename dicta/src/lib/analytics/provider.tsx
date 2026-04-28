/**
 * Analytics Provider using Tauri PostHog plugin
 * PostHog is initialized on the Rust side, this just manages React context state
 */
import { invoke } from '@tauri-apps/api/core'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { PostHog } from 'tauri-plugin-posthog-api'

import { useSettingsStore } from '@/features/settings'

import { AnalyticsContext } from './context'

const IS_DEVELOPMENT = import.meta.env.DEV
const APP_VERSION = import.meta.env.PACKAGE_VERSION || 'unknown'

interface AnalyticsProviderProps {
  children: ReactNode
}

export function AnalyticsProvider({ children }: AnalyticsProviderProps) {
  const [isInitialized, setIsInitialized] = useState(false)
  const analyticsEnabled = useSettingsStore(
    state => state.settings.privacy.analytics
  )
  const settingsInitialized = useSettingsStore(state => state.initialized)

  useEffect(() => {
    if (!settingsInitialized) {
      return
    }

    // Mark as initialized once settings are ready
    if (!isInitialized) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setIsInitialized(true)
    }
  }, [settingsInitialized, isInitialized])

  // Identify device with persistent hardware ID on startup
  useEffect(() => {
    // Never identify in development mode
    if (IS_DEVELOPMENT || !isInitialized || !analyticsEnabled) {
      return
    }

    const identifyDevice = async () => {
      try {
        const deviceId = await invoke<string>('get_device_id')
        await PostHog.identify(deviceId, {
          app_version: APP_VERSION,
          platform: 'macos',
        })
      } catch (error) {
        console.error('[Analytics] Failed to identify device:', error)
      }
    }

    identifyDevice()
  }, [isInitialized, analyticsEnabled])

  // Handle opt-in/opt-out based on user settings
  useEffect(() => {
    if (!isInitialized) {
      return
    }

    const updateOptStatus = async () => {
      try {
        const posthogInstance = await PostHog.getInstance()
        // Always opt out in development mode
        if (IS_DEVELOPMENT || !analyticsEnabled) {
          posthogInstance.opt_out_capturing()
        } else {
          posthogInstance.opt_in_capturing()
        }
      } catch (error) {
        console.error('[Analytics] Failed to update opt status:', error)
      }
    }

    updateOptStatus()
  }, [analyticsEnabled, isInitialized])

  const contextValue = useMemo(
    () => ({
      isInitialized,
      isEnabled: analyticsEnabled && isInitialized && !IS_DEVELOPMENT,
    }),
    [isInitialized, analyticsEnabled]
  )

  return (
    <AnalyticsContext.Provider value={contextValue}>
      {children}
    </AnalyticsContext.Provider>
  )
}
