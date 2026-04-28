'use client'

export default function VideoSection() {
  const stats = [
    { value: '<100ms', label: 'Latency' },
    { value: '50+', label: 'Languages' },
    { value: '100%', label: 'Private' },
    { value: 'Free', label: 'Forever' },
  ]

  return (
    <section id="demo" className="section-bordered">
      {/* Header */}
      <div className="section-padding-sm text-center border-b border-border">
        <span className="text-primary text-sm font-medium mb-4 block">
          See it in action
        </span>
        <h2 className="text-display-lg mb-4">
          Watch Dicta in action
        </h2>
        <p className="text-muted-foreground max-w-xl mx-auto">
          See how fast and accurate local transcription can be.
          No internet required, no data leaves your Mac.
        </p>
      </div>

      {/* Video container */}
      <div className="section-padding border-b border-border">
        <div className="relative aspect-video max-w-4xl mx-auto rounded-2xl overflow-hidden border border-border bg-muted/20">
          {/* Placeholder for video */}
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center space-y-4">
              {/* Play button */}
              <button className="group w-20 h-20 rounded-full bg-foreground/10 border border-white/20 flex items-center justify-center hover:bg-foreground/20 hover:scale-105 transition-all">
                <svg className="w-8 h-8 text-foreground ml-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
              </button>
              <p className="text-sm text-muted-foreground">Watch demo video</p>
            </div>
          </div>

          {/* Decorative elements */}
          <div className="absolute top-4 left-4 flex gap-2">
            <div className="w-3 h-3 rounded-full bg-red-500/60" />
            <div className="w-3 h-3 rounded-full bg-yellow-500/60" />
            <div className="w-3 h-3 rounded-full bg-green-500/60" />
          </div>

          {/* Waveform decoration */}
          <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex items-end gap-1">
            {[...Array(20)].map((_, i) => (
              <div
                key={i}
                className="w-1 bg-primary/40 rounded-full"
                style={{
                  height: `${12 + Math.sin(i * 0.5) * 20 + Math.random() * 10}px`,
                }}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Stats - 4 boxes divided by borders */}
      <div className="grid grid-cols-2 md:grid-cols-4">
        {stats.map((stat, index) => (
          <div
            key={index}
            className={`py-8 px-6 text-center ${
              index < stats.length - 1 ? 'border-r border-border' : ''
            } ${index < 2 ? 'md:border-r' : ''} ${index === 2 ? 'md:border-r' : ''}`}
          >
            <div className="text-2xl font-medium text-foreground">{stat.value}</div>
            <div className="text-sm text-muted-foreground">{stat.label}</div>
          </div>
        ))}
      </div>
    </section>
  )
}
