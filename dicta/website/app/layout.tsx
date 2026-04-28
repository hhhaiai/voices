import { Analytics } from "@vercel/analytics/next"
import type { Metadata } from 'next'
import { DM_Sans, Instrument_Serif } from 'next/font/google'
import './globals.css'

// DM Sans - Clean geometric sans-serif
const dmSans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-satoshi',
  display: 'swap',
  weight: ['400', '500', '600', '700'],
})

// Instrument Serif - Elegant display font
const instrumentSerif = Instrument_Serif({
  subsets: ['latin'],
  variable: '--font-instrument',
  display: 'swap',
  weight: '400',
  style: ['normal', 'italic'],
})

export const metadata: Metadata = {
  title: 'Dicta — Voice to Text AI for macOS',
  description:
    'Transform your voice into polished text instantly. Open source, offline-first, and 100% private. The AI-powered dictation app that respects your privacy.',
  keywords: [
    'voice to text',
    'speech recognition',
    'dictation',
    'macOS',
    'AI',
    'Whisper',
    'offline',
    'privacy',
    'open source',
  ],
  authors: [{ name: 'Nitin Panwar', url: 'https://github.com/nitintf' }],
  openGraph: {
    title: 'Dicta — Voice to Text AI for macOS',
    description:
      'Transform your voice into polished text instantly. Open source, offline-first, and 100% private.',
    url: 'https://dicta.app',
    siteName: 'Dicta',
    type: 'website',
    locale: 'en_US',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Dicta — Voice to Text AI for macOS',
    description:
      'Transform your voice into polished text instantly. Open source, offline-first, and 100% private.',
  },
  icons: {
    icon: '/icon.png',
    apple: '/icon.png',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${dmSans.variable} ${instrumentSerif.variable} font-sans antialiased bg-black`}
      >
        {/* Noise texture overlay */}
        <div className="noise-overlay" aria-hidden="true" />
        {children}
      </body>
      <Analytics />
    </html>
  )
}
