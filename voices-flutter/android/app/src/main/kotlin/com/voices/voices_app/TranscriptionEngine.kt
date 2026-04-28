package com.voices.voices_app

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import com.whispercpp.whisper.WhisperContext
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min

class TranscriptionEngine(private val context: Context) {
    private var isLoaded = false
    private var currentModel: String? = null
    private var modelResolvedPath: String? = null
    private var voskModel: Model? = null
    private var whisperContext: WhisperContext? = null
    private var mode: EngineMode = EngineMode.DEMO
    private var currentEngineType: String = ENGINE_VOSK
    private var transcribeCount = 0
    private var transcribeErrorCount = 0
    private var transcribeTotalMs = 0L
    private var transcribeMaxMs = 0L

    companion object {
        private const val TAG = "TranscriptionEngine"
        private const val ENGINE_VOSK = "vosk"
        private const val ENGINE_WHISPER = "whisper"

        private val MODEL_ASSET_ROOTS = listOf(
            "flutter_assets/assets/models",
            "assets/models",
            "models"
        )
    }

    private enum class EngineMode {
        VOSK,
        WHISPER,
        DEMO
    }

    fun loadModel(modelPath: String): Boolean = loadModel(ENGINE_VOSK, modelPath)

    fun loadModel(engineType: String, modelPath: String): Boolean {
        close()
        val normalizedEngine = engineType.trim().lowercase()
        currentEngineType = normalizedEngine

        return try {
            Log.d(TAG, "Loading model. engine=$normalizedEngine path=$modelPath")
            when (normalizedEngine) {
                ENGINE_VOSK -> loadVoskModel(modelPath)
                ENGINE_WHISPER -> loadWhisperModel(modelPath)
                else -> {
                    Log.e(TAG, "Unsupported engine type: $normalizedEngine")
                    false
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadModel failed: ${e.message}", e)
            false
        }
    }

    fun transcribe(audioData: FloatArray, sampleRate: Int): String {
        if (!isLoaded) {
            return "Error: 模型未加载"
        }
        if (audioData.isEmpty()) {
            return ""
        }

        val pcmBytes = floatToPcm16Le(audioData)
        return transcribePcm(pcmBytes, sampleRate)
    }

    fun transcribePcm(pcmData: ByteArray, sampleRate: Int): String {
        if (!isLoaded) {
            return "Error: 模型未加载"
        }
        if (pcmData.isEmpty()) {
            return ""
        }

        val startNs = System.nanoTime()
        var text = ""
        var hasError = false
        try {
            text = when (mode) {
                EngineMode.VOSK -> transcribeWithVoskBytes(pcmData, sampleRate)
                EngineMode.WHISPER -> transcribeWithWhisperBytes(pcmData, sampleRate)
                EngineMode.DEMO -> "Error: 当前模型已加载，但尚未接入该模型的原生推理内核"
            }
            hasError = text.startsWith("Error:")
            return text
        } finally {
            val costMs = (System.nanoTime() - startNs) / 1_000_000
            transcribeCount += 1
            transcribeTotalMs += costMs
            if (costMs > transcribeMaxMs) {
                transcribeMaxMs = costMs
            }
            if (hasError) {
                transcribeErrorCount += 1
            }

            if (transcribeCount % 10 == 0) {
                val avgMs = if (transcribeCount == 0) 0 else transcribeTotalMs / transcribeCount
                Log.i(
                    TAG,
                    "stats engine=$currentEngineType count=$transcribeCount err=$transcribeErrorCount " +
                        "avgMs=$avgMs maxMs=$transcribeMaxMs pcmBytes=${pcmData.size} textLen=${text.length}"
                )
            }
        }
    }

    fun transcribeFile(filePath: String): String {
        if (!isLoaded) {
            return "Error: 模型未加载"
        }

        val file = File(filePath)
        if (!file.exists()) {
            return "Error: 文件不存在: $filePath"
        }

        val pcmData = decodeAudioToPcm(filePath)
        if (pcmData == null || pcmData.isEmpty()) {
            return "Error: 无法解码音频文件: $filePath"
        }

        return transcribePcm(pcmData, 16000)
    }

    private fun decodeAudioToPcm(filePath: String): ByteArray? {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(filePath)

            // Find audio track
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || audioFormat == null) {
                Log.e(TAG, "No audio track found in file: $filePath")
                return null
            }

            extractor.selectTrack(audioTrackIndex)

            val sampleRate = try {
                audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } catch (e: Exception) {
                44100
            }
            val channelCount = try {
                audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } catch (e: Exception) {
                1
            }

            // For simplicity, use a basic decoder approach
            // For more formats, consider using MediaCodec directly
            val pcmData = decodeWithMediaCodec(extractor, audioFormat)

            if (pcmData != null && sampleRate != 16000) {
                // Resample to 16kHz if needed
                val floatAudio = pcm16LeToFloat(pcmData)
                val resampled = resampleLinear(floatAudio, sampleRate, 16000)
                return floatToPcm16Le(resampled)
            }

            pcmData
        } catch (e: Exception) {
            Log.e(TAG, "Error decoding audio file: ${e.message}", e)
            null
        } finally {
            extractor.release()
        }
    }

