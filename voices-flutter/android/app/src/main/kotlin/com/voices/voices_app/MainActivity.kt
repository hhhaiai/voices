package com.voices.voices_app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sanbo.voices/transcription"
    private lateinit var engine: TranscriptionEngine
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        engine = TranscriptionEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Unified Engine API
                "engineLoad" -> {
                    val engineType = call.argument<String>("engineType") ?: "vosk"
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "modelPath is required", null)
                    } else {
                        runInWorker(result) {
                            engine.loadModel(engineType, modelPath)
                        }
                    }
                }
                "engineTranscribePcm" -> {
                    val pcmData = call.argument<ByteArray>("pcmData")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    if (pcmData == null) {
                        result.error("INVALID_ARGUMENT", "pcmData is required", null)
                    } else {
                        runInWorker(result) {
                            engine.transcribePcm(pcmData, sampleRate)
                        }
                    }
                }
                "engineTranscribeFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    } else {
                        runInWorker(result) {
                            engine.transcribeFile(filePath)
                        }
                    }
                }
                "engineTranscribe" -> {
                    val audioData = call.argument<List<Double>>("audioData")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    if (audioData == null) {
                        result.error("INVALID_ARGUMENT", "audioData is required", null)
                    } else {
                        val floatData = audioData.map { it.toFloat() }.toFloatArray()
                        runInWorker(result) {
                            engine.transcribe(floatData, sampleRate)
                        }
                    }
                }
                "engineUnload" -> {
                    runInWorker(result) {
                        engine.close()
                        true
                    }
                }
                "engineStatus" -> {
                    result.success(engine.statusMap())
                }

                // Backward-compatible old API
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null) {
                        runInWorker(result) {
                            engine.loadModel("vosk", modelPath)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "modelPath is required", null)
                    }
                }
                "transcribe" -> {
                    val audioData = call.argument<List<Double>>("audioData")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000

                    if (audioData != null) {
                        val floatData = audioData.map { it.toFloat() }.toFloatArray()
                        runInWorker(result) {
                            engine.transcribe(floatData, sampleRate)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "audioData is required", null)
                    }
                }
                "transcribePcm" -> {
                    val pcmData = call.argument<ByteArray>("pcmData")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000

                    if (pcmData != null) {
                        runInWorker(result) {
                            engine.transcribePcm(pcmData, sampleRate)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "pcmData is required", null)
                    }
                }
                "isModelLoaded" -> {
                    result.success(engine.isLoaded())
                }
                "unloadModel" -> {
                    runInWorker(result) {
                        engine.close()
                        true
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        if (::engine.isInitialized) {
            engine.close()
        }
        super.onDestroy()
    }

    private fun runInWorker(result: MethodChannel.Result, task: () -> Any?) {
        worker.execute {
            try {
                val value = task()
                mainHandler.post {
                    result.success(value)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("ENGINE_ERROR", e.message, null)
                }
            }
        }
    }
}
