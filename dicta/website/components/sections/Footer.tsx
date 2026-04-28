import Image from 'next/image'
import Link from 'next/link'

export default function Footer() {
  const links = {
    main: [
      { name: 'Features', href: '/#features' },
      { name: 'Demo', href: '/#demo' },
      { name: 'Pricing', href: '/#pricing' },
      { name: 'FAQ', href: '/#faq' },
    ],
    company: [
      { name: 'Changelog', href: '/changelog' },
      { name: 'Roadmap', href: '/roadmap' },
      { name: 'Privacy Policy', href: '/privacy-policy' },
      { name: 'Terms of Service', href: '/terms-of-service' },
    ],
    links: [
      { name: 'GitHub', href: 'https://github.com/nitintf/dicta', external: true },
      { name: 'Discussions', href: 'https://github.com/nitintf/dicta/discussions', external: true },
    ],
  }

  return (
    <footer className="border-t border-border">
      <div className="grid md:grid-cols-2 lg:grid-cols-5 gap-12 p-8 md:p-12">
        {/* Brand column */}
        <div className="lg:col-span-2 space-y-5">
          <Link href="/" className="flex items-center gap-2.5">
            <Image
              src="/icon.png"
              alt="Dicta"
              className="w-7 h-7 rounded-lg"
              width={28}
              height={28}
            />
            <span className="text-base font-medium">Dicta</span>
          </Link>
          <p className="text-sm text-muted-foreground max-w-xs leading-relaxed">
            Open source voice-to-text AI for macOS.
            100% private, works offline, free forever.
          </p>
        </div>

        {/* Links columns */}
        <div>
          <h3 className="font-medium mb-4 text-sm">Product</h3>
          <ul className="space-y-3">
            {links.main.map((link) => (
              <li key={link.name}>
                <a
                  href={link.href}
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  {link.name}
                </a>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h3 className="font-medium mb-4 text-sm">Company</h3>
          <ul className="space-y-3">
            {links.company.map((link) => (
              <li key={link.name}>
                <a
                  href={link.href}
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  {link.name}
                </a>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h3 className="font-medium mb-4 text-sm">Connect</h3>
          <ul className="space-y-3">
            {links.links.map((link) => (
              <li key={link.name}>
                <a
                  href={link.href}
                  target={link.external ? '_blank' : undefined}
                  rel={link.external ? 'noopener noreferrer' : undefined}
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  {link.name}
                </a>
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* Bottom bar */}
      <div className="px-8 md:px-12 py-6 border-t border-border flex flex-col md:flex-row justify-between items-center gap-4">
        <p className="text-sm text-muted-foreground">
          © 2026 Dicta. Open source under MIT License.
        </p>
        <div className="flex items-center gap-4">
          {/* Social icons */}
          <a
            href="https://github.com/nitintf/dicta"
            target="_blank"
            rel="noopener noreferrer"
            className="text-muted-foreground hover:text-foreground transition-colors"
            aria-label="GitHub"
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
            </svg>
          </a>
        </div>
      </div>
    </footer>
  )
}
