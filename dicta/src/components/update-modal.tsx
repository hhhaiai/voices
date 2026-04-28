import { invoke } from '@tauri-apps/api/core'
import { relaunch } from '@tauri-apps/plugin-process'
import {
  ArrowRight,
  Download,
  RefreshCw,
  Rocket,
  Sparkles,
  Zap,
} from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { useAnalytics } from '@/lib/analytics'

interface UpdateModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  version: string
  releaseNotes?: string
  status: 'available' | 'downloading' | 'ready'
  downloadProgress?: number
}

export function UpdateModal({
  open,
  onOpenChange,
  version,
  status,
  downloadProgress = 0,
}: UpdateModalProps) {
  const { capture, events } = useAnalytics()

  const handleDownload = () => {
    invoke('download_and_install_update')
    capture(events.UPDATE_DOWNLOADED, { version })
  }

  const handleRestart = () => {
    relaunch()
  }

  const handleRemindLater = () => {
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="sm:max-w-[520px] p-0 overflow-hidden gap-0"
        showCloseButton={false}
        onPointerDownOutside={e => e.preventDefault()}
        onEscapeKeyDown={e => e.preventDefault()}
        onInteractOutside={e => e.preventDefault()}
      >
        {/* Top section with gradient background and illustration */}
        <div className="relative bg-gradient-to-br from-primary/10 via-primary/5 to-transparent pt-12 pb-8 px-8">
          {/* Subtle glow effect */}
          <div className="absolute top-0 left-0 w-64 h-64 bg-primary/20 rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2" />
          <div className="absolute top-1/2 right-0 w-48 h-48 bg-primary/10 rounded-full blur-3xl translate-x-1/2" />

          {/* Floating particles */}
          <div className="absolute inset-0 overflow-hidden">
            <div className="absolute top-8 left-12 w-2 h-2 bg-primary/40 rounded-full animate-pulse" />
            <div className="absolute top-16 right-16 w-1.5 h-1.5 bg-primary/30 rounded-full animate-pulse delay-300" />
            <div className="absolute bottom-12 left-20 w-1 h-1 bg-primary/50 rounded-full animate-pulse delay-500" />
            <div className="absolute top-24 left-1/2 w-1.5 h-1.5 bg-primary/25 rounded-full animate-pulse delay-700" />
          </div>

          {/* Main content */}
          <div className="relative z-10 flex flex-col items-center text-center">
            {/* Icon */}
            <div className="relative mb-6">
              <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-primary to-primary/80 flex items-center justify-center shadow-lg shadow-primary/25">
                <Rocket
                  className="w-10 h-10 text-primary-foreground"
                  strokeWidth={1.5}
                />
              </div>
              {/* Badge */}
              <div className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-background border-2 border-primary flex items-center justify-center">
                <Sparkles className="w-4 h-4 text-primary" />
              </div>
            </div>

            {/* Title */}
            <h2 className="text-2xl font-semibold tracking-tight mb-2">
              {status === 'ready' ? 'Ready to Launch' : 'A New Update Awaits'}
            </h2>

            {/* Version badge */}
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/10 border border-primary/20 mb-4">
              <span className="text-sm font-medium text-primary">
                Version {version}
              </span>
            </div>

            {/* Description */}
            <p className="text-muted-foreground text-sm max-w-[320px]">
              {status === 'available' && (
                <>We've been working hard to make Dicta even better for you.</>
              )}
              {status === 'downloading' && (
                <>Downloading the latest improvements...</>
              )}
              {status === 'ready' && (
                <>Your update is ready. Restart to enjoy the latest features.</>
              )}
            </p>
          </div>
        </div>

        {/* Bottom section */}
        <div className="p-6 space-y-6">
          {/* Progress bar for downloading */}
          {status === 'downloading' && (
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Downloading...</span>
                <span className="font-medium">
                  {downloadProgress.toFixed(0)}%
                </span>
              </div>
              <div className="h-2 bg-muted rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-primary to-primary/80 transition-all duration-300 ease-out rounded-full"
                  style={{ width: `${downloadProgress}%` }}
                />
              </div>
            </div>
          )}

          {/* Feature highlights - only show when available */}
          {status === 'available' && (
            <div className="grid grid-cols-3 gap-3">
              <FeatureCard
                icon={<Zap className="w-4 h-4" />}
                label="Performance"
              />
              <FeatureCard
                icon={<Sparkles className="w-4 h-4" />}
                label="New Features"
              />
              <FeatureCard
                icon={<RefreshCw className="w-4 h-4" />}
                label="Bug Fixes"
              />
            </div>
          )}

          {/* Actions */}
          <div className="flex flex-col gap-2">
            {status === 'available' && (
              <>
                <Button
                  onClick={handleDownload}
                  size="lg"
                  className="w-full h-12 text-base font-medium"
                >
                  <Download className="w-4 h-4 mr-2" />
                  Download Update
                  <ArrowRight className="w-4 h-4 ml-2" />
                </Button>
                <Button
                  variant="ghost"
                  onClick={handleRemindLater}
                  className="w-full text-muted-foreground hover:text-foreground"
                >
                  Maybe later
                </Button>
              </>
            )}
            {status === 'downloading' && (
              <Button disabled size="lg" className="w-full h-12">
                <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                Downloading...
              </Button>
            )}
            {status === 'ready' && (
              <>
                <Button
                  onClick={handleRestart}
                  size="lg"
                  className="w-full h-12 text-base font-medium"
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Restart Now
                  <ArrowRight className="w-4 h-4 ml-2" />
                </Button>
                <Button
                  variant="ghost"
                  onClick={handleRemindLater}
                  className="w-full text-muted-foreground hover:text-foreground"
                >
                  Restart later
                </Button>
              </>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function FeatureCard({
  icon,
  label,
}: {
  icon: React.ReactNode
  label: string
}) {
  return (
    <div className="flex flex-col items-center gap-2 p-3 rounded-xl bg-muted/50 border border-border/50">
      <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
        {icon}
      </div>
      <span className="text-xs font-medium text-muted-foreground">{label}</span>
    </div>
  )
}
