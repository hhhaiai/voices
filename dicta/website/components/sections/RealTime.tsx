'use client'

import { useEffect, useRef } from 'react'

const features = [
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    title: 'Fast responses for text and audio.',
    description: null,
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M8.288 15.038a5.25 5.25 0 017.424 0M5.106 11.856c3.807-3.808 9.98-3.808 13.788 0M1.924 8.674c5.565-5.565 14.587-5.565 20.152 0M12.53 18.22l-.53.53-.53-.53a.75.75 0 011.06 0z" />
      </svg>
    ),
    title: 'Offline continuity.',
    description: 'No network, no break.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
      </svg>
    ),
    title: 'Consistent latency.',
    description: 'Even under load.',
  },
]

// Animated vertical lines - full height, colorful
function AnimatedVerticalLines() {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const colors = [
      { base: 'rgba(74, 222, 128, 0.08)', bright: 'rgba(74, 222, 128, 0.25)' },
      { base: 'rgba(251, 146, 60, 0.06)', bright: 'rgba(251, 146, 60, 0.2)' },
      { base: 'rgba(96, 165, 250, 0.06)', bright: 'rgba(96, 165, 250, 0.2)' },
      { base: 'rgba(167, 139, 250, 0.06)', bright: 'rgba(167, 139, 250, 0.2)' },
      { base: 'rgba(255, 255, 255, 0.03)', bright: 'rgba(255, 255, 255, 0.1)' },
    ]

    const createLine = () => {
      const line = document.createElement('div')
      const color = colors[Math.floor(Math.random() * colors.length)]
      const goingUp = Math.random() > 0.5

      line.style.position = 'absolute'
      line.style.width = '1px'
      line.style.left = `${5 + Math.random() * 90}%`
      line.style.height = `${25 + Math.random() * 35}%`

      line.style.background = `linear-gradient(to bottom, transparent 0%, ${color.base} 20%, ${color.bright} 50%, ${color.base} 80%, transparent 100%)`

      const duration = 3 + Math.random() * 3
      const delay = Math.random() * 1.5

      line.style.animation = `${goingUp ? 'v-line-rise' : 'v-line-fall'} ${duration}s linear ${delay}s`
      line.style.opacity = '0'

      container.appendChild(line)

      setTimeout(() => {
        line.remove()
      }, (duration + delay) * 1000 + 100)
    }

    for (let i = 0; i < 12; i++) {
      setTimeout(createLine, i * 150)
    }

    const interval = setInterval(createLine, 350)

    return () => {
      clearInterval(interval)
    }
  }, [])

  return <div ref={containerRef} className="absolute inset-0 overflow-hidden pointer-events-none" />
}

export default function RealTime() {
  return (
    <section className="section-grey" id="realtime">
      <div className="split-section">
        {/* Left side - Content */}
        <div className="space-y-6">
          <h2 className="text-display-md">
            Build real-time workflows
            <br />
            <span className="text-primary">with on-device AI</span>
          </h2>

          <p className="text-muted-foreground">
            Users don&apos;t care where your model runs.{' '}
            <span className="text-foreground">They care how it feels.</span>
          </p>

          {/* Features */}
          <div className="space-y-4 pt-4">
            {features.map((feature, index) => (
              <div key={index} className="flex items-start gap-3">
                <span className="text-muted-foreground mt-0.5">{feature.icon}</span>
                <div>
                  <span className="font-medium">{feature.title}</span>
                  {feature.description && (
                    <span className="text-muted-foreground"> {feature.description}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right side - Animated vertical lines */}
        <div className="relative min-h-[350px] hidden md:block">
          <AnimatedVerticalLines />
        </div>
      </div>
    </section>
  )
}
