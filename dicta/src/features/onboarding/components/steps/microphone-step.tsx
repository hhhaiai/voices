import { Mic, Check, AlertCircle, ArrowRight } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { usePermissionPolling } from '@/hooks/use-permission-polling'
import { usePermissions } from '@/hooks/use-permissions'

import { useOnboarding } from '../../hooks/use-onboarding'

export function MicrophoneStep() {
  const { completeCurrentStepAndGoNext, markStepComplete } = useOnboarding()
  const { permissions, requestMicrophone } = usePermissions()

  usePermissionPolling(true, 2000)

  const isGranted = permissions?.microphone === 'granted'
  const isDenied = permissions?.microphone === 'denied'

  const handleRequest = async () => {
    const granted = await requestMicrophone()
    if (granted) {
      markStepComplete('microphone')
    }
  }

  const handleContinue = () => {
    if (isGranted) {
      completeCurrentStepAndGoNext()
    }
  }

  return (
    <div className="flex flex-col items-center text-center">
      {/* Icon */}
      <div className="mb-8">
        <div
          className={`
            flex items-center justify-center w-20 h-20 rounded-full
            transition-colors duration-300
            ${
              isGranted
                ? 'bg-primary/10 border border-primary/30'
                : 'bg-zinc-900 border border-zinc-800'
            }
          `}
        >
          {isGranted ? (
            <Check className="w-8 h-8 text-primary" strokeWidth={2} />
          ) : (
            <Mic className="w-8 h-8 text-muted-foreground" strokeWidth={1.5} />
          )}
        </div>
      </div>

      {/* Title */}
      <h1 className="text-3xl font-semibold tracking-tight mb-3">
        Microphone Access
      </h1>

      {/* Subtitle */}
      <p className="text-muted-foreground mb-8 max-w-sm">
        Dicta needs microphone access to transcribe your voice in real-time.
      </p>

      {/* Status messages */}
      {isGranted && (
        <div className="flex items-center gap-2 mb-8 text-sm">
          <Check className="w-4 h-4 text-primary" strokeWidth={2.5} />
          <span className="text-primary font-medium">Microphone enabled</span>
          <span className="text-muted-foreground">·</span>
          <span className="text-muted-foreground">Ready to transcribe</span>
        </div>
      )}

      {isDenied && !isGranted && (
        <div className="flex items-start gap-3 p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 mb-8 max-w-sm text-left">
          <AlertCircle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-amber-400">
              Permission needed
            </p>
            <p className="text-xs text-amber-400/70 mt-1">
              Open System Settings → Privacy & Security → Microphone and enable
              Dicta
            </p>
          </div>
        </div>
      )}

      {/* Privacy features */}
      {!isGranted && !isDenied && (
        <div className="flex items-center justify-center gap-6 mb-8 text-sm text-muted-foreground">
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Processed Locally</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Never Uploaded</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>100% Private</span>
          </div>
        </div>
      )}

      {/* CTA */}
      <Button
        onClick={isGranted ? handleContinue : handleRequest}
        className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
      >
        {isGranted ? (
          <>
            Continue
            <ArrowRight className="w-4 h-4 ml-2" />
          </>
        ) : (
          'Grant Microphone Access'
        )}
      </Button>
    </div>
  )
}
