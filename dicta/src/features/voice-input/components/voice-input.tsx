import { load } from '@tauri-apps/plugin-store'
import { useEffect, useState } from 'react'

import { LiveWaveform } from '@/components/ui/live-waveform'
import { useAudioRecording } from '@/hooks/use-audio-recording'
import { useTauriEvent } from '@/hooks/use-tauri-event'

import { CancelButton } from './cancel-button'
import { StopButton } from './stop-button'
import { VoiceInputContainer } from './voice-input-container'

import type { VoiceInputDisplayMode } from '@/features/settings/types/generated'

interface VoiceInputModePayload {
  displayMode: VoiceInputDisplayMode
}

interface StoredSettings {
  voiceInput?: {
    displayMode?: VoiceInputDisplayMode
  }
}

export const VoiceInput = () => {
  const recording = useAudioRecording()
  const [audioLevel, setAudioLevel] = useState<number>(0)
  const [displayMode, setDisplayMode] =
    useState<VoiceInputDisplayMode>('standard')
  const [initialized, setInitialized] = useState(false)

  // Load initial display mode from settings on mount
  useEffect(() => {
    const loadInitialMode = async () => {
      try {
        const store = await load('settings')
        const settings = await store.get<StoredSettings>('settings')
        const mode = settings?.voiceInput?.displayMode ?? 'standard'
        // Only accept valid modes (standard or minimal)
        setDisplayMode(mode === 'minimal' ? 'minimal' : 'standard')
      } catch (error) {
        console.error('Failed to load display mode:', error)
      } finally {
        setInitialized(true)
      }
    }
    void loadInitialMode()
  }, [])

  const isTranscribing = recording.state === 'transcribing'
  const isProcessing = recording.state === 'stopping' || isTranscribing

  // Only show buttons in standard mode
  const showButtons = displayMode === 'standard'

  useTauriEvent<number>('audio-level', event => {
    setAudioLevel(event.payload)
  })

  // Listen for display mode from Rust backend
  useTauriEvent<VoiceInputModePayload>('voice-input-mode', event => {
    const mode = event.payload.displayMode
    // Only accept valid modes (standard or minimal)
    setDisplayMode(mode === 'minimal' ? 'minimal' : 'standard')
  })

  // Don't render until we have loaded the initial mode from settings
  if (!initialized) {
    return null
  }

  return (
    <VoiceInputContainer mode={displayMode}>
      {showButtons && (
        <CancelButton
          onClick={recording.cancelRecording}
          disabled={isProcessing}
        />
      )}

      <div className="flex-1 flex items-center justify-center h-full overflow-hidden min-w-0">
        {isProcessing ? (
          <TranscriberProcessing />
        ) : (
          <LiveWaveform
            active={recording.isRecording}
            audioLevel={audioLevel}
            mode="static"
            barWidth={4}
            barGap={1.5}
            barRadius={10}
            barColor="#ffffff"
            height={20}
            sensitivity={3.5}
            fadeEdges
            fadeWidth={10}
            className="h-full w-full"
          />
        )}
      </div>

      {showButtons && (
        <StopButton
          onClick={recording.stopRecording}
          isRecording={recording.isRecording}
          isProcessing={isProcessing}
        />
      )}
    </VoiceInputContainer>
  )
}

const TranscriberProcessing = () => {
  return (
    <LiveWaveform
      active={false}
      processing
      barWidth={4}
      barGap={1.5}
      barRadius={10}
      barColor="#9ca3af"
      fadeEdges
      fadeWidth={20}
      height={24}
      className="w-full opacity-70"
    />
  )
}
