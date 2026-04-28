'use client'

import { useEffect, useRef } from 'react'

// Animated HORIZONTAL lines on left and right sides
function SideHorizontalLines({ side }: { side: 'left' | 'right' }) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return

    const colors = [
      { base: 'rgba(74, 222, 128, 0.15)', bright: 'rgba(74, 222, 128, 0.4)' }, // Green
      { base: 'rgba(251, 146, 60, 0.12)', bright: 'rgba(251, 146, 60, 0.35)' }, // Orange
      { base: 'rgba(96, 165, 250, 0.12)', bright: 'rgba(96, 165, 250, 0.35)' }, // Blue
      { base: 'rgba(167, 139, 250, 0.12)', bright: 'rgba(167, 139, 250, 0.35)' }, // Purple
      { base: 'rgba(255, 255, 255, 0.04)', bright: 'rgba(255, 255, 255, 0.12)' }, // White dim
    ]

    const createLine = () => {
      const line = document.createElement('div')
      const color = colors[Math.floor(Math.random() * colors.length)]

      // Position - full height coverage
      const top = Math.random() * 100
      const width = 20 + Math.random() * 40

      line.style.position = 'absolute'
      line.style.height = '1px'
      line.style.top = `${top}%`
      line.style.width = `${width}%`

      if (side === 'left') {
        line.style.left = '0'
        line.style.background = `linear-gradient(to right, ${color.bright} 0%, ${color.base} 50%, transparent 100%)`
      } else {
        line.style.right = '0'
        line.style.background = `linear-gradient(to left, ${color.bright} 0%, ${color.base} 50%, transparent 100%)`
      }

      const duration = 3 + Math.random() * 4
      const delay = Math.random() * 2

      line.style.animation = `fade-line ${duration}s ease-in-out ${delay}s`
      line.style.opacity = '0'

      container.appendChild(line)

      setTimeout(() => {
        line.remove()
      }, (duration + delay) * 1000 + 100)
    }

    // Create initial batch - more lines for full coverage
    for (let i = 0; i < 12; i++) {
      setTimeout(createLine, i * 150)
    }

    const interval = setInterval(createLine, 300)

    return () => {
      clearInterval(interval)
    }
  }, [side])

  return (
    <div
      ref={containerRef}
      className="absolute top-0 bottom-0 overflow-hidden pointer-events-none"
      style={{
        width: '30%',
        [side]: 0,
      }}
    />
  )
}

