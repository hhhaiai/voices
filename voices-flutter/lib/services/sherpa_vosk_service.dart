import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/engine_config.dart';

class SherpaVoskService {
  static final SherpaVoskService _instance = SherpaVoskService._internal();
  factory SherpaVoskService() => _instance;
  SherpaVoskService._internal();

  sherpa_onnx.OfflineRecognizer? _recognizer;
  String? _modelPath;
  String? _tokensPath;
  String? _lastError;
  static bool _bindingsInitialized = false;
  VoskConfig _config = const VoskConfig();

  bool get isLoaded => _recognizer != null;
  String? get modelPath => _modelPath;
  String? get tokensPath => _tokensPath;
  String? get lastError => _lastError;
  VoskConfig get config => _config;

  Future<bool> loadModel(String modelPathOrDir, {VoskConfig? engineConfig}) async {
    await unload();
    _lastError = null;
    _config = engineConfig ?? const VoskConfig();

    final resolvedDir = await _resolveModelDir(modelPathOrDir);
    if (resolvedDir == null) {
      _lastError =
          '未找到有效的 Vosk ONNX 模型目录（需包含 model.onnx/encoder/decoder/joiner 与 tokens.txt）';
      return false;
    }

    final modelPaths = await _resolveVoskModelPaths(resolvedDir);
    if (modelPaths == null) {
      _lastError =
          'Vosk ONNX 模型目录不完整，缺少 paraformer/transducer 模型文件或 tokens.txt';
      return false;
    }

    _ensureBindings();

    final config = sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        paraformer: sherpa_onnx.OfflineParaformerModelConfig(
          model: modelPaths.model,
        ),
        transducer: sherpa_onnx.OfflineTransducerModelConfig(
          encoder: modelPaths.encoder,
          decoder: modelPaths.decoder,
          joiner: modelPaths.joiner,
        ),
        tokens: modelPaths.tokens,
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      ),
    );

    try {
      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      _modelPath = modelPaths.model.isNotEmpty
          ? modelPaths.model
          : '${modelPaths.encoder}|${modelPaths.decoder}|${modelPaths.joiner}';
      _tokensPath = modelPaths.tokens;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _recognizer = null;
      _modelPath = null;
      _tokensPath = null;
      return false;
    }
  }

  Future<String> transcribePcm(Uint8List pcmData, int sampleRate) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      if (_lastError != null && _lastError!.isNotEmpty) {
        return 'Error: $_lastError';
      }
      return 'Error: Vosk ONNX 模型未加载';
    }
    if (pcmData.isEmpty) return '';

    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(
        samples: _pcm16LeToFloat32(pcmData),
        sampleRate: sampleRate,
      );
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      return result.text.trim();
    } catch (e) {
      return 'Error: $e';
    } finally {
      stream.free();
    }
  }

  /// 转写音频文件（支持 WAV 格式）
  Future<String> transcribeFile(String filePath) async {
    final recognizer = _recognizer;
    if (recognizer == null) {
      if (_lastError != null && _lastError!.isNotEmpty) {
        return 'Error: $_lastError';
      }
      return 'Error: Vosk ONNX 模型未加载';
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'Error: 文件不存在: $filePath';
      }

      final decoded = await _decodeWavFile(file);
      if (decoded == null) {
        return 'Error: 不支持的音频格式，仅支持 WAV 文件';
      }

      return transcribePcm(decoded.$1, decoded.$2);
    } catch (e) {
      return 'Error: 文件转写失败: $e';
    }
  }

  /// 解码 WAV 文件，返回 (PCM 16-bit LE bytes, sampleRate)
  Future<(Uint8List, int)?> _decodeWavFile(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return null;

    // RIFF header
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;

    // Find fmt and data chunks
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

  Future<void> unload() async {
    try {
      _recognizer?.free();
    } catch (_) {
      // ignore
    } finally {
      _recognizer = null;
      _modelPath = null;
      _tokensPath = null;
      _lastError = null;
    }
  }

  Map<String, dynamic> statusMap() {
    return {
      'loaded': isLoaded,
      'modelPath': _modelPath,
      'tokensPath': _tokensPath,
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

  Future<_VoskModelPaths?> _resolveVoskModelPaths(Directory modelDir) async {
    final tokens = File('${modelDir.path}/tokens.txt');
    if (!await tokens.exists()) {
      return null;
    }

    final paraformer = await _pickFirstExistingFile(modelDir, const [
      'model.int8.onnx',
      'model.onnx',
    ]);
    if (paraformer != null) {
      return _VoskModelPaths(
        model: paraformer.path,
        encoder: '',
        decoder: '',
        joiner: '',
        tokens: tokens.path,
      );
    }

    final encoder = await _pickFirstExistingFile(modelDir, const [
      'encoder.int8.onnx',
      'encoder.onnx',
    ]);
    final decoder = await _pickFirstExistingFile(modelDir, const [
      'decoder.int8.onnx',
      'decoder.onnx',
    ]);
    final joiner = await _pickFirstExistingFile(modelDir, const [
      'joiner.int8.onnx',
      'joiner.onnx',
    ]);

    if (encoder == null || decoder == null || joiner == null) {
      return null;
    }

    return _VoskModelPaths(
      model: '',
      encoder: encoder.path,
      decoder: decoder.path,
      joiner: joiner.path,
      tokens: tokens.path,
    );
  }

  Future<File?> _pickFirstExistingFile(Directory dir, List<String> names) async {
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
}

class _VoskModelPaths {
  const _VoskModelPaths({
    required this.model,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });

  final String model;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
}
