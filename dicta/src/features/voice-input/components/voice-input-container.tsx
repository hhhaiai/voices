import { motion } from 'motion/react'

import { cn } from '@/lib/cn'

import type { VoiceInputDisplayMode } from '@/features/settings/types/generated'
import type { ReactNode } from 'react'

interface VoiceInputContainerProps {
  children: ReactNode
  mode?: VoiceInputDisplayMode
}

export function VoiceInputContainer({
  children,
  mode = 'standard',
}: VoiceInputContainerProps) {
  const isMinimal = mode === 'minimal'

  return (
    <div className="flex h-full w-full items-end justify-center">
      <motion.div
        layout
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{
          type: 'spring',
          stiffness: 400,
          damping: 30,
          mass: 0.8,
        }}
        className={cn(
          'relative flex h-full w-full items-center justify-center overflow-hidden rounded-full border border-white/12 bg-gradient-to-br from-black via-neutral-950 to-black',
          isMinimal ? 'px-3' : 'gap-1.5 px-2.5'
        )}
      >
        {children}
      </motion.div>
    </div>
  )
}
