'use client'

const features = [
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    ),
    text: 'One-click install. No dependencies.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
      </svg>
    ),
    text: '100% local processing. Your data stays private.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z" />
      </svg>
    ),
    text: 'Global shortcuts work in any app.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    text: 'Start transcribing in under a minute.',
  },
]

const steps = [
  {
    number: 1,
    title: 'Download Dicta',
    description: 'Get the latest version for macOS',
    content: (
      <div className="code-block flex items-center justify-between">
        <span className="text-muted-foreground">dicta-v1.0.0.dmg</span>
        <svg className="w-4 h-4 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
        </svg>
      </div>
    ),
  },
  {
    number: 2,
    title: 'Grant Permissions',
    description: 'Allow microphone and accessibility access',
    content: (
      <div className="flex gap-3">
        <span className="px-3 py-2 rounded-md bg-muted/30 border border-border text-sm flex items-center gap-2">
          <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
          </svg>
          Microphone
        </span>
        <span className="px-3 py-2 rounded-md bg-muted/30 border border-border text-sm flex items-center gap-2">
          <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
          </svg>
          Accessibility
        </span>
      </div>
    ),
  },
  {
    number: 3,
    title: 'Set your shortcut',
    description: 'Default: Option + Space',
    content: (
      <div className="code-block flex items-center gap-3">
        <span className="px-2 py-1 rounded bg-muted text-sm font-mono">Option</span>
        <span className="text-muted-foreground">+</span>
        <span className="px-2 py-1 rounded bg-muted text-sm font-mono">Space</span>
        <span className="text-muted-foreground ml-auto">Start recording</span>
      </div>
    ),
  },
  {
    number: 4,
    title: 'Start speaking',
    description: 'Your voice, instantly transcribed',
    content: (
      <div className="code-block text-sm text-muted-foreground">
        Press shortcut &rarr; Speak &rarr; Release &rarr; Text appears
      </div>
    ),
  },
]

export default function GetStarted() {
  return (
    <section className="section-bordered">
      <div className="split-section">
        {/* Left side - Info */}
        <div className="space-y-8">
          <div className="space-y-4">
            <span className="text-primary text-sm font-medium">Free Forever</span>
            <h2 className="text-display-md">
              Get started with Dicta
            </h2>
          </div>

          {/* Features list */}
          <div className="space-y-4">
            {features.map((feature, index) => (
              <div key={index} className="flex items-center gap-3">
                <span className="text-muted-foreground">{feature.icon}</span>
                <span className="text-sm">{feature.text}</span>
              </div>
            ))}
          </div>

          {/* CTAs */}
          <div className="flex gap-3 pt-4">
            <a
              href="/download"
              className="group bg-foreground text-background font-medium px-6 py-3 rounded-lg text-sm flex items-center gap-3 hover:bg-white/90 transition-all"
            >
              <span>Download</span>
              <svg className="w-4 h-4 transition-transform group-hover:translate-x-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </a>
            <a
              href="https://github.com/nitintf/dicta"
              target="_blank"
              rel="noopener noreferrer"
              className="group bg-white/5 border border-white/10 text-foreground font-medium px-6 py-3 rounded-lg text-sm flex items-center gap-3 hover:bg-white/10 hover:border-white/20 transition-all"
            >
              <span>View source</span>
              <svg className="w-4 h-4 opacity-60" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
              </svg>
            </a>
          </div>
        </div>

        {/* Right side - Steps */}
        <div className="space-y-6">
          {steps.map((step, index) => (
            <div key={index} className="space-y-3">
              <div className="flex items-center gap-3">
                <span className="step-number">{step.number}</span>
                <div>
                  <h3 className="font-medium">{step.title}</h3>
                  <p className="text-sm text-muted-foreground">{step.description}</p>
                </div>
              </div>
              {step.content}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
