import { writeText } from '@tauri-apps/plugin-clipboard-manager'
import { CheckIcon, CopyIcon } from 'lucide-react'
import * as React from 'react'

import { Button, ButtonProps } from '@/components/ui/button'
import { useControlledState } from '@/hooks/use-controlled-state'
import { useAnalytics } from '@/lib/analytics'
import { cn } from '@/lib/cn'

type CopyButtonProps = ButtonProps & {
  content: string
  copied?: boolean
  onCopiedChange?: (copied: boolean, content?: string) => void
  delay?: number
}

function CopyButton({
  content,
  copied,
  onCopiedChange,
  onClick,
  delay = 3000,
  ...props
}: CopyButtonProps) {
  const [isCopied, setIsCopied] = useControlledState({
    value: copied,
    onChange: onCopiedChange,
  })
  const { capture, events } = useAnalytics()

  const handleCopy = React.useCallback(
    (e: React.MouseEvent<HTMLButtonElement>) => {
      onClick?.(e)
      if (copied) return
      if (content) {
        writeText(content)
          .then(() => {
            setIsCopied(true)
            onCopiedChange?.(true, content)
            capture(events.COPY_TO_CLIPBOARD, {
              content_length: content.length,
            })
            setTimeout(() => {
              setIsCopied(false)
              onCopiedChange?.(false)
            }, delay)
          })
          .catch(error => {
            console.error('Error copying command', error)
          })
      }
    },
    [
      onClick,
      copied,
      content,
      setIsCopied,
      onCopiedChange,
      delay,
      capture,
      events,
    ]
  )

  return (
    <Button data-slot="copy-button" onClick={handleCopy} {...props}>
      <span
        data-slot="copy-button-icon"
        className="relative flex items-center justify-center"
      >
        <CopyIcon
          className={cn(
            'h-3.5 w-3.5 transition-all duration-200',
            isCopied ? 'scale-0 opacity-0' : 'scale-100 opacity-100'
          )}
        />
        <CheckIcon
          className={cn(
            'h-3.5 w-3.5 absolute transition-all duration-200 text-emerald-500',
            isCopied ? 'scale-100 opacity-100' : 'scale-0 opacity-0'
          )}
        />
      </span>
    </Button>
  )
}

export { CopyButton, type CopyButtonProps }
