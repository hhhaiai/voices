import { invoke } from '@tauri-apps/api/core'
import { useEffect, useState } from 'react'

/**
 * Converts a base64 string to a Uint8Array
 */
function base64ToUint8Array(base64: string): Uint8Array {
  const binaryString = atob(base64)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  return bytes
}

export function useAudioPath(timestamp: number | null) {
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    // If no timestamp provided, skip loading
    if (timestamp === null) {
      setAudioUrl(null)
      setIsLoading(false)
      setError(null)
      return
    }

    let cancelled = false
    let objectUrl: string | null = null

    const loadAudioPath = async () => {
      setIsLoading(true)
      setError(null)

      try {
        // Get base64 encoded audio from Rust
        const base64Audio = await invoke<string>('get_recording_audio_path', {
          timestamp,
        })

        if (!cancelled) {
          // Convert base64 to Uint8Array
          const audioBytes = base64ToUint8Array(base64Audio)
          // Create Blob from bytes
          const blob = new Blob([audioBytes], { type: 'audio/wav' })
          // Create object URL
          objectUrl = URL.createObjectURL(blob)
          setAudioUrl(objectUrl)
        }
      } catch (err) {
        if (!cancelled) {
          setError(err as string)
          setAudioUrl(null)
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false)
        }
      }
    }

    loadAudioPath()

    return () => {
      cancelled = true
      // Clean up object URL when component unmounts
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl)
      }
    }
  }, [timestamp])

  return { audioPath: audioUrl, isLoading, error }
}
