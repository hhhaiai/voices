import { Check } from 'lucide-react'

import { cn } from '@/lib/cn'
import { useTheme } from '@/providers/theme-provider'

type Theme = 'light' | 'dark' | 'system'

interface ThemeOption {
  value: Theme
  label: string
}

const themeOptions: ThemeOption[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'System' },
]

export function VisualThemeSelector() {
  const { theme, setTheme } = useTheme()

  return (
    <div className="flex gap-3">
      {themeOptions.map(option => (
        <button
          key={option.value}
          onClick={() => setTheme(option.value)}
          className="flex flex-col items-center gap-2 group"
        >
          <div
            className={cn(
              'relative w-24 h-16 rounded-lg border-2 overflow-hidden transition-all',
              theme === option.value
                ? 'border-blue-500 ring-2 ring-blue-500/20'
                : 'border-border hover:border-muted-foreground/50'
            )}
          >
            <ThemePreview variant={option.value} />
            {theme === option.value && (
              <div className="absolute bottom-1 right-1 w-4 h-4 bg-blue-500 rounded-full flex items-center justify-center">
                <Check className="w-2.5 h-2.5 text-white" strokeWidth={3} />
              </div>
            )}
          </div>
          <span
            className={cn(
              'text-xs font-medium transition-colors',
              theme === option.value ? 'text-blue-500' : 'text-muted-foreground'
            )}
          >
            {option.label}
          </span>
        </button>
      ))}
    </div>
  )
}

function ThemePreview({ variant }: { variant: Theme }) {
  const isLight = variant === 'light'
  const isSystem = variant === 'system'

  if (isSystem) {
    // System theme shows split view
    return (
      <div className="w-full h-full flex">
        {/* Light half */}
        <div className="w-1/2 h-full bg-gray-100 p-1.5">
          <div className="flex gap-0.5 mb-1.5">
            <div className="w-1 h-1 rounded-full bg-gray-300" />
            <div className="w-1 h-1 rounded-full bg-gray-300" />
            <div className="w-1 h-1 rounded-full bg-gray-300" />
          </div>
          <div className="w-6 h-1 bg-blue-500 rounded-sm mb-1" />
          <div className="w-4 h-0.5 bg-gray-300 rounded-sm" />
        </div>
        {/* Dark half */}
        <div className="w-1/2 h-full bg-zinc-900 p-1.5">
          <div className="flex gap-0.5 mb-1.5">
            <div className="w-1 h-1 rounded-full bg-zinc-700" />
            <div className="w-1 h-1 rounded-full bg-zinc-700" />
            <div className="w-1 h-1 rounded-full bg-zinc-700" />
          </div>
          <div className="w-6 h-1 bg-blue-500 rounded-sm mb-1" />
          <div className="w-4 h-0.5 bg-zinc-700 rounded-sm" />
        </div>
      </div>
    )
  }

  const bgColor = isLight ? 'bg-gray-100' : 'bg-zinc-900'
  const dotColor = isLight ? 'bg-gray-300' : 'bg-zinc-700'
  const panelBg = isLight ? 'bg-white' : 'bg-zinc-800'

  return (
    <div className={cn('w-full h-full p-1.5', bgColor)}>
      {/* Window chrome dots */}
      <div className="flex gap-0.5 mb-1.5">
        <div className={cn('w-1 h-1 rounded-full', dotColor)} />
        <div className={cn('w-1 h-1 rounded-full', dotColor)} />
        <div className={cn('w-1 h-1 rounded-full', dotColor)} />
      </div>
      {/* Title bar accent */}
      <div className="w-8 h-1 bg-blue-500 rounded-sm mb-1.5" />
      {/* Content lines */}
      <div className="flex gap-1">
        <div className={cn('w-4 h-6 rounded-sm', panelBg)} />
        <div className="flex-1 flex flex-col gap-0.5">
          <div className={cn('w-full h-2.5 rounded-sm', panelBg)} />
          <div className={cn('w-full h-2.5 rounded-sm', panelBg)} />
        </div>
      </div>
    </div>
  )
}
