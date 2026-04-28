import { AlertCircle } from 'lucide-react'
import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useState } from 'react'

import { useTauriEvent } from '@/hooks/use-tauri-event'

import { LiveWaveform } from '../../../components/ui/live-waveform'

interface CommandResultPayload {
  transcription: string
}

type ViewState = 'generating' | 'error'

export function CommandResult() {
  const [transcription, setTranscription] = useState<string | null>(null)
  const [isVisible, setIsVisible] = useState(false)
  const [viewState, setViewState] = useState<ViewState>('generating')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const handleShow = useCallback((event: { payload: CommandResultPayload }) => {
    // Reset state first, then show - ensures clean state on open
    setViewState('generating')
    setErrorMessage(null)
    setTranscription(event.payload.transcription)
    setIsVisible(true)
  }, [])

  const handleError = useCallback((event: { payload: string }) => {
    setViewState('error')
    setErrorMessage(event.payload)
  }, [])

  const handleHide = useCallback(() => {
    setIsVisible(false)
    // Reset state on hide so next open is clean
    setViewState('generating')
    setErrorMessage(null)
  }, [])

  useTauriEvent<CommandResultPayload>('show-command-result', handleShow)
  useTauriEvent<string>('command-result-error', handleError)
  useTauriEvent('hide-command-result', handleHide)

  return (
    <div className="flex h-full w-full items-end justify-center p-4">
      <AnimatePresence>
        {isVisible && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 10 }}
            transition={{
              type: 'spring',
              stiffness: 400,
              damping: 30,
            }}
            className="flex h-[160px] w-full flex-col rounded-2xl border border-white/12 bg-gradient-to-br from-black via-neutral-950 to-black p-4"
          >
            {/* Top section: "I heard" + transcription */}
            <div className="min-h-0 flex-1">
              {/* "I heard" label */}
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.1 }}
                className="mb-1.5 text-[9px] font-medium uppercase tracking-wider text-zinc-500"
              >
                I heard
              </motion.p>

              {/* Transcription text - with max height and fade mask for overflow */}
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.15, duration: 0.3 }}
                className="relative max-h-[60px] overflow-hidden"
              >
                <p className="text-[13px] leading-relaxed text-white/90">
                  {transcription}
                </p>
                {/* Fade mask for overflow */}
                <div className="pointer-events-none absolute inset-x-0 bottom-0 h-6 bg-gradient-to-t from-neutral-950 to-transparent" />
              </motion.div>
            </div>

            {/* Bottom section: Generating or Error */}
            <AnimatePresence mode="wait">
              {viewState === 'generating' ? (
                <motion.div
                  key="generating"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ delay: 0.25 }}
                  className="flex flex-col items-center pt-2"
                >
                  {/* "Generating" label - small, centered above waves */}
                  <span className="mb-1.5 text-[9px] font-medium uppercase tracking-wider text-zinc-500">
                    Generating
                  </span>

                  <LiveWaveform
                    active={false}
                    processing
                    barWidth={2.5}
                    barGap={2}
                    barRadius={4}
                    barColor="#9ca3af"
                    fadeEdges
                    fadeWidth={200}
                    height={26}
                    className="w-full opacity-70"
                  />
                </motion.div>
              ) : (
                <motion.div
                  key="error"
                  initial={{ opacity: 0, y: 5 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  className="flex items-center gap-2 pt-2"
                >
                  <AlertCircle className="h-4 w-4 flex-shrink-0 text-amber-500" />
                  <p className="text-[13px] leading-snug text-amber-500/90">
                    {errorMessage}
                  </p>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
