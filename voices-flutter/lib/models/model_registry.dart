import '../utils/platform_utils.dart';

class DownloadableModelDefinition {
  final String id;
  final String engineId;
  final String name;
  final String version;
  final String downloadUrl;
  final String? sha256;
  final int sizeMB;
  final List<String> notes;
  final List<String> extraDownloadUrls;
  final List<String> allowedHosts;
  final bool android;
  final bool ios;
  final bool macos;
  final bool linux;
  final bool windows;

  const DownloadableModelDefinition({
    required this.id,
    required this.engineId,
    required this.name,
    required this.version,
    required this.downloadUrl,
    this.sha256,
    required this.sizeMB,
    required this.notes,
    this.extraDownloadUrls = const [],
    this.allowedHosts = const ['huggingface.co'],
    this.android = true,
    this.ios = true,
    this.macos = true,
    this.linux = false,
    this.windows = false,
  });

  bool get supportsCurrentPlatform {
    final platform = PlatformUtils.currentPlatform;
    switch (platform) {
      case 'android': return android;
      case 'ios': return ios;
      case 'macos': return macos;
      case 'linux': return linux;
      case 'windows': return windows;
      default: return false;
    }
  }
}

class BuiltinModelDefinition {
  final String id;
  final String engineId;
  final String name;
  final String assetBasePath;
  final String modelRelativePath;
  final List<String> requiredAssetFiles;
  final bool resolveToDirectory;
  final bool requiresLocalFilesystem;
  final bool android;
  final bool ios;
  final bool macos;
  final bool linux;
  final bool windows;

  const BuiltinModelDefinition({
    required this.id,
    required this.engineId,
    required this.name,
    required this.assetBasePath,
    required this.modelRelativePath,
    required this.requiredAssetFiles,
    this.resolveToDirectory = false,
    this.requiresLocalFilesystem = true,
    this.android = true,
    this.ios = true,
    this.macos = true,
    this.linux = false,
    this.windows = false,
  });

  bool get supportsCurrentPlatform {
    final platform = PlatformUtils.currentPlatform;
    switch (platform) {
      case 'android': return android;
      case 'ios': return ios;
      case 'macos': return macos;
      case 'linux': return linux;
      case 'windows': return windows;
      default: return false;
    }
  }
}

class ModelRegistry {
  const ModelRegistry._();

  static const List<DownloadableModelDefinition> downloadableModels = [
    DownloadableModelDefinition(
      id: 'whisper-tiny-ggml',
      engineId: 'whisper',
      name: 'Whisper Tiny (ggml)',
      version: '1.0.0',
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      sizeMB: 75,
      notes: ['Android 推荐', '速度快，精度均衡'],
      android: true,
      ios: false,
      macos: false,
    ),
    DownloadableModelDefinition(
      id: 'whisper-base-ggml',
      engineId: 'whisper',
      name: 'Whisper Base (ggml)',
      version: '1.1.0',
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      sizeMB: 142,
      notes: ['Android 可用', '精度更高，体积更大'],
      android: true,
      ios: false,
      macos: false,
    ),
    DownloadableModelDefinition(
      id: 'whisper-small-ggml',
      engineId: 'whisper',
      name: 'Whisper Small (ggml)',
      version: '1.2.0',
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      sizeMB: 466,
      notes: ['Android 高精度', '建议在高性能设备使用'],
      android: true,
      ios: false,
      macos: false,
    ),
    DownloadableModelDefinition(
      id: 'whisper-tiny-onnx-apple',
      engineId: 'whisper',
      name: 'Whisper Tiny (ONNX, sherpa)',
      version: 'onnx-1.0.0',
      downloadUrl:
          'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-encoder.int8.onnx',
      extraDownloadUrls: [
        'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-decoder.int8.onnx',
        'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-tokens.txt',
      ],
      sizeMB: 74,
      notes: ['非 Android 平台推荐', '下载 encoder/decoder/tokens 三个文件'],
      android: false,
      ios: true,
      macos: true,
      linux: true,
      windows: true,
    ),
    DownloadableModelDefinition(
      id: 'vosk-paraformer-zh-small-onnx',
      engineId: 'vosk',
      name: 'Vosk Paraformer ZH Small (ONNX)',
      version: 'onnx-1.0.0',
      downloadUrl:
          'https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/model.int8.onnx',
      extraDownloadUrls: [
        'https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/tokens.txt',
      ],
      sizeMB: 24,
      notes: ['非 Android 平台推荐', '下载 model/tokens 两个文件'],
      android: false,
      ios: true,
      macos: true,
      linux: true,
      windows: true,
    ),
    DownloadableModelDefinition(
      id: 'sensevoice-onnx-int8',
      engineId: 'sensevoice_onnx',
      name: 'SenseVoice (ONNX int8)',
      version: 'onnx-1.0.0',
      downloadUrl:
          'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
      extraDownloadUrls: [
        'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
      ],
      sizeMB: 167,
      notes: ['全平台可用', '下载 model/tokens 两个文件'],
      android: true,
      ios: true,
      macos: true,
      linux: true,
      windows: true,
    ),
    // TTS 模型需要用户手动下载（需要 HuggingFace 认证接受 Terms）
    // 下载后放置到 models/tts/<version>/ 目录
    // 下载地址: https://huggingface.co/csukuangfj/sherpa-onnx-vits-melo-tts-zh_en
    // 所需文件: model.onnx, tokens.txt
    // 注意: sherpa-onnx VITS 模型需要在 HuggingFace 接受 Terms 才能下载
  ];

