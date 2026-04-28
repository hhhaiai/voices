import { ReactNode } from 'react'

import { cn } from '@/lib/cn'

interface SettingsPanelProps {
  title: string
  description?: string
  children: ReactNode
  className?: string
}

export function SettingsPanel({
  title,
  description,
  children,
  className,
}: SettingsPanelProps) {
  return (
    <div className={cn('space-y-6', className)}>
      <div>
        <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
        {description && (
          <p className="text-sm text-muted-foreground mt-1">{description}</p>
        )}
      </div>
      <div className="space-y-6">{children}</div>
    </div>
  )
}

interface SettingItemProps {
  title: string
  description?: string
  action?: ReactNode
  children?: ReactNode
  disabled?: boolean
  info?: ReactNode
  /** Use 'stacked' layout to place action below title/description */
  layout?: 'inline' | 'stacked'
}

export function SettingItem({
  title,
  description,
  action,
  children,
  disabled,
  info,
  layout = 'inline',
}: SettingItemProps) {
  if (layout === 'stacked') {
    return (
      <div className="py-4 space-y-3" aria-disabled={disabled ?? false}>
        <div
          className={cn(
            'space-y-1 transition-opacity',
            disabled && 'opacity-50'
          )}
        >
          <div className="flex items-center gap-1.5">
            <h3
              className={cn(
                'text-sm font-medium leading-none',
                disabled && 'text-muted-foreground'
              )}
            >
              {title}
            </h3>
            {info && <div className="opacity-100">{info}</div>}
          </div>
          {description && (
            <p
              className={cn(
                'text-sm text-muted-foreground',
                disabled && 'text-muted-foreground/60'
              )}
            >
              {description}
            </p>
          )}
        </div>
        {action && <div className={cn(disabled && 'opacity-50')}>{action}</div>}
        {children && <div>{children}</div>}
      </div>
    )
  }

  return (
    <div
      className="flex items-start justify-between gap-4 py-4"
      aria-disabled={disabled ?? false}
    >
      <div
        className={cn(
          'flex-1 space-y-1 transition-opacity',
          disabled && 'opacity-50'
        )}
      >
        <div className="flex items-center gap-1.5">
          <h3
            className={cn(
              'text-sm font-medium leading-none',
              disabled && 'text-muted-foreground'
            )}
          >
            {title}
          </h3>
          {/* Info tooltip should always be interactive */}
          {info && <div className="opacity-100">{info}</div>}
        </div>
        {description && (
          <p
            className={cn(
              'text-sm text-muted-foreground',
              disabled && 'text-muted-foreground/60'
            )}
          >
            {description}
          </p>
        )}
        {children && <div className="pt-2">{children}</div>}
      </div>
      {action && (
        <div className={cn('shrink-0', disabled && 'opacity-50')}>{action}</div>
      )}
    </div>
  )
}

export function SettingsSection({
  title,
  children,
  className,
}: {
  title?: string
  children: ReactNode
  className?: string
}) {
  return (
    <div className={cn('space-y-4', className)}>
      {title && (
        <h3 className="text-sm font-medium text-muted-foreground">{title}</h3>
      )}
      <div className="divide-y">{children}</div>
    </div>
  )
}