// Company logos for "Trusted by" - using actual-looking SVG icons
const trustedCompanies = [
  {
    name: 'Vercel',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M24 22.525H0l12-21.05 12 21.05z" />
      </svg>
    ),
  },
  {
    name: 'Linear',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 100 100" fill="currentColor">
        <path d="M1.22541 61.5228c-.2225-.9485.90748-1.5459 1.59638-.857L39.3342 97.1782c.6889.6889.0915 1.8189-.857 1.5765C20.0515 94.4426 5.69081 80.0819 1.22541 61.5228zM.00189135 46.8891c-.01764375.2833.0796075.5599.27854.7808l52.0496118 52.0496c.2209.1989.4975.2962.7808.2785 1.8922-.117 3.7549-.3332 5.5826-.6456C62.0649 98.8893 61.38 98.1561 60.5683 97.3443L2.65558 39.4317c-.78781-.8116-1.52098-1.4965-1.13598-2.6716a46.5003 46.5003 0 0 0-.51771 10.1290zM4.73813 28.729c-.12231.2921-.05485.6316.18347.8699L56.2 80.8783c.2383.2383.5778.3058.8699.1835 1.5679-.6566 3.0899-1.4061 4.5592-2.2418.3095-.176.3823-.5844.1602-.8614L13.3213 29.4906c-.2221-.277-.5305-.3497-.8064-.1402-1.1354.8634-2.2279 1.7844-3.27286 2.7582-.26143.2434-.48013.4856-.50411.5204zM13.4661 19.2883c-.24552.2464-.27393.6405-.05765.9087l53.3943 59.3831c.2163.2681.5626.3148.8504.1127 1.2274-.8609 2.4018-1.7929 3.5162-2.7887.2355-.2105.2711-.5558.0932-.8131L18.2608 15.8603c-.1779-.2573-.4934-.3265-.7507-.1485-1.1271.7794-2.2177 1.6165-3.2666 2.5077-.29SEK.2515-.5259.5173-.7774.9688zM22.2133 11.1205c-.2359.2345-.2568.6127-.0355.8667L75.6 66.2076c.2213.254.5527.2925.8241.1003 1.0737-.7595 2.1052-1.572 3.0902-2.4322.2269-.198.258-.5363.0735-.7885L26.0063 8.6847c-.1846-.2522-.4892-.3144-.7385-.1493-1.0718.7098-2.1114 1.4702-3.1136 2.2781-.2538.2045-.4391.4057-.5409.307zM34.003 3.99295c-.2157.2378-.2185.5995.004.8306l54.5535 56.1989c.2225.2312.5488.2587.8138.0622.8853-.6565 1.7438-1.3448 2.573-2.0625.2094-.181.2367-.4932.0644-.7271L35.8052 1.83948c-.1723-.234-.4573-.29538-.6749-.14543-.8591.59189-1.6924 1.21489-2.4973 1.86656-.229.1853-.4143.3997-.63.43234zM47.0722.22595c-.2048.2225-.1971.5641.0359.7774L98.7736 51.1758c.233.2132.5462.2349.7875.0474a46.5002 46.5002 0 0 0 .4389-4.6828L51.5738.07765c-.2123-.21234-.5268-.24932-.7711-.08753A46.5003 46.5003 0 0 0 47.0722.22595zM61.6114.01734c-.2702-.04999-.5192.15498-.5267.43259L61.032 2.41746c-.0075.27762.2022.51254.4725.56253 15.6987 2.91032 28.3169 15.5285 31.2273 31.2273.05.2703.285.48.5625.4725l1.9675-.0523c.2776-.0074.4826-.2565.4326-.5267C92.2891 15.0949 76.9051-.37699 61.6114.01734z" />
      </svg>
    ),
  },
  {
    name: 'Notion',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M4.459 4.208c.746.606 1.026.56 2.428.466l13.215-.793c.28 0 .047-.28-.046-.326L17.86 1.968c-.42-.326-.98-.7-2.055-.607L3.01 2.295c-.466.046-.56.28-.374.466zm.793 3.08v13.904c0 .747.373 1.027 1.214.98l14.523-.84c.84-.046.933-.56.933-1.167V6.354c0-.606-.233-.933-.746-.886l-15.177.887c-.56.046-.747.326-.747.933zm14.337.745c.093.42 0 .84-.42.888l-.7.14v10.264c-.608.327-1.168.514-1.635.514-.748 0-.935-.234-1.495-.933l-4.577-7.186v6.952l1.448.327s0 .84-1.168.84l-3.22.186c-.094-.186 0-.653.327-.746l.84-.233V9.854L7.822 9.76c-.094-.42.14-1.026.793-1.073l3.456-.233 4.764 7.279v-6.44l-1.215-.14c-.093-.514.28-.887.747-.933zM1.936 1.035l13.31-.98c1.634-.14 2.055-.047 3.082.7l4.249 2.986c.7.513.933.653.933 1.213v16.378c0 1.026-.373 1.634-1.68 1.726l-15.458.934c-.98.047-1.448-.093-1.962-.747l-3.129-4.06c-.56-.747-.793-1.306-.793-1.96V2.667c0-.839.374-1.54 1.448-1.632z" />
      </svg>
    ),
  },
  {
    name: 'Stripe',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M13.976 9.15c-2.172-.806-3.356-1.426-3.356-2.409 0-.831.683-1.305 1.901-1.305 2.227 0 4.515.858 6.09 1.631l.89-5.494C18.252.975 15.697 0 12.165 0 9.667 0 7.589.654 6.104 1.872 4.56 3.147 3.757 4.992 3.757 7.218c0 4.039 2.467 5.76 6.476 7.219 2.585.92 3.445 1.574 3.445 2.583 0 .98-.84 1.545-2.354 1.545-1.875 0-4.965-.921-6.99-2.109l-.9 5.555C5.175 22.99 8.385 24 11.714 24c2.641 0 4.843-.624 6.328-1.813 1.664-1.305 2.525-3.236 2.525-5.732 0-4.128-2.524-5.851-6.591-7.305z" />
      </svg>
    ),
  },
  {
    name: 'Raycast',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 512 512" fill="currentColor">
        <path d="M256 0L0 256l107 107 149-149 149 149 107-107L256 0zM107 299L0 406v106h106l107-107-106-106zm192 0l-43 43 106 106V342l-63-43zm106 63l-106 106v44h150V362l-44-44v44z" />
      </svg>
    ),
  },
  {
    name: 'Figma',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M15.852 8.981h-4.588V0h4.588c2.476 0 4.49 2.014 4.49 4.49s-2.014 4.491-4.49 4.491zM12.735 7.51h3.117c1.665 0 3.019-1.355 3.019-3.019s-1.355-3.019-3.019-3.019h-3.117V7.51zm0 1.471H8.148c-2.476 0-4.49-2.014-4.49-4.49S5.672 0 8.148 0h4.588v8.981zm-4.587-7.51c-1.665 0-3.019 1.355-3.019 3.019s1.354 3.02 3.019 3.02h3.117V1.471H8.148zm4.587 15.019H8.148c-2.476 0-4.49-2.014-4.49-4.49s2.014-4.49 4.49-4.49h4.588v8.98zM8.148 8.981c-1.665 0-3.019 1.355-3.019 3.019s1.355 3.019 3.019 3.019h3.117V8.981H8.148zM8.172 24c-2.489 0-4.515-2.014-4.515-4.49s2.014-4.49 4.49-4.49h4.588v4.441c0 2.503-2.047 4.539-4.563 4.539zm-.024-7.51a3.023 3.023 0 0 0-3.019 3.019c0 1.665 1.365 3.019 3.044 3.019 1.705 0 3.093-1.376 3.093-3.068v-2.97H8.148zm7.704 0h-.098c-2.476 0-4.49-2.014-4.49-4.49s2.014-4.49 4.49-4.49h.098c2.476 0 4.49 2.014 4.49 4.49s-2.014 4.49-4.49 4.49zm-.098-7.509c-1.665 0-3.019 1.355-3.019 3.019s1.355 3.019 3.019 3.019h.098c1.665 0 3.019-1.355 3.019-3.019s-1.355-3.019-3.019-3.019h-.098z" />
      </svg>
    ),
  },
  {
    name: 'Arc',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M5.25 3A2.25 2.25 0 003 5.25v13.5A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V5.25A2.25 2.25 0 0018.75 3H5.25zm6.114 4.5h1.272l3.537 9h-1.418l-.844-2.25h-3.822L9.245 16.5H7.827l3.537-9zm.636 1.875l-1.418 3.75h2.836l-1.418-3.75z" />
      </svg>
    ),
  },
  {
    name: 'Framer',
    icon: (
      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
        <path d="M4 0h16v8h-8zM4 8h8l8 8H4zM4 16h8v8z" />
      </svg>
    ),
  },
]