    private fun decodeWithMediaCodec(extractor: MediaExtractor, format: MediaFormat): ByteArray? {
        val mime = format.getString(MediaFormat.KEY_MIME) ?: return null

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        val pcmChunks = mutableListOf<ByteArray>()

        var inputDone = false
        var outputDone = false

        try {
            while (!outputDone) {
                // Feed input
                if (!inputDone) {
                    val inputBufferIndex = codec.dequeueInputBuffer(10000)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                        if (inputBuffer != null) {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inputBufferIndex, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputDone = true
                            } else {
                                val presentationTime = extractor.sampleTime
                                codec.queueInputBuffer(
                                    inputBufferIndex, 0, sampleSize,
                                    presentationTime, 0
                                )
                                extractor.advance()
                            }
                        }
                    }
                }

                // Get output
                val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outputBufferIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputBufferIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.get(chunk)
                        pcmChunks.add(chunk)
                    }
                    codec.releaseOutputBuffer(outputBufferIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }

        // Combine all chunks
        return if (pcmChunks.isNotEmpty()) {
            val totalSize = pcmChunks.sumOf { it.size }
            val result = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN)
            for (chunk in pcmChunks) {
                result.put(chunk)
            }
            result.array()
        } else {
            null
        }
    }

    fun statusMap(): Map<String, Any?> {
        return mapOf(
            "loaded" to isLoaded,
            "engineType" to currentEngineType,
            "model" to currentModel,
            "modelResolvedPath" to modelResolvedPath,
            "mode" to mode.name.lowercase(),
        )
    }

    private fun loadVoskModel(modelPath: String): Boolean {
        val resolvedDir = resolveModelDir(modelPath)
        if (resolvedDir == null) {
            Log.e(TAG, "Vosk model directory not found: $modelPath")
            return false
        }

        val modelDir = File(resolvedDir)
        if (!hasVoskStructure(modelDir)) {
            Log.e(TAG, "Invalid Vosk model structure: $resolvedDir")
            return false
        }

        voskModel = Model(resolvedDir)
        mode = EngineMode.VOSK
        isLoaded = true
        currentModel = modelPath
        modelResolvedPath = resolvedDir
        Log.i(TAG, "Vosk model loaded: $resolvedDir")
        return true
    }

    private fun loadWhisperModel(modelPath: String): Boolean {
        val resolvedFile = resolveWhisperModelFile(modelPath)
        if (resolvedFile == null) {
            Log.e(TAG, "Whisper model file not found: $modelPath")
            return false
        }

        whisperContext = WhisperContext.createContextFromFile(resolvedFile.absolutePath)
        mode = EngineMode.WHISPER
        isLoaded = true
        currentModel = modelPath
        modelResolvedPath = resolvedFile.absolutePath
        Log.i(TAG, "Whisper model loaded: ${resolvedFile.absolutePath}")
        return true
    }

    private fun transcribeWithVoskBytes(pcmData: ByteArray, sampleRate: Int): String {
        val model = voskModel ?: return "Error: Vosk 模型未初始化"

        // 小于 250ms 的音频通常噪声较大，直接忽略（16-bit mono）。
        if (pcmData.size < (sampleRate / 4) * 2) {
            return ""
        }

        var recognizer: Recognizer? = null
        return try {
            recognizer = Recognizer(model, sampleRate.toFloat())
            recognizer.acceptWaveForm(pcmData, pcmData.size)

            val finalText = extractText(recognizer.finalResult, "text")
            if (finalText.isNotEmpty()) {
                return finalText
            }

            extractText(recognizer.partialResult, "partial")
        } catch (e: Exception) {
            Log.e(TAG, "transcribeWithVosk failed: ${e.message}", e)
            "Error: ${e.message}"
        } finally {
            recognizer?.close()
        }
    }

    private fun transcribeWithWhisperBytes(pcmData: ByteArray, sampleRate: Int): String {
        val ctx = whisperContext ?: return "Error: Whisper 模型未初始化"

        val input = pcm16LeToFloat(pcmData)
        if (input.isEmpty()) return ""

        val mono16k = if (sampleRate == 16000) {
            input
        } else {
            resampleLinear(input, sampleRate, 16000)
        }

        if (mono16k.isEmpty()) return ""

        return try {
            runBlocking {
                ctx.transcribeData(mono16k, printTimestamp = false)
                    .replace("\n", " ")
                    .trim()
            }
        } catch (e: Exception) {
            Log.e(TAG, "transcribeWithWhisper failed: ${e.message}", e)
            "Error: ${e.message}"
        }
    }

    private fun resolveWhisperModelFile(modelPath: String): File? {
        val direct = File(modelPath)
        if (direct.exists()) {
            if (isWhisperModelFile(direct)) {
                return direct
            }
            if (direct.isDirectory) {
                findWhisperBinInDir(direct)?.let { return it }
            }
        }

        val candidates = mutableListOf<File>()
        val aliases = listOf(modelPath, "whisper-tiny")
        for (alias in aliases) {
            candidates.add(File(context.filesDir, "models/$alias"))
            candidates.add(File(context.cacheDir, "models/$alias"))
            context.getExternalFilesDir(null)?.let { candidates.add(File(it, "models/$alias")) }
            candidates.add(File("/storage/emulated/0/voices/models/$alias"))
        }

        for (candidate in candidates) {
            if (candidate.exists()) {
                if (isWhisperModelFile(candidate)) return candidate
                if (candidate.isDirectory) {
                    findWhisperBinInDir(candidate)?.let { return it }
                }
            }
        }

        val assetCandidates = listOf(
            "whisper-tiny/ggml-tiny.bin",
            "whisper-tiny"
        )

        for (root in MODEL_ASSET_ROOTS) {
            for (assetModelPath in assetCandidates) {
                val assetPath = "$root/$assetModelPath"
                if (assetPathExists(assetPath)) {
                    if (assetModelPath.endsWith(".bin")) {
                        val target = File(context.filesDir, "models/$assetModelPath")
                        copyAssetFile(assetPath, target)
                        if (target.exists() && target.isFile) {
                            return target
                        }
                    } else {
                        val targetDir = File(context.filesDir, "models/$assetModelPath")
                        copyAssetDir(assetPath, targetDir)
                        findWhisperBinInDir(targetDir)?.let { return it }
                    }
                }
            }
        }

        return null
    }

    private fun resolveModelDir(modelPath: String): String? {
        val direct = File(modelPath)
        if (direct.exists() && direct.isDirectory) {
            return direct.absolutePath
        }

        val candidates = mutableListOf<File>()
        candidates.add(File(context.filesDir, "models/$modelPath"))
        candidates.add(File(context.cacheDir, "models/$modelPath"))
        context.getExternalFilesDir(null)?.let {
            candidates.add(File(it, "models/$modelPath"))
        }
        candidates.add(File("/storage/emulated/0/voices/models/$modelPath"))

        for (candidate in candidates) {
            if (candidate.exists() && candidate.isDirectory) {
                return candidate.absolutePath
            }
        }

        for (root in MODEL_ASSET_ROOTS) {
            val assetPath = "$root/$modelPath"
            if (assetPathExists(assetPath)) {
                val target = File(context.filesDir, "models/$modelPath")
                copyAssetDir(assetPath, target)
                if (target.exists() && target.isDirectory) {
                    Log.i(TAG, "Resolved model from assets root: $root")
                    return target.absolutePath
                }
            }
        }

        return null
    }

    private fun findWhisperBinInDir(dir: File): File? {
        if (!dir.exists() || !dir.isDirectory) return null
        val files = dir.listFiles() ?: return null
        val preferred = files.firstOrNull { it.isFile && it.name == "ggml-tiny.bin" }
        if (preferred != null) return preferred
        val fallback = files.firstOrNull { isWhisperModelFile(it) }
        if (fallback != null) return fallback

        for (f in files) {
            if (f.isDirectory) {
                val nested = findWhisperBinInDir(f)
                if (nested != null) return nested
            }
        }
        return null
    }

    private fun isWhisperModelFile(file: File): Boolean {
        if (!file.isFile) return false
        val name = file.name.lowercase()
        return name.startsWith("ggml") && name.endsWith(".bin")
    }

    private fun assetPathExists(path: String): Boolean {
        if (path.endsWith(".bin")) {
            return try {
                context.assets.open(path).close()
                true
            } catch (_: Exception) {
                false
            }
        }

        return try {
            val children = context.assets.list(path)
            children != null && children.isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }

    private fun copyAssetDir(assetPath: String, outDir: File) {
        val children = context.assets.list(assetPath) ?: emptyArray()
        if (!outDir.exists()) {
            outDir.mkdirs()
        }
        for (child in children) {
            val childAssetPath = "$assetPath/$child"
            val childOut = File(outDir, child)
            val grandChildren = context.assets.list(childAssetPath) ?: emptyArray()
            if (grandChildren.isEmpty()) {
                copyAssetFile(childAssetPath, childOut)
            } else {
                copyAssetDir(childAssetPath, childOut)
            }
        }
    }

    private fun copyAssetFile(assetPath: String, outFile: File): Boolean {
        if (outFile.exists() && outFile.length() > 0L) {
            return true
        }
        return try {
            outFile.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input ->
                outFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "copyAssetFile failed: $assetPath -> ${outFile.absolutePath}: ${e.message}")
            false
        }
    }

    private fun hasVoskStructure(dir: File): Boolean {
        return File(dir, "am/final.mdl").exists() &&
            File(dir, "conf/model.conf").exists()
    }

    private fun floatToPcm16Le(audioData: FloatArray): ByteArray {
        val buffer = ByteBuffer.allocate(audioData.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (sample in audioData) {
            val clamped = sample.coerceIn(-1.0f, 1.0f)
            val pcm = (clamped * Short.MAX_VALUE).toInt().toShort()
            buffer.putShort(pcm)
        }
        return buffer.array()
    }

    private fun pcm16LeToFloat(pcmData: ByteArray): FloatArray {
        if (pcmData.size < 2) return FloatArray(0)
        val out = FloatArray(pcmData.size / 2)
        var j = 0
        var i = 0
        while (i + 1 < pcmData.size) {
            val lo = pcmData[i].toInt() and 0xFF
            val hi = pcmData[i + 1].toInt()
            val sample = ((hi shl 8) or lo).toShort()
            out[j++] = sample / 32768.0f
            i += 2
        }
        return out
    }

    private fun resampleLinear(input: FloatArray, inputRate: Int, outputRate: Int): FloatArray {
        if (input.isEmpty() || inputRate <= 0 || outputRate <= 0) return FloatArray(0)
        if (inputRate == outputRate) return input

        val outputLength = max(1, (input.size.toLong() * outputRate / inputRate).toInt())
        val output = FloatArray(outputLength)
        val ratio = inputRate.toDouble() / outputRate.toDouble()

        for (i in 0 until outputLength) {
            val srcPos = i * ratio
            val idx = srcPos.toInt()
            val frac = (srcPos - idx).toFloat()
            val idx2 = min(idx + 1, input.size - 1)
            val s1 = input[idx]
            val s2 = input[idx2]
            output[i] = s1 + (s2 - s1) * frac
        }

        return output
    }

    private fun extractText(json: String?, key: String): String {
        if (json.isNullOrBlank()) return ""
        return try {
            JSONObject(json).optString(key, "").trim()
        } catch (_: Exception) {
            ""
        }
    }

    fun close() {
        try {
            voskModel?.close()
        } catch (_: Exception) {
        } finally {
            voskModel = null
        }

        try {
            val ctx = whisperContext
            if (ctx != null) {
                runBlocking {
                    ctx.release()
                }
            }
        } catch (_: Exception) {
        } finally {
            whisperContext = null
        }

        isLoaded = false
        currentModel = null
        modelResolvedPath = null
        mode = EngineMode.DEMO
        transcribeCount = 0
        transcribeErrorCount = 0
        transcribeTotalMs = 0L
        transcribeMaxMs = 0L
    }

    fun isLoaded(): Boolean = isLoaded
}
