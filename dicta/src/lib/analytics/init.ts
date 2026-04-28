/**
 * PostHog initialization using Tauri plugin
 * The plugin handles initialization on the Rust side
 */

let isInitialized = false

export interface InitAnalyticsOptions {
  onLoaded?: () => void
}

/**
 * Initialize analytics.
 * With the Tauri plugin, PostHog is already initialized on the Rust side.
 * This function just marks the frontend as ready.
 *
 * @param options - Optional configuration
 */
export function initAnalytics(options: InitAnalyticsOptions = {}): void {
  const { onLoaded } = options

  if (isInitialized) {
    if (onLoaded) {
      setTimeout(onLoaded, 0)
    }
    return
  }

  isInitialized = true

  if (onLoaded) {
    setTimeout(onLoaded, 0)
  }
}

/**
 * Check if analytics has been initialized
 */
export function isAnalyticsInitialized(): boolean {
  return isInitialized
}
