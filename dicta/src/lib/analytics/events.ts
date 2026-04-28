/**
 * Pre-defined analytics event names for consistency
 */
export const AnalyticsEvents = {
  // Recording events
  RECORDING_STARTED: 'recording_started',
  RECORDING_COMPLETED: 'recording_completed',
  RECORDING_CANCELLED: 'recording_cancelled',
  RECORDING_ERROR: 'recording_error',

  // Transcription events
  TRANSCRIPTION_STARTED: 'transcription_started',
  TRANSCRIPTION_COMPLETED: 'transcription_completed',
  TRANSCRIPTION_ERROR: 'transcription_error',

  // AI Processing events
  AI_PROCESSING_STARTED: 'ai_processing_started',
  AI_PROCESSING_COMPLETED: 'ai_processing_completed',
  AI_PROCESSING_ERROR: 'ai_processing_error',

  // Model events
  MODEL_DOWNLOADED: 'model_downloaded',
  MODEL_DELETED: 'model_deleted',
  MODEL_STARTED: 'model_started',
  MODEL_STOPPED: 'model_stopped',
  MODEL_SELECTED: 'model_selected',

  // Feature usage
  FEATURE_USED: 'feature_used',
  PASTE_TRANSCRIPT: 'paste_transcript',
  COPY_TO_CLIPBOARD: 'copy_to_clipboard',

  // Settings events
  SETTING_CHANGED: 'setting_changed',
  ONBOARDING_COMPLETED: 'onboarding_completed',
  ONBOARDING_STEP_COMPLETED: 'onboarding_step_completed',

  // Navigation events
  PAGE_VIEWED: 'page_viewed',
  SETTINGS_OPENED: 'settings_opened',
  SETTINGS_SECTION_VIEWED: 'settings_section_viewed',

  // App lifecycle
  APP_LAUNCHED: 'app_launched',
  APP_CLOSED: 'app_closed',
  UPDATE_CHECKED: 'update_checked',
  UPDATE_DOWNLOADED: 'update_downloaded',
  UPDATE_INSTALLED: 'update_installed',

  // Errors
  ERROR_OCCURRED: 'error_occurred',
} as const

export type AnalyticsEvent =
  (typeof AnalyticsEvents)[keyof typeof AnalyticsEvents]
