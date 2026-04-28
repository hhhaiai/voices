import 'dart:io';

/// 模型格式类型。
enum ModelFormat {
  /// Whisper GGML 格式（Android whisper.cpp）。
  whisperGgml,

  /// Whisper ONNX 格式（iOS/macOS sherpa-onnx）。
  whisperOnnx,

  /// Whisper PyTorch 格式（需要转换）。
  whisperPytorch,

  /// Vosk Kaldi 原生格式（Android vosk-android）。
  voskKaldi,

  /// Vosk ONNX 格式（iOS/macOS sherpa-onnx）。
  voskOnnx,

  /// SenseVoice ONNX 格式（sherpa-onnx 兼容）。
  senseVoiceOnnx,

  /// SenseVoice ONNX 格式（缺少 metadata，需要修复）。
  senseVoiceOnnxBroken,

  /// 未知格式。
  unknown,
}

/// 平台兼容性。
enum PlatformCompatibility {
  /// 当前平台可用。
  available,

  /// 当前平台不可用，需要转换。
  needsConversion,

  /// 当前平台不支持此格式。
  notSupported,
}

/// 模型格式检测报告。
class ModelFormatReport {
  const ModelFormatReport({
    required this.path,
    required this.format,
    required this.engineId,
    required this.isCompatible,
    required this.platformCompat,
    this.issues = const [],
    this.suggestions = const [],
    this.details,
  });

  /// 模型路径。
  final String path;

  /// 检测到的格式。
  final ModelFormat format;

  /// 对应的引擎 ID。
  final String engineId;

  /// 是否可直接加载。
  final bool isCompatible;

  /// 当前平台兼容性。
  final PlatformCompatibility platformCompat;

  /// 发现的问题列表。
  final List<String> issues;

  /// 修复建议。
  final List<String> suggestions;

  /// 附加详情。
  final String? details;

  /// 获取人类可读的格式名称。
  String get formatName {
    switch (format) {
      case ModelFormat.whisperGgml:
        return 'Whisper GGML';
      case ModelFormat.whisperOnnx:
        return 'Whisper ONNX';
      case ModelFormat.whisperPytorch:
        return 'Whisper PyTorch';
      case ModelFormat.voskKaldi:
        return 'Vosk Kaldi';
      case ModelFormat.voskOnnx:
        return 'Vosk ONNX';
      case ModelFormat.senseVoiceOnnx:
        return 'SenseVoice ONNX';
      case ModelFormat.senseVoiceOnnxBroken:
        return 'SenseVoice ONNX (需修复)';
      case ModelFormat.unknown:
        return '未知格式';
    }
  }

  /// 获取兼容性状态图标。
  String get statusIcon {
    if (isCompatible) return '✅';
    if (platformCompat == PlatformCompatibility.needsConversion) return '⚠️';
    return '❌';
  }
}

/// 模型格式检测器。
///
/// 自动检测目录中的模型文件格式，并提供兼容性报告和修复建议。
class ModelFormatDetector {
  ModelFormatDetector._();

  /// 检测目录中的模型格式。
  static Future<ModelFormatReport?> detect(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      final file = File(path);
      if (await file.exists()) {
        return _detectSingleFile(file);
      }
      return null;
    }

