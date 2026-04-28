import type { FilterState } from '../components/search-filter-bar'
import type { Transcription } from '@/features/transcriptions'

/**
 * Check if a timestamp is from today
 */
function isToday(timestamp: number): boolean {
  const today = new Date()
  const date = new Date(timestamp)
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  )
}

/**
 * Check if a timestamp is from this week (last 7 days)
 */
function isThisWeek(timestamp: number): boolean {
  const now = new Date()
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  return timestamp >= weekAgo.getTime()
}

/**
 * Check if a timestamp is from this month (last 30 days)
 */
function isThisMonth(timestamp: number): boolean {
  const now = new Date()
  const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
  return timestamp >= monthAgo.getTime()
}

/**
 * Check if transcription text matches the search query
 * Performs case-insensitive search
 */
function matchesSearch(text: string, query: string): boolean {
  if (!query.trim()) return true
  const normalizedQuery = query.toLowerCase().trim()
  const normalizedText = text.toLowerCase()

  // Split query into words and check if all words are present
  const queryWords = normalizedQuery.split(/\s+/)
  return queryWords.every(word => normalizedText.includes(word))
}

/**
 * Filter transcriptions based on filter state
 */
export function filterTranscriptions(
  transcriptions: Transcription[],
  filters: FilterState
): Transcription[] {
  return transcriptions.filter(transcription => {
    // Search filter
    if (filters.search && !matchesSearch(transcription.text, filters.search)) {
      return false
    }

    // Source filter
    if (filters.source !== 'all') {
      const sourceType = transcription.sourceType || 'recording'
      if (sourceType !== filters.source) {
        return false
      }
    }

    // Time filter
    if (filters.time !== 'all') {
      switch (filters.time) {
        case 'today':
          if (!isToday(transcription.timestamp)) return false
          break
        case 'week':
          if (!isThisWeek(transcription.timestamp)) return false
          break
        case 'month':
          if (!isThisMonth(transcription.timestamp)) return false
          break
      }
    }

    // Audio filter
    if (filters.audio !== 'all') {
      const hasAudio = transcription.hasAudio ?? false
      if (filters.audio === 'with-audio' && !hasAudio) return false
      if (filters.audio === 'without-audio' && hasAudio) return false
    }

    return true
  })
}

/**
 * Highlight search matches in text
 * Returns an array of segments with isHighlight flag
 */
export function highlightSearchMatches(
  text: string,
  query: string
): Array<{ text: string; isHighlight: boolean }> {
  if (!query.trim()) {
    return [{ text, isHighlight: false }]
  }

  const normalizedQuery = query.toLowerCase().trim()
  const queryWords = normalizedQuery.split(/\s+/).filter(Boolean)

  if (queryWords.length === 0) {
    return [{ text, isHighlight: false }]
  }

  // Create a regex pattern that matches any of the query words
  const pattern = new RegExp(
    `(${queryWords.map(w => escapeRegex(w)).join('|')})`,
    'gi'
  )

  const segments: Array<{ text: string; isHighlight: boolean }> = []
  let lastIndex = 0
  let match: RegExpExecArray | null

  while ((match = pattern.exec(text)) !== null) {
    // Add text before match
    if (match.index > lastIndex) {
      segments.push({
        text: text.slice(lastIndex, match.index),
        isHighlight: false,
      })
    }
    // Add matched text
    segments.push({
      text: match[0],
      isHighlight: true,
    })
    lastIndex = pattern.lastIndex
  }

  // Add remaining text
  if (lastIndex < text.length) {
    segments.push({
      text: text.slice(lastIndex),
      isHighlight: false,
    })
  }

  return segments.length > 0 ? segments : [{ text, isHighlight: false }]
}

function escapeRegex(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
