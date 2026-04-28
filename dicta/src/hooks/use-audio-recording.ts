import { invoke } from '@tauri-apps/api/core'
import { listen, UnlistenFn } from '@tauri-apps/api/event'
import { useCallback, useEffect, useRef, useState } from 'react'

import { AnalyticsEvents, storeAnalytics } from '@/lib/analytics'

import type { RecordingResponse } from '@/features/voice-input/types/generated/RecordingResponse'
import type { RecordingState } from '@/features/voice-input/types/generated/RecordingState'

interface UseAudioRecordingReturn {
  state: RecordingState
  isRecording: boolean
  isActive: boolean
  error: string | null
  filePath: string | null
  startRecording: () => Promise<void>
  stopRecording: () => Promise<void>
  cancelRecording: () => Promise<void>
}

/**
 * Hook for managing audio recording through Tauri backend
 * Handles state synchronization and provides clean API for recording controls
 */
export function useAudioRecording(): UseAudioRecordingReturn {
  const [state, setState] = useState<RecordingState>('idle')
  const [error, setError] = useState<string | null>(null)
  const [filePath, setFilePath] = useState<string | null>(null)
  const recordingStartTime = useRef<number | null>(null)

  // Listen for state changes from backend
  useEffect(() => {
    let unlisten: UnlistenFn | undefined

    const setupListener = async () => {
      unlisten = await listen<RecordingState>(
        'recording-state-changed',
        event => {
          setState(event.payload)
        }
      )
    }

    setupListener()

    return () => {
      if (unlisten) {
        unlisten()
      }
    }
  }, [])

  // Load initial state on mount
  useEffect(() => {
    const loadInitialState = async () => {
      try {
        const response = await invoke<RecordingResponse>('get_recording_state')
        setState(response.state)
        setError(response.error || null)
        setFilePath(response.filePath || null)
      } catch (err) {
        console.error('Failed to load recording state:', err)
      }
    }

    loadInitialState()
  }, [])

  const startRecording = useCallback(async () => {
    try {
      const response = await invoke<RecordingResponse>('start_recording')
      if (response.success) {
        setState(response.state)
        setFilePath(response.filePath || null)
        setError(null)
        recordingStartTime.current = Date.now()
        storeAnalytics.capture(AnalyticsEvents.RECORDING_STARTED)
      } else {
        setError(response.error || 'Failed to start recording')
        storeAnalytics.trackError(
          response.error || 'Failed to start recording',
          { context: 'recording_start' }
        )
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err)
      setError(errorMsg)
      console.error('Failed to start recording:', err)
      storeAnalytics.trackError(errorMsg, { context: 'recording_start' })
    }
  }, [])

  const stopRecording = useCallback(async () => {
    try {
      const response = await invoke<RecordingResponse>('stop_recording')
      if (response.success) {
        setState(response.state)
        setError(null)
        const duration = recordingStartTime.current
          ? (Date.now() - recordingStartTime.current) / 1000
          : undefined
        storeAnalytics.capture(AnalyticsEvents.RECORDING_COMPLETED, {
          duration_seconds: duration,
        })
        recordingStartTime.current = null
      } else {
        setError(response.error || 'Failed to stop recording')
        storeAnalytics.trackError(
          response.error || 'Failed to stop recording',
          { context: 'recording_stop' }
        )
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err)
      setError(errorMsg)
      console.error('Failed to stop recording:', err)
      storeAnalytics.trackError(errorMsg, { context: 'recording_stop' })
    }
  }, [])

  const cancelRecording = useCallback(async () => {
    try {
      const response = await invoke<RecordingResponse>('cancel_recording')
      if (response.success) {
        setState(response.state)
        setFilePath(null)
        setError(null)
        storeAnalytics.capture(AnalyticsEvents.RECORDING_CANCELLED)
        recordingStartTime.current = null
      } else {
        setError(response.error || 'Failed to cancel recording')
        storeAnalytics.trackError(
          response.error || 'Failed to cancel recording',
          { context: 'recording_cancel' }
        )
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err)
      setError(errorMsg)
      console.error('Failed to cancel recording:', err)
      storeAnalytics.trackError(errorMsg, { context: 'recording_cancel' })
    }
  }, [])

  const isRecording = state === 'recording'
  const isActive = state !== 'idle' && state !== 'error'

  return {
    state,
    isRecording,
    isActive,
    error,
    filePath,
    startRecording,
    stopRecording,
    cancelRecording,
  }
}
