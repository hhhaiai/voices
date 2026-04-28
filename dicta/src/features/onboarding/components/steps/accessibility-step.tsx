import { Check, ArrowRight, Mic, ExternalLink } from 'lucide-react'
import { useState, useEffect } from 'react'

import { Button } from '@/components/ui/button'
import { usePermissionPolling } from '@/hooks/use-permission-polling'
import { usePermissions } from '@/hooks/use-permissions'

import { useOnboarding } from '../../hooks/use-onboarding'

export function AccessibilityStep() {
  const { completeCurrentStepAndGoNext, markStepComplete } = useOnboarding()
  const { permissions, requestAccessibilityPermission, checkPermissions } =
    usePermissions()
  const [hasRequestedOnce, setHasRequestedOnce] = useState(false)
  const [isChecking, setIsChecking] = useState(false)

  usePermissionPolling(true, 2000)

  const isGranted = permissions?.accessibility === 'granted'
  // After requesting once, treat 'unknown' as potentially granted (user may need to verify)
  const showManualVerify =
    hasRequestedOnce && !isGranted && permissions?.accessibility === 'unknown'

  // Auto-complete if granted
  useEffect(() => {
    if (isGranted) {
      markStepComplete('accessibility')
    }
  }, [isGranted, markStepComplete])

  const handleRequest = async () => {
    setHasRequestedOnce(true)
    await requestAccessibilityPermission()
  }

  const handleCheckAgain = async () => {
    setIsChecking(true)
    await checkPermissions()
    setIsChecking(false)
  }

  const handleContinue = () => {
    completeCurrentStepAndGoNext()
  }

  // Allow skipping if user has already tried granting
  // (macOS accessibility permissions are notoriously unreliable to detect)
  const handleSkipForNow = () => {
    completeCurrentStepAndGoNext()
  }

  return (
    <div className="flex flex-col items-center text-center">
      {/* Shortcut Demo */}
      <div className="mb-8">
        <div className="flex items-center gap-3">
          {/* Option key */}
          <div
            className={`
              flex items-center justify-center h-12 w-12 rounded-lg
              bg-zinc-800 border transition-colors duration-300
              ${isGranted ? 'border-primary/40' : 'border-zinc-700'}
            `}
          >
            <span
              className={`text-lg font-medium ${isGranted ? 'text-primary' : 'text-muted-foreground'}`}
            >
              ⌥
            </span>
          </div>

          <span className="text-lg text-muted-foreground">+</span>

          {/* Space key */}
          <div
            className={`
              flex items-center justify-center h-12 px-6 rounded-lg
              bg-zinc-800 border transition-colors duration-300
              ${isGranted ? 'border-primary/40' : 'border-zinc-700'}
            `}
          >
            <span
              className={`text-xs font-medium tracking-wider ${isGranted ? 'text-primary' : 'text-muted-foreground'}`}
            >
              SPACE
            </span>
          </div>

          {/* Arrow */}
          <div className="w-6 h-px bg-zinc-700 mx-2" />

          {/* Mic indicator */}
          <div
            className={`
              flex items-center justify-center w-12 h-12 rounded-full
              transition-colors duration-300
              ${
                isGranted
                  ? 'bg-primary/10 border border-primary/30'
                  : 'bg-zinc-900 border border-zinc-800'
              }
            `}
          >
            {isGranted ? (
              <Check className="w-5 h-5 text-primary" strokeWidth={2.5} />
            ) : (
              <Mic className="w-5 h-5 text-muted-foreground" />
            )}
          </div>
        </div>
      </div>

      {/* Title */}
      <h1 className="text-3xl font-semibold tracking-tight mb-3">
        Enable Global Shortcuts
      </h1>

      {/* Subtitle */}
      <p className="text-muted-foreground mb-8 max-w-sm">
        Start transcribing from anywhere with a simple keyboard shortcut.
      </p>

      {/* Status messages */}
      {isGranted && (
        <div className="flex items-center gap-2 mb-8 text-sm">
          <Check className="w-4 h-4 text-primary" strokeWidth={2.5} />
          <span className="text-primary font-medium">All set!</span>
          <span className="text-muted-foreground">·</span>
          <span className="text-muted-foreground">
            Global shortcuts enabled
          </span>
        </div>
      )}

      {/* Manual verification needed */}
      {showManualVerify && (
        <div className="flex items-start gap-3 p-4 rounded-xl bg-blue-500/10 border border-blue-500/20 mb-8 max-w-sm text-left">
          <ExternalLink className="w-5 h-5 text-blue-400 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-blue-400">
              Enabled in System Settings?
            </p>
            <p className="text-xs text-blue-400/70 mt-1">
              If you've enabled Dicta in Accessibility settings, click "I've
              Enabled It" to continue.
            </p>
          </div>
        </div>
      )}

      {/* Info features */}
      {!isGranted && !showManualVerify && (
        <div className="flex items-center justify-center gap-6 mb-8 text-sm text-muted-foreground">
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Works Anywhere</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Background Ready</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Instant Access</span>
          </div>
        </div>
      )}

      {/* CTA Buttons */}
      <div className="flex flex-col gap-3">
        {isGranted ? (
          <Button
            onClick={handleContinue}
            className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
          >
            Finish Setup
            <ArrowRight className="w-4 h-4 ml-2" />
          </Button>
        ) : showManualVerify ? (
          <>
            <div className="flex gap-3">
              <Button
                onClick={handleCheckAgain}
                variant="outline"
                disabled={isChecking}
                className="h-11 px-6"
              >
                {isChecking ? 'Checking...' : 'Check Again'}
              </Button>
              <Button
                onClick={handleSkipForNow}
                className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
              >
                I've Enabled It
                <ArrowRight className="w-4 h-4 ml-2" />
              </Button>
            </div>
            <button
              onClick={handleRequest}
              className="text-xs text-muted-foreground hover:text-foreground transition-colors"
            >
              Open System Settings again
            </button>
          </>
        ) : (
          <Button
            onClick={handleRequest}
            className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
          >
            Grant Accessibility Access
          </Button>
        )}
      </div>
    </div>
  )
}
