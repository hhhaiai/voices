import { Check } from 'lucide-react'

import { cn } from '@/lib/cn'

import { useSettingsStore } from '../store'

import type { VoiceInputDisplayMode } from '../types/generated'

interface DisplayModeOption {
  value: VoiceInputDisplayMode
  label: string
}

const displayModeOptions: DisplayModeOption[] = [
  { value: 'standard', label: 'Standard' },
  { value: 'minimal', label: 'Minimal' },
]

export function VisualDisplayModeSelector() {
  const { settings, setVoiceInputDisplayMode } = useSettingsStore()
  const currentMode = settings.voiceInput.displayMode ?? 'standard'

  return (
    <div className="flex gap-3">
      {displayModeOptions.map(option => (
        <button
          key={option.value}
          onClick={() => void setVoiceInputDisplayMode(option.value)}
          className="flex flex-col items-center gap-2 group"
        >
          <div
            className={cn(
              'relative w-24 h-16 rounded-lg border-2 overflow-hidden transition-all flex items-end justify-center pb-2',
              currentMode === option.value
                ? 'border-blue-500 ring-2 ring-blue-500/20'
                : 'border-border hover:border-muted-foreground/50',
              'bg-zinc-900'
            )}
          >
            <DisplayModePreview variant={option.value} />
            {currentMode === option.value && (
              <div className="absolute bottom-1 right-1 w-4 h-4 bg-blue-500 rounded-full flex items-center justify-center">
                <Check className="w-2.5 h-2.5 text-white" strokeWidth={3} />
              </div>
            )}
          </div>
          <span
            className={cn(
              'text-xs font-medium transition-colors',
              currentMode === option.value
                ? 'text-blue-500'
                : 'text-muted-foreground'
            )}
          >
            {option.label}
          </span>
        </button>
      ))}
    </div>
  )
}

function DisplayModePreview({ variant }: { variant: VoiceInputDisplayMode }) {
  const isStandard = variant === 'standard'

  // Pill container dimensions based on mode
  const pillWidth = isStandard ? 'w-16' : 'w-12'

  return (
    <div
      className={cn(
        'h-3 rounded-full bg-zinc-800 border border-zinc-700 flex items-center justify-center gap-0.5 px-1',
        pillWidth
      )}
    >
      {isStandard && (
        // Cancel button (X)
        <div className="w-1.5 h-1.5 rounded-full bg-zinc-600 flex items-center justify-center">
          <div className="w-0.5 h-0.5 bg-zinc-400" />
        </div>
      )}

      {/* Waveform bars */}
      <div className="flex items-center gap-px flex-1 justify-center">
        <div className="w-0.5 h-1 bg-white/80 rounded-full" />
        <div className="w-0.5 h-1.5 bg-white/80 rounded-full" />
        <div className="w-0.5 h-2 bg-white/80 rounded-full" />
        <div className="w-0.5 h-1.5 bg-white/80 rounded-full" />
        <div className="w-0.5 h-1 bg-white/80 rounded-full" />
      </div>

      {isStandard && (
        // Stop button (square)
        <div className="w-1.5 h-1.5 rounded-sm bg-red-500" />
      )}
    </div>
  )
}
