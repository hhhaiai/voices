import Navbar from '@/components/Navbar'
import Footer from '@/components/sections/Footer'

interface Release {
  tagName: string
  name: string
  body: string
  publishedAt: string
  assets: Array<{
    name: string
    downloadCount: number
    size: number
    url: string
  }>
}

async function getReleases(): Promise<Release[]> {
  try {
    const response = await fetch(
      'https://api.github.com/repos/nitintf/dicta/releases',
      {
        headers: {
          Accept: 'application/vnd.github.v3+json',
        },
        next: { revalidate: 3600 }, // Cache for 1 hour
      }
    )

    if (!response.ok) {
      throw new Error('Failed to fetch releases')
    }

    const data = await response.json()
    return data.map((release: Record<string, unknown>) => ({
      tagName: release.tag_name,
      name: release.name,
      body: release.body || '',
      publishedAt: release.published_at,
      assets:
        (release.assets as Array<Record<string, unknown>>)
          ?.filter(
            (a: Record<string, unknown>) =>
              (a.name as string).endsWith('.dmg') ||
              (a.name as string).endsWith('.app.tar.gz')
          )
          .map((a: Record<string, unknown>) => ({
            name: a.name,
            downloadCount: a.download_count,
            size: a.size,
            url: a.browser_download_url,
          })) || [],
    }))
  } catch {
    return []
  }
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

function formatSize(bytes: number): string {
  const mb = bytes / (1024 * 1024)
  return `${mb.toFixed(1)} MB`
}

function getVersionChanges(tagName: string): string[] {
  // Based on actual development progress
  const changes: Record<string, string[]> = {
    'v0.0.9': [
      'Added auto-detect language - Dicta now identifies what language you\'re speaking automatically',
      'New translate to English option - speak in any language and get English text output',
      'Support for 100+ languages with multilingual Whisper models',
      'Quick language switcher in the system tray menu',
      'Added helpful tooltips throughout settings to explain features',
      'Improved language compatibility warnings when using English-only models',
    ],
    'v0.0.8': [
      'Performance improvements for faster transcription processing',
      'Fixed audio recording reliability issues',
      'Improved model loading and memory management',
      'Minor UI polish and bug fixes',
    ],
    'v0.0.7': [
      'New search feature - quickly find any transcription by keyword',
      'Filter transcriptions by date, model, or language',
      'Search matches are now highlighted in transcription text',
      'Improved transcription history browsing experience',
    ],
    'v0.0.3': [
      'Improved accessibility step with enhanced permission handling',
      'Streamlined logging across the application',
      'Bug fixes and stability improvements',
    ],
    'v0.0.2': [
      'Fixed pill window positioning on multiple monitors',
      'Improved waveform sensitivity for better audio visualization',
      'Added microphone selection sync with tray menu',
    ],
    'v0.0.1': [
      'Initial release of Dicta',
      'Local Whisper model support for offline transcription',
      'Global keyboard shortcuts for quick access',
      'System tray integration for macOS',
      'Support for 50+ languages',
      'Privacy-first design - all processing on device',
    ],
  }
  return changes[tagName] || ['Various improvements and bug fixes']
}

export default async function ChangelogPage() {
  const releases = await getReleases()

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
                  Changelog
                </span>
                <h1 className="text-display-lg mb-4">
                  What&apos;s new in Dicta
                </h1>
                <p className="text-muted-foreground">
                  Track all updates, improvements, and bug fixes. Subscribe to{' '}
                  <a
                    href="https://github.com/nitintf/dicta/releases.atom"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:underline"
                  >
                    releases via RSS
                  </a>{' '}
                  to stay updated.
                </p>
              </div>

              {/* Releases */}
              {releases.length > 0 ? (
                <div className="space-y-12">
                  {releases.map((release, index) => (
                    <article
                      key={release.tagName}
                      className="relative pl-8 border-l-2 border-border"
                    >
                      {/* Version indicator */}
                      <div className="absolute -left-[9px] top-0 w-4 h-4 rounded-full bg-black border-2 border-primary" />

                      {/* Header */}
                      <div className="flex flex-wrap items-center gap-3 mb-4">
                        <h2 className="text-xl font-semibold">
                          {release.tagName}
                        </h2>
                        {index === 0 && (
                          <span className="px-2 py-0.5 text-xs font-medium bg-primary/20 text-primary rounded">
                            Latest
                          </span>
                        )}
                        <span className="text-sm text-muted-foreground">
                          {formatDate(release.publishedAt)}
                        </span>
                      </div>

                      {/* Changes */}
                      <div className="mb-6">
                        <h3 className="text-sm font-medium text-muted-foreground mb-3">
                          Changes
                        </h3>
                        <ul className="space-y-2">
                          {getVersionChanges(release.tagName).map(
                            (change, i) => (
                              <li key={i} className="flex items-start gap-2">
                                <svg
                                  className="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                                  fill="none"
                                  viewBox="0 0 24 24"
                                  stroke="currentColor"
                                  strokeWidth={2}
                                >
                                  <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    d="M5 13l4 4L19 7"
                                  />
                                </svg>
                                <span className="text-sm">{change}</span>
                              </li>
                            )
                          )}
                        </ul>
                      </div>

                      {/* Downloads */}
                      {release.assets.length > 0 && (
                        <div>
                          <h3 className="text-sm font-medium text-muted-foreground mb-3">
                            Downloads
                          </h3>
                          <div className="grid gap-2">
                            {release.assets
                              .filter(a => a.name.endsWith('.dmg'))
                              .map(asset => (
                                <a
                                  key={asset.name}
                                  href={asset.url}
                                  className="group flex items-center justify-between p-3 rounded-lg border border-border bg-white/[0.02] hover:bg-white/[0.05] hover:border-white/20 transition-all"
                                >
                                  <div className="flex items-center gap-3">
                                    <svg
                                      className="w-5 h-5 text-muted-foreground"
                                      fill="none"
                                      viewBox="0 0 24 24"
                                      stroke="currentColor"
                                      strokeWidth={1.5}
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                                      />
                                    </svg>
                                    <div>
                                      <span className="text-sm font-medium">
                                        {asset.name.includes('aarch64')
                                          ? 'Apple Silicon (M1/M2/M3/M4)'
                                          : 'Intel Mac'}
                                      </span>
                                      <span className="text-xs text-muted-foreground ml-2">
                                        {formatSize(asset.size)}
                                      </span>
                                    </div>
                                  </div>
                                  <svg
                                    className="w-4 h-4 text-muted-foreground group-hover:text-primary transition-colors"
                                    fill="none"
                                    viewBox="0 0 24 24"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                  >
                                    <path
                                      strokeLinecap="round"
                                      strokeLinejoin="round"
                                      d="M14 5l7 7m0 0l-7 7m7-7H3"
                                    />
                                  </svg>
                                </a>
                              ))}
                          </div>
                        </div>
                      )}

                      {/* GitHub link */}
                      <div className="mt-4 pt-4 border-t border-border">
                        <a
                          href={`https://github.com/nitintf/dicta/releases/tag/${release.tagName}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
                        >
                          <svg
                            className="w-4 h-4"
                            fill="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                          </svg>
                          View full release on GitHub
                        </a>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <div className="text-center py-12">
                  <p className="text-muted-foreground">
                    Unable to load releases. Please check{' '}
                    <a
                      href="https://github.com/nitintf/dicta/releases"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-primary hover:underline"
                    >
                      GitHub Releases
                    </a>{' '}
                    directly.
                  </p>
                </div>
              )}
            </div>
          </section>
        </main>
        <Footer />
      </div>
    </div>
  )
}
