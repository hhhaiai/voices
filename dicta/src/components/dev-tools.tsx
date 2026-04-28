import { Bug } from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'

import { UpdateModal } from './update-modal'

type UpdateTestStatus = 'available' | 'downloading' | 'ready'

export function DevTools() {
  const [open, setOpen] = useState(false)

  // Update modal test states
  const [showUpdateModal, setShowUpdateModal] = useState(false)
  const [updateStatus, setUpdateStatus] =
    useState<UpdateTestStatus>('available')
  const [downloadProgress, setDownloadProgress] = useState(0)

  const testUpdateAvailable = () => {
    setUpdateStatus('available')
    setDownloadProgress(0)
    setShowUpdateModal(true)
  }

  const testUpdateDownloading = () => {
    setUpdateStatus('downloading')
    setDownloadProgress(0)
    setShowUpdateModal(true)

    // Simulate download progress
    let progress = 0
    const interval = setInterval(() => {
      progress += 10
      setDownloadProgress(progress)
      if (progress >= 100) {
        clearInterval(interval)
        setUpdateStatus('ready')
      }
    }, 500)
  }

  const testUpdateReady = () => {
    setUpdateStatus('ready')
    setDownloadProgress(100)
    setShowUpdateModal(true)
  }

  return (
    <>
      {/* Floating button */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger asChild>
          <Button
            variant="outline"
            size="icon"
            className="fixed bottom-4 left-4 z-50 h-10 w-10 rounded-full shadow-lg border-border/50 bg-background/80 backdrop-blur-sm hover:bg-accent"
          >
            <Bug className="h-4 w-4" />
          </Button>
        </DialogTrigger>

        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Dev Tools</DialogTitle>
            <DialogDescription>
              Test components and features during development.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-6 py-4">
            {/* Update Modal Tests */}
            <div className="space-y-3">
              <h3 className="text-sm font-medium">Update Modal</h3>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={testUpdateAvailable}
                >
                  Available
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={testUpdateDownloading}
                >
                  Downloading
                </Button>
                <Button variant="outline" size="sm" onClick={testUpdateReady}>
                  Ready
                </Button>
              </div>
            </div>

            {/* Add more test sections here */}
            <div className="space-y-3">
              <h3 className="text-sm font-medium">Toast Notifications</h3>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    toast.success('Success message', {
                      description: 'This is a success toast',
                    })
                  }}
                >
                  Success
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    toast.error('Error message', {
                      description: 'This is an error toast',
                    })
                  }}
                >
                  Error
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    const id = toast.loading('Loading...', {
                      description: 'Please wait',
                    })
                    setTimeout(() => {
                      toast.dismiss(id)
                    }, 3000)
                  }}
                >
                  Loading
                </Button>
              </div>
            </div>

            {/* Theme test */}
            <div className="space-y-3">
              <h3 className="text-sm font-medium">Quick Actions</h3>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    document.documentElement.classList.toggle('dark')
                  }}
                >
                  Toggle Theme
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    localStorage.clear()
                    window.location.reload()
                  }}
                >
                  Clear Storage
                </Button>
              </div>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Update Modal for testing */}
      <UpdateModal
        open={showUpdateModal}
        onOpenChange={setShowUpdateModal}
        version="1.2.3"
        status={updateStatus}
        downloadProgress={downloadProgress}
      />
    </>
  )
}
