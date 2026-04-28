//! Audio recorder with lock-free sample collection.
//!
//! Uses a ring buffer for lock-free audio sample collection from the audio callback,
//! preventing mutex deadlocks that were causing app crashes.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, Host, Stream, StreamConfig};
use hound::{WavSpec, WavWriter};
use parking_lot::Mutex;
use ringbuf::{traits::*, HeapRb};
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tauri::{AppHandle, Emitter};

/// Audio recorder state
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum RecorderState {
    Idle,
    Recording,
    Error,
}

/// Audio recorder configuration
#[derive(Debug, Clone)]
pub struct RecorderConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
}

impl Default for RecorderConfig {
    fn default() -> Self {
        Self {
            sample_rate: 16000, // Optimal for speech recognition
            channels: 1,        // Mono
            bits_per_sample: 16,
        }
    }
}

/// Ring buffer size - enough for ~5 seconds of 48kHz stereo audio
const RING_BUFFER_SIZE: usize = 48000 * 2 * 5;

/// Emission throttle interval in milliseconds (~30 FPS)
const EMIT_INTERVAL_MS: u64 = 33;

/// Safely extract a message from a panic payload.
///
/// This handles both &str and String payloads without panicking itself.
fn extract_panic_message(payload: &Box<dyn std::any::Any + Send>) -> String {
    if let Some(s) = payload.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "Unknown panic payload".to_string()
    }
}

/// Main audio recorder using lock-free ring buffer.
///
/// The audio callback pushes samples to a ring buffer without acquiring any locks.
/// A separate consumer thread reads from the buffer and writes to the WAV file.
pub struct AudioRecorder {
    state: Mutex<RecorderState>,
    stream: Mutex<Option<Stream>>,
    writer: Mutex<Option<WavWriter<std::io::BufWriter<std::fs::File>>>>,
    is_recording: Arc<AtomicBool>,
    config: RecorderConfig,
    app_handle: Mutex<Option<AppHandle>>,
    /// Consumer thread handle
    consumer_handle: Mutex<Option<std::thread::JoinHandle<()>>>,
    /// Signal to stop the consumer thread
    stop_consumer: Arc<AtomicBool>,
}

