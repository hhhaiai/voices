import { Info, Sparkles, X, Zap } from 'lucide-react'
import { useEffect } from 'react'
import { create } from 'zustand'

import { useModelsStore } from '@/features/models/store'
import { useSettingsStore } from '@/features/settings/store'
import { cn } from '@/lib/cn'

// In-memory store for dismissed banners (survives window close, resets on app quit)
interface BannerDismissState {
  dismissed: Record<string, boolean>
  dismiss: (bannerId: string) => void
}

const useBannerDismissStore = create<BannerDismissState>(set => ({
  dismissed: {},
  dismiss: (bannerId: string) =>
    set(state => ({
      dismissed: { ...state.dismissed, [bannerId]: true },
    })),
}))

interface FeatureBannerProps {
  className?: string
  bannerId: string
  title: string
  description: string
  icon: React.ReactNode
}

function FeatureBanner({
  className,
  bannerId,
  title,
  description,
  icon,
}: FeatureBannerProps) {
  const { dismissed, dismiss } = useBannerDismissStore()

  if (dismissed[bannerId]) return null

  return (
    <div
      className={cn(
        'relative rounded-lg border border-border/50 bg-card/50 backdrop-blur-sm overflow-hidden hover:border-border/80 transition-colors',
        className
      )}
    >
      {/* Gradient accent line at top */}
      <div
        className="absolute top-0 left-0 right-0 h-[2px] opacity-60"
        style={{
          background: `linear-gradient(90deg, #4ade8000, #4ade80, #4ade8000)`,
        }}
      />

      <div className="px-3 py-2 flex items-center gap-2.5">
        {/* Icon */}
        <div className="shrink-0">{icon}</div>

        {/* Content */}
        <p className="flex-1 min-w-0 text-[11px] text-muted-foreground">
          <span className="font-medium text-foreground">{title}</span>
          <span className="mx-1.5 text-border">·</span>
          {description}
        </p>

        {/* Close button */}
        <button
          onClick={() => dismiss(bannerId)}
          className="shrink-0 p-1 rounded text-muted-foreground hover:text-foreground hover:bg-muted/50 transition-colors"
          aria-label="Dismiss"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  )
}

interface VocabularySupportBannerProps {
  className?: string
}

export function VocabularySupportBanner({
  className,
}: VocabularySupportBannerProps) {
  const { models, initialized, initialize } = useModelsStore()
  const { settings } = useSettingsStore()

  useEffect(() => {
    if (!initialized) {
      initialize()
    }
  }, [initialized, initialize])

  if (!initialized) return null

  const selectedSttModel = models.find(
    m => m.purpose === 'speech-to-text' && m.isSelected
  )

  const aiProcessingEnabled = settings.aiProcessing?.enabled
  const supportsVocabulary = selectedSttModel?.supportsVocabulary ?? false

  if (aiProcessingEnabled) {
    return (
      <FeatureBanner
        className={className}
        bannerId="vocabulary-ai-active"
        title="Full support active"
        description="AI uses your vocabulary for best accuracy"
        icon={<Sparkles className="h-3.5 w-3.5 text-amber-500" />}
      />
    )
  }

  if (supportsVocabulary) {
    return (
      <FeatureBanner
        className={className}
        bannerId="vocabulary-word-boost"
        title={`${selectedSttModel?.name} supports word boost`}
        description="Enable AI for better results"
        icon={<Zap className="h-3.5 w-3.5 text-amber-500" />}
      />
    )
  }

  return (
    <FeatureBanner
      className={className}
      bannerId="vocabulary-no-support"
      title="Word boost not supported"
      description="Enable AI processing to use vocabulary"
      icon={<Info className="h-3.5 w-3.5 text-muted-foreground" />}
    />
  )
}

interface SnippetsSupportBannerProps {
  className?: string
}

export function SnippetsSupportBanner({
  className,
}: SnippetsSupportBannerProps) {
  const { settings } = useSettingsStore()
  const aiProcessingEnabled = settings.aiProcessing?.enabled

  if (aiProcessingEnabled) {
    return (
      <FeatureBanner
        className={className}
        bannerId="snippets-active"
        title="Snippets active"
        description="AI expands snippets during transcription"
        icon={<Sparkles className="h-3.5 w-3.5 text-amber-500" />}
      />
    )
  }

  return (
    <FeatureBanner
      className={className}
      bannerId="snippets-inactive"
      title="Snippets require AI"
      description="Enable AI processing to use text expansions"
      icon={<Info className="h-3.5 w-3.5 text-muted-foreground" />}
    />
  )
}

interface VibesSupportBannerProps {
  className?: string
}

export function VibesSupportBanner({ className }: VibesSupportBannerProps) {
  const { settings } = useSettingsStore()
  const aiProcessingEnabled = settings.aiProcessing?.enabled

  if (aiProcessingEnabled) {
    return (
      <FeatureBanner
        className={className}
        bannerId="vibes-active"
        title="Vibes active"
        description="AI applies your style to transcriptions"
        icon={<Sparkles className="h-3.5 w-3.5 text-amber-500" />}
      />
    )
  }

  return (
    <FeatureBanner
      className={className}
      bannerId="vibes-inactive"
      title="Vibes require AI"
      description="Enable AI processing to style transcriptions"
      icon={<Info className="h-3.5 w-3.5 text-muted-foreground" />}
    />
  )
}