  static const List<BuiltinModelDefinition> builtinModels = [
    BuiltinModelDefinition(
      id: 'builtin-whisper-tiny-ggml',
      engineId: 'whisper',
      name: 'Whisper Tiny (Built-in)',
      assetBasePath: 'assets/models/whisper-tiny',
      modelRelativePath: 'ggml-tiny.bin',
      requiredAssetFiles: ['ggml-tiny.bin'],
      resolveToDirectory: false,
      requiresLocalFilesystem: false,
      android: true,
      ios: false,
      macos: false,
    ),
    BuiltinModelDefinition(
      id: 'builtin-vosk-cn',
      engineId: 'vosk',
      name: 'Vosk CN (Built-in)',
      assetBasePath: 'assets/models/vosk-cn',
      modelRelativePath: '',
      requiredAssetFiles: [
        'README',
        'am/final.mdl',
        'conf/mfcc.conf',
      ],
      resolveToDirectory: true,
      requiresLocalFilesystem: false,
      android: true,
      ios: false,
      macos: false,
    ),
    BuiltinModelDefinition(
      id: 'builtin-sensevoice-onnx',
      engineId: 'sensevoice_onnx',
      name: 'SenseVoice ONNX (Built-in)',
      assetBasePath: 'assets/models/sensevoice-onnx',
      modelRelativePath: 'model_quant.onnx',
      requiredAssetFiles: [
        'model_quant.onnx',
        'tokens.txt',
        'tokens.json',
        'config.yaml',
        'configuration.json',
        'am.mvn',
        'README.md',
      ],
      resolveToDirectory: false,
      requiresLocalFilesystem: true,
      android: true,
      ios: true,
      macos: true,
      linux: true,
      windows: true,
    ),
    BuiltinModelDefinition(
      id: 'builtin-tts-vits',
      engineId: 'sherpa_tts',
      name: 'VITS TTS (Built-in)',
      assetBasePath: 'assets/models/tts-vits',
      modelRelativePath: 'model.onnx',
      // model.onnx 被分割成多个 .part* 文件以绕过 GitHub 100MB 限制
      // 合并方式: model.onnx.partaa + model.onnx.partab + ... = model.onnx
      requiredAssetFiles: [
        'model.onnx.partaa',
        'model.onnx.partab',
        'model.onnx.partac',
        'model.onnx.partad',
        'model.int8.onnx.partaa',
        'model.int8.onnx.partab',
        'tokens.txt',
        'lexicon.txt',
      ],
      resolveToDirectory: true,
      requiresLocalFilesystem: false,
      android: true,
      ios: true,
      macos: true,
      linux: true,
      windows: true,
    ),
  ];

  static List<DownloadableModelDefinition> modelsForEngine(String engineId) {
    return downloadableModels
        .where((m) => m.engineId == engineId && m.supportsCurrentPlatform)
        .toList(growable: false);
  }

  static List<BuiltinModelDefinition> builtinModelsForEngine(String engineId) {
    return builtinModels
        .where((m) => m.engineId == engineId && m.supportsCurrentPlatform)
        .toList(growable: false);
  }

  static BuiltinModelDefinition? preferredBuiltinForEngine(String engineId) {
    final models = builtinModelsForEngine(engineId);
    if (models.isEmpty) return null;
    return models.first;
  }
}
