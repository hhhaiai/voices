import { Mic } from 'lucide-react'

export function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-20 px-4">
      <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-muted/60 mb-4">
        <Mic className="w-5 h-5 text-muted-foreground/60" strokeWidth={1.5} />
      </div>
      <h3 className="text-sm font-medium text-foreground mb-1">
        No transcriptions yet
      </h3>
      <p className="text-xs text-muted-foreground text-center max-w-[260px] leading-relaxed">
        Press the global shortcut to start your first transcription
      </p>
    </div>
  )
}
