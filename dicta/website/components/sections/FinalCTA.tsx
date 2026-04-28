'use client'

import { useEffect, useRef } from 'react'

// Animated horizontal lines for final CTA - colorful
function HorizontalLinesCTA() {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const colors = [
      { base: 'rgba(74, 222, 128, 0.12)', bright: 'rgba(74, 222, 128, 0.35)' },
      { base: 'rgba(251, 146, 60, 0.1)', bright: 'rgba(251, 146, 60, 0.3)' },
      { base: 'rgba(96, 165, 250, 0.1)', bright: 'rgba(96, 165, 250, 0.3)' },
      { base: 'rgba(167, 139, 250, 0.1)', bright: 'rgba(167, 139, 250, 0.3)' },
      { base: 'rgba(255, 255, 255, 0.03)', bright: 'rgba(255, 255, 255, 0.1)' },
    ]

    const createLine = () => {
      const line = document.createElement('div')
      const color = colors[Math.floor(Math.random() * colors.length)]

      const top = Math.random() * 100
      const width = 25 + Math.random() * 40

      line.style.position = 'absolute'
      line.style.height = '1px'
      line.style.top = `${top}%`
      line.style.left = `${-20 + Math.random() * 20}%`
      line.style.width = `${width}%`

      line.style.background = `linear-gradient(to right, transparent 0%, ${color.base} 10%, ${color.bright} 50%, ${color.base} 90%, transparent 100%)`

      const duration = 4 + Math.random() * 4
      const delay = Math.random() * 2

      line.style.animation = `h-line-move ${duration}s linear ${delay}s`
      line.style.opacity = '0'

      container.appendChild(line)

      setTimeout(() => {
        line.remove()
      }, (duration + delay) * 1000 + 100)
    }

    for (let i = 0; i < 18; i++) {
      setTimeout(createLine, i * 120)
    }

    const interval = setInterval(createLine, 250)

    return () => {
      clearInterval(interval)
    }
  }, [])

  return <div ref={containerRef} className="absolute inset-0 overflow-hidden pointer-events-none" />
}

export default function FinalCTA() {
  return (
    <section className="section-bordered relative section-padding overflow-hidden">
      {/* Animated background */}
      <div className="absolute inset-0 -z-10">
        <HorizontalLinesCTA />
        <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black/60" />
      </div>

      <div className="text-center relative z-10">
        {/* Headline */}
        <h2 className="text-display-lg mb-6">
          <span className="text-primary">Free your voice.</span>
          <br />
          Start transcribing locally
        </h2>

        <p className="text-muted-foreground max-w-lg mx-auto mb-10">
          Download Dicta and experience AI transcription that respects your privacy.
          No subscriptions, no limits, no cloud required.
        </p>

        {/* CTA Buttons */}
        <div className="flex flex-col sm:flex-row gap-4 items-center justify-center">
          <a
            href="/download"
            className="group bg-foreground text-background font-medium px-8 py-4 rounded-xl text-base flex items-center gap-4 hover:bg-white/90 transition-all w-full sm:w-auto justify-center"
          >
            <span>Download for Mac</span>
            <svg className="w-4 h-4 transition-transform group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </a>

          <a
            href="https://github.com/nitintf/dicta"
            target="_blank"
            rel="noopener noreferrer"
            className="group bg-white/5 border border-white/10 text-foreground font-medium px-6 py-4 rounded-xl text-base flex items-center gap-3 hover:bg-white/10 hover:border-white/20 transition-all w-full sm:w-auto"
          >
            <svg className="w-4 h-4 opacity-60" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
            </svg>
            <span>View on GitHub</span>
          </a>
        </div>
      </div>
    </section>
  )
}
