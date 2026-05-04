import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/engine_config.dart';

/// 语音翻译服务状态
enum TranslationServiceState {
  idle,
  loading,
  ready,
  translating,
  error,
}

/// 翻译服务
/// 使用 Whisper 的 translate 任务进行语音翻译
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  sherpa_onnx.OfflineRecognizer? _recognizer;
  String? _modelDir;
  String? _lastError;
  static bool _bindingsInitialized = false;

  TranslationServiceState _state = TranslationServiceState.idle;
  final WhisperConfig _config = const WhisperConfig();

  TranslationServiceState get state => _state;
  bool get isLoaded => _recognizer != null;
  String? get modelDir => _modelDir;
  String? get lastError => _lastError;

  /// 加载翻译模型
  /// [modelPathOrDir] 模型路径或目录
  /// [sourceLanguage] 源语言（默认 auto 自动检测）
  Future<bool> loadModel(String modelPathOrDir, {String sourceLanguage = 'auto'}) async {
    await unload();
    _state = TranslationServiceState.loading;
    _lastError = null;

    final resolvedDir = await _resolveModelDir(modelPathOrDir);
    if (resolvedDir == null) {
      _lastError = '未找到有效的 Whisper ONNX 模型目录';
      _state = TranslationServiceState.error;
      return false;
    }

    final modelPaths = await _resolveWhisperModelPaths(resolvedDir);
    if (modelPaths == null) {
      _lastError = 'Whisper ONNX 模型目录不完整';
      _state = TranslationServiceState.error;
      return false;
    }

    _ensureBindings();

    // 设置翻译任务
    final effectiveLanguage = sourceLanguage == 'auto' ? '' : sourceLanguage;

    final config = sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        whisper: sherpa_onnx.OfflineWhisperModelConfig(
          encoder: modelPaths.encoder,
          decoder: modelPaths.decoder,
          language: effectiveLanguage,
          task: 'translate',  // 使用翻译任务
          tailPaddings: _config.tailPaddings,
        ),
        tokens: modelPaths.tokens,
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      ),
    );

    try {
      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      _modelDir = resolvedDir.path;
      _state = TranslationServiceState.ready;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _state = TranslationServiceState.error;
      return false;
    }
  }

  /// 翻译 PCM 音频数据
  /// 返回翻译后的文本
  Future<String?> translatePcm(Uint8List pcmData, int sampleRate) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      _lastError = '翻译模型未加载';
      _state = TranslationServiceState.error;
      return null;
    }

    if (pcmData.isEmpty) return '';

    _state = TranslationServiceState.translating;

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(
        samples: _pcm16LeToFloat32(pcmData),
        sampleRate: sampleRate,
      );
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      _state = TranslationServiceState.ready;
      return result.text.trim();
    } catch (e) {
      _lastError = e.toString();
      _state = TranslationServiceState.error;
      return null;
    } finally {
      stream.free();
    }
  }

  /// 翻译音频文件（支持 WAV 格式）
  Future<String?> translateFile(String filePath) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      _lastError = '翻译模型未加载';
      _state = TranslationServiceState.error;
      return null;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _lastError = '文件不存在: $filePath';
        return null;
      }

      final decoded = await _decodeWavFile(file);
      if (decoded == null) {
        _lastError = '不支持的音频格式，仅支持 WAV 文件';
        return null;
      }

      return translatePcm(decoded.$1, decoded.$2);
    } catch (e) {
      _lastError = e.toString();
      _state = TranslationServiceState.error;
      return null;
    }
  }

  /// 卸载模型
  Future<void> unload() async {
    try {
      _recognizer?.free();
    } catch (_) {
      // ignore
    } finally {
      _recognizer = null;
      _modelDir = null;
      _lastError = null;
      _state = TranslationServiceState.idle;
    }
  }

  /// 预热模型
  Future<bool> warmup() async {
    final recognizer = _recognizer;
    if (recognizer == null) return false;

    try {
      const numSamples = 8000; // 500ms @ 16kHz
      final pcmData = Uint8List(numSamples * 2);
      final floatSamples = _pcm16LeToFloat32(pcmData);

      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(samples: floatSamples, sampleRate: 16000);
        recognizer.decode(stream);
      } finally {
        stream.free();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取状态信息
  Map<String, dynamic> getStatusMap() {
    return {
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelDir': _modelDir,
      'lastError': _lastError,
    };
  }

  void _ensureBindings() {
    if (_bindingsInitialized) return;
    sherpa_onnx.initBindings();
    _bindingsInitialized = true;
  }

  Future<Directory?> _resolveModelDir(String input) async {
    final directFile = File(input);
    if (await directFile.exists()) {
      return directFile.parent;
    }

    final directDir = Directory(input);
    if (await directDir.exists()) {
      return directDir;
    }

    return null;
  }

  Future<_WhisperModelPaths?> _resolveWhisperModelPaths(Directory modelDir) async {
    final encoder = await _pickFirstExistingFile(modelDir, const [
      'tiny-encoder.int8.onnx',
      'tiny-encoder.onnx',
      'encoder.int8.onnx',
      'encoder.onnx',
    ]);
    final decoder = await _pickFirstExistingFile(modelDir, const [
      'tiny-decoder.int8.onnx',
      'tiny-decoder.onnx',
      'decoder.int8.onnx',
      'decoder.onnx',
    ]);
    final tokens = await _pickFirstExistingFile(modelDir, const [
      'tiny-tokens.txt',
      'tokens.txt',
    ]);

    if (encoder == null || decoder == null || tokens == null) {
      return null;
    }

    return _WhisperModelPaths(
      encoder: encoder.path,
      decoder: decoder.path,
      tokens: tokens.path,
    );
  }

  Future<File?> _pickFirstExistingFile(
    Directory dir,
    List<String> names,
  ) async {
    for (final name in names) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Float32List _pcm16LeToFloat32(Uint8List pcmData) {
    final out = Float32List(pcmData.length ~/ 2);
    var outIndex = 0;
    for (var i = 0; i + 1 < pcmData.length; i += 2) {
      final lo = pcmData[i];
      final hi = pcmData[i + 1];
      var sample = (hi << 8) | lo;
      if (sample >= 32768) {
        sample -= 65536;
      }
      out[outIndex++] = sample / 32768.0;
    }
    return out;
  }

  Future<(Uint8List, int)?> _decodeWavFile(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return null;

    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;

    var offset = 12;
    int? audioFormat, sampleRate, bitsPerSample, channels;
    int? dataOffset, dataSize;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize =
          bytes[offset + 4] |
          (bytes[offset + 5] << 8) |
          (bytes[offset + 6] << 16) |
          (bytes[offset + 7] << 24);

      if (chunkId == 'fmt ') {
        audioFormat = bytes[offset + 8] | (bytes[offset + 9] << 8);
        channels = bytes[offset + 10] | (bytes[offset + 11] << 8);
        sampleRate = bytes[offset + 12] |
            (bytes[offset + 13] << 8) |
            (bytes[offset + 14] << 16) |
            (bytes[offset + 15] << 24);
        bitsPerSample = bytes[offset + 22] | (bytes[offset + 23] << 8);
      } else if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = chunkSize;
        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset++;
    }

    if (audioFormat != 1 ||
        bitsPerSample != 16 ||
        dataOffset == null ||
        dataSize == null ||
        sampleRate == null ||
        channels == null) {
      return null;
    }

    var pcmData = bytes.sublist(dataOffset, dataOffset + dataSize);

    // Convert stereo to mono
    if (channels == 2) {
      final mono = Uint8List(pcmData.length ~/ 2);
      for (var i = 0, j = 0; i + 3 < pcmData.length; i += 4, j += 2) {
        final left = pcmData[i] | (pcmData[i + 1] << 8);
        final right = pcmData[i + 2] | (pcmData[i + 3] << 8);
        final avg = ((left + right) ~/ 2);
        mono[j] = avg & 0xFF;
        mono[j + 1] = (avg >> 8) & 0xFF;
      }
      pcmData = mono;
    }

    // Resample to 16kHz if needed
    if (sampleRate != 16000) {
      pcmData = _resampleTo16kHz(pcmData, sampleRate);
      sampleRate = 16000;
    }

    return (pcmData, sampleRate);
  }

  Uint8List _resampleTo16kHz(Uint8List pcm16, int srcRate) {
    if (srcRate == 16000) return pcm16;
    final srcSamples = pcm16.length ~/ 2;
    final dstSamples = (srcSamples * 16000) ~/ srcRate;
    final out = Uint8List(dstSamples * 2);
    for (var i = 0; i < dstSamples; i++) {
      final srcPos = (i * srcRate) / 16000;
      final idx = srcPos.floor();
      final frac = srcPos - idx;
      final s0 = _readSample(pcm16, idx);
      final s1 = _readSample(pcm16, idx + 1);
      final sample = (s0 + (s1 - s0) * frac).round().clamp(-32768, 32767);
      out[i * 2] = sample & 0xFF;
      out[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return out;
  }

  int _readSample(Uint8List pcm, int index) {
    final srcSamples = pcm.length ~/ 2;
    if (index >= srcSamples) index = srcSamples - 1;
    if (index < 0) index = 0;
    final lo = pcm[index * 2];
    final hi = pcm[index * 2 + 1];
    var sample = (hi << 8) | lo;
    if (sample >= 32768) sample -= 65536;
    return sample;
  }
}

class _WhisperModelPaths {
  const _WhisperModelPaths({
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String tokens;
}
