import { Mic } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useAudioDevices } from '@/hooks/use-audio-devices'
import { useAudioRecording } from '@/hooks/use-audio-recording'

import { useSettingsStore } from '../store'

export function MicrophoneSelector() {
  const { devices } = useAudioDevices()
  const { settings, setMicrophoneDevice } = useSettingsStore()
  const { isActive: isRecordingActive } = useAudioRecording()
  const selectedDeviceId = settings.voiceInput.microphoneDeviceId

  const handleSelectDevice = async (deviceId: string) => {
    // Don't allow changes while recording is active
    if (isRecordingActive) return
    await setMicrophoneDevice(deviceId === 'auto-detect' ? null : deviceId)
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild disabled={isRecordingActive}>
        <Button
          variant="outline"
          className="gap-2 max-w-[300px]"
          disabled={isRecordingActive}
        >
          <Mic className="h-4 w-4 shrink-0" />
          <span className="truncate">
            {isRecordingActive
              ? 'Recording in progress...'
              : 'Select microphone'}
          </span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-[300px]">
        <DropdownMenuRadioGroup
          value={selectedDeviceId || 'auto-detect'}
          onValueChange={handleSelectDevice}
        >
          {/* Auto-detect option */}
          <DropdownMenuRadioItem value="auto-detect">
            <div className="flex flex-col">
              <span>
                Auto-detect{' '}
                {devices.find(d => d.isDefault || d.isRecommended) && (
                  <span className="text-muted-foreground">
                    ({devices.find(d => d.isDefault || d.isRecommended)?.label})
                  </span>
                )}
              </span>
            </div>
          </DropdownMenuRadioItem>

          {/* Individual devices */}
          {devices.map(device => (
            <DropdownMenuRadioItem
              key={device.deviceId}
              value={device.deviceId}
            >
              <div className="flex flex-col">
                <span>
                  {device.label ||
                    `Microphone ${device.deviceId.substring(0, 8)}`}
                  {device.isRecommended && (
                    <span className="ml-2 text-xs text-muted-foreground">
                      (recommended)
                    </span>
                  )}
                </span>
              </div>
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
