import 'dart:typed_data';
import 'dart:math';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 模型预热状态
enum WarmupState {
  /// 未开始
  idle,

  /// 预热中
  warming,

  /// 预热完成
  done,

  /// 预热失败
  failed,
}

/// 预热结果
class WarmupResult {
  final WarmupState state;
  final Duration? latency;
  final String? error;

  const WarmupResult({
    required this.state,
    this.latency,
    this.error,
  });

  bool get isSuccess => state == WarmupState.done;

  @override
  String toString() {
    if (state == WarmupState.done) {
      return 'WarmupResult(done, latency: ${latency?.inMilliseconds}ms)';
    }
    if (state == WarmupState.failed) {
      return 'WarmupResult(failed, error: $error)';
    }
    return 'WarmupResult($state)';
  }
}

/// 模型预热管理器
/// 在模型加载后执行哑推理以减少首次推理延迟
class WarmupManager {
  /// 预热音频时长（毫秒）
  static const int warmupDurationMs = 500;

  /// 预热音频采样率
  static const int warmupSampleRate = 16000;

  /// 生成预热用的静音音频
  /// 返回 500ms 的静音 PCM 数据（16-bit LE）
  static Uint8List generateSilenceAudio() {
    // 500ms @ 16kHz = 8000 samples
    // 16-bit = 2 bytes per sample = 16000 bytes
    const numSamples = (warmupDurationMs * warmupSampleRate) ~/ 1000;
    const numBytes = numSamples * 2;
    return Uint8List(numBytes); // 静音默认为 0
  }

  /// 生成预热用的带能量音频
  /// 返回包含低能量正弦波的 PCM 数据，用于更真实的预热
  static Uint8List generateToneAudio({double frequency = 100.0}) {
    const numSamples = (warmupDurationMs * warmupSampleRate) ~/ 1000;
    final pcmData = Int16List(numSamples);
    const amplitude = 100; // 低能量，避免clipping

    for (var i = 0; i < numSamples; i++) {
      final t = i / warmupSampleRate;
      final sample = (amplitude * sin(2 * pi * frequency * t)).round();
      pcmData[i] = sample;
    }

    return pcmData.buffer.asUint8List();
  }

  /// 对 Sherpa Whisper 模型执行预热
  static Future<WarmupResult> warmupWhisper(
    sherpa_onnx.OfflineRecognizer recognizer, {
    bool useTone = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      // 生成预热音频
      final warmupPcm = useTone ? generateToneAudio() : generateSilenceAudio();
      final floatSamples = _pcm16LeToFloat32(warmupPcm);

      // 执行哑推理
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: floatSamples,
          sampleRate: warmupSampleRate,
        );
        recognizer.decode(stream);
        // 忽略结果，只是为了触发模型初始化
      } finally {
        stream.free();
      }

      stopwatch.stop();

      return WarmupResult(
        state: WarmupState.done,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      return WarmupResult(
        state: WarmupState.failed,
        error: e.toString(),
      );
    }
  }

  /// PCM 16-bit LE 转换为 Float32
  static Float32List _pcm16LeToFloat32(Uint8List pcmData) {
    final out = Float32List(pcmData.length ~/ 2);
    var outIndex = 0;
    for (var i = 0; i + 1 < pcmData.length; i += 2) {
      final lo = pcmData[i];
      final hi = pcmData[i + 1];
      var sample = (hi << 8) | lo;
      if (sample >= 32768) sample -= 65536;
      out[outIndex++] = sample / 32768.0;
    }
    return out;
  }
}