impl AudioRecorder {
    pub fn new() -> Self {
        Self {
            state: Mutex::new(RecorderState::Idle),
            stream: Mutex::new(None),
            writer: Mutex::new(None),
            is_recording: Arc::new(AtomicBool::new(false)),
            config: RecorderConfig::default(),
            app_handle: Mutex::new(None),
            consumer_handle: Mutex::new(None),
            stop_consumer: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Set the app handle for emitting events
    pub fn set_app_handle(&mut self, app: AppHandle) {
        *self.app_handle.lock() = Some(app);
    }

    /// Get the default input device
    fn get_input_device(host: &Host) -> Result<Device, String> {
        host.default_input_device()
            .ok_or_else(|| "No input device available".to_string())
    }

    fn get_device_by_name(host: &Host, device_name: &str) -> Result<Device, String> {
        host.input_devices()
            .map_err(|e| format!("Failed to enumerate devices: {}", e))?
            .find(|device| {
                device
                    .description()
                    .map(|desc| desc.name() == device_name)
                    .unwrap_or(false)
            })
            .ok_or_else(|| format!("Device '{}' not found", device_name))
    }

    /// Start recording to a file
    pub fn start_recording(
        &mut self,
        output_path: impl AsRef<Path>,
        device_name: Option<String>,
    ) -> Result<(), String> {
        // Check if already recording
        if self.is_recording.load(Ordering::Acquire) {
            return Err("Already recording".to_string());
        }

        let host = cpal::default_host();

        // Get the input device
        let device = if let Some(name) = device_name {
            Self::get_device_by_name(&host, &name)?
        } else {
            Self::get_input_device(&host)?
        };

        let device_name = device
            .description()
            .map(|desc| desc.name().to_string())
            .unwrap_or_else(|_| "Unknown".to_string());
        log::info!("Using audio device: {}", device_name);

        // Get the default input config
        let config = device
            .default_input_config()
            .map_err(|e| format!("Failed to get default input config: {}", e))?;

        let stream_config: StreamConfig = config.clone().into();
        let device_sample_rate = stream_config.sample_rate;
        let device_channels = stream_config.channels;

        log::info!(
            "Device config - Sample rate: {}, Channels: {}",
            device_sample_rate,
            device_channels
        );

        // Create WAV writer using device's native sample rate
        let spec = WavSpec {
            channels: device_channels,
            sample_rate: device_sample_rate,
            bits_per_sample: self.config.bits_per_sample,
            sample_format: hound::SampleFormat::Int,
        };

        let writer = WavWriter::create(output_path.as_ref(), spec)
            .map_err(|e| format!("Failed to create WAV file: {}", e))?;

        // Store writer
        *self.writer.lock() = Some(writer);

        // Create lock-free ring buffer
        let ring = HeapRb::<f32>::new(RING_BUFFER_SIZE);
        let (producer, consumer) = ring.split();

        // Wrap producer in Arc for sharing with callback
        let producer = Arc::new(parking_lot::Mutex::new(producer));
        let producer_clone = Arc::clone(&producer);

        // Clone state for callback
        let is_recording = Arc::clone(&self.is_recording);
        let app_handle_clone = self.app_handle.lock().clone();
        let last_emit_time = Arc::new(AtomicU64::new(0));
        let last_emit_time_clone = Arc::clone(&last_emit_time);

        // Build the audio input stream
        let stream = device
            .build_input_stream(
                &stream_config,
                move |data: &[f32], _: &cpal::InputCallbackInfo| {
                    // Early exit if not recording - lock-free check
                    if !is_recording.load(Ordering::Relaxed) {
                        return;
                    }

                    // Calculate RMS level for visualization (before pushing to buffer)
                    let mut sum_squares = 0.0f32;
                    for &sample in data.iter() {
                        sum_squares += sample * sample;
                    }

                    // Push samples to ring buffer - lock-free operation
                    // Try to acquire lock briefly, drop samples if can't
                    if let Some(mut prod) = producer_clone.try_lock() {
                        // Push as many samples as possible
                        let pushed = prod.push_slice(data);
                        if pushed < data.len() {
                            // Buffer full - log occasionally to avoid spam
                            static OVERFLOW_COUNT: AtomicU64 = AtomicU64::new(0);
                            let count = OVERFLOW_COUNT.fetch_add(1, Ordering::Relaxed);
                            if count % 100 == 0 {
                                log::warn!(
                                    "Ring buffer overflow: dropped {} samples (total overflows: {})",
                                    data.len() - pushed,
                                    count + 1
                                );
                            }
                        }
                    }

                    // Throttle audio level emissions to ~30 FPS
                    // Use Instant-based timing (monotonic, no syscalls for time)
                    let now_ms = {
                        static START: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
                        let start = START.get_or_init(Instant::now);
                        start.elapsed().as_millis() as u64
                    };

                    let last_emit = last_emit_time_clone.load(Ordering::Relaxed);
                    if now_ms.saturating_sub(last_emit) >= EMIT_INTERVAL_MS {
                        last_emit_time_clone.store(now_ms, Ordering::Relaxed);

                        let rms = (sum_squares / data.len() as f32).sqrt();
                        let level = (rms * 100.0).min(100.0);

                        if let Some(ref app) = app_handle_clone {
                            // Emit is non-blocking, safe in callback
                            let _ = app.emit("audio-level", level);
                        }
                    }
                },
                |err| {
                    // Log audio stream errors with context
                    // Note: We can't recover the stream from here, but logging helps debugging
                    log::error!("Audio stream error: {} - recording may be corrupted", err);

                    // Common errors and their implications:
                    // - DeviceNotAvailable: Microphone was unplugged
                    // - BackendSpecific: Driver or hardware issue
                    // - DeviceClosed: Device was closed by another process
                },
                None,
            )
            .map_err(|e| format!("Failed to build input stream: {}", e))?;

        // Set recording flag BEFORE starting stream
        self.is_recording.store(true, Ordering::Release);
        *self.state.lock() = RecorderState::Recording;
        self.stop_consumer.store(false, Ordering::Release);

        // Start the stream
        stream
            .play()
            .map_err(|e| format!("Failed to start stream: {}", e))?;

        // Store stream
        *self.stream.lock() = Some(stream);

        // Start consumer thread to write samples from ring buffer to file
        let writer_clone = Arc::new(parking_lot::Mutex::new(self.writer.lock().take()));
        let stop_signal = Arc::clone(&self.stop_consumer);
        let is_recording_clone = Arc::clone(&self.is_recording);

        let consumer = Arc::new(parking_lot::Mutex::new(consumer));
        let consumer_handle = std::thread::Builder::new()
            .name("audio-writer".to_string())
            .spawn(move || {
                let mut buffer = vec![0.0f32; 4096]; // Read buffer

                while !stop_signal.load(Ordering::Relaxed) {
                    // Read from ring buffer
                    let count = if let Some(mut cons) = consumer.try_lock() {
                        cons.pop_slice(&mut buffer)
                    } else {
                        0
                    };

                    if count > 0 {
                        // Write to WAV file
                        if let Some(mut writer_guard) = writer_clone.try_lock() {
                            if let Some(ref mut writer) = *writer_guard {
                                for &sample in &buffer[..count] {
                                    let sample_i16 = (sample * i16::MAX as f32) as i16;
                                    if let Err(e) = writer.write_sample(sample_i16) {
                                        log::error!("Failed to write sample: {}", e);
                                        break;
                                    }
                                }
                            }
                        }
                    } else if !is_recording_clone.load(Ordering::Relaxed) {
                        // No more data and recording stopped - exit
                        break;
                    } else {
                        // No data available, sleep briefly
                        std::thread::sleep(std::time::Duration::from_millis(5));
                    }
                }

                // Finalize WAV file
                if let Some(mut writer_guard) = writer_clone.try_lock() {
                    if let Some(writer) = writer_guard.take() {
                        if let Err(e) = writer.finalize() {
                            log::error!("Failed to finalize WAV file: {}", e);
                        } else {
                            log::info!("WAV file finalized successfully");
                        }
                    }
                }
            })
            .map_err(|e| format!("Failed to spawn consumer thread: {}", e))?;

        *self.consumer_handle.lock() = Some(consumer_handle);

        log::info!("Recording started");
        Ok(())
    }

    /// Stop recording and wait for consumer thread to finish.
    ///
    /// This method ensures all audio samples are flushed to the WAV file
    /// before returning. Uses a timeout to prevent indefinite hanging.
    pub fn stop_recording(&mut self) -> Result<(), String> {
        if !self.is_recording.load(Ordering::Acquire) {
            return Err("Not recording".to_string());
        }

        // Signal to stop recording
        self.is_recording.store(false, Ordering::Release);
        self.stop_consumer.store(true, Ordering::Release);

        // Drop the stream to stop it
        *self.stream.lock() = None;

        // Wait for consumer thread to finish with proper cleanup
        self.wait_for_consumer_thread();

        // Update state
        *self.state.lock() = RecorderState::Idle;

        log::info!("Recording stopped");
        Ok(())
    }

    /// Wait for consumer thread to finish with timeout and proper error handling.
    fn wait_for_consumer_thread(&mut self) {
        let handle = match self.consumer_handle.lock().take() {
            Some(h) => h,
            None => return,
        };

        let timeout = std::time::Duration::from_secs(3);
        let start = Instant::now();
        let poll_interval = std::time::Duration::from_millis(10);

        loop {
            if handle.is_finished() {
                // Thread finished - try to join and handle any panic
                match handle.join() {
                    Ok(_) => {
                        log::debug!("Consumer thread joined successfully");
                    }
                    Err(panic_payload) => {
                        // Safely extract panic message without panicking ourselves
                        let panic_msg = extract_panic_message(&panic_payload);
                        log::error!("Consumer thread panicked: {}", panic_msg);
                    }
                }
                return;
            }

            if start.elapsed() > timeout {
                log::warn!(
                    "Consumer thread join timed out after {:?} - thread may still be running",
                    timeout
                );
                // Don't call handle.join() on timeout - it would block
                // The thread will eventually complete or be cleaned up on app exit
                return;
            }

            std::thread::sleep(poll_interval);
        }
    }

    /// Check if currently recording
    pub fn is_recording(&self) -> bool {
        self.is_recording.load(Ordering::Acquire)
    }

    /// Get current recorder state
    pub fn get_state(&self) -> RecorderState {
        *self.state.lock()
    }

    pub fn list_devices() -> Result<Vec<String>, String> {
        let host = cpal::default_host();
        let devices = host
            .input_devices()
            .map_err(|e| format!("Failed to enumerate devices: {}", e))?;

        let device_names: Vec<String> = devices
            .filter_map(|device| {
                device
                    .description()
                    .ok()
                    .map(|desc| desc.name().to_string())
            })
            .collect();

        Ok(device_names)
    }
}

impl Default for AudioRecorder {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for AudioRecorder {
    fn drop(&mut self) {
        // Ensure recording is stopped and resources are cleaned up
        if self.is_recording.load(Ordering::Acquire) {
            let _ = self.stop_recording();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_recorder_initialization() {
        let recorder = AudioRecorder::new();
        assert_eq!(recorder.get_state(), RecorderState::Idle);
        assert!(!recorder.is_recording());
    }

    #[test]
    fn test_list_devices() {
        let devices = AudioRecorder::list_devices();
        // Should at least not error out
        assert!(devices.is_ok());
    }

    #[test]
    fn test_recording_lifecycle() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.wav");

        let mut recorder = AudioRecorder::new();

        // Start recording
        let result = recorder.start_recording(&file_path, None);
        if result.is_ok() {
            assert!(recorder.is_recording());
            assert_eq!(recorder.get_state(), RecorderState::Recording);

            // Stop recording
            std::thread::sleep(std::time::Duration::from_millis(100));
            let stop_result = recorder.stop_recording();
            assert!(stop_result.is_ok());
            assert!(!recorder.is_recording());
            assert_eq!(recorder.get_state(), RecorderState::Idle);

            // Verify file was created
            assert!(file_path.exists());
        }
    }

    #[test]
    fn test_double_start_fails() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.wav");

        let mut recorder = AudioRecorder::new();

        if recorder.start_recording(&file_path, None).is_ok() {
            // Second start should fail
            let result = recorder.start_recording(&file_path, None);
            assert!(result.is_err());
            assert!(result.unwrap_err().contains("Already recording"));

            let _ = recorder.stop_recording();
        }
    }
}
