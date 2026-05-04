package com.voices.voices_app

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sanbo.voices/transcription"
    private val DOWNLOAD_CHANNEL = "com.sanbo.voices/download"
    private val DOWNLOAD_EVENT_CHANNEL = "com.sanbo.voices/download_events"

    private lateinit var engine: TranscriptionEngine
    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Download manager
    private var downloadManager: DownloadManager? = null
    private val activeDownloads = ConcurrentHashMap<Long, DownloadCallback>()
    private val downloadHandler = Handler(Looper.getMainLooper())

    // Download receiver
    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action
            if (DownloadManager.ACTION_DOWNLOAD_COMPLETE == action) {
                val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                val callback = activeDownloads.remove(downloadId)
                if (callback != null) {
                    queryDownloadStatus(downloadId, callback)
                }
            }
        }
    }

    data class DownloadCallback(
        val downloadId: Long,
        val destPath: String,
        val onSuccess: (String) -> Unit,
        val onError: (String) -> Unit,
        val onProgress: (Double) -> Unit
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize download manager
        downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

        // Register download receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE), RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        }

        // Transcription engine channel
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
                // Download API
                "startDownload" -> {
                    val downloadId = call.argument<String>("downloadId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "downloadId is required", null)
                    val url = call.argument<String>("url") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "url is required", null)
                    val destPath = call.argument<String>("destPath") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "destPath is required", null)

                    startSystemDownload(downloadId, url, destPath, result)
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<String>("downloadId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "downloadId is required", null)
                    cancelDownload(downloadId)
                    result.success(true)
                }
                "getDownloadStatus" -> {
                    val downloadId = call.argument<String>("downloadId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "downloadId is required", null)
                    getDownloadStatus(downloadId, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startSystemDownload(downloadId: String, url: String, destPath: String, result: MethodChannel.Result) {
        try {
            // Delete existing file if present
            val existingFile = File(destPath)
            if (existingFile.exists()) {
                existingFile.delete()
            }

            // Delete any existing download with same destination
            val query = DownloadManager.Query()
            downloadManager?.let { dm ->
                val cursor = dm.query(query)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
                    val dest = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                    if (dest == "file://$destPath") {
                        dm.remove(id)
                    }
                }
                cursor.close()
            }

            // Create download request
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("Voices Model Download")
                .setDescription("Downloading AI model...")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationUri(Uri.fromFile(File(destPath)))
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)

            // Start download
            val downloadIdLong = downloadManager?.enqueue(request) ?: -1L

            if (downloadIdLong != -1L) {
                // Store callback info - we'll poll for status
                activeDownloads[downloadIdLong] = DownloadCallback(
                    downloadIdLong,
                    destPath,
                    onSuccess = { path -> mainHandler.post { result.success(mapOf("status" to "completed", "path" to path)) } },
                    onError = { error -> mainHandler.post { result.error("DOWNLOAD_ERROR", error, null) } },
                    onProgress = { progress -> /* Progress handled via polling */ }
                )

                // Start polling for progress
                startProgressPolling(downloadIdLong)

                result.success(mapOf("status" to "started", "downloadId" to downloadId))
            } else {
                result.error("DOWNLOAD_ERROR", "Failed to start download", null)
            }
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message, null)
        }
    }

    private fun startProgressPolling(downloadId: Long) {
        downloadHandler.post(object : Runnable {
            override fun run() {
                val callback = activeDownloads[downloadId] ?: return
                val dm = downloadManager ?: return

                val query = DownloadManager.Query().setFilterById(downloadId)
                val cursor = dm.query(query)

                if (cursor.moveToFirst()) {
                    val bytesDownloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    val bytesTotal = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))

                    when (status) {
                        DownloadManager.STATUS_RUNNING -> {
                            if (bytesTotal > 0) {
                                val progress = bytesDownloaded.toDouble() / bytesTotal.toDouble()
                                callback.onProgress(progress)
                            }
                            downloadHandler.postDelayed(this, 500)
                        }
                        DownloadManager.STATUS_SUCCESSFUL -> {
                            callback.onSuccess(callback.destPath)
                        }
                        DownloadManager.STATUS_FAILED -> {
                            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                            callback.onError("Download failed: $reason")
                        }
                        DownloadManager.STATUS_PAUSED -> {
                            downloadHandler.postDelayed(this, 1000)
                        }
                        DownloadManager.STATUS_PENDING -> {
                            downloadHandler.postDelayed(this, 500)
                        }
                    }
                }
                cursor.close()
            }
        })
    }

    private fun queryDownloadStatus(downloadId: Long, callback: DownloadCallback) {
        val dm = downloadManager ?: return
        val query = DownloadManager.Query().setFilterById(downloadId)
        val cursor = dm.query(query)

        if (cursor.moveToFirst()) {
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> {
                    callback.onSuccess(callback.destPath)
                }
                DownloadManager.STATUS_FAILED -> {
                    val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                    callback.onError("Download failed: $reason")
                }
            }
        }
        cursor.close()
    }

    private fun cancelDownload(downloadId: String) {
        // Find and cancel the download
        val query = DownloadManager.Query()
        downloadManager?.let { dm ->
            val cursor = dm.query(query)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
                val description = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_DESCRIPTION))
                if (description == downloadId) {
                    dm.remove(id)
                    activeDownloads.remove(id)
                    break
                }
            }
            cursor.close()
        }
    }

    private fun getDownloadStatus(downloadId: String, result: MethodChannel.Result) {
        val query = DownloadManager.Query()
        downloadManager?.let { dm ->
            val cursor = dm.query(query)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
                val description = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_DESCRIPTION))
                if (description == downloadId) {
                    val bytesDownloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                    val bytesTotal = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                    val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))

                    val statusStr = when (status) {
                        DownloadManager.STATUS_PENDING -> "pending"
                        DownloadManager.STATUS_PAUSED -> "paused"
                        DownloadManager.STATUS_RUNNING -> "running"
                        DownloadManager.STATUS_SUCCESSFUL -> "completed"
                        DownloadManager.STATUS_FAILED -> "failed"
                        else -> "unknown"
                    }

                    val progress = if (bytesTotal > 0) bytesDownloaded.toDouble() / bytesTotal.toDouble() else 0.0

                    cursor.close()
                    result.success(mapOf(
                        "status" to statusStr,
                        "progress" to progress,
                        "bytesDownloaded" to bytesDownloaded,
                        "bytesTotal" to bytesTotal
                    ))
                    return
                }
            }
            cursor.close()
        }
        result.success(mapOf("status" to "not_found", "progress" to 0.0))
    }

    override fun onDestroy() {
        worker.shutdownNow()
        if (::engine.isInitialized) {
            engine.close()
        }
        try {
            unregisterReceiver(downloadReceiver)
        } catch (e: Exception) {
            // Receiver not registered
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
