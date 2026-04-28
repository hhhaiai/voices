import type { Transcription } from './schema'

export type { Transcription }

export interface TranscriptionsStore {
  transcriptions: Transcription[]
  initialized: boolean
  initialize: () => Promise<void>
  addTranscription: (
    transcription: Omit<Transcription, 'id' | 'wordCount'>
  ) => Promise<Transcription>
  deleteTranscription: (id: string) => Promise<void>
  clearAll: () => Promise<void>
  getStats: () => {
    totalTranscriptions: number
    totalWords: number
    todayCount: number
    todayWords: number
    totalDuration: number
    wordsPerMinute: number
    timeSavedMinutes: number
    avgWordsPerTranscription: number
    languageStats: {
      topLanguages: Array<{ code: string; count: number }>
      translatedCount: number
      uniqueLanguages: number
    }
    sourceStats: {
      recordings: number
      uploads: number
      commands: number
      todayRecordings: number
      todayCommands: number
    }
    commandStats: {
      totalCommands: number
      todayCommands: number
      wordsGenerated: number
      todayWordsGenerated: number
      avgWordsPerCommand: number
    }
  }
}
