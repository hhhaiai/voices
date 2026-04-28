import { cn } from '@/lib/cn'

import type { ReactNode } from 'react'

interface InfoCardProps {
  children: ReactNode
  className?: string
  variant?: 'default' | 'accent'
}

export function InfoCard({
  children,
  className,
  variant = 'default',
}: InfoCardProps) {
  return (
    <div
      className={cn(
        'rounded-lg p-4 transition-colors',
        variant === 'default' && 'bg-surface border border-border',
        variant === 'accent' &&
          'bg-surface border-l-2 border-l-primary border border-border',
        className
      )}
    >
      {children}
    </div>
  )
}

InfoCard.Title = function InfoCardTitle({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <h3 className={cn('text-base font-medium text-foreground mb-2', className)}>
      {children}
    </h3>
  )
}

InfoCard.Description = function InfoCardDescription({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <p
      className={cn('text-sm text-muted-foreground leading-relaxed', className)}
    >
      {children}
    </p>
  )
}

InfoCard.Content = function InfoCardContent({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return <div className={cn('space-y-3', className)}>{children}</div>
}
