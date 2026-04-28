import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { create } from 'zustand'

import { Transcription } from './schema'

import type { TranscriptionsStore } from './types'

function isToday(timestamp: number): boolean {
  const today = new Date()
  const date = new Date(timestamp)
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  )
}

export const useTranscriptionsStore = create<TranscriptionsStore>(
  (set, get) => ({
    transcriptions: [],
    initialized: false,

    initialize: async () => {
      try {
        const transcriptions = await invoke<Transcription[]>(
          'get_all_transcriptions'
        )

        set({
          transcriptions: transcriptions ?? [],
          initialized: true,
        })
      } catch (error) {
        console.error('Error initializing transcriptions store:', error)
        set({ transcriptions: [], initialized: true })
      }
    },

    addTranscription: async transcription => {
      // Note: This is now handled by the Rust backend during transcription
      // We just need to refresh from the recordings folder
      await get().initialize()

      // Return the most recent transcription (should be the one just added)
      const transcriptions = get().transcriptions
      return transcriptions[0] ?? transcription
    },

    deleteTranscription: async id => {
      try {
        // Parse timestamp from id (format: "timestamp-randomstring" or just "timestamp")
        const timestamp = parseInt(id.split('-')[0])

        // Delete from recordings folder via Rust command
        await invoke('delete_recording', { timestamp })

        // Update local state
        const newTranscriptions = get().transcriptions.filter(t => t.id !== id)
        set({ transcriptions: newTranscriptions })
      } catch (error) {
        console.error('Error deleting transcription:', error)
        throw error
      }
    },

    clearAll: async () => {
      try {
        // Delete all recordings
        const transcriptions = get().transcriptions
        for (const transcription of transcriptions) {
          const timestamp = parseInt(transcription.id.split('-')[0])
          await invoke('delete_recording', { timestamp })
        }

        set({ transcriptions: [] })
      } catch (error) {
        console.error('Error clearing transcriptions:', error)
      }
    },

    getStats: () => {
      const transcriptions = get().transcriptions
      const todayTranscriptions = transcriptions.filter(t =>
        isToday(t.timestamp)
      )
      const totalWords = transcriptions.reduce((sum, t) => sum + t.wordCount, 0)
      const todayWords = todayTranscriptions.reduce(
        (sum, t) => sum + t.wordCount,
        0
      )
      const totalDuration = transcriptions.reduce(
        (sum, t) => sum + (t.duration || 0),
        0
      )

      // Calculate words per minute (if we have duration data)
      const wordsPerMinute =
        totalDuration > 0 ? Math.round((totalWords / totalDuration) * 60) : 0

      // Estimate time saved: typing ~40 WPM vs speaking ~150 WPM
      // Time saved = words / 40 - actual speaking time
      const typingTimeMinutes = totalWords / 40
      const speakingTimeMinutes = totalDuration / 60
      const timeSavedMinutes = Math.max(
        0,
        typingTimeMinutes - speakingTimeMinutes
      )

      // Language statistics
      const languageCounts: Record<string, number> = {}
      let translatedCount = 0

      for (const t of transcriptions) {
        const lang = t.language || 'en'
        languageCounts[lang] = (languageCounts[lang] || 0) + 1
        if (t.translatedToEnglish) {
          translatedCount++
        }
      }

      // Sort languages by count and get top 5
      const topLanguages = Object.entries(languageCounts)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 5)
        .map(([code, count]) => ({ code, count }))

      // Source type breakdown
      const recordings = transcriptions.filter(
        t => t.sourceType === 'recording'
      )
      const uploads = transcriptions.filter(t => t.sourceType === 'upload')
      const commands = transcriptions.filter(t => t.sourceType === 'command')

      // Today's breakdown
      const todayRecordings = todayTranscriptions.filter(
        t => t.sourceType === 'recording'
      )
      const todayCommands = todayTranscriptions.filter(
        t => t.sourceType === 'command'
      )

      // Command stats - count words generated (from commandResult)
      const commandWordsGenerated = commands.reduce((sum, t) => {
        if (t.commandResult) {
          return sum + t.commandResult.split(/\s+/).filter(Boolean).length
        }
        return sum
      }, 0)

      const todayCommandWordsGenerated = todayCommands.reduce((sum, t) => {
        if (t.commandResult) {
          return sum + t.commandResult.split(/\s+/).filter(Boolean).length
        }
        return sum
      }, 0)

      return {
        totalTranscriptions: transcriptions.length,
        totalWords,
        todayCount: todayTranscriptions.length,
        todayWords,
        totalDuration,
        wordsPerMinute,
        timeSavedMinutes: Math.round(timeSavedMinutes),
        avgWordsPerTranscription:
          transcriptions.length > 0
            ? Math.round(totalWords / transcriptions.length)
            : 0,
        languageStats: {
          topLanguages,
          translatedCount,
          uniqueLanguages: Object.keys(languageCounts).length,
        },
        // Source breakdown
        sourceStats: {
          recordings: recordings.length,
          uploads: uploads.length,
          commands: commands.length,
          todayRecordings: todayRecordings.length,
          todayCommands: todayCommands.length,
        },
        // Command mode stats
        commandStats: {
          totalCommands: commands.length,
          todayCommands: todayCommands.length,
          wordsGenerated: commandWordsGenerated,
          todayWordsGenerated: todayCommandWordsGenerated,
          avgWordsPerCommand:
            commands.length > 0
              ? Math.round(commandWordsGenerated / commands.length)
              : 0,
        },
      }
    },
  })
)

export const initializeTranscriptions = async () => {
  await useTranscriptionsStore.getState().initialize()
}

// Set up listener for changes from other windows
export const setupTranscriptionsSync = () => {
  listen('transcriptions-changed', async () => {
    // Reload from Tauri store when another window makes changes
    await useTranscriptionsStore.getState().initialize()
  })
}
