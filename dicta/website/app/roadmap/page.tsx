import Navbar from '@/components/Navbar'
import Footer from '@/components/sections/Footer'

interface RoadmapItem {
  title: string
  description: string
  status: 'completed' | 'in-progress' | 'planned'
  category: string
}

const roadmapItems: RoadmapItem[] = [
  // Completed
  {
    title: 'Local Whisper Models',
    description: 'Run transcription entirely on your Mac with no internet required using OpenAI Whisper.',
    status: 'completed',
    category: 'Core Features',
  },
  {
    title: 'Global Keyboard Shortcuts',
    description: 'Start transcribing from any app with customizable system-wide shortcuts.',
    status: 'completed',
    category: 'Core Features',
  },
  {
    title: 'Multi-Language Support',
    description: 'Transcribe in 50+ languages with automatic language detection.',
    status: 'completed',
    category: 'Core Features',
  },
  {
    title: 'System Tray Integration',
    description: 'Full menubar app experience with quick access to all features.',
    status: 'completed',
    category: 'Core Features',
  },
  {
    title: 'Improved Waveform Visualization',
    description: 'Smooth, water-like wave animation with better audio sensitivity.',
    status: 'completed',
    category: 'UI/UX',
  },
  {
    title: 'Multi-Monitor Support',
    description: 'Voice input window appears correctly on all connected displays.',
    status: 'completed',
    category: 'Core Features',
  },

  // In Progress
  {
    title: 'Custom Vocabulary Training',
    description: 'Train Dicta on your names, technical terms, and domain-specific jargon for better accuracy.',
    status: 'in-progress',
    category: 'Transcription',
  },
  {
    title: 'Accessibility Improvements',
    description: 'Fixing auto-paste functionality and improving permission handling.',
    status: 'in-progress',
    category: 'Core Features',
  },
  {
    title: 'Auto-Update System',
    description: 'Check for updates automatically and install with one click.',
    status: 'in-progress',
    category: 'App Experience',
  },
  {
    title: 'Performance Optimization',
    description: 'Faster app startup and reduced memory usage.',
    status: 'in-progress',
    category: 'Performance',
  },

  // Planned
  {
    title: 'Voice-Activated Snippets',
    description: 'Say trigger words to instantly expand into full text blocks. Perfect for signatures and templates.',
    status: 'planned',
    category: 'Productivity',
  },
  {
    title: 'Real-time Streaming Transcription',
    description: 'See your words appear as you speak with minimal latency.',
    status: 'planned',
    category: 'Transcription',
  },
  {
    title: 'Audio File Transcription',
    description: 'Drag and drop audio files to transcribe them locally.',
    status: 'planned',
    category: 'Transcription',
  },
  {
    title: 'Transcription History',
    description: 'View and search past transcriptions with full text history.',
    status: 'planned',
    category: 'Productivity',
  },
  {
    title: 'Export & Import Settings',
    description: 'Backup your settings and restore them on a new device.',
    status: 'planned',
    category: 'App Experience',
  },
  {
    title: 'Data Retention Settings',
    description: 'Automatically clean up old transcriptions and recordings based on your preferences.',
    status: 'planned',
    category: 'Privacy',
  },
  {
    title: 'Recording Feedback Sounds',
    description: 'Audio feedback when recording starts and stops.',
    status: 'planned',
    category: 'UI/UX',
  },
  {
    title: 'iOS Companion App',
    description: 'Sync your settings and snippets across devices.',
    status: 'planned',
    category: 'Platform',
  },
]

const statusConfig = {
  completed: {
    label: 'Completed',
    color: 'bg-primary',
    textColor: 'text-primary',
    bgLight: 'bg-primary/10',
  },
  'in-progress': {
    label: 'In Progress',
    color: 'bg-yellow-500',
    textColor: 'text-yellow-500',
    bgLight: 'bg-yellow-500/10',
  },
  planned: {
    label: 'Planned',
    color: 'bg-blue-500',
    textColor: 'text-blue-500',
    bgLight: 'bg-blue-500/10',
  },
}

