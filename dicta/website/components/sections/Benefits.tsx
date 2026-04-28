'use client'

import { useEffect, useRef } from 'react'

const benefits = [
  {
    icon: (
      <svg className="benefit-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    title: 'Instant, private transcription.',
    description: 'Near-zero latency and full data privacy.',
  },
  {
    icon: (
      <svg className="benefit-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M4.26 10.147a60.436 60.436 0 00-.491 6.347A48.627 48.627 0 0112 20.904a48.627 48.627 0 018.232-4.41 60.46 60.46 0 00-.491-6.347m-15.482 0a50.57 50.57 0 00-2.658-.813A59.905 59.905 0 0112 3.493a59.902 59.902 0 0110.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.697 50.697 0 0112 13.489a50.702 50.702 0 017.74-3.342M6.75 15a.75.75 0 100-1.5.75.75 0 000 1.5zm0 0v-3.675A55.378 55.378 0 0112 8.443m-7.007 11.55A5.981 5.981 0 006.75 15.75v-1.5" />
      </svg>
    ),
    title: 'Custom vocabulary learning.',
    description: 'Train on your names, terms, and technical jargon.',
  },
  {
    icon: (
      <svg className="benefit-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z" />
      </svg>
    ),
    title: 'Global keyboard shortcuts.',
    description: 'System-wide hotkeys that work in any app.',
  },
  {
    icon: (
      <svg className="benefit-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    ),
    title: 'Voice-activated snippets.',
    description: 'Say trigger words, expand to full text blocks.',
  },
  {
    icon: (
      <svg className="benefit-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364C11.176 10.658 7.69 15.08 3 17.502m9.334-12.138c.896.061 1.785.147 2.666.257m-4.589 8.495a18.023 18.023 0 01-3.827-5.802" />
      </svg>
    ),
    title: '50+ languages supported.',
    description: 'Transcribe across languages with Whisper AI.',
  },
]

// Animated vertical lines - full height, colorful
function AnimatedVerticalLines() {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const colors = [
      { base: 'rgba(74, 222, 128, 0.08)', bright: 'rgba(74, 222, 128, 0.25)' }, // Green
      { base: 'rgba(251, 146, 60, 0.06)', bright: 'rgba(251, 146, 60, 0.2)' }, // Orange
      { base: 'rgba(96, 165, 250, 0.06)', bright: 'rgba(96, 165, 250, 0.2)' }, // Blue
      { base: 'rgba(167, 139, 250, 0.06)', bright: 'rgba(167, 139, 250, 0.2)' }, // Purple
      { base: 'rgba(255, 255, 255, 0.03)', bright: 'rgba(255, 255, 255, 0.1)' }, // White dim
    ]

    const createLine = () => {
      const line = document.createElement('div')
      const color = colors[Math.floor(Math.random() * colors.length)]
      const goingUp = Math.random() > 0.5

      line.style.position = 'absolute'
      line.style.width = '1px'
      line.style.left = `${5 + Math.random() * 90}%`
      line.style.height = `${30 + Math.random() * 40}%`

      line.style.background = `linear-gradient(to bottom, transparent 0%, ${color.base} 20%, ${color.bright} 50%, ${color.base} 80%, transparent 100%)`

      const duration = 4 + Math.random() * 4
      const delay = Math.random() * 2

      line.style.animation = `${goingUp ? 'v-line-rise' : 'v-line-fall'} ${duration}s linear ${delay}s`
      line.style.opacity = '0'

      container.appendChild(line)

      setTimeout(() => {
        line.remove()
      }, (duration + delay) * 1000 + 100)
    }

    for (let i = 0; i < 10; i++) {
      setTimeout(createLine, i * 200)
    }

    const interval = setInterval(createLine, 400)

    return () => {
      clearInterval(interval)
    }
  }, [])

  return <div ref={containerRef} className="absolute inset-0 overflow-hidden pointer-events-none" />
}

export default function Benefits() {
  return (
    <section className="section-grey" id="benefits">
      <div className="split-section">
        {/* Left side - Content */}
        <div className="space-y-6">
          <h2 className="text-display-md">
            Key benefits
          </h2>

          {/* Benefits list */}
          <div className="space-y-1">
            {benefits.map((benefit, index) => (
              <div key={index} className="benefit-item">
                {benefit.icon}
                <div>
                  <h3 className="text-foreground font-medium">
                    {benefit.title}
                  </h3>
                  <p className="text-muted-foreground text-sm">
                    {benefit.description}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right side - Animated vertical lines - full height */}
        <div className="relative min-h-[400px] hidden md:block">
          <AnimatedVerticalLines />
        </div>
      </div>
    </section>
  )
}
