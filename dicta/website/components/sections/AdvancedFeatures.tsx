'use client'

const features = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z" />
      </svg>
    ),
    title: 'Custom Vocabulary',
    description: 'Train Dicta on your names, technical terms, and domain-specific jargon for better accuracy.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    ),
    title: 'Voice Snippets',
    description: 'Say trigger words to instantly expand into full text blocks. Perfect for signatures and templates.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364C11.176 10.658 7.69 15.08 3 17.502m9.334-12.138c.896.061 1.785.147 2.666.257m-4.589 8.495a18.023 18.023 0 01-3.827-5.802" />
      </svg>
    ),
    title: 'Multi-Language',
    description: 'Transcribe in 50+ languages with automatic detection. Switch languages on the fly.',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z" />
      </svg>
    ),
    title: 'Global Shortcuts',
    description: 'System-wide keyboard shortcuts that work in any app. Customizable to your workflow.',
  },
]

export default function AdvancedFeatures() {
  return (
    <section id="advanced-features" className="section-bordered">
      {/* Section header */}
      <div className="section-padding-sm text-center border-b border-border">
        <span className="text-primary text-sm font-medium mb-4 block">
          Advanced capabilities
        </span>
        <h2 className="text-display-lg mb-4">
          Power features for <span className="text-primary">power users</span>
        </h2>
        <p className="text-muted-foreground max-w-xl mx-auto">
          Dicta goes beyond basic transcription. Customize it to fit your workflow perfectly.
        </p>
      </div>

      {/* Feature grid - 2x2 with borders */}
      <div className="feature-grid">
        {features.map((feature, index) => (
          <div key={index}>
            <div className="text-muted-foreground mb-6">
              {feature.icon}
            </div>
            <h3 className="text-lg font-medium text-foreground mb-3">
              {feature.title}
            </h3>
            <p className="text-muted-foreground text-sm leading-relaxed">
              {feature.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  )
}