export default function Hero() {
  return (
    <section className="section-bordered relative min-h-[90vh] flex flex-col">
      {/* Animated horizontal lines on left and right sides */}
      <SideHorizontalLines side="left" />
      <SideHorizontalLines side="right" />

      {/* Gradient overlays */}
      <div className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-t from-black to-transparent pointer-events-none" />
      <div className="absolute inset-x-0 top-0 h-20 bg-gradient-to-b from-black to-transparent pointer-events-none" />

      <div className="flex-1 flex flex-col justify-center section-padding relative z-10">
        {/* Main headline */}
        <div className="text-center space-y-6 mb-20">
          <h1 className="text-display-2xl opacity-0 animate-fade-in delay-0" style={{ animationFillMode: 'forwards' }}>
            <span className="block">Your voice,</span>
            <span className="block">
              <span className="text-primary">perfectly</span>
              {' '}transcribed
            </span>
          </h1>

          <p className="text-lg text-muted-foreground max-w-xl mx-auto opacity-0 animate-fade-in delay-100" style={{ animationFillMode: 'forwards' }}>
            Transform speech into polished text with AI that runs entirely on your Mac.
            No cloud, no subscriptions, no limits.
          </p>
        </div>

        {/* CTA Buttons */}
        <div className="flex flex-col md:flex-row items-center justify-center gap-4 opacity-0 animate-fade-in delay-200" style={{ animationFillMode: 'forwards' }}>
          <a
            href="/download"
            className="group bg-foreground text-background font-medium px-8 py-4 rounded-xl text-base flex items-center gap-4 hover:bg-white/90 transition-all"
          >
            <span>Download for Mac</span>
            <svg className="w-4 h-4 transition-transform group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </a>

          <div className="flex gap-3">
            <a
              href="/#demo"
              className="group bg-white/5 border border-white/10 text-foreground font-medium px-6 py-4 rounded-xl text-base flex items-center gap-3 hover:bg-white/10 hover:border-white/20 transition-all"
            >
              <svg className="w-4 h-4 opacity-60" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Watch Demo</span>
            </a>

            <a
              href="https://github.com/nitintf/dicta"
              target="_blank"
              rel="noopener noreferrer"
              className="group bg-white/5 border border-white/10 text-foreground font-medium px-6 py-4 rounded-xl text-base flex items-center gap-3 hover:bg-white/10 hover:border-white/20 transition-all"
            >
              <svg className="w-4 h-4 opacity-60" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
              </svg>
              <span>GitHub</span>
            </a>
          </div>
        </div>
      </div>

      {/* Trusted by section */}
      <div className="border-t border-border py-8 px-6 opacity-0 animate-fade-in delay-300" style={{ animationFillMode: 'forwards' }}>
        <div className="flex flex-col md:flex-row items-center gap-6">
          <p className="text-sm text-muted-foreground whitespace-nowrap font-medium">
            Trusted by developers at
          </p>
          <div className="marquee-container flex-1">
            <div className="marquee-content animate-marquee">
              {[...trustedCompanies, ...trustedCompanies].map((company, i) => (
                <span key={i} className="company-logo">
                  {company.icon}
                  <span className="text-sm font-medium">{company.name}</span>
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