    // 检测目录中的模型。
    return _detectDirectory(dir);
  }

  /// 扫描外部模型目录，返回所有检测到的模型报告。
  static Future<List<ModelFormatReport>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final reports = <ModelFormatReport>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final report = await _detectDirectory(entity);
        if (report != null) {
          reports.add(report);
        }
      }
    }
    return reports;
  }

  /// 检测单个目录。
  static Future<ModelFormatReport?> _detectDirectory(Directory dir) async {
    final dirName = dir.path.split(Platform.pathSeparator).last;

    // SenseVoice 检测。
    if (_isSenseVoiceDir(dirName)) {
      return _detectSenseVoice(dir);
    }

    // Whisper 检测。
    if (_isWhisperDir(dirName)) {
      return _detectWhisper(dir);
    }

    // Vosk 检测。
    if (_isVoskDir(dirName)) {
      return _detectVosk(dir);
    }

    // 通用检测：检查目录中的文件。
    return _detectGeneric(dir);
  }

  /// SenseVoice 格式检测。
  static Future<ModelFormatReport> _detectSenseVoice(Directory dir) async {
    // 查找模型文件。
    final modelFile = await _findSenseVoiceModelFile(dir);
    if (modelFile == null) {
      return ModelFormatReport(
        path: dir.path,
        format: ModelFormat.unknown,
        engineId: 'sensevoice_onnx',
        isCompatible: false,
        platformCompat: PlatformCompatibility.notSupported,
        issues: ['未找到 ONNX 模型文件'],
        suggestions: ['请确保目录包含 model.onnx 或 model_sherpa.onnx'],
      );
    }

    // 检查 tokens。
    final hasTokens = await _hasTokens(dir);

    // 检查 metadata 兼容性。
    final isSherpaCompatible =
        await _isSenseVoiceSherpaCompatible(modelFile);

    if (isSherpaCompatible && hasTokens) {
      return ModelFormatReport(
        path: modelFile.path,
        format: ModelFormat.senseVoiceOnnx,
        engineId: 'sensevoice_onnx',
        isCompatible: true,
        platformCompat: PlatformCompatibility.available,
        details: '文件: ${modelFile.path.split(Platform.pathSeparator).last}',
      );
    }

    final issues = <String>[];
    final suggestions = <String>[];

    if (!hasTokens) {
      issues.add('缺少 tokens.txt 或 tokens.json');
      suggestions.add('请确保目录包含 tokens 文件');
    }

    if (!isSherpaCompatible) {
      issues.add('模型缺少 sherpa-onnx 所需的 SenseVoice metadata');
      final fileName = modelFile.path.split(Platform.pathSeparator).last;
      if (fileName == 'model.onnx' || fileName == 'model_quant.onnx') {
        // 检查是否有 model_sherpa.onnx。
        final sherpa = File('${dir.path}/model_sherpa.onnx');
        if (await sherpa.exists()) {
          suggestions.add('发现 model_sherpa.onnx，将自动使用修复版本');
        } else {
          suggestions.add('请下载 sherpa-onnx 兼容版本的 SenseVoice 模型');
          suggestions.add('或使用 fix_model.py 为当前模型注入 metadata');
        }
      }
    }

    return ModelFormatReport(
      path: modelFile.path,
      format:
          isSherpaCompatible
              ? ModelFormat.senseVoiceOnnx
              : ModelFormat.senseVoiceOnnxBroken,
      engineId: 'sensevoice_onnx',
      isCompatible: isSherpaCompatible && hasTokens,
      platformCompat:
          isSherpaCompatible
              ? PlatformCompatibility.available
              : PlatformCompatibility.needsConversion,
      issues: issues,
      suggestions: suggestions,
      details: '文件: ${modelFile.path.split(Platform.pathSeparator).last}',
    );
  }

  /// Whisper 格式检测。
  static Future<ModelFormatReport> _detectWhisper(Directory dir) async {
    // 检查 GGML 格式。
    final ggmlFile = await _findGgmlFile(dir);
    if (ggmlFile != null) {
      return ModelFormatReport(
        path: ggmlFile.path,
        format: ModelFormat.whisperGgml,
        engineId: 'whisper',
        isCompatible: Platform.isAndroid,
        platformCompat:
            Platform.isAndroid
                ? PlatformCompatibility.available
                : PlatformCompatibility.needsConversion,
        issues:
            Platform.isAndroid
                ? []
                : ['GGML 格式仅支持 Android，iOS/macOS 需要 ONNX 格式'],
        suggestions:
            Platform.isAndroid
                ? []
                : [
                    '请下载 sherpa-onnx Whisper ONNX 模型（encoder/decoder/tokens）',
                  ],
        details: '文件: ${ggmlFile.path.split(Platform.pathSeparator).last}',
      );
    }

    // 检查 ONNX 格式。
    if (await _isWhisperOnnxDir(dir)) {
      return ModelFormatReport(
        path: dir.path,
        format: ModelFormat.whisperOnnx,
        engineId: 'whisper',
        isCompatible: !Platform.isAndroid,
        platformCompat:
            Platform.isAndroid
                ? PlatformCompatibility.needsConversion
                : PlatformCompatibility.available,
        issues:
            Platform.isAndroid
                ? ['ONNX 格式仅支持 iOS/macOS，Android 需要 GGML 格式']
                : [],
        suggestions:
            Platform.isAndroid
                ? ['请下载 ggml 格式的 Whisper 模型']
                : [],
      );
    }

    // 检查 PyTorch 格式。
    if (await _isWhisperPytorchDir(dir)) {
      return ModelFormatReport(
        path: dir.path,
        format: ModelFormat.whisperPytorch,
        engineId: 'whisper',
        isCompatible: false,
        platformCompat: PlatformCompatibility.needsConversion,
        issues: ['PyTorch 格式不能直接加载，需要转换'],
        suggestions: [
          'Android: 使用 whisper.cpp 的 convert-pt-to-ggml.py 转换为 GGML',
          'iOS/macOS: 使用 sherpa-onnx 的 export-onnx.py 转换为 ONNX',
          '或直接下载已转换好的模型文件',
        ],
      );
    }

    return ModelFormatReport(
      path: dir.path,
      format: ModelFormat.unknown,
      engineId: 'whisper',
      isCompatible: false,
      platformCompat: PlatformCompatibility.notSupported,
      issues: ['未找到有效的 Whisper 模型文件'],
    );
  }

  /// Vosk 格式检测。
  static Future<ModelFormatReport> _detectVosk(Directory dir) async {
    // 检查 Kaldi 格式。
    final hasReadme = await File('${dir.path}/README').exists();
    final hasMdl = await File('${dir.path}/am/final.mdl').exists();

    if (hasReadme || hasMdl) {
      return ModelFormatReport(
        path: dir.path,
        format: ModelFormat.voskKaldi,
        engineId: 'vosk',
        isCompatible: Platform.isAndroid,
        platformCompat:
            Platform.isAndroid
                ? PlatformCompatibility.available
                : PlatformCompatibility.needsConversion,
        issues:
            Platform.isAndroid
                ? []
                : ['Kaldi 格式仅支持 Android，iOS/macOS 需要 ONNX 格式'],
        suggestions:
            Platform.isAndroid
                ? []
                : [
                    '请下载 ONNX 格式的 Vosk/Paraformer 模型',
                    '或使用 sherpa-onnx 的 export-onnx.py 转换',
                  ],
      );
    }

    // 检查 ONNX 格式。
    if (await _isVoskOnnxDir(dir)) {
      return ModelFormatReport(
        path: dir.path,
        format: ModelFormat.voskOnnx,
        engineId: 'vosk',
        isCompatible: !Platform.isAndroid,
        platformCompat:
            Platform.isAndroid
                ? PlatformCompatibility.needsConversion
                : PlatformCompatibility.available,
        issues:
            Platform.isAndroid
                ? ['ONNX 格式仅支持 iOS/macOS，Android 需要 Kaldi 格式']
                : [],
      );
    }

    return ModelFormatReport(
      path: dir.path,
      format: ModelFormat.unknown,
      engineId: 'vosk',
      isCompatible: false,
      platformCompat: PlatformCompatibility.notSupported,
      issues: ['未找到有效的 Vosk 模型文件'],
    );
  }

  /// 通用格式检测。
  static Future<ModelFormatReport?> _detectGeneric(Directory dir) async {
    // 检查是否包含 ONNX 文件。
    final onnxFiles = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.onnx')) {
        onnxFiles.add(entity);
      }
    }

    if (onnxFiles.isEmpty) return null;

    // 尝试按文件名判断引擎。
    for (final file in onnxFiles) {
      final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
      if (name.contains('encoder') || name.contains('decoder')) {
        return ModelFormatReport(
          path: dir.path,
          format: ModelFormat.whisperOnnx,
          engineId: 'whisper',
          isCompatible: false,
          platformCompat: PlatformCompatibility.needsConversion,
          issues: ['检测到 Whisper ONNX 文件，但目录结构不完整'],
          suggestions: ['需要 encoder.int8.onnx、decoder.int8.onnx 和 tokens.txt'],
        );
      }
    }

    return null;
  }

  /// 单文件检测。
  static Future<ModelFormatReport?> _detectSingleFile(File file) async {
    final name = file.path.split(Platform.pathSeparator).last.toLowerCase();

    if (name.endsWith('.bin') && name.contains('ggml')) {
      return ModelFormatReport(
        path: file.path,
        format: ModelFormat.whisperGgml,
        engineId: 'whisper',
        isCompatible: Platform.isAndroid,
        platformCompat:
            Platform.isAndroid
                ? PlatformCompatibility.available
                : PlatformCompatibility.needsConversion,
      );
    }

    if (name.endsWith('.onnx')) {
      // 检查是否是 SenseVoice 模型。
      final isSV = await _fileContainsPattern(file, 'sense_voice');
      if (isSV) {
        final isCompatible = await _isSenseVoiceSherpaCompatible(file);
        return ModelFormatReport(
          path: file.path,
          format:
              isCompatible
                  ? ModelFormat.senseVoiceOnnx
                  : ModelFormat.senseVoiceOnnxBroken,
          engineId: 'sensevoice_onnx',
          isCompatible: isCompatible,
          platformCompat:
              isCompatible
                  ? PlatformCompatibility.available
                  : PlatformCompatibility.needsConversion,
        );
      }
    }

    return null;
  }

  // === 辅助方法 ===

  static bool _isSenseVoiceDir(String name) {
    return name.contains('sensevoice') || name.contains('sense-voice');
  }

  static bool _isWhisperDir(String name) {
    return name.contains('whisper');
  }

  static bool _isVoskDir(String name) {
    return name.contains('vosk');
  }

  static Future<File?> _findSenseVoiceModelFile(Directory dir) async {
    final candidates = [
      'model_sherpa.onnx',
      'model_quant.onnx',
      'model.int8.fixed.onnx',
      'model.int8.onnx',
      'model.onnx',
    ];
    for (final name in candidates) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) return file;
    }
    return null;
  }

  static Future<File?> _findGgmlFile(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('ggml') && name.endsWith('.bin')) {
          return entity;
        }
      }
    }
    return null;
  }

  static Future<bool> _hasTokens(Directory dir) async {
    final txt = File('${dir.path}/tokens.txt');
    final json = File('${dir.path}/tokens.json');
    return await txt.exists() || await json.exists();
  }

  static Future<bool> _isSenseVoiceSherpaCompatible(File modelFile) async {
    const requiredKeys = [
      'vocab_size',
      'normalize_samples',
      'lfr_window_size',
      'lfr_window_shift',
    ];
    for (final key in requiredKeys) {
      final found = await _fileContainsPattern(modelFile, key);
      if (!found) return false;
    }
    return true;
  }

  static Future<bool> _isWhisperOnnxDir(Directory dir) async {
    final encoderInt8 = File('${dir.path}/encoder.int8.onnx');
    final encoder = File('${dir.path}/encoder.onnx');
    final decoderInt8 = File('${dir.path}/decoder.int8.onnx');
    final decoder = File('${dir.path}/decoder.onnx');
    final tokens = File('${dir.path}/tokens.txt');

    final hasEncoder = await encoderInt8.exists() || await encoder.exists();
    final hasDecoder = await decoderInt8.exists() || await decoder.exists();
    final hasTokens = await tokens.exists();

    return hasEncoder && hasDecoder && hasTokens;
  }

  static Future<bool> _isWhisperPytorchDir(Directory dir) async {
    final pytorch = File('${dir.path}/pytorch_model.bin');
    final config = File('${dir.path}/config.json');
    return await pytorch.exists() && await config.exists();
  }

  static Future<bool> _isVoskOnnxDir(Directory dir) async {
    final tokens = File('${dir.path}/tokens.txt');
    if (!await tokens.exists()) return false;

    final modelOnnx = File('${dir.path}/model.onnx');
    final modelInt8 = File('${dir.path}/model.int8.onnx');
    if (await modelOnnx.exists() || await modelInt8.exists()) return true;

    final encoder = File('${dir.path}/encoder.onnx');
    final decoder = File('${dir.path}/decoder.onnx');
    final joiner = File('${dir.path}/joiner.onnx');
    return await encoder.exists() &&
        await decoder.exists() &&
        await joiner.exists();
  }

  static Future<bool> _fileContainsPattern(File file, String pattern) async {
    final needle = pattern.codeUnits;
    if (needle.isEmpty) return true;

    var carry = <int>[];
    await for (final chunk in file.openRead()) {
      final data = List<int>.from(carry)..addAll(chunk);

      for (var i = 0; i <= data.length - needle.length; i++) {
        var match = true;
        for (var j = 0; j < needle.length; j++) {
          if (data[i + j] != needle[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }

      final keep = needle.length - 1;
      carry =
          keep > 0 && data.length >= keep
              ? data.sublist(data.length - keep)
              : [];
    }
    return false;
  }
}
