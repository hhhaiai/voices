import { cn } from '@/lib/cn'

import type { ReactNode } from 'react'

interface ContextBannerProps {
  children: ReactNode
  className?: string
  variant?: 'default' | 'subtle'
}

/**
 * A refined banner component for contextual information.
 * Used across pages for consistent styling - vibes info, stats, tips, etc.
 */
export function ContextBanner({
  children,
  className,
  variant = 'default',
}: ContextBannerProps) {
  return (
    <div
      className={cn(
        'relative rounded-xl border overflow-hidden',
        variant === 'default' && [
          'bg-gradient-to-r from-primary/[0.04] via-transparent to-transparent',
          'border-border/60',
        ],
        variant === 'subtle' && ['bg-card/50', 'border-border/50'],
        className
      )}
    >
      {/* Content */}
      <div className="relative px-5 py-4">{children}</div>
    </div>
  )
}

ContextBanner.Content = function ContextBannerContent({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex items-center gap-4', className)}>{children}</div>
  )
}

ContextBanner.Icon = function ContextBannerIcon({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex items-center justify-center shrink-0', className)}>
      {children}
    </div>
  )
}

ContextBanner.Text = function ContextBannerText({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return <div className={cn('flex-1 min-w-0', className)}>{children}</div>
}

ContextBanner.Title = function ContextBannerTitle({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <h3
      className={cn(
        'text-sm font-medium text-foreground leading-snug',
        className
      )}
    >
      {children}
    </h3>
  )
}

ContextBanner.Description = function ContextBannerDescription({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <p
      className={cn(
        'text-xs text-muted-foreground leading-relaxed mt-0.5',
        className
      )}
    >
      {children}
    </p>
  )
}
