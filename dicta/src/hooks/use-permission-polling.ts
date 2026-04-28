import { useEffect } from 'react'

import { usePermissions } from './use-permissions'

/**
 * Custom hook that polls for permission changes at a specified interval.
 * This is useful during onboarding when users are granting permissions in System Settings.
 *
 * @param enabled - Whether to enable polling
 * @param interval - Polling interval in milliseconds (default: 2000ms)
 */
export function usePermissionPolling(enabled = true, interval = 2000) {
  const { checkPermissions } = usePermissions()

  useEffect(() => {
    if (!enabled) return

    // Check immediately on mount
    checkPermissions()

    // Set up polling interval
    const intervalId = setInterval(() => {
      checkPermissions()
    }, interval)

    return () => clearInterval(intervalId)
  }, [checkPermissions, enabled, interval])
}
