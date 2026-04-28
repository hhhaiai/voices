import { useCallback } from 'react'
import { PostHog } from 'tauri-plugin-posthog-api'

import { useAnalyticsContext } from './context'
import { AnalyticsEvents } from './events'

/**
 * Hook for analytics tracking in React components
 * Uses Tauri PostHog plugin for native analytics
 */
export function useAnalytics() {
  const { isEnabled } = useAnalyticsContext()

  const capture = useCallback(
    async (event: string, properties?: Record<string, unknown>) => {
      if (!isEnabled) return
      try {
        await PostHog.capture(event, properties)
      } catch (error) {
        console.error('[Analytics] Failed to capture event:', error)
      }
    },
    [isEnabled]
  )

  const identify = useCallback(
    async (userId: string, properties?: Record<string, unknown>) => {
      if (!isEnabled) return
      try {
        await PostHog.identify(userId, properties)
      } catch (error) {
        console.error('[Analytics] Failed to identify user:', error)
      }
    },
    [isEnabled]
  )

  const reset = useCallback(async () => {
    if (!isEnabled) return
    try {
      await PostHog.reset()
    } catch (error) {
      console.error('[Analytics] Failed to reset:', error)
    }
  }, [isEnabled])

  const trackRecording = useCallback(
    (props: {
      duration?: number
      modelId?: string
      modelType?: 'cloud' | 'local'
      aiProcessingEnabled?: boolean
      success: boolean
      error?: string
    }) => {
      if (props.success) {
        capture(AnalyticsEvents.RECORDING_COMPLETED, {
          duration_seconds: props.duration,
          model_id: props.modelId,
          model_type: props.modelType,
          ai_processing_enabled: props.aiProcessingEnabled,
        })
      } else {
        capture(AnalyticsEvents.RECORDING_ERROR, {
          error: props.error,
          model_id: props.modelId,
        })
      }
    },
    [capture]
  )

  const trackModelAction = useCallback(
    (
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
    [capture]
  )

  const trackSettingChange = useCallback(
    (setting: string, value: unknown) => {
      capture(AnalyticsEvents.SETTING_CHANGED, {
        setting_name: setting,
        setting_value: value,
      })
    },
    [capture]
  )

  const trackFeatureUsed = useCallback(
    (feature: string, props?: Record<string, unknown>) => {
      capture(AnalyticsEvents.FEATURE_USED, {
        feature_name: feature,
        ...props,
      })
    },
    [capture]
  )

  const trackError = useCallback(
    (error: Error | string, context?: Record<string, unknown>) => {
      capture(AnalyticsEvents.ERROR_OCCURRED, {
        error_message: typeof error === 'string' ? error : error.message,
        error_stack: typeof error === 'string' ? undefined : error.stack,
        ...context,
      })
    },
    [capture]
  )

  const trackPageView = useCallback(
    (page: string, props?: Record<string, unknown>) => {
      capture(AnalyticsEvents.PAGE_VIEWED, {
        page_name: page,
        ...props,
      })
    },
    [capture]
  )

  return {
    capture,
    identify,
    reset,
    events: AnalyticsEvents,
    trackRecording,
    trackModelAction,
    trackSettingChange,
    trackFeatureUsed,
    trackError,
    trackPageView,
  }
}
