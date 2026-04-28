import { VibesSupportBanner } from '@/components/ui/feature-banner'

import { VibesPanel } from '../components'

export function VibesPage() {
  return (
    <div className="h-full w-full flex flex-col px-8">
      <div className="shrink-0 pt-16 pb-6">
        <h1 className="text-2xl font-medium tracking-tight text-foreground">
          Vibes
        </h1>
        <p className="text-sm text-muted-foreground mt-1.5">
          Style your transcriptions for different contexts.
        </p>
      </div>

      <div className="flex-1 overflow-y-auto">
        <VibesPanel />
      </div>

      {/* Bottom Banner */}
      <VibesSupportBanner className="shrink-0 mt-6 mb-8" />
    </div>
  )
}
