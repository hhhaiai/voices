import Navbar from '@/components/Navbar'
import Footer from '@/components/sections/Footer'

export default function PrivacyPolicyPage() {
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
                  Legal
                </span>
                <h1 className="text-display-lg mb-4">Privacy Policy</h1>
                <p className="text-muted-foreground">
                  Last updated: February 15, 2026
                </p>
              </div>

              {/* Privacy Highlights */}
              <div className="grid sm:grid-cols-3 gap-4 mb-12">
                <div className="p-4 rounded-lg border border-primary/20 bg-primary/5">
                  <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center mb-3">
                    <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                    </svg>
                  </div>
                  <h3 className="font-medium text-sm mb-1">100% Local</h3>
                  <p className="text-xs text-muted-foreground">Processing happens on your device</p>
                </div>
                <div className="p-4 rounded-lg border border-primary/20 bg-primary/5">
                  <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center mb-3">
                    <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                    </svg>
                  </div>
                  <h3 className="font-medium text-sm mb-1">No Tracking</h3>
                  <p className="text-xs text-muted-foreground">Zero analytics or telemetry</p>
                </div>
                <div className="p-4 rounded-lg border border-primary/20 bg-primary/5">
                  <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center mb-3">
                    <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  </div>
                  <h3 className="font-medium text-sm mb-1">Open Source</h3>
                  <p className="text-xs text-muted-foreground">Fully auditable code</p>
                </div>
              </div>

              {/* Content */}
              <div className="prose prose-invert max-w-none">
                <div className="space-y-8">
                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">1.</span> Introduction
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      Dicta is an open-source voice-to-text application for macOS. This Privacy Policy explains how we handle your information. <strong className="text-foreground">The short version: we don&apos;t collect any data.</strong> All processing happens locally on your device.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">2.</span> Information We Collect
                    </h2>
                    <div className="space-y-4 text-muted-foreground leading-relaxed">
                      <div className="p-4 rounded-lg bg-primary/5 border border-primary/10">
                        <h3 className="font-medium text-foreground mb-2">Voice Recordings</h3>
                        <p>When using local models (the default), your voice recordings are processed entirely on your device. We never collect, transmit, or store these recordings.</p>
                      </div>
                      <div className="p-4 rounded-lg bg-white/[0.02] border border-border">
                        <h3 className="font-medium text-foreground mb-2">Transcriptions</h3>
                        <p>Transcribed text is stored locally on your device. We do not collect, transmit, or access your transcriptions.</p>
                      </div>
                      <div className="p-4 rounded-lg bg-white/[0.02] border border-border">
                        <h3 className="font-medium text-foreground mb-2">Application Data</h3>
                        <p>Settings, preferences, and custom vocabulary are stored locally and never transmitted.</p>
                      </div>
                    </div>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">3.</span> Third-Party Services
                    </h2>
                    <p className="text-muted-foreground leading-relaxed mb-4">
                      If you choose to use cloud-based transcription services (optional), your voice recordings may be transmitted to third-party providers. Review their privacy policies:
                    </p>
                    <ul className="space-y-2">
                      {[
                        { name: 'OpenAI', url: 'https://openai.com/privacy' },
                        { name: 'Google Cloud', url: 'https://cloud.google.com/privacy' },
                        { name: 'Deepgram', url: 'https://deepgram.com/privacy' },
                        { name: 'AssemblyAI', url: 'https://www.assemblyai.com/privacy' },
                      ].map((service) => (
                        <li key={service.name}>
                          <a
                            href={service.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-primary hover:underline inline-flex items-center gap-1"
                          >
                            {service.name}
                            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                              <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                          </a>
                        </li>
                      ))}
                    </ul>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">4.</span> Your Rights
                    </h2>
                    <p className="text-muted-foreground leading-relaxed mb-4">
                      Since all data is stored locally, you have full control:
                    </p>
                    <ul className="space-y-2 text-muted-foreground">
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Delete transcriptions and recordings at any time
                      </li>
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Use local-only processing to avoid any cloud transmission
                      </li>
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Export or delete all application data
                      </li>
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Uninstall to remove all local data
                      </li>
                    </ul>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">5.</span> Open Source
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      Dicta is open-source under the MIT License. You can review our entire codebase on{' '}
                      <a
                        href="https://github.com/nitintf/dicta"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        GitHub
                      </a>
                      {' '}to verify our privacy claims.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">6.</span> Contact
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      Questions about this policy? Reach out via{' '}
                      <a
                        href="https://github.com/nitintf/dicta/discussions"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        GitHub Discussions
                      </a>
                      .
                    </p>
                  </section>
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
