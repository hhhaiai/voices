import { invoke } from '@tauri-apps/api/core'

export type SpeechRecognitionAuthStatus =
  | 'notDetermined'
  | 'denied'
  | 'restricted'
  | 'authorized'

/**
 * Check the current speech recognition authorization status
 */
export async function checkSpeechRecognitionPermission(): Promise<SpeechRecognitionAuthStatus> {
  try {
    const status = await invoke<SpeechRecognitionAuthStatus>(
      'check_speech_recognition_permission'
    )
    console.log('Speech recognition permission status:', status)
    return status
  } catch (error) {
    console.error('Failed to check speech recognition permission:', error)
    return 'notDetermined'
  }
}

/**
 * Request speech recognition authorization from the user
 * This will show a system dialog asking for permission
 */
export async function requestSpeechRecognitionPermission(): Promise<SpeechRecognitionAuthStatus> {
  try {
    console.log('Requesting speech recognition permission...')
    const status = await invoke<SpeechRecognitionAuthStatus>(
      'request_speech_recognition_permission'
    )
    console.log('Speech recognition permission result:', status)
    return status
  } catch (error) {
    console.error('Failed to request speech recognition permission:', error)
    return 'notDetermined'
  }
}

/**
 * Check if speech recognition is authorized
 */
export async function isSpeechRecognitionAuthorized(): Promise<boolean> {
  const status = await checkSpeechRecognitionPermission()
  return status === 'authorized'
}
