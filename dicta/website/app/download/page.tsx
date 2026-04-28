'use client'

import { useEffect, useState } from 'react'
import Navbar from '@/components/Navbar'
import Footer from '@/components/sections/Footer'

interface ReleaseAsset {
  name: string
  browser_download_url: string
  size: number
}

interface Release {
  tag_name: string
  name: string
  published_at: string
  assets: ReleaseAsset[]
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

export default function DownloadPage() {
  const [release, setRelease] = useState<Release | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchLatestRelease() {
      try {
        const response = await fetch(
          'https://api.github.com/repos/nitintf/dicta/releases/latest'
        )
        if (!response.ok) {
          throw new Error('Failed to fetch release')
        }
        const data = await response.json()
        setRelease(data)
      } catch (err) {
        setError('Unable to fetch latest release. Please try again later.')
        console.error(err)
      } finally {
        setLoading(false)
      }
    }

    fetchLatestRelease()
  }, [])

  const getAssetByArch = (arch: 'aarch64' | 'x86_64'): ReleaseAsset | undefined => {
    return release?.assets.find(
      (asset) => asset.name.includes(arch) && asset.name.endsWith('.dmg')
    )
  }

  const applesilconAsset = getAssetByArch('aarch64')
  const intelAsset = getAssetByArch('x86_64')

  return (
    <div className="min-h-screen bg-black text-foreground">
      <div className="main-container">
        <Navbar />
        <main>
          <section className="section-bordered section-padding">
            <div className="max-w-3xl mx-auto">
              {/* Header */}
              <div className="text-center mb-16">
                <span className="text-primary text-sm font-medium mb-4 block">
                  Download
                </span>
                <h1 className="text-display-xl mb-4">
                  Get Dicta for <span className="text-primary">Mac</span>
                </h1>
                <p className="text-muted-foreground text-lg">
                  Transform your voice into polished text with AI that runs entirely on your Mac.
                </p>
              </div>

              {/* Loading State */}
              {loading && (
                <div className="flex justify-center py-12">
                  <div className="flex items-center gap-3 text-muted-foreground">
                    <svg
                      className="w-5 h-5 animate-spin"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      />
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    <span>Loading latest release...</span>
                  </div>
                </div>
              )}

              {/* Error State */}
              {error && (
                <div className="text-center py-12">
                  <p className="text-red-400 mb-4">{error}</p>
                  <a
                    href="https://github.com/nitintf/dicta/releases/latest"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary hover:underline"
                  >
                    View releases on GitHub →
                  </a>
                </div>
              )}

              {/* Download Cards */}
              {!loading && !error && release && (
                <>
                  {/* Version Info */}
                  <div className="text-center mb-10">
                    <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-border bg-white/[0.02]">
                      <span className="text-sm text-muted-foreground">
                        Latest Version:
                      </span>
                      <span className="text-sm font-medium text-primary">
                        {release.tag_name}
                      </span>
                      <span className="text-sm text-muted-foreground">
                        · {formatDate(release.published_at)}
                      </span>
                    </div>
                  </div>

                  {/* Download Options */}
                  <div className="grid md:grid-cols-2 gap-6 mb-12">
                    {/* Apple Silicon */}
                    <div className="p-6 rounded-2xl border border-border bg-white/[0.02] hover:bg-white/[0.04] transition-colors flex flex-col h-full">
                      <div className="flex items-start gap-4 flex-1">
                        <div className="p-3 rounded-xl bg-primary/10">
                          <svg
                            className="w-8 h-8 text-primary"
                            fill="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                          </svg>
                        </div>
                        <div className="flex-1">
                          <h3 className="text-lg font-medium mb-1">Apple Silicon</h3>
                          <p className="text-sm text-muted-foreground">
                            For M1, M2, M3, and M4 Macs
                          </p>
                        </div>
                      </div>

                      <div className="mt-6">
                        {applesilconAsset ? (
                          <a
                            href={applesilconAsset.browser_download_url}
                            className="group w-full bg-foreground text-background font-medium px-6 py-4 rounded-xl flex items-center justify-center gap-3 hover:bg-white/90 transition-all"
                          >
                            <svg
                              className="w-5 h-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                              />
                            </svg>
                            <span>Download</span>
                            <span className="text-sm opacity-60">
                              ({formatBytes(applesilconAsset.size)})
                            </span>
                          </a>
                        ) : (
                          <div className="w-full px-6 py-4 rounded-xl bg-white/5 text-center text-muted-foreground text-sm">
                            Not available
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Intel */}
                    <div className="p-6 rounded-2xl border border-border bg-white/[0.02] hover:bg-white/[0.04] transition-colors flex flex-col h-full">
                      <div className="flex items-start gap-4 flex-1">
                        <div className="p-3 rounded-xl bg-blue-500/10">
                          <svg
                            className="w-8 h-8 text-blue-400"
                            fill="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                          </svg>
                        </div>
                        <div className="flex-1">
                          <h3 className="text-lg font-medium mb-1">Intel</h3>
                          <p className="text-sm text-muted-foreground">
                            For Intel-based Macs (2020 and earlier)
                          </p>
                        </div>
                      </div>

                      <div className="mt-6">
                        {intelAsset ? (
                          <a
                            href={intelAsset.browser_download_url}
                            className="group w-full bg-white/5 border border-white/10 text-foreground font-medium px-6 py-4 rounded-xl flex items-center justify-center gap-3 hover:bg-white/10 hover:border-white/20 transition-all"
                          >
                            <svg
                              className="w-5 h-5"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                              />
                            </svg>
                            <span>Download</span>
                            <span className="text-sm opacity-60">
                              ({formatBytes(intelAsset.size)})
                            </span>
                          </a>
                        ) : (
                          <div className="w-full px-6 py-4 rounded-xl bg-white/5 text-center text-muted-foreground text-sm">
                            Not available
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Which Mac do I have? */}
                  <div className="text-center mb-12">
                    <p className="text-sm text-muted-foreground">
                      Not sure which Mac you have?{' '}
                      <button
                        onClick={() => {
                          // Show instructions
                          const el = document.getElementById('mac-check')
                          if (el) el.classList.toggle('hidden')
                        }}
                        className="text-primary hover:underline"
                      >
                        Check here
                      </button>
                    </p>
                    <div
                      id="mac-check"
                      className="hidden mt-4 p-4 rounded-lg border border-border bg-white/[0.02] text-left max-w-md mx-auto"
                    >
                      <p className="text-sm text-muted-foreground mb-2">
                        Click the Apple menu  → <strong>About This Mac</strong>
                      </p>
                      <ul className="text-sm text-muted-foreground space-y-1">
                        <li>
                          • If it says <strong>Apple M1/M2/M3/M4</strong> → Choose{' '}
                          <span className="text-primary">Apple Silicon</span>
                        </li>
                        <li>
                          • If it says <strong>Intel</strong> → Choose{' '}
                          <span className="text-blue-400">Intel</span>
                        </li>
                      </ul>
                    </div>
                  </div>
                </>
              )}

              {/* Requirements */}
              <div className="p-6 rounded-xl border border-border bg-white/[0.02]">
                <h3 className="font-medium mb-4">System Requirements</h3>
                <ul className="space-y-2 text-sm text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <svg
                      className="w-4 h-4 text-primary"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                    macOS 13 (Ventura) or later
                  </li>
                  <li className="flex items-center gap-2">
                    <svg
                      className="w-4 h-4 text-primary"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                    8 GB RAM minimum (16 GB recommended for larger models)
                  </li>
                  <li className="flex items-center gap-2">
                    <svg
                      className="w-4 h-4 text-primary"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                    2 GB free disk space for app and models
                  </li>
                </ul>
              </div>

              {/* Alternative Links */}
              <div className="mt-8 flex flex-wrap justify-center gap-4 text-sm">
                <a
                  href="https://github.com/nitintf/dicta/releases"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-muted-foreground hover:text-foreground transition-colors flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                  </svg>
                  All Releases
                </a>
                <span className="text-border">•</span>
                <a
                  href="/changelog"
                  className="text-muted-foreground hover:text-foreground transition-colors"
                >
                  Changelog
                </a>
                <span className="text-border">•</span>
                <a
                  href="https://github.com/nitintf/dicta"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-muted-foreground hover:text-foreground transition-colors"
                >
                  Source Code
                </a>
              </div>
            </div>
          </section>
        </main>
        <Footer />
      </div>
    </div>
  )
}
