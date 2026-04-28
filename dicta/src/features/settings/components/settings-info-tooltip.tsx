import { Info } from 'lucide-react'

import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/components/ui/tooltip'

interface SettingsInfoTooltipProps {
  content: string | string[]
  title?: string
}

export function SettingsInfoTooltip({
  content,
  title,
}: SettingsInfoTooltipProps) {
  const lines = Array.isArray(content) ? content : [content]

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          className="inline-flex items-center justify-center rounded-full p-0.5 hover:bg-accent/50 transition-colors group"
          onClick={e => e.stopPropagation()}
          type="button"
        >
          <Info className="w-3.5 h-3.5 text-muted-foreground group-hover:text-foreground transition-colors" />
        </button>
      </TooltipTrigger>
      <TooltipContent
        side="top"
        className="max-w-[280px] p-3 bg-popover border border-border shadow-xl backdrop-blur-none"
        sideOffset={8}
        showArrow={false}
      >
        <div className="space-y-1.5">
          {title && (
            <div className="text-xs font-semibold text-foreground">{title}</div>
          )}
          <div className="text-xs text-muted-foreground space-y-1">
            {lines.map((line, index) => (
              <p key={index}>{line}</p>
            ))}
          </div>
        </div>
      </TooltipContent>
    </Tooltip>
  )
}
