import { ArrowRight } from 'lucide-react'
import { useEffect, useState } from 'react'

import { Button } from '@/components/ui/button'
import { LiveWaveform } from '@/components/ui/live-waveform'

import { useOnboarding } from '../../hooks/use-onboarding'

export function WelcomeStep() {
  const { completeCurrentStepAndGoNext } = useOnboarding()
  const [simulatedAudioLevel, setSimulatedAudioLevel] = useState(0)

  // Simulate audio levels for demo animation
  useEffect(() => {
    let time = 0
    const interval = setInterval(() => {
      time += 0.08
      const wave1 = Math.sin(time * 1.5) * 0.4
      const wave2 = Math.sin(time * 0.9 + 1.2) * 0.35
      const wave3 = Math.cos(time * 2.1 + 2.5) * 0.25
      const combined = wave1 + wave2 + wave3
      const level = Math.max(8, Math.min(75, (combined + 0.5) * 45 + 15))
      setSimulatedAudioLevel(level)
    }, 40)

    return () => clearInterval(interval)
  }, [])

  return (
    <div className="flex flex-col items-center text-center">
      {/* Voice pill demo */}
      <div className="mb-10">
        <div className="flex items-center h-11 w-[280px] rounded-full bg-zinc-900 border border-zinc-800 px-4">
          <div className="flex-1 flex items-center justify-center overflow-hidden">
            <LiveWaveform
              active={true}
              audioLevel={simulatedAudioLevel}
              barWidth={3}
              barGap={2}
              barRadius={3}
              barColor="#ffffff"
              height={20}
              sensitivity={1.2}
              fadeEdges
              fadeWidth={30}
              className="w-full"
            />
          </div>
        </div>
      </div>

      {/* Title */}
      <h1 className="text-3xl font-semibold tracking-tight mb-3">
        Welcome to <span className="text-primary">Dicta</span>
      </h1>

      {/* Subtitle */}
      <p className="text-muted-foreground mb-8 max-w-sm">
        Transform your voice into text instantly. Private, fast, and works
        completely offline.
      </p>

      {/* Features */}
      <div className="flex items-center justify-center gap-6 mb-10 text-sm text-muted-foreground">
        <div className="flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-primary" />
          <span>Offline First</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-primary" />
          <span>100% Private</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-primary" />
          <span>No API Costs</span>
        </div>
      </div>

      {/* CTA */}
      <Button
        onClick={completeCurrentStepAndGoNext}
        className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
      >
        Get Started
        <ArrowRight className="w-4 h-4 ml-2" />
      </Button>
    </div>
  )
}
