import { invoke } from '@tauri-apps/api/core'
import { FileAudio, Upload, X, Loader2 } from 'lucide-react'
import { useCallback, useRef, useState } from 'react'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useTranscriptionsStore } from '@/features/transcriptions'
import { useAnalytics } from '@/lib/analytics'
import { cn } from '@/lib/cn'

import type { UploadTranscriptionResponse } from '@/features/transcriptions/types/generated'

interface UploadDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

const SUPPORTED_FORMATS = ['.wav', '.mp3', '.m4a', '.ogg', '.webm', '.flac']
const MAX_FILE_SIZE = 25 * 1024 * 1024 // 25MB

export function UploadDialog({ open, onOpenChange }: UploadDialogProps) {
  const { initialize } = useTranscriptionsStore()
  const [file, setFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const { trackFeatureUsed, trackError } = useAnalytics()

  const resetState = useCallback(() => {
    setFile(null)
    setError(null)
    setIsUploading(false)
  }, [])

  const handleOpenChange = useCallback(
    (newOpen: boolean) => {
      if (!newOpen) {
        resetState()
      }
      onOpenChange(newOpen)
    },
    [onOpenChange, resetState]
  )

  const validateFile = (file: File): string | null => {
    const extension = '.' + file.name.split('.').pop()?.toLowerCase()
    if (!SUPPORTED_FORMATS.includes(extension)) {
      return `Unsupported format. Please use: ${SUPPORTED_FORMATS.join(', ')}`
    }
    if (file.size > MAX_FILE_SIZE) {
      return 'File too large. Maximum size is 25MB.'
    }
    return null
  }

  const handleFileSelect = useCallback((selectedFile: File) => {
    const validationError = validateFile(selectedFile)
    if (validationError) {
      setError(validationError)
      return
    }
    setFile(selectedFile)
    setError(null)
  }, [])

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault()
      setIsDragging(false)

      const droppedFile = e.dataTransfer.files[0]
      if (droppedFile) {
        handleFileSelect(droppedFile)
      }
    },
    [handleFileSelect]
  )

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
  }, [])

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const selectedFile = e.target.files?.[0]
      if (selectedFile) {
        handleFileSelect(selectedFile)
      }
    },
    [handleFileSelect]
  )

  const handleUpload = async () => {
    if (!file) return

    setIsUploading(true)
    setError(null)

    try {
      // Read file as array buffer
      const arrayBuffer = await file.arrayBuffer()
      const audioData = Array.from(new Uint8Array(arrayBuffer))

      // Call Tauri command
      const response = await invoke<UploadTranscriptionResponse>(
        'transcribe_uploaded_file',
        {
          request: {
            audioData,
            filename: file.name,
            language: null,
          },
        }
      )

      if (response.success) {
        // Refresh transcriptions list
        await initialize()
        trackFeatureUsed('audio_upload', {
          file_size: file.size,
          file_type: file.name.split('.').pop()?.toLowerCase(),
        })
        handleOpenChange(false)
      } else {
        setError(response.error || 'Failed to transcribe audio file')
        trackError(response.error || 'Failed to transcribe audio file', {
          context: 'audio_upload',
        })
      }
    } catch (err) {
      console.error('Upload error:', err)
      // Tauri errors are returned as strings, not Error objects
      const errorMessage =
        typeof err === 'string'
          ? err
          : err instanceof Error
            ? err.message
            : 'An unexpected error occurred'
      setError(errorMessage)
      trackError(errorMessage, { context: 'audio_upload' })
    } finally {
      setIsUploading(false)
    }
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[420px]">
        <DialogHeader>
          <DialogTitle>Upload Audio</DialogTitle>
          <DialogDescription>
            Upload an audio file to transcribe using your selected model.
          </DialogDescription>
        </DialogHeader>

        <div className="py-2">
          {/* Drop zone */}
          <div
            className={cn(
              'relative rounded-lg transition-all cursor-pointer',
              file
                ? 'border border-border bg-muted/30'
                : 'border-2 border-dashed',
              isDragging
                ? 'border-primary bg-primary/5'
                : !file && 'border-border hover:border-muted-foreground/50'
            )}
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onClick={() => !file && fileInputRef.current?.click()}
          >
            <input
              ref={fileInputRef}
              type="file"
              accept={SUPPORTED_FORMATS.join(',')}
              className="hidden"
              onChange={handleInputChange}
              disabled={isUploading}
            />

            {file ? (
              <div className="flex items-center gap-2 p-3">
                <div className="flex-shrink-0 w-8 h-8 rounded-md bg-muted flex items-center justify-center">
                  <FileAudio className="w-4 h-4 text-muted-foreground" />
                </div>
                <div className="flex-1 min-w-0 overflow-hidden">
                  <p className="text-sm font-medium truncate max-w-[280px]">
                    {file.name}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {formatFileSize(file.size)}
                  </p>
                </div>
                <Button
                  size="icon-sm"
                  variant="ghost"
                  className="flex-shrink-0 h-7 w-7"
                  onClick={e => {
                    e.stopPropagation()
                    setFile(null)
                  }}
                  disabled={isUploading}
                >
                  <X className="w-3.5 h-3.5" />
                </Button>
              </div>
            ) : (
              <div className="text-center py-8 px-4">
                <Upload className="w-6 h-6 mx-auto mb-2 text-muted-foreground/60" />
                <p className="text-sm text-muted-foreground">
                  Drop audio file or{' '}
                  <span className="text-primary font-medium">browse</span>
                </p>
                <p className="text-xs text-muted-foreground/60 mt-1">
                  WAV, MP3, M4A, OGG, WebM, FLAC (max 25MB)
                </p>
              </div>
            )}
          </div>

          {/* Error message */}
          {error && <p className="mt-2 text-xs text-destructive">{error}</p>}
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => handleOpenChange(false)}
            disabled={isUploading}
          >
            Cancel
          </Button>
          <Button onClick={handleUpload} disabled={!file || isUploading}>
            {isUploading ? (
              <>
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                Transcribing...
              </>
            ) : (
              'Transcribe'
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
