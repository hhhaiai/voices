/**
 * Analytics utilities for Zustand stores and non-React code
 * Uses Tauri PostHog plugin for native analytics
 */
import { PostHog } from 'tauri-plugin-posthog-api'

import { AnalyticsEvents } from './events'

const IS_DEVELOPMENT = import.meta.env.DEV

async function capture(event: string, properties?: Record<string, unknown>) {
  // Never capture analytics in development mode
  if (IS_DEVELOPMENT) {
    return
  }

  try {
    await PostHog.capture(event, properties)
  } catch (error) {
    console.error('[Analytics] Failed to capture event:', error)
  }
}

/**
 * Analytics helper for use in Zustand stores and non-React code
 * (e.g., voice input window which doesn't have AnalyticsProvider)
 */
export const storeAnalytics = {
  capture,

  trackSettingChange: (setting: string, value: unknown) => {
    capture(AnalyticsEvents.SETTING_CHANGED, {
      setting_name: setting,
      setting_value: value,
    })
  },

  trackModelAction: (
    action: 'downloaded' | 'deleted' | 'started' | 'stopped' | 'selected',
    props: {
      modelId: string
      modelType: 'stt' | 'post-processing'
      modelProvider?: string
      modelSize?: string
    }
  ) => {
    const eventMap = {
      downloaded: AnalyticsEvents.MODEL_DOWNLOADED,
      deleted: AnalyticsEvents.MODEL_DELETED,
      started: AnalyticsEvents.MODEL_STARTED,
      stopped: AnalyticsEvents.MODEL_STOPPED,
      selected: AnalyticsEvents.MODEL_SELECTED,
    }
    capture(eventMap[action], {
      model_id: props.modelId,
      model_type: props.modelType,
      model_provider: props.modelProvider,
      model_size: props.modelSize,
    })
  },

  trackFeatureUsed: (feature: string, props?: Record<string, unknown>) => {
    capture(AnalyticsEvents.FEATURE_USED, {
      feature_name: feature,
      ...props,
    })
  },

  trackError: (error: Error | string, context?: Record<string, unknown>) => {
    capture(AnalyticsEvents.ERROR_OCCURRED, {
      error_message: typeof error === 'string' ? error : error.message,
      error_stack: typeof error === 'string' ? undefined : error.stack,
      ...context,
    })
  },
}
