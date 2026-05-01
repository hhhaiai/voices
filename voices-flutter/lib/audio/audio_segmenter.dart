import 'dart:math';
import 'dart:typed_data';

import 'vad_processor.dart';
import 'audio_normalizer.dart';

/// 音频片段
class AudioSegment {
  /// 片段数据（PCM 16-bit LE）
  final Uint8List data;

  /// 起始时间（毫秒）
  final int startMs;

  /// 结束时间（毫秒）
  final int endMs;

  /// 采样率
  final int sampleRate;

  /// 是否为语音片段
  final bool isSpeech;

  const AudioSegment({
    required this.data,
    required this.startMs,
    required this.endMs,
    required this.sampleRate,
    required this.isSpeech,
  });

  /// 片段时长（毫秒）
  int get durationMs => endMs - startMs;

  /// 样本数量
  int get numSamples => data.length ~/ 2;

  @override
  String toString() =>
      'AudioSegment(startMs: $startMs, endMs: $endMs, durationMs: $durationMs, '
      'numSamples: $numSamples, isSpeech: $isSpeech)';
}

/// 音频分段器
/// 基于 VAD 结果对音频进行分段
class AudioSegmenter {
  /// 采样率
  final int sampleRate;

  /// 前置静音时间（毫秒），添加到语音片段开头
  final int preRollMs;

  /// 后置静音时间（毫秒），添加到语音片段结尾
  final int postRollMs;

  /// VAD 处理器
  final VadProcessor vadProcessor;

  /// 音频归一化器
  final AudioNormalizer normalizer;

  AudioSegmenter({
    this.sampleRate = 16000,
    this.preRollMs = 100,
    this.postRollMs = 300,
    VadProcessor? vadProcessor,
    AudioNormalizer? normalizer,
  })  : vadProcessor = vadProcessor ?? VadProcessor(sampleRate: sampleRate),
        normalizer = normalizer ?? const AudioNormalizer();

  /// 对音频进行分段
  /// [pcmData] 输入的 PCM 音频数据（16-bit LE）
  /// [offsetMs] 音频数据的起始时间偏移（毫秒），用于处理连续音频流
  /// 返回分段列表
  List<AudioSegment> segment(
    Uint8List pcmData, {
    int offsetMs = 0,
  }) {
    if (pcmData.isEmpty) return [];

    // 重置 VAD 状态
    vadProcessor.reset();

    // 执行 VAD
    final vadResults = vadProcessor.process(pcmData);

    // 基于 VAD 结果生成分段
    final segments = <AudioSegment>[];
    int speechStartMs = 0;
    int speechEndMs = 0;
    bool inSpeech = false;

    for (final vad in vadResults) {
      final segmentStartMs = offsetMs + vad.startMs;
      final segmentEndMs = offsetMs + vad.endMs;

      if (vad.isSpeech) {
        if (!inSpeech) {
          // 语音开始
          inSpeech = true;
          speechStartMs = max(0, segmentStartMs - preRollMs);
        }
        speechEndMs = segmentEndMs;
      } else {
        if (inSpeech) {
          // 语音结束，添加语音片段
          speechEndMs += postRollMs;

          final speechBytes = _extractBytes(
            pcmData,
            speechStartMs,
            speechEndMs,
            offsetMs,
          );

          // 应用归一化
          final normalizedBytes = normalizer.normalize(speechBytes);

          segments.add(AudioSegment(
            data: normalizedBytes,
            startMs: speechStartMs,
            endMs: speechEndMs,
            sampleRate: sampleRate,
            isSpeech: true,
          ));

          inSpeech = false;
        }
      }
    }

    // 处理最后一段（如果还在语音中）
    if (inSpeech) {
      speechEndMs += postRollMs;
      final speechBytes = _extractBytes(
        pcmData,
        speechStartMs,
        speechEndMs,
        offsetMs,
      );
      final normalizedBytes = normalizer.normalize(speechBytes);

      segments.add(AudioSegment(
        data: normalizedBytes,
        startMs: speechStartMs,
        endMs: speechEndMs,
        sampleRate: sampleRate,
        isSpeech: true,
      ));
    }

    return segments;
  }

  /// 从 PCM 数据中提取指定时间范围的字节
  Uint8List _extractBytes(
    Uint8List pcmData,
    int startMs,
    int endMs,
    int offsetMs,
  ) {
    // 计算样本索引
    final startSample = ((startMs - offsetMs) * sampleRate / 1000).round();
    final endSample = ((endMs - offsetMs) * sampleRate / 1000).round();

    // 边界检查
    final byteStart = max(0, startSample * 2);
    final byteEnd = min(pcmData.length, endSample * 2);

    if (byteStart >= byteEnd) return Uint8List(0);

    return Uint8List.view(pcmData.buffer, byteStart, byteEnd - byteStart);
  }

  /// 获取所有语音片段
  List<AudioSegment> getSpeechSegments(List<AudioSegment> segments) {
    return segments.where((s) => s.isSpeech).toList();
  }

  /// 合并相邻的语音片段（如果有间隔很短的片段）
  List<AudioSegment> mergeAdjacentSpeech(
    List<AudioSegment> segments, {
    int gapThresholdMs = 100,
  }) {
    if (segments.isEmpty) return [];

    final merged = <AudioSegment>[];
    AudioSegment? current;

    for (final segment in segments) {
      if (!segment.isSpeech) continue;

      if (current == null) {
        current = segment;
        continue;
      }

      // 检查是否与当前片段相邻
      final gap = segment.startMs - current.endMs;
      if (gap <= gapThresholdMs) {
        // 合并片段
        final combinedData = Uint8List(current.data.length + segment.data.length);
        combinedData.setAll(0, current.data);
        combinedData.setAll(current.data.length, segment.data);

        current = AudioSegment(
          data: combinedData,
          startMs: current.startMs,
          endMs: segment.endMs,
          sampleRate: sampleRate,
          isSpeech: true,
        );
      } else {
        merged.add(current);
        current = segment;
      }
    }

    if (current != null) {
      merged.add(current);
    }

    return merged;
  }
}
