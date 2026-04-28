import { Check, Pencil, Trash2 } from 'lucide-react'
import { ReactNode } from 'react'

import { Button } from '@/components/ui/button'
import { cn } from '@/lib/cn'

interface VibeCardProps {
  id: string
  name: string
  description: string
  isSelected: boolean
  isDefault: boolean
  showActions: boolean
  preview: ReactNode
  onSelect: () => void
  onEdit?: () => void
  onDelete?: () => void
}

export function VibeCard({
  name,
  description,
  isSelected,
  isDefault,
  showActions,
  preview,
  onSelect,
  onEdit,
  onDelete,
}: VibeCardProps) {
  return (
    <div
      className={cn(
        'relative rounded-xl transition-all cursor-pointer group overflow-hidden',
        'border',
        isSelected
          ? 'border-primary/60 bg-primary/[0.02] shadow-[0_0_0_1px_rgba(74,222,128,0.15)]'
          : 'border-border/40 bg-card/30 hover:border-border/60 hover:bg-card/50'
      )}
      onClick={onSelect}
    >
      {/* Accent line at top when selected */}
      {isSelected && (
        <div className="absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r from-primary/0 via-primary to-primary/0" />
      )}

      {/* Header section */}
      <div className="p-3.5 pb-2.5">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <h3 className="text-sm font-semibold text-foreground mb-0.5">
              {name}
            </h3>
            <p className="text-[11px] text-muted-foreground leading-relaxed">
              {description}
            </p>
          </div>

          {/* Selection indicator or actions */}
          <div className="shrink-0">
            {isSelected ? (
              <div className="flex items-center justify-center w-5 h-5 rounded-full bg-primary">
                <Check
                  className="h-3 w-3 text-primary-foreground"
                  strokeWidth={3}
                />
              </div>
            ) : !isDefault && showActions ? (
              <div className="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="h-5 w-5"
                  onClick={e => {
                    e.stopPropagation()
                    onEdit?.()
                  }}
                >
                  <Pencil className="h-2.5 w-2.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="h-5 w-5 text-muted-foreground hover:text-destructive"
                  onClick={e => {
                    e.stopPropagation()
                    onDelete?.()
                  }}
                >
                  <Trash2 className="h-2.5 w-2.5" />
                </Button>
              </div>
            ) : (
              <div
                className={cn(
                  'w-5 h-5 rounded-full border-2 transition-colors',
                  'border-border/40 group-hover:border-primary/40'
                )}
              />
            )}
          </div>
        </div>
      </div>

      {/* Preview section */}
      <div className="px-3.5 pb-3.5">
        <div
          className={cn(
            'rounded-lg overflow-hidden transition-colors',
            isSelected ? 'bg-primary/[0.04]' : 'bg-muted/20'
          )}
        >
          {preview}
        </div>
      </div>
    </div>
  )
}