export default function RoadmapPage() {
  const completed = roadmapItems.filter((item) => item.status === 'completed')
  const inProgress = roadmapItems.filter((item) => item.status === 'in-progress')
  const planned = roadmapItems.filter((item) => item.status === 'planned')

  return (
    <div className="min-h-screen bg-black text-foreground">
      <div className="main-container">
        <Navbar />
        <main>
          <section className="section-bordered section-padding">
            <div className="max-w-3xl mx-auto">
              {/* Header */}
              <div className="mb-12">
                <span className="text-primary text-sm font-medium mb-4 block">
                  Roadmap
                </span>
                <h1 className="text-display-lg mb-4">Building the future of voice input</h1>
                <p className="text-muted-foreground">
                  See what we&apos;re working on and what&apos;s coming next. Have a feature
                  request?{' '}
                  <a
                    href="https://github.com/nitintf/dicta/discussions/categories/ideas"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:underline"
                  >
                    Share it on GitHub
                  </a>
                  .
                </p>
              </div>

              {/* Status Legend */}
              <div className="flex flex-wrap gap-4 mb-10 p-4 rounded-lg border border-border bg-white/[0.02]">
                {Object.entries(statusConfig).map(([key, config]) => (
                  <div key={key} className="flex items-center gap-2">
                    <span className={`w-2.5 h-2.5 rounded-full ${config.color}`} />
                    <span className="text-sm text-muted-foreground">{config.label}</span>
                  </div>
                ))}
              </div>

              {/* In Progress */}
              <div className="mb-12">
                <h2 className="text-lg font-semibold mb-6 flex items-center gap-3">
                  <span className={`w-3 h-3 rounded-full ${statusConfig['in-progress'].color}`} />
                  Currently Working On
                </h2>
                <div className="space-y-4">
                  {inProgress.map((item, index) => (
                    <div
                      key={index}
                      className="p-5 rounded-xl border border-yellow-500/20 bg-yellow-500/5"
                    >
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <h3 className="font-medium mb-1">{item.title}</h3>
                          <p className="text-sm text-muted-foreground">{item.description}</p>
                        </div>
                        <span className="px-2 py-1 text-xs font-medium bg-yellow-500/20 text-yellow-500 rounded shrink-0">
                          {item.category}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Planned */}
              <div className="mb-12">
                <h2 className="text-lg font-semibold mb-6 flex items-center gap-3">
                  <span className={`w-3 h-3 rounded-full ${statusConfig.planned.color}`} />
                  Coming Soon
                </h2>
                <div className="space-y-3">
                  {planned.map((item, index) => (
                    <div
                      key={index}
                      className="p-4 rounded-lg border border-border bg-white/[0.02] hover:bg-white/[0.04] transition-colors"
                    >
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <h3 className="font-medium mb-1">{item.title}</h3>
                          <p className="text-sm text-muted-foreground">{item.description}</p>
                        </div>
                        <span className="px-2 py-1 text-xs font-medium bg-blue-500/10 text-blue-500 rounded shrink-0">
                          {item.category}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Completed */}
              <div>
                <h2 className="text-lg font-semibold mb-6 flex items-center gap-3">
                  <span className={`w-3 h-3 rounded-full ${statusConfig.completed.color}`} />
                  Recently Completed
                </h2>
                <div className="space-y-3">
                  {completed.map((item, index) => (
                    <div
                      key={index}
                      className="p-4 rounded-lg border border-primary/20 bg-primary/5"
                    >
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex items-start gap-3">
                          <svg
                            className="w-5 h-5 text-primary mt-0.5 shrink-0"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            strokeWidth={2}
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <div>
                            <h3 className="font-medium mb-1">{item.title}</h3>
                            <p className="text-sm text-muted-foreground">{item.description}</p>
                          </div>
                        </div>
                        <span className="px-2 py-1 text-xs font-medium bg-primary/20 text-primary rounded shrink-0">
                          {item.category}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Contribute CTA */}
              <div className="mt-12 p-6 rounded-xl border border-border bg-white/[0.02] text-center">
                <h3 className="font-medium mb-2">Want to contribute?</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Dicta is open source. Help us build the features you want to see.
                </p>
                <div className="flex justify-center gap-3">
                  <a
                    href="https://github.com/nitintf/dicta"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium bg-foreground text-background rounded-lg hover:bg-white/90 transition-colors"
                  >
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                    </svg>
                    View on GitHub
                  </a>
                  <a
                    href="https://github.com/nitintf/dicta/issues"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium border border-border rounded-lg hover:bg-white/5 transition-colors"
                  >
                    Report an Issue
                  </a>
                </div>
              </div>
            </div>
          </section>
        </main>
        <Footer />
      </div>
    </div>
  )
}
