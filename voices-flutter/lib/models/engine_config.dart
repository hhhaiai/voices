/// Whisper 引擎配置
class WhisperConfig {
  final String language;
  final String task;
  final int tailPaddings;
  final int numThreads;
  final String provider;
  final bool debug;

  const WhisperConfig({
    this.language = 'auto',
    this.task = 'transcribe',
    this.tailPaddings = -1,
    this.numThreads = 4,
    this.provider = 'cpu',
    this.debug = false,
  });

  WhisperConfig copyWith({
    String? language,
    String? task,
    int? tailPaddings,
    int? numThreads,
    String? provider,
    bool? debug,
  }) {
    return WhisperConfig(
      language: language ?? this.language,
      task: task ?? this.task,
      tailPaddings: tailPaddings ?? this.tailPaddings,
      numThreads: numThreads ?? this.numThreads,
      provider: provider ?? this.provider,
      debug: debug ?? this.debug,
    );
  }

  Map<String, dynamic> toMap() => {
        'language': language,
        'task': task,
        'tailPaddings': tailPaddings,
        'numThreads': numThreads,
        'provider': provider,
        'debug': debug,
      };

  static WhisperConfig fromMap(Map<String, dynamic> map) {
    return WhisperConfig(
      language: map['language'] as String? ?? 'auto',
      task: map['task'] as String? ?? 'transcribe',
      tailPaddings: map['tailPaddings'] as int? ?? -1,
      numThreads: map['numThreads'] as int? ?? 4,
      provider: map['provider'] as String? ?? 'cpu',
      debug: map['debug'] as bool? ?? false,
    );
  }
}

/// SenseVoice 引擎配置
class SenseVoiceConfig {
  final String language;
  final bool useInverseTextNormalization;
  final int numThreads;
  final String provider;
  final bool debug;

  const SenseVoiceConfig({
    this.language = 'auto',
    this.useInverseTextNormalization = true,
    this.numThreads = 4,
    this.provider = 'cpu',
    this.debug = false,
  });

  SenseVoiceConfig copyWith({
    String? language,
    bool? useInverseTextNormalization,
    int? numThreads,
    String? provider,
    bool? debug,
  }) {
    return SenseVoiceConfig(
      language: language ?? this.language,
      useInverseTextNormalization:
          useInverseTextNormalization ?? this.useInverseTextNormalization,
      numThreads: numThreads ?? this.numThreads,
      provider: provider ?? this.provider,
      debug: debug ?? this.debug,
    );
  }

  Map<String, dynamic> toMap() => {
        'language': language,
        'useInverseTextNormalization': useInverseTextNormalization,
        'numThreads': numThreads,
        'provider': provider,
        'debug': debug,
      };

  static SenseVoiceConfig fromMap(Map<String, dynamic> map) {
    return SenseVoiceConfig(
      language: map['language'] as String? ?? 'auto',
      useInverseTextNormalization:
          map['useInverseTextNormalization'] as bool? ?? true,
      numThreads: map['numThreads'] as int? ?? 4,
      provider: map['provider'] as String? ?? 'cpu',
      debug: map['debug'] as bool? ?? false,
    );
  }
}

/// Vosk 引擎配置
class VoskConfig {
  final int numThreads;
  final String provider;
  final bool debug;

  const VoskConfig({
    this.numThreads = 4,
    this.provider = 'cpu',
    this.debug = false,
  });

  VoskConfig copyWith({
    int? numThreads,
    String? provider,
    bool? debug,
  }) {
    return VoskConfig(
      numThreads: numThreads ?? this.numThreads,
      provider: provider ?? this.provider,
      debug: debug ?? this.debug,
    );
  }

  Map<String, dynamic> toMap() => {
        'numThreads': numThreads,
        'provider': provider,
        'debug': debug,
      };

  static VoskConfig fromMap(Map<String, dynamic> map) {
    return VoskConfig(
      numThreads: map['numThreads'] as int? ?? 4,
      provider: map['provider'] as String? ?? 'cpu',
      debug: map['debug'] as bool? ?? false,
    );
  }
}

/// 从 Map 创建引擎配置
WhisperConfig createWhisperConfig(Map<String, dynamic> map) {
  return WhisperConfig.fromMap(map);
}

/// 从 Map 创建 SenseVoice 配置
SenseVoiceConfig createSenseVoiceConfig(Map<String, dynamic> map) {
  return SenseVoiceConfig.fromMap(map);
}

/// 从 Map 创建 Vosk 配置
VoskConfig createVoskConfig(Map<String, dynamic> map) {
  return VoskConfig.fromMap(map);
}

/// TTS 引擎配置
class TtsConfig {
  final double noiseScale;
  final double noiseScaleW;
  final double lengthScale;
  final int numThreads;
  final String provider;
  final bool debug;

  const TtsConfig({
    this.noiseScale = 0.667,
    this.noiseScaleW = 0.8,
    this.lengthScale = 1.0,
    this.numThreads = 4,
    this.provider = 'cpu',
    this.debug = false,
  });

  TtsConfig copyWith({
    double? noiseScale,
    double? noiseScaleW,
    double? lengthScale,
    int? numThreads,
    String? provider,
    bool? debug,
  }) {
    return TtsConfig(
      noiseScale: noiseScale ?? this.noiseScale,
      noiseScaleW: noiseScaleW ?? this.noiseScaleW,
      lengthScale: lengthScale ?? this.lengthScale,
      numThreads: numThreads ?? this.numThreads,
      provider: provider ?? this.provider,
      debug: debug ?? this.debug,
    );
  }

  Map<String, dynamic> toMap() => {
        'noiseScale': noiseScale,
        'noiseScaleW': noiseScaleW,
        'lengthScale': lengthScale,
        'numThreads': numThreads,
        'provider': provider,
        'debug': debug,
      };

  static TtsConfig fromMap(Map<String, dynamic> map) {
    return TtsConfig(
      noiseScale: (map['noiseScale'] as num?)?.toDouble() ?? 0.667,
      noiseScaleW: (map['noiseScaleW'] as num?)?.toDouble() ?? 0.8,
      lengthScale: (map['lengthScale'] as num?)?.toDouble() ?? 1.0,
      numThreads: map['numThreads'] as int? ?? 4,
      provider: map['provider'] as String? ?? 'cpu',
      debug: map['debug'] as bool? ?? false,
    );
  }
}
