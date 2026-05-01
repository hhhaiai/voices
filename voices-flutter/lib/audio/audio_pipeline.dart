import 'dart:math';
import 'dart:typed_data';

import 'vad_processor.dart';
import 'audio_normalizer.dart';
import 'audio_segmenter.dart';

/// 音频预处理配置
class AudioPipelineConfig {
  /// 是否启用 VAD
  final bool enableVad;

  /// 是否启用音频归一化
  final bool enableNormalization;

  /// 是否启用分段
  final bool enableSegmentation;

  /// VAD 灵敏度 (0-3)
  final int vadSensitivity;

  /// VAD 阈值
  final double vadThreshold;

  /// 前置静音时间（毫秒）
  final int preRollMs;

  /// 后置静音时间（毫秒）
  final int postRollMs;

  /// 目标 RMS
  final double targetRms;

  const AudioPipelineConfig({
    this.enableVad = true,
    this.enableNormalization = true,
    this.enableSegmentation = true,
    this.vadSensitivity = 3,
    this.vadThreshold = 0.02,
    this.preRollMs = 100,
    this.postRollMs = 300,
    this.targetRms = 0.1,
  });

  /// 默认配置
  static const defaultConfig = AudioPipelineConfig();

  /// 低延迟配置（减少预处理）
  static const lowLatencyConfig = AudioPipelineConfig(
    enableVad: false,
    enableNormalization: false,
    enableSegmentation: false,
  );

  /// 高质量配置（启用所有处理）
  static const highQualityConfig = AudioPipelineConfig(
    enableVad: true,
    enableNormalization: true,
    enableSegmentation: true,
    preRollMs: 200,
    postRollMs: 500,
  );

  AudioPipelineConfig copyWith({
    bool? enableVad,
    bool? enableNormalization,
    bool? enableSegmentation,
    int? vadSensitivity,
    double? vadThreshold,
    int? preRollMs,
    int? postRollMs,
    double? targetRms,
  }) {
    return AudioPipelineConfig(
      enableVad: enableVad ?? this.enableVad,
      enableNormalization: enableNormalization ?? this.enableNormalization,
      enableSegmentation: enableSegmentation ?? this.enableSegmentation,
      vadSensitivity: vadSensitivity ?? this.vadSensitivity,
      vadThreshold: vadThreshold ?? this.vadThreshold,
      preRollMs: preRollMs ?? this.preRollMs,
      postRollMs: postRollMs ?? this.postRollMs,
      targetRms: targetRms ?? this.targetRms,
    );
  }
}

/// 预处理后的音频数据
class ProcessedAudio {
  /// 处理后的 PCM 数据（16-bit LE）
  final Uint8List pcmData;

  /// VAD 结果（如果启用）
  final List<VadResult>? vadResults;

  /// 音频片段（如果启用分段）
  final List<AudioSegment>? segments;

  /// 是否检测到语音
  final bool hasSpeech;

  /// 配置
  final AudioPipelineConfig config;

  const ProcessedAudio({
    required this.pcmData,
    this.vadResults,
    this.segments,
    required this.hasSpeech,
    required this.config,
  });
}

/// 音频预处理流水线
/// 统一封装 VAD、归一化、分段等功能
class AudioPipeline {
  final AudioPipelineConfig config;
  final VadProcessor _vadProcessor;
  final AudioNormalizer _normalizer;
  final AudioSegmenter _segmenter;

  AudioPipeline({
    AudioPipelineConfig? config,
    int sampleRate = 16000,
  })  : config = config ?? const AudioPipelineConfig(),
        _vadProcessor = VadProcessor(
          sampleRate: sampleRate,
          threshold: config?.vadThreshold ?? 0.02,
        ),
        _normalizer = AudioNormalizer(
          targetRms: config?.targetRms ?? 0.1,
        ),
        _segmenter = AudioSegmenter(
          sampleRate: sampleRate,
          preRollMs: config?.preRollMs ?? 100,
          postRollMs: config?.postRollMs ?? 300,
          vadProcessor: VadProcessor(
            sampleRate: sampleRate,
            threshold: config?.vadThreshold ?? 0.02,
          ),
          normalizer: AudioNormalizer(
            targetRms: config?.targetRms ?? 0.1,
          ),
        );

  /// 处理音频数据
  /// 返回预处理后的音频数据
  ProcessedAudio process(Uint8List pcmData, {int offsetMs = 0}) {
    if (pcmData.isEmpty) {
      return ProcessedAudio(
        pcmData: pcmData,
        hasSpeech: false,
        config: config,
      );
    }

    Uint8List processedData = pcmData;
    List<VadResult>? vadResults;
    List<AudioSegment>? segments;

    // 1. 归一化
    if (config.enableNormalization) {
      processedData = _normalizer.normalize(pcmData);
    }

    // 2. VAD
    if (config.enableVad) {
      _vadProcessor.reset();
      vadResults = _vadProcessor.process(processedData);
    }

    // 3. 分段
    if (config.enableSegmentation) {
      segments = _segmenter.segment(processedData, offsetMs: offsetMs);
    }

    // 判断是否有语音
    bool hasSpeech = false;
    if (vadResults != null) {
      hasSpeech = vadResults.any((v) => v.isSpeech);
    } else if (segments != null) {
      hasSpeech = segments.any((s) => s.isSpeech);
    }

    return ProcessedAudio(
      pcmData: processedData,
      vadResults: vadResults,
      segments: segments,
      hasSpeech: hasSpeech,
      config: config,
    );
  }

  /// 快速检测音频是否包含语音
  /// 不进行完整处理，只做能量检测
  bool detectSpeech(Uint8List pcmData) {
    if (pcmData.isEmpty) return false;

    // 简单的能量检测
    double sum = 0;
    final sampleCount = min(pcmData.length ~/ 2, 16000); // 最多检查 1 秒
    for (var i = 0; i + 1 < sampleCount * 2; i += 2) {
      final lo = pcmData[i];
      final hi = pcmData[i + 1];
      var sample = (hi << 8) | lo;
      if (sample >= 32768) sample -= 65536;
      sum += (sample / 32768.0) * (sample / 32768.0);
    }
    final rms = sum > 0 ? (sum / sampleCount) : 0.0;

    return rms > config.vadThreshold;
  }

  /// 重置内部状态
  void reset() {
    _vadProcessor.reset();
  }
}
