import { TranscriptionCard } from './transcription-card'

import type { GroupedTranscriptions } from '../utils'

interface TranscriptionGroupProps {
  group: GroupedTranscriptions
  onDeleteTranscription: (id: string) => void
  searchQuery?: string
}

export function TranscriptionGroup({
  group,
  onDeleteTranscription,
  searchQuery,
}: TranscriptionGroupProps) {
  return (
    <div className="mb-6">
      <div className="sticky top-0 z-10 -mx-8 px-8 bg-background pb-2.5 pt-1 shadow-[0_8px_12px_-4px_hsl(var(--background))]">
        <span className="inline-flex items-center text-[11px] font-medium text-muted-foreground bg-muted/50 px-2 py-0.5 rounded">
          {group.label}
        </span>
      </div>

      <div className="rounded-lg border border-border bg-card overflow-hidden">
        {group.transcriptions.map((transcription, index) => (
          <TranscriptionCard
            key={transcription.id}
            transcription={transcription}
            onDelete={onDeleteTranscription}
            isLast={index === group.transcriptions.length - 1}
            searchQuery={searchQuery}
          />
        ))}
      </div>
    </div>
  )
}
