import {
  ChevronDown,
  ChevronUp,
  Languages,
  Sparkles,
  Trash2,
  Upload,
} from 'lucide-react'
import { useMemo, useState } from 'react'

import { Button } from '@/components/ui/button'
import { CopyButton } from '@/components/ui/copy-button'
import { PlayButton } from '@/components/ui/play-button'
import { useAudioPath } from '@/features/transcriptions'
import { cn } from '@/lib/cn'

import { formatTime, formatDuration, highlightSearchMatches } from '../utils'

import type { Transcription } from '@/features/transcriptions'

interface TranscriptionCardProps {
  transcription: Transcription
  onDelete: (id: string) => void
  isLast: boolean
  searchQuery?: string
}

export function TranscriptionCard({
  transcription,
  onDelete,
  isLast,
  searchQuery,
}: TranscriptionCardProps) {
  const [isExpanded, setIsExpanded] = useState(false)
  const timestamp = parseInt(transcription.id.split('-')[0])
  // Only fetch audio path if the transcription has audio saved
  const { audioPath } = useAudioPath(transcription.hasAudio ? timestamp : null)
  const isUploaded = transcription.sourceType === 'upload'
  const isCommand = transcription.sourceType === 'command'
  const isTranslated = transcription.translatedToEnglish

  // Highlight search matches
  const highlightedText = useMemo(() => {
    if (!searchQuery) return null
    return highlightSearchMatches(transcription.text, searchQuery)
  }, [transcription.text, searchQuery])

  // For command mode, highlight the command result as well
  const highlightedCommandResult = useMemo(() => {
    if (!searchQuery || !transcription.commandResult) return null
    return highlightSearchMatches(transcription.commandResult, searchQuery)
  }, [transcription.commandResult, searchQuery])

  return (
    <div
      className={cn(
        'group border-b border-border transition-colors hover:bg-accent/40',
        {
          'border-b-0': isLast,
        }
      )}
    >
      <div className="px-4 py-3.5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1">
              {isCommand && (
                <span className="inline-flex items-center gap-1 px-1.5 py-0.5 text-[10px] font-medium bg-teal-500/10 text-teal-400 rounded">
                  <Sparkles className="h-2.5 w-2.5" />
                  Command
                </span>
              )}
              {isUploaded && (
                <span className="inline-flex items-center gap-1 px-1.5 py-0.5 text-[10px] font-medium bg-blue-500/10 text-blue-500 rounded">
                  <Upload className="h-2.5 w-2.5" />
                  Uploaded
                </span>
              )}
              {isUploaded && transcription.originalFilename && (
                <span className="text-[10px] text-muted-foreground truncate max-w-[150px]">
                  {transcription.originalFilename}
                </span>
              )}
              {isTranslated && (
                <span className="inline-flex items-center gap-1 px-1.5 py-0.5 text-[10px] font-medium rounded bg-violet-500/10 text-violet-600 dark:text-violet-400">
                  <Languages className="h-2.5 w-2.5" />
                  Translated
                </span>
              )}
            </div>
            <p
              className={cn(
                'text-[13px] leading-relaxed text-foreground mb-1.5',
                !isExpanded && 'line-clamp-2'
              )}
            >
              {highlightedText
                ? highlightedText.map((segment, i) =>
                    segment.isHighlight ? (
                      <mark
                        key={i}
                        className="bg-yellow-200/80 dark:bg-yellow-500/30 text-foreground rounded-sm px-0.5"
                      >
                        {segment.text}
                      </mark>
                    ) : (
                      <span key={i}>{segment.text}</span>
                    )
                  )
                : transcription.text}
            </p>

            {/* Command mode: show generated content when expanded */}
            {isCommand && transcription.commandResult && isExpanded && (
              <div className="my-3 p-3 rounded-lg bg-teal-500/5 border border-teal-500/10">
                <p className="text-[10px] font-medium uppercase tracking-wider text-teal-400/70 mb-1.5">
                  Generated Content
                </p>
                <p className="text-[13px] leading-relaxed text-foreground/90 whitespace-pre-wrap">
                  {highlightedCommandResult
                    ? highlightedCommandResult.map((segment, i) =>
                        segment.isHighlight ? (
                          <mark
                            key={i}
                            className="bg-yellow-200/80 dark:bg-yellow-500/30 text-foreground rounded-sm px-0.5"
                          >
                            {segment.text}
                          </mark>
                        ) : (
                          <span key={i}>{segment.text}</span>
                        )
                      )
                    : transcription.commandResult}
                </p>
              </div>
            )}

            <div className="flex items-center gap-3 text-[11px] text-muted-foreground">
              <span>{formatTime(transcription.timestamp)}</span>
              <span className="w-px h-3 bg-border" />
              <span>{transcription.wordCount} words</span>
              <span className="w-px h-3 bg-border" />
              <span>{formatDuration(transcription.duration ?? undefined)}</span>
              {transcription.language && transcription.language !== 'en' && (
                <>
                  <span className="w-px h-3 bg-border" />
                  <span className="uppercase">{transcription.language}</span>
                </>
              )}
            </div>
          </div>

          <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
            {/* Expand/collapse button for command mode */}
            {isCommand && transcription.commandResult && (
              <Button
                size="icon-sm"
                variant="ghost"
                className="text-muted-foreground hover:text-teal-400"
                onClick={() => setIsExpanded(!isExpanded)}
                aria-label={isExpanded ? 'Collapse' : 'Expand'}
              >
                {isExpanded ? (
                  <ChevronUp className="h-3.5 w-3.5" />
                ) : (
                  <ChevronDown className="h-3.5 w-3.5" />
                )}
              </Button>
            )}
            {audioPath && <PlayButton audioPath={audioPath} size={26} />}
            <CopyButton
              content={
                isCommand && transcription.commandResult
                  ? transcription.commandResult
                  : transcription.text
              }
              size="icon"
              variant="ghost"
            />
            <Button
              size="icon-sm"
              variant="ghost"
              className="text-muted-foreground hover:text-destructive"
              onClick={() => onDelete(transcription.id)}
              aria-label="Delete transcription"
            >
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
