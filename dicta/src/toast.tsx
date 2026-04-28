import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow'
import { CircleCheck, CircleX, Info, TriangleAlert } from 'lucide-react'
import { StrictMode, useCallback, useEffect, useRef, useState } from 'react'
import ReactDOM from 'react-dom/client'

import { useTauriEvent } from './hooks/use-tauri-event'

import './index.css'

interface ToastMessage {
  message: string
  type?: 'info' | 'success' | 'error' | 'warning'
}

const TOAST_DURATION = 2500 // ms

function ToastWindowApp() {
  const [message, setMessage] = useState<string>('')
  const [type, setType] = useState<'info' | 'success' | 'error' | 'warning'>(
    'info'
  )
  const [isVisible, setIsVisible] = useState(false)
  const [progress, setProgress] = useState(100)
  const windowRef = useRef(getCurrentWebviewWindow())
  const animationFrameRef = useRef<number | null>(null)
  const startTimeRef = useRef<number | null>(null)
  const isHidingRef = useRef(false)

  const hideToast = useCallback(async () => {
    if (isHidingRef.current) return
    isHidingRef.current = true

    // Cancel any ongoing animation
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current)
      animationFrameRef.current = null
    }

    setIsVisible(false)
    await windowRef.current.hide()
    setProgress(100)
    startTimeRef.current = null
    isHidingRef.current = false
  }, [])

  const startProgressAnimation = useCallback(() => {
    startTimeRef.current = performance.now()

    const animate = (currentTime: number) => {
      if (!startTimeRef.current) return

      const elapsed = currentTime - startTimeRef.current
      const remaining = Math.max(0, 100 - (elapsed / TOAST_DURATION) * 100)

      setProgress(remaining)

      if (remaining > 0) {
        animationFrameRef.current = requestAnimationFrame(animate)
      } else {
        // Progress complete, hide the toast
        hideToast()
      }
    }

    animationFrameRef.current = requestAnimationFrame(animate)
  }, [hideToast])

  useTauriEvent<ToastMessage>('show_toast', async event => {
    // Cancel any existing animation
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current)
      animationFrameRef.current = null
    }

    // Reset state
    isHidingRef.current = false
    setMessage(event.payload.message)
    setType(event.payload.type || 'info')
    setProgress(100)
    setIsVisible(true)

    // Show the window first
    await windowRef.current.show()

    // Small delay to ensure render, then start animation
    requestAnimationFrame(() => {
      startProgressAnimation()
    })
  })

  useTauriEvent<void>('hide_toast', () => {
    hideToast()
  })

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
    }
  }, [])

  const getIcon = () => {
    const iconClass = 'w-4 h-4 flex-shrink-0'
    switch (type) {
      case 'success':
        return <CircleCheck className={`${iconClass} text-emerald-400`} />
      case 'error':
        return <CircleX className={`${iconClass} text-red-400`} />
      case 'warning':
        return <TriangleAlert className={`${iconClass} text-amber-400`} />
      default:
        return <Info className={`${iconClass} text-blue-400`} />
    }
  }

  const getProgressColor = () => {
    switch (type) {
      case 'success':
        return 'bg-emerald-400'
      case 'error':
        return 'bg-red-400'
      case 'warning':
        return 'bg-amber-400'
      default:
        return 'bg-blue-400'
    }
  }

  if (!isVisible) return null

  return (
    <div className="w-full h-full flex flex-col bg-black/90 backdrop-blur-md rounded-xl border border-white/10 overflow-hidden shadow-2xl animate-in slide-in-from-bottom-2 fade-in duration-200">
      <div className="flex-1 flex items-center px-4 gap-3 min-w-0">
        <div className="flex-shrink-0">{getIcon()}</div>
        <p className="text-[12px] leading-tight font-medium text-white/90 line-clamp-2 min-w-0 flex-1">
          {message}
        </p>
      </div>
      <div className="w-full h-[2px] bg-white/5 flex-shrink-0">
        <div
          className={`h-full ${getProgressColor()}`}
          style={{
            width: `${progress}%`,
            transition: 'none', // Use RAF for smooth animation, not CSS transitions
          }}
        />
      </div>
    </div>
  )
}

const rootElement = document.getElementById('toast-root')!
const root = ReactDOM.createRoot(rootElement)
root.render(
  <StrictMode>
    <ToastWindowApp />
  </StrictMode>
)
