'use client'

import { useState } from 'react'

const faqs = [
  {
    question: 'Is Dicta really free?',
    answer: 'Yes, completely free forever. Dicta is open source under the MIT License. There are no subscriptions, no trials, no hidden fees, and no premium tiers. Everything is included.',
  },
  {
    question: 'Does Dicta work offline?',
    answer: 'Yes! Dicta runs entirely on your Mac using local AI models. No internet connection is required for transcription. Your voice data never leaves your device.',
  },
  {
    question: 'What languages does Dicta support?',
    answer: 'Dicta supports 50+ languages through the Whisper AI model, including English, Spanish, French, German, Chinese, Japanese, Korean, Arabic, and many more.',
  },
  {
    question: 'How accurate is the transcription?',
    answer: 'Dicta uses OpenAI\'s Whisper model, which is state-of-the-art for speech recognition. Accuracy depends on audio quality and the model size you choose, but it rivals cloud-based services.',
  },
  {
    question: 'What Mac do I need to run Dicta?',
    answer: 'Dicta works best on Apple Silicon Macs (M1, M2, M3, M4) where it can leverage the Neural Engine for fast inference. It also works on Intel Macs, though performance may vary.',
  },
  {
    question: 'How do I use Dicta?',
    answer: 'Simply press the global shortcut (Option + Space by default), speak, and release. Your transcribed text will be automatically typed wherever your cursor is. You can also customize the shortcut in settings.',
  },
  {
    question: 'Can I train Dicta on my vocabulary?',
    answer: 'Yes! Dicta supports custom vocabulary training so it can better recognize names, technical terms, and domain-specific jargon that you use frequently.',
  },
  {
    question: 'Is my data private?',
    answer: 'Absolutely. All processing happens locally on your Mac. No audio is ever sent to any server. No data is collected. Your voice and transcriptions stay completely private.',
  },
]

function FAQItem({ faq, index }: { faq: typeof faqs[0]; index: number }) {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <div className="border-b border-border">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full py-5 flex items-center justify-between text-left hover:text-primary transition-colors"
      >
        <span className="font-medium pr-4">{faq.question}</span>
        <svg
          className={`w-5 h-5 flex-shrink-0 text-muted-foreground transition-transform ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      <div
        className={`overflow-hidden transition-all duration-300 ${isOpen ? 'max-h-96 pb-5' : 'max-h-0'}`}
      >
        <p className="text-muted-foreground text-sm leading-relaxed pr-8">
          {faq.answer}
        </p>
      </div>
    </div>
  )
}

export default function FAQ() {
  return (
    <section id="faq" className="section-grey section-padding">
      <div className="max-w-3xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <span className="text-primary text-sm font-medium mb-4 block">
            FAQ
          </span>
          <h2 className="text-display-lg mb-4">
            Frequently asked questions
          </h2>
          <p className="text-muted-foreground">
            Everything you need to know about Dicta
          </p>
        </div>

        {/* FAQ list */}
        <div className="border-t border-border">
          {faqs.map((faq, index) => (
            <FAQItem key={index} faq={faq} index={index} />
          ))}
        </div>

        {/* Still have questions */}
        <div className="text-center mt-12">
          <p className="text-muted-foreground mb-4">
            Still have questions?
          </p>
          <a
            href="https://github.com/nitintf/dicta/discussions"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 text-primary hover:underline"
          >
            Ask on GitHub Discussions
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </a>
        </div>
      </div>
    </section>
  )
}
