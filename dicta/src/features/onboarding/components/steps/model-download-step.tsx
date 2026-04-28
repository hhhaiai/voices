import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { Download, Check, AlertCircle, ArrowRight } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'

import { Button } from '@/components/ui/button'

import {
  TranscriptionModel,
  useModelsStore,
  initializeModels,
} from '../../../models'
import { useOnboarding } from '../../hooks/use-onboarding'

interface DownloadProgress {
  downloaded: number
  total: number
  percentage: number
  modelId: string
}

export function ModelDownloadStep() {
  const { completeCurrentStepAndGoNext, markStepComplete } = useOnboarding()
  const { selectModel, startLocalModel } = useModelsStore()
  const [isDownloading, setIsDownloading] = useState(false)
  const [isDownloaded, setIsDownloaded] = useState(false)
  const [progress, setProgress] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [downloadedMB, setDownloadedMB] = useState(0)
  const [totalMB, setTotalMB] = useState(75)
  const hasStartedModelRef = useRef(false)

  const checkIfDownloaded = useCallback(async () => {
    try {
      await initializeModels()
      const { models } = useModelsStore.getState()
      const tinyModel = models.find(m => m.id === 'whisper-tiny')
      if (tinyModel?.isDownloaded) {
        setIsDownloaded(true)
        markStepComplete('model-download')

        if (!hasStartedModelRef.current) {
          hasStartedModelRef.current = true
          if (!tinyModel.isSelected) {
            await selectModel('whisper-tiny')
          } else if (tinyModel.status === 'stopped') {
            await startLocalModel('whisper-tiny')
          }
        }
      }
    } catch (err) {
      console.error('Failed to check model status:', err)
    }
  }, [markStepComplete, selectModel, startLocalModel])

  useEffect(() => {
    checkIfDownloaded()

    const unlisten = listen<DownloadProgress>(
      'local-model-download-progress',
      event => {
        const { downloaded, total, percentage, modelId } = event.payload
        if (modelId === 'whisper-tiny') {
          setProgress(percentage)
          setDownloadedMB(Math.round(downloaded / 1024 / 1024))
          setTotalMB(Math.round(total / 1024 / 1024))

          if (percentage >= 100) {
            setIsDownloaded(true)
            setIsDownloading(false)
            markStepComplete('model-download')

            if (!hasStartedModelRef.current) {
              hasStartedModelRef.current = true
              setTimeout(async () => {
                try {
                  await initializeModels()
                  const { models } = useModelsStore.getState()
                  const tinyModel = models.find(m => m.id === 'whisper-tiny')
                  if (tinyModel && !tinyModel.isSelected) {
                    await selectModel('whisper-tiny')
                  }
                } catch (err) {
                  console.error(
                    'Failed to select/start model after download:',
                    err
                  )
                }
              }, 500)
            }
          }
        }
      }
    )

    return () => {
      unlisten.then(fn => fn())
    }
  }, [markStepComplete, checkIfDownloaded, selectModel, startLocalModel])

  const handleDownload = async () => {
    setIsDownloading(true)
    setError(null)
    setProgress(0)

    try {
      const models = await invoke<TranscriptionModel[]>('get_all_models')
      const tinyModel = models.find(m => m.id === 'whisper-tiny')

      if (
        !tinyModel ||
        !tinyModel.downloadUrl ||
        !tinyModel.filename ||
        !tinyModel.engine
      ) {
        throw new Error('Model configuration not found')
      }

      await invoke('download_local_model', {
        modelId: tinyModel.id,
        downloadUrl: tinyModel.downloadUrl,
        filename: tinyModel.filename,
        engineType: tinyModel.engine,
      })
    } catch (err) {
      console.error('Download failed:', err)
      setError(err instanceof Error ? err.message : 'Download failed')
      setIsDownloading(false)
    }
  }

  const handleContinue = () => {
    if (isDownloaded) {
      completeCurrentStepAndGoNext()
    }
  }

  return (
    <div className="flex flex-col items-center text-center">
      {/* Icon */}
      <div className="mb-8">
        <div
          className={`
            flex items-center justify-center w-20 h-20 rounded-2xl
            transition-colors duration-300
            ${
              isDownloaded
                ? 'bg-primary/10 border border-primary/30'
                : 'bg-zinc-900 border border-zinc-800'
            }
          `}
        >
          {isDownloaded ? (
            <Check className="w-8 h-8 text-primary" strokeWidth={2} />
          ) : (
            <Download
              className={`w-8 h-8 ${isDownloading ? 'text-primary' : 'text-muted-foreground'}`}
              strokeWidth={1.5}
            />
          )}
        </div>
      </div>

      {/* Title */}
      <h1 className="text-3xl font-semibold tracking-tight mb-3">
        Download AI Model
      </h1>

      {/* Subtitle */}
      <p className="text-muted-foreground mb-6 max-w-sm">
        Get Whisper Tiny for fast, private transcription directly on your
        device.
      </p>

      {/* Model info */}
      <div className="flex items-center gap-2 text-sm text-muted-foreground mb-8">
        <span className="font-medium text-foreground">Whisper Tiny</span>
        <span className="text-zinc-600">·</span>
        <span>75 MB</span>
        <span className="text-zinc-600">·</span>
        <span>Fast & lightweight</span>
      </div>

      {/* Progress section */}
      {isDownloading && (
        <div className="w-full max-w-sm mb-8">
          <div className="flex justify-between text-sm mb-2">
            <span className="text-muted-foreground">Downloading...</span>
            <span className="text-foreground font-medium">
              {downloadedMB} / {totalMB} MB
            </span>
          </div>
          <div className="h-2 rounded-full bg-zinc-800 overflow-hidden">
            <div
              className="h-full bg-primary rounded-full transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
          <p className="text-xs text-muted-foreground mt-2">
            {progress.toFixed(0)}% complete
          </p>
        </div>
      )}

      {/* Error */}
      {error && !isDownloaded && (
        <div className="flex items-start gap-3 p-4 rounded-xl bg-red-500/10 border border-red-500/20 mb-8 max-w-sm text-left">
          <AlertCircle className="w-5 h-5 text-red-400 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-red-400">Download failed</p>
            <p className="text-xs text-red-400/70 mt-1">{error}</p>
          </div>
        </div>
      )}

      {/* Success message */}
      {isDownloaded && (
        <div className="flex items-center gap-2 mb-8 text-sm">
          <Check className="w-4 h-4 text-primary" strokeWidth={2.5} />
          <span className="text-primary font-medium">Model ready</span>
          <span className="text-muted-foreground">·</span>
          <span className="text-muted-foreground">Whisper Tiny installed</span>
        </div>
      )}

      {/* Features */}
      {!isDownloading && !isDownloaded && (
        <div className="flex items-center justify-center gap-6 mb-8 text-sm text-muted-foreground">
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>Runs Locally</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>100% Private</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-primary" />
            <span>No API Costs</span>
          </div>
        </div>
      )}

      {/* CTA */}
      <Button
        onClick={isDownloaded ? handleContinue : handleDownload}
        disabled={isDownloading}
        className="h-11 px-6 bg-primary hover:bg-primary/90 text-primary-foreground font-medium"
      >
        {isDownloaded ? (
          <>
            Continue
            <ArrowRight className="w-4 h-4 ml-2" />
          </>
        ) : isDownloading ? (
          'Downloading...'
        ) : error ? (
          'Try Again'
        ) : (
          <>
            Download Model
            <span className="text-primary-foreground/60 font-normal ml-2">
              75 MB
            </span>
          </>
        )}
      </Button>
    </div>
  )
}
