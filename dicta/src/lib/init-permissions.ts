import { useOnboardingStore } from '@/features/onboarding/store'

import { checkAllPermissions } from './permissions'

/**
 * Initialize permissions on app startup.
 * This checks all permissions and stores them in the onboarding store.
 * Should be called once when the app starts.
 */
export async function initializePermissions() {
  try {
    console.log('Initializing permissions...')
    const permissions = await checkAllPermissions()
    useOnboardingStore.getState().setPermissions(permissions)
    console.log('Permissions initialized:', permissions)
  } catch (error) {
    console.error('Failed to initialize permissions:', error)
  }
}
