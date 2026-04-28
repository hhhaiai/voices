'use client'

import { useEffect, useRef, useState } from 'react'

const testimonials = [
  {
    quote: "Dicta has completely transformed how I write documentation. I can focus on my thoughts instead of typing speed. It's like having a superpower.",
    author: 'Sarah Chen',
    role: 'Software Engineer',
    company: 'Stripe',
    avatar: 'SC',
    color: 'violet',
  },
  {
    quote: "As someone with RSI, Dicta has been life-changing. I can work full days without pain, and my productivity has actually increased.",
    author: 'Michael Rodriguez',
    role: 'Content Writer',
    company: 'Vercel',
    avatar: 'MR',
    color: 'blue',
  },
  {
    quote: "The local processing means I can dictate sensitive client information without privacy concerns. Plus, it's incredibly accurate.",
    author: 'Emma Thompson',
    role: 'Legal Assistant',
    company: 'Morrison & Co',
    avatar: 'ET',
    color: 'cyan',
  },
  {
    quote: "I was skeptical about voice typing, but the custom vocabulary feature learned all my technical terms in days. More accurate than my typing now.",
    author: 'David Park',
    role: 'Data Scientist',
    company: 'OpenAI',
    avatar: 'DP',
    color: 'orange',
  },
  {
    quote: "The snippets feature is genius. I set up shortcuts for common responses and handle emails 3x faster. It's not just transcription, it's automation.",
    author: 'Lisa Anderson',
    role: 'Customer Success',
    company: 'Linear',
    avatar: 'LA',
    color: 'pink',
  },
  {
    quote: "Being open source gives me confidence that my data is safe. Plus, I've contributed a few features myself. The community is amazing!",
    author: 'Alex Kumar',
    role: 'Security Engineer',
    company: 'Cloudflare',
    avatar: 'AK',
    color: 'violet',
  },
]

const colorClasses = {
  violet: {
    star: 'text-violet-400',
    avatar: 'bg-violet-500/10 border-violet-500/20 text-violet-400',
    hover: 'from-violet-500/5',
  },
  blue: {
    star: 'text-blue-400',
    avatar: 'bg-blue-500/10 border-blue-500/20 text-blue-400',
    hover: 'from-blue-500/5',
  },
  cyan: {
    star: 'text-cyan-400',
    avatar: 'bg-cyan-500/10 border-cyan-500/20 text-cyan-400',
    hover: 'from-cyan-500/5',
  },
  orange: {
    star: 'text-orange-400',
    avatar: 'bg-orange-500/10 border-orange-500/20 text-orange-400',
    hover: 'from-orange-500/5',
  },
  pink: {
    star: 'text-pink-400',
    avatar: 'bg-pink-500/10 border-pink-500/20 text-pink-400',
    hover: 'from-pink-500/5',
  },
}

function TestimonialCard({ testimonial, index }: { testimonial: typeof testimonials[0]; index: number }) {
  const [isVisible, setIsVisible] = useState(false)
  const cardRef = useRef<HTMLDivElement>(null)
  const colors = colorClasses[testimonial.color as keyof typeof colorClasses]

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true)
        }
      },
      { threshold: 0.1 }
    )

    if (cardRef.current) {
      observer.observe(cardRef.current)
    }

    return () => observer.disconnect()
  }, [])

  return (
    <div
      ref={cardRef}
      className={`
        relative group rounded-2xl border border-white/[0.06] bg-white/[0.02] p-6
        overflow-hidden card-hover
        ${isVisible ? 'animate-fade-in-up' : 'opacity-0'}
      `}
      style={{ animationDelay: `${index * 100}ms`, animationFillMode: 'forwards' }}
    >
      {/* Hover gradient */}
      <div className={`absolute inset-0 bg-gradient-to-br ${colors.hover} via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity`} />

      <div className="relative z-10 space-y-4">
        {/* Stars */}
        <div className="flex gap-1">
          {[...Array(5)].map((_, i) => (
            <svg
              key={i}
              className={`w-4 h-4 ${colors.star} fill-current`}
              viewBox="0 0 20 20"
            >
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
          ))}
        </div>

        {/* Quote */}
        <p className="text-foreground/90 leading-relaxed text-sm">
          &ldquo;{testimonial.quote}&rdquo;
        </p>

        {/* Author */}
        <div className="flex items-center gap-3 pt-2">
          <div className={`w-10 h-10 rounded-full ${colors.avatar} flex items-center justify-center text-sm font-semibold border`}>
            {testimonial.avatar}
          </div>
          <div>
            <div className="font-medium text-sm">{testimonial.author}</div>
            <div className="text-xs text-muted-foreground">
              {testimonial.role} · {testimonial.company}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function Reviews() {
  return (
    <section className="section-spacing relative overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-0 left-1/4 w-[500px] h-[500px] bg-violet-500/[0.02] rounded-full blur-[150px]" />
        <div className="absolute bottom-0 right-1/4 w-[400px] h-[400px] bg-blue-500/[0.03] rounded-full blur-[120px]" />
      </div>

      <div className="container-default">
        {/* Section header */}
        <div className="text-center mb-16 space-y-4">
          <h2 className="text-display-lg font-bold">
            Loved by{' '}
            <span className="font-[family-name:var(--font-instrument)] italic gradient-text">thousands</span>
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Join the community of writers, developers, and professionals who&apos;ve discovered the power of voice.
          </p>
        </div>

        {/* Testimonials grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-16">
          {testimonials.map((testimonial, index) => (
            <TestimonialCard key={index} testimonial={testimonial} index={index} />
          ))}
        </div>

        {/* Social proof stats */}
        <div className="relative">
          {/* Glow */}
          <div className="absolute inset-0 bg-white/[0.02] rounded-3xl blur-xl" />

          <div className="relative rounded-3xl border border-white/[0.06] bg-white/[0.02] p-8 md:p-12">
            <div className="grid md:grid-cols-4 gap-8 md:gap-4 text-center">
              {[
                { value: '10K+', label: 'Active Users' },
                { value: '500K+', label: 'Words Transcribed Daily' },
                { value: '4.9', label: 'Average Rating' },
                { value: '50+', label: 'Languages Supported' },
              ].map((stat, i) => (
                <div key={i} className="relative">
                  {i < 3 && (
                    <div className="hidden md:block absolute right-0 top-1/2 -translate-y-1/2 w-px h-12 bg-white/[0.06]" />
                  )}
                  <div className="text-4xl md:text-5xl font-bold gradient-text mb-2">{stat.value}</div>
                  <div className="text-sm text-muted-foreground">{stat.label}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
