import { Pause, Play } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

import { cn } from '@/lib/cn'

interface PlayButtonProps {
  audioPath: string
  size?: number
  className?: string
}

export function PlayButton({
  audioPath,
  size = 24,
  className,
}: PlayButtonProps) {
  const audioRef = useRef<HTMLAudioElement>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [progress, setProgress] = useState(0)
  const [isReady, setIsReady] = useState(false)

  useEffect(() => {
    const audio = audioRef.current
    if (!audio) return

    const updateProgress = () => {
      if (audio.duration > 0) {
        setProgress((audio.currentTime / audio.duration) * 100)
      }
    }

    const handleEnded = () => {
      setIsPlaying(false)
      setProgress(0)
    }

    const handleCanPlay = () => setIsReady(true)

    audio.addEventListener('timeupdate', updateProgress)
    audio.addEventListener('ended', handleEnded)
    audio.addEventListener('canplay', handleCanPlay)

    // Check if audio is already ready (deferred to avoid synchronous setState in effect)
    if (audio.readyState >= 2) {
      queueMicrotask(() => setIsReady(true))
    }

    return () => {
      audio.removeEventListener('timeupdate', updateProgress)
      audio.removeEventListener('ended', handleEnded)
      audio.removeEventListener('canplay', handleCanPlay)
    }
  }, [audioPath])

  // Cleanup on unmount - stop audio
  useEffect(() => {
    return () => {
      const audio = audioRef.current
      if (audio) {
        audio.pause()
        audio.currentTime = 0
      }
    }
  }, [])

  const togglePlay = async () => {
    const audio = audioRef.current
    if (!audio) return

    try {
      if (isPlaying) {
        audio.pause()
        setIsPlaying(false)
      } else {
        await audio.play()
        setIsPlaying(true)
      }
    } catch (error) {
      console.error('Error playing audio:', error)
      setIsPlaying(false)
    }
  }

  // SVG circle calculations
  const strokeWidth = 2
  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (progress / 100) * circumference

  return (
    <button
      onClick={togglePlay}
      disabled={!isReady}
      className={cn(
        'relative flex items-center justify-center rounded-full transition-all',
        'hover:bg-accent/60 active:scale-95',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        'focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/50',
        className
      )}
      style={{ width: size, height: size }}
      aria-label={isPlaying ? 'Pause' : 'Play'}
    >
      <audio ref={audioRef} src={audioPath} preload="auto" />

      {/* Progress ring */}
      <svg className="absolute inset-0 -rotate-90" width={size} height={size}>
        {/* Background circle */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          className="text-muted-foreground/20"
        />
        {/* Progress circle */}
        {isPlaying && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke="currentColor"
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={strokeDashoffset}
            className="text-primary transition-all duration-100"
          />
        )}
      </svg>

      {/* Icon */}
      {isPlaying ? (
        <Pause className="h-3 w-3 text-primary" fill="currentColor" />
      ) : (
        <Play
          className="h-3 w-3 ml-0.5 text-muted-foreground"
          fill="currentColor"
        />
      )}
    </button>
  )
}
