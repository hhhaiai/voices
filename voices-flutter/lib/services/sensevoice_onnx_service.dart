import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/engine_config.dart';
import '../utils/sensevoice_metadata_fixer.dart';

class SenseVoiceOnnxService {
  static final SenseVoiceOnnxService _instance =
      SenseVoiceOnnxService._internal();
  factory SenseVoiceOnnxService() => _instance;
  SenseVoiceOnnxService._internal();

  sherpa_onnx.OfflineRecognizer? _recognizer;
  String? _modelPath;
  String? _tokensPath;
  String? _lastError;
  static bool _bindingsInitialized = false;
  SenseVoiceConfig _config = const SenseVoiceConfig();

  bool get isLoaded => _recognizer != null;
  String? get modelPath => _modelPath;
  String? get tokensPath => _tokensPath;
  String? get lastError => _lastError;
  SenseVoiceConfig get config => _config;

  Future<bool> loadModel(String modelPathOrDir, {SenseVoiceConfig? engineConfig}) async {
    await unload();
    _lastError = null;
    _config = engineConfig ?? const SenseVoiceConfig();

    final resolved = await _resolveModelAndTokens(modelPathOrDir);
    if (resolved == null) {
      _lastError = '未找到有效的 SenseVoice ONNX 模型或 tokens 文件';
      return false;
    }

    var modelPath = resolved.modelPath;

    // 兼容性预检：检查是否已包含必需 metadata。
    var compatible = await _looksLikeSherpaSenseVoiceModel(modelPath);
    if (!compatible) {
      // 尝试自动修复：注入缺失的 SenseVoice metadata。
      final fixedPath = await _tryAutoFix(modelPath);
      if (fixedPath != null) {
        modelPath = fixedPath;
        compatible = true;
      } else {
        final missingKeys =
            await SenseVoiceMetadataFixer.getMissingKeys(modelPath);
        _lastError =
            '当前模型不是 sherpa-onnx SenseVoice 可加载格式\n'
            '缺少 metadata: ${missingKeys.join(", ")}\n'
            '请使用 model_sherpa.onnx 或运行 fix_model.py 修复';
        return false;
      }
    }

    _ensureBindings();

    final config = sherpa_onnx.OfflineRecognizerConfig(
      model: sherpa_onnx.OfflineModelConfig(
        senseVoice: sherpa_onnx.OfflineSenseVoiceModelConfig(
          model: modelPath,
          language: _config.language,
          useInverseTextNormalization: _config.useInverseTextNormalization,
        ),
        tokens: resolved.tokensPath,
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      ),
    );

    try {
      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      _modelPath = modelPath;
      _tokensPath = resolved.tokensPath;
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
      return 'Error: SenseVoice 模型未加载';
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
      return 'Error: SenseVoice 模型未加载';
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

  /// 尝试自动修复 SenseVoice ONNX 模型。
  ///
  /// 优先查找同目录下的 model_sherpa.onnx（已修复版本），
  /// 如果不存在则尝试注入缺失 metadata 到临时文件。
  Future<String?> _tryAutoFix(String brokenModelPath) async {
    final brokenFile = File(brokenModelPath);
    if (!await brokenFile.exists()) return null;

    // 策略 1：查找同目录或兄弟目录的 model_sherpa.onnx。
    final parentDir = brokenFile.parent;
    final sherpaInSameDir = File('${parentDir.path}/model_sherpa.onnx');
    if (await sherpaInSameDir.exists()) {
      return sherpaInSameDir.path;
    }
    // 检查兄弟目录 sensevoice/。
    final siblingSenseVoice =
        Directory('${parentDir.parent.path}/sensevoice');
    if (await siblingSenseVoice.exists()) {
      final sherpaInSibling =
          File('${siblingSenseVoice.path}/model_sherpa.onnx');
      if (await sherpaInSibling.exists()) return sherpaInSibling.path;
    }

    // 策略 2：尝试注入缺失 metadata 到临时文件。
    try {
      final supportDir = await getApplicationSupportDirectory();
      final fixDir = Directory('${supportDir.path}/sensevoice_fixed');
      final fixedPath = await SenseVoiceMetadataFixer.fixModel(
        onnxPath: brokenModelPath,
        outputDir: fixDir.path,
      );
      return fixedPath;
    } catch (_) {
      return null;
    }
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

  Future<_SenseVoiceResolvedModel?> _resolveModelAndTokens(String input) async {
    final modelFile = await _resolveModelFile(input);
    if (modelFile == null || !await modelFile.exists()) {
      return null;
    }

    final tokensPath = await _resolveTokensPath(modelFile.parent);
    if (tokensPath == null) {
      return null;
    }

    return _SenseVoiceResolvedModel(
      modelPath: modelFile.path,
      tokensPath: tokensPath,
    );
  }

  Future<File?> _resolveModelFile(String input) async {
    final direct = File(input);
    if (await direct.exists()) {
      if (_isOnnxFile(direct)) {
        return direct;
      }
    }

    final dir = Directory(input);
    if (await dir.exists()) {
      final candidate = await _findOnnxModelInDir(dir);
      if (candidate != null) {
        return candidate;
      }
    }

    final fallbackDirs = <Directory>[
      Directory('/storage/emulated/0/Android/data/com.sanbo.voices/files/models/sensevoice-onnx'),
      Directory('/storage/emulated/0/Android/data/com.sanbo.voices/files/models/sensevoice_onnx'),
    ];

    final docsDir = await getApplicationDocumentsDirectory();
    fallbackDirs.add(Directory('${docsDir.path}/models/sensevoice-onnx'));
    fallbackDirs.add(Directory('${docsDir.path}/models/sensevoice_onnx'));

    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      fallbackDirs.add(Directory('${extDir.path}/models/sensevoice-onnx'));
      fallbackDirs.add(Directory('${extDir.path}/models/sensevoice_onnx'));
    }

    for (final d in fallbackDirs) {
      if (await d.exists()) {
        final candidate = await _findOnnxModelInDir(d);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  Future<File?> _findOnnxModelInDir(Directory dir) async {
    final deterministicCandidates = <String>[
      'model_sherpa.onnx',
      'model_quant.onnx',
      'model.int8.fixed.onnx',
      'model.int8.onnx',
      'model.onnx',
    ];

    for (final name in deterministicCandidates) {
      final candidate = File('${dir.path}/$name');
      if (await candidate.exists()) {
        return candidate;
      }
    }

    final children = dir.listSync(followLinks: false);
    for (final child in children) {
      if (child is File && _isOnnxFile(child)) {
        return child;
      }
    }

    return null;
  }

  bool _isOnnxFile(File file) {
    return file.path.toLowerCase().endsWith('.onnx');
  }

  Future<String?> _resolveTokensPath(Directory modelDir) async {
    final txt = File('${modelDir.path}/tokens.txt');
    if (await txt.exists()) {
      return txt.path;
    }

    final json = File('${modelDir.path}/tokens.json');
    if (await json.exists()) {
      return _convertTokensJsonToTxt(json);
    }

    final sibling = Directory('${modelDir.parent.path}/sensevoice');
    final siblingTxt = File('${sibling.path}/tokens.txt');
    if (await siblingTxt.exists()) {
      return siblingTxt.path;
    }

    final siblingJson = File('${sibling.path}/tokens.json');
    if (await siblingJson.exists()) {
      return _convertTokensJsonToTxt(siblingJson);
    }

    return null;
  }

  Future<String?> _convertTokensJsonToTxt(File tokensJsonFile) async {
    try {
      final raw = await tokensJsonFile.readAsString();
      final list = jsonDecode(raw);
      if (list is! List) return null;
      final tokens = list.map((e) => e.toString()).toList();

      final supportDir = await getApplicationSupportDirectory();
      final outDir = Directory('${supportDir.path}/sensevoice');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final outFile = File('${outDir.path}/tokens.generated.txt');
      await outFile.writeAsString(tokens.join('\n'));
      return outFile.path;
    } catch (_) {
      return null;
    }
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

  Future<bool> _looksLikeSherpaSenseVoiceModel(String onnxPath) async {
    final file = File(onnxPath);
    if (!await file.exists()) return false;

    // sherpa-onnx 1.12.x 读取的是 lfr_window_size/lfr_window_shift，
    // 而不是旧代码中误判的 window_size/shift_size。
    const commonKeys = <String>[
      'vocab_size',
      'normalize_samples',
      'lfr_window_size',
      'lfr_window_shift',
    ];
    const standardSenseVoiceKeys = <String>[
      'with_itn',
      'without_itn',
      'lang_auto',
      'lang_zh',
      'lang_en',
      'lang_ja',
      'lang_ko',
      'lang_yue',
      'neg_mean',
      'inv_stddev',
    ];

    for (final key in commonKeys) {
      final ok = await _fileContainsAsciiPattern(file, key);
      if (!ok) {
        return false;
      }
    }

    for (final key in standardSenseVoiceKeys) {
      final ok = await _fileContainsAsciiPattern(file, key);
      if (!ok) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _fileContainsAsciiPattern(File file, String pattern) async {
    final needle = pattern.codeUnits;
    if (needle.isEmpty) return true;

    var carry = <int>[];
    await for (final chunk in file.openRead()) {
      final data = Uint8List(carry.length + chunk.length);
      data.setRange(0, carry.length, carry);
      data.setRange(carry.length, data.length, chunk);

      if (_containsSubList(data, needle)) {
        return true;
      }

      final keep = needle.length - 1;
      if (keep > 0) {
        final start = data.length - keep;
        carry = data.sublist(start < 0 ? 0 : start);
      } else {
        carry = <int>[];
      }
    }
    return false;
  }

  bool _containsSubList(Uint8List data, List<int> needle) {
    if (needle.length > data.length) return false;
    final last = data.length - needle.length;
    for (var i = 0; i <= last; i++) {
      var ok = true;
      for (var j = 0; j < needle.length; j++) {
        if (data[i + j] != needle[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }
}

class _SenseVoiceResolvedModel {
  const _SenseVoiceResolvedModel({
    required this.modelPath,
    required this.tokensPath,
  });

  final String modelPath;
  final String tokensPath;
}
