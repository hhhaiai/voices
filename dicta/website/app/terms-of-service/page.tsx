import Navbar from '@/components/Navbar'
import Footer from '@/components/sections/Footer'

export default function TermsOfServicePage() {
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
                <h1 className="text-display-lg mb-4">Terms of Service</h1>
                <p className="text-muted-foreground">
                  Last updated: February 15, 2026
                </p>
              </div>

              {/* Key Points */}
              <div className="p-6 rounded-xl border border-primary/20 bg-primary/5 mb-12">
                <h2 className="font-semibold mb-4">Key Points</h2>
                <ul className="space-y-2 text-sm">
                  <li className="flex items-start gap-2">
                    <svg className="w-4 h-4 text-primary mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Dicta is free, open-source software under the MIT License</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="w-4 h-4 text-primary mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>You retain full ownership of your content and transcriptions</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="w-4 h-4 text-primary mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>The software is provided &quot;as is&quot; without warranties</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="w-4 h-4 text-primary mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    <span>Use responsibly and in compliance with applicable laws</span>
                  </li>
                </ul>
              </div>

              {/* Content */}
              <div className="prose prose-invert max-w-none">
                <div className="space-y-6">
                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">1.</span> Acceptance of Terms
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      By downloading, installing, or using Dicta, you agree to these Terms of Service. If you do not agree, please do not use the software.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">2.</span> License
                    </h2>
                    <p className="text-muted-foreground leading-relaxed mb-4">
                      Dicta is licensed under the MIT License. You may:
                    </p>
                    <ul className="space-y-2 text-muted-foreground mb-4">
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Use the software for personal or commercial purposes
                      </li>
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Modify, distribute, and sublicense the software
                      </li>
                      <li className="flex items-start gap-2">
                        <svg className="w-4 h-4 text-primary mt-1 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                        Include the software in other projects
                      </li>
                    </ul>
                    <p className="text-muted-foreground leading-relaxed">
                      The full license text is available in our{' '}
                      <a
                        href="https://github.com/nitintf/dicta/blob/main/LICENSE"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        GitHub repository
                      </a>
                      .
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">3.</span> Your Responsibilities
                    </h2>
                    <p className="text-muted-foreground leading-relaxed mb-4">
                      When using Dicta, you agree to:
                    </p>
                    <ul className="space-y-2 text-muted-foreground">
                      <li className="flex items-start gap-2">
                        <span className="text-primary mt-1">•</span>
                        Use the software only for lawful purposes
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-primary mt-1">•</span>
                        Obtain consent before recording others
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-primary mt-1">•</span>
                        Comply with applicable privacy and recording laws
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-primary mt-1">•</span>
                        Secure your device and any API keys
                      </li>
                      <li className="flex items-start gap-2">
                        <span className="text-primary mt-1">•</span>
                        Respect intellectual property rights
                      </li>
                    </ul>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">4.</span> Third-Party Services
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      If you use cloud-based transcription services, you are also subject to their terms. We are not responsible for third-party service availability, accuracy, fees, or data handling practices.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">5.</span> Your Content
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      You retain all rights to content you create, record, or transcribe using Dicta. We do not claim any ownership of your content.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-yellow-500/20 bg-yellow-500/5">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-yellow-500">6.</span> Disclaimer of Warranties
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      <strong className="text-foreground">DICTA IS PROVIDED &quot;AS IS&quot; WITHOUT WARRANTIES OF ANY KIND.</strong> We do not guarantee accuracy, reliability, uninterrupted operation, or fitness for any particular purpose. Transcription accuracy may vary based on audio quality, accents, and model selection.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-yellow-500/20 bg-yellow-500/5">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-yellow-500">7.</span> Limitation of Liability
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      To the maximum extent permitted by law, we are not liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of Dicta. Since Dicta is free, our total liability is limited to zero dollars ($0.00).
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">8.</span> Contributing
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      If you contribute to Dicta, you grant us and all users a perpetual, worldwide, royalty-free license to use your contributions under the MIT License. You represent that you have the right to make such contributions.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">9.</span> Changes to Terms
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      We may update these terms occasionally. Continued use of Dicta after changes constitutes acceptance of the new terms. We recommend reviewing this page periodically.
                    </p>
                  </section>

                  <section className="p-6 rounded-xl border border-border bg-white/[0.02]">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <span className="text-primary">10.</span> Contact
                    </h2>
                    <p className="text-muted-foreground leading-relaxed">
                      Questions about these terms? Contact us via{' '}
                      <a
                        href="https://github.com/nitintf/dicta/discussions"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        GitHub Discussions
                      </a>
                      {' '}or{' '}
                      <a
                        href="https://github.com/nitintf/dicta/issues"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        GitHub Issues
                      </a>
                      .
                    </p>
                  </section>
                </div>
              </div>

              {/* Acceptance Banner */}
              <div className="mt-12 p-6 rounded-xl border border-border bg-white/[0.02] text-center">
                <p className="text-sm text-muted-foreground">
                  By using Dicta, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.
                </p>
              </div>
            </div>
          </section>
        </main>
        <Footer />
      </div>
    </div>
  )
}
