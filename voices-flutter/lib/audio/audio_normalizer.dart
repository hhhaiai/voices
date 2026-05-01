import 'dart:typed_data';
import 'dart:math';

/// 音频归一化器
/// 用于音频增益控制和能量归一化
class AudioNormalizer {
  /// 目标 RMS 能量级别
  final double targetRms;

  /// 最大增益倍数（防止过度放大）
  final double maxGain;

  /// 峰值限制阈值（超过此值会被裁剪）
  final double clipThreshold;

  /// 是否启用自动增益控制
  final bool enableAgc;

  const AudioNormalizer({
    this.targetRms = 0.1,
    this.maxGain = 10.0,
    this.clipThreshold = 0.95,
    this.enableAgc = true,
  });

  /// 对 PCM 音频数据进行归一化（16-bit LE）
  /// 返回归一化后的 PCM 数据
  Uint8List normalize(Uint8List pcmData) {
    if (pcmData.isEmpty) return pcmData;

    final samples = _pcm16LeToDoubleList(pcmData);
    final currentRms = _calculateRms(samples);

    // 计算需要的增益
    double gain = 1.0;
    if (enableAgc && currentRms > 0) {
      gain = targetRms / currentRms;
      gain = min(gain, maxGain);
    }

    // 应用增益并进行峰值限制
    final normalized = Float64List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var sample = samples[i] * gain;

      // 峰值限制
      if (sample > clipThreshold) {
        sample = clipThreshold;
      } else if (sample < -clipThreshold) {
        sample = -clipThreshold;
      }

      normalized[i] = sample;
    }

    return _doubleListToPcm16Le(normalized);
  }

  /// 对音频片段进行归一化
  Uint8List normalizeSegment(Uint8List pcmData, int startMs, int endMs, int sampleRate) {
    // 计算片段对应的样本范围
    final startSample = (startMs * sampleRate / 1000).round();
    final endSample = (endMs * sampleRate / 1000).round();

    if (startSample >= pcmData.length ~/ 2 || endSample <= 0) {
      return pcmData;
    }

    // 提取片段
    final clippedStart = max(0, startSample);
    final clippedEnd = min(pcmData.length ~/ 2, endSample);
    final segmentBytes = (clippedEnd - clippedStart) * 2;

    if (segmentBytes <= 0) return pcmData;

    final segmentPcm = Uint8List.view(
      pcmData.buffer,
      clippedStart * 2,
      segmentBytes,
    );

    return normalize(segmentPcm);
  }

  /// 计算 RMS
  double _calculateRms(List<double> samples) {
    if (samples.isEmpty) return 0;
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return sqrt(sum / samples.length);
  }

  /// PCM 16-bit LE 转换为 Double 列表
  List<double> _pcm16LeToDoubleList(Uint8List pcmData) {
    final out = <double>[];
    for (var i = 0; i + 1 < pcmData.length; i += 2) {
      final lo = pcmData[i];
      final hi = pcmData[i + 1];
      var sample = (hi << 8) | lo;
      if (sample >= 32768) sample -= 65536;
      out.add(sample / 32768.0);
    }
    return out;
  }

  /// Double 列表转换回 PCM 16-bit LE
  Uint8List _doubleListToPcm16Le(Float64List samples) {
    final out = Uint8List(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      var sample = (samples[i] * 32768).round().clamp(-32768, 32767);
      out[i * 2] = sample & 0xFF;
      out[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return out;
  }
}
