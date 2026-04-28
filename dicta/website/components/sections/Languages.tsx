'use client'

const features = [
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
      </svg>
    ),
    title: 'Auto-detect',
    description: 'Whisper identifies the spoken language automatically.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" />
      </svg>
    ),
    title: 'Translate to English',
    description: 'Speak any language, get English output.',
  },
  {
    icon: (
      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418" />
      </svg>
    ),
    title: '100+ Languages',
    description: 'Multilingual models support global voices.',
  },
]

const languages = [
  'English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese',
  'Chinese', 'Japanese', 'Korean', 'Hindi', 'Arabic', 'Russian',
]

export default function Languages() {
  return (
    <section className="section-grey" id="languages">
      <div className="split-section">
        {/* Left side - Content */}
        <div className="space-y-6">
          <span className="badge">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364C11.176 10.658 7.69 15.08 3 17.502m9.334-12.138c.896.061 1.785.147 2.666.257m-4.589 8.495a18.023 18.023 0 01-3.827-5.802" />
            </svg>
            <span>Multilingual</span>
          </span>

          <h2 className="text-display-md">
            Speak your language
          </h2>

          <p className="text-muted-foreground">
            Dicta understands you, no matter what language you speak.
          </p>

          {/* Features */}
          <div className="space-y-4 pt-2">
            {features.map((feature, index) => (
              <div key={index} className="flex items-start gap-3">
                <span className="text-primary mt-0.5">{feature.icon}</span>
                <div>
                  <span className="font-medium">{feature.title}</span>
                  <span className="text-muted-foreground"> — {feature.description}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right side - Language pills */}
        <div className="flex flex-wrap gap-2 content-center justify-center md:justify-start">
          {languages.map((lang, index) => (
            <span
              key={index}
              className="px-3 py-1.5 text-sm rounded-full border border-border bg-background/50 text-muted-foreground hover:text-foreground hover:border-primary/50 transition-colors"
            >
              {lang}
            </span>
          ))}
          <span className="px-3 py-1.5 text-sm rounded-full border border-primary/30 bg-primary/10 text-primary font-medium">
            +90 more
          </span>
        </div>
      </div>
    </section>
  )
}
