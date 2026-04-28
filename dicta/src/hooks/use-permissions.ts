import { useCallback } from 'react'

import { useOnboardingStore } from '@/features/onboarding/store'
import {
  checkAllPermissions,
  requestMicPermission,
  requestAccessibility,
  requestSpeechRecognition,
  areRequiredPermissionsGranted,
} from '@/lib/permissions'

/**
 * Simplified permissions hook that uses onboardingStore as the single source of truth.
 * This eliminates duplicate state management and synchronization issues.
 */
export function usePermissions() {
  const permissions = useOnboardingStore(state => state.permissions)
  const setPermissions = useOnboardingStore(state => state.setPermissions)

  const checkPermissions = useCallback(async () => {
    const status = await checkAllPermissions()
    setPermissions(status)
    return status
  }, [setPermissions])

  const requestMicrophone = useCallback(async () => {
    const granted = await requestMicPermission()
    await checkPermissions()
    return granted
  }, [checkPermissions])

  const requestAccessibilityPermission = useCallback(async () => {
    const granted = await requestAccessibility()
    await checkPermissions()
    return granted
  }, [checkPermissions])

  const requestSpeechRecognitionPermission = useCallback(async () => {
    const granted = await requestSpeechRecognition()
    await checkPermissions()
    return granted
  }, [checkPermissions])

  return {
    permissions,
    allGranted: permissions
      ? areRequiredPermissionsGranted(permissions)
      : false,
    requestMicrophone,
    requestAccessibilityPermission,
    requestSpeechRecognitionPermission,
    checkPermissions,
  }
}
