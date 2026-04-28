import { motion, AnimatePresence } from 'motion/react'

import { DictaLogo } from '@/components/ui/dicta-logo'

import { StepProgress } from './step-progress'
import { useOnboarding } from '../hooks/use-onboarding'

import type { ReactNode } from 'react'

interface OnboardingLayoutProps {
  children: ReactNode
}

export function OnboardingLayout({ children }: OnboardingLayoutProps) {
  const { steps, currentStep } = useOnboarding()

  return (
    <div className="relative flex flex-col h-screen bg-background overflow-hidden">
      {/* Drag region */}
      <div
        data-tauri-drag-region
        className="absolute left-0 right-0 top-0 h-12 z-50"
      />

      {/* Subtle grid pattern */}
      <div
        className="absolute inset-0 opacity-[0.02] pointer-events-none"
        style={{
          backgroundImage: `linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px),
                           linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)`,
          backgroundSize: '60px 60px',
        }}
      />

      {/* Header */}
      <header className="relative z-10 flex items-center justify-between px-8 pt-12 pb-6">
        <div className="flex items-center gap-2.5">
          <DictaLogo size={24} className="text-primary" />
          <span className="text-base font-medium tracking-tight">Dicta</span>
        </div>
        <StepProgress totalSteps={steps.length} currentStep={currentStep} />
      </header>

      {/* Main content */}
      <div className="relative z-10 flex-1 flex items-center justify-center px-8 pb-8">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentStep}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="w-full max-w-lg"
          >
            {children}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Footer */}
      <footer className="relative z-10 px-8 pb-6">
        <p className="text-xs text-muted-foreground text-center">
          By continuing, you agree to our Terms of Service and Privacy Policy
        </p>
      </footer>
    </div>
  )
}
