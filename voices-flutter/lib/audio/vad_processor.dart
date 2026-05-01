import 'dart:typed_data';
import 'dart:math';

/// VAD 语音活动检测结果
class VadResult {
  /// 是否检测到语音
  final bool isSpeech;

  /// 该片段的起始时间（毫秒）
  final int startMs;

  /// 该片段的结束时间（毫秒）
  final int endMs;

  /// 该片段的能量
  final double energy;

  const VadResult({
    required this.isSpeech,
    required this.startMs,
    required this.endMs,
    required this.energy,
  });

  @override
  String toString() =>
      'VadResult(isSpeech: $isSpeech, startMs: $startMs, endMs: $endMs, energy: ${energy.toStringAsFixed(2)})';
}

/// VAD 语音活动检测器
/// 基于能量检测的简单 VAD 实现
class VadProcessor {
  /// 采样率
  final int sampleRate;

  /// 帧长（毫秒）
  final int frameDurationMs;

  /// 语音检测阈值（能量低于此值认为是静音）
  final double threshold;

  /// 前置静音时间（毫秒），用于判断语音开始
  final int preRollMs;

  /// 后置静音时间（毫秒），用于判断语音结束
  final int postRollMs;

  /// 计算帧长对应的样本数
  int get _frameSamples => (sampleRate * frameDurationMs / 1000).round();

  /// 帧数据缓冲区
  final List<double> _frameBuffer = [];

  /// 当前处理的起始时间（毫秒）
  int _currentStartMs = 0;

  /// 最近帧的能量值
  final List<double> _recentEnergies = [];

  /// 连续静音帧计数
  int _silenceFrames = 0;

  /// 是否处于语音中
  bool _inSpeech = false;

  /// 语音开始的帧索引
  int _speechStartFrame = 0;

  /// 当前帧索引
  int _frameIndex = 0;

  VadProcessor({
    this.sampleRate = 16000,
    this.frameDurationMs = 32,
    this.threshold = 0.02,
    this.preRollMs = 200,
    this.postRollMs = 500,
  });

  /// 处理 PCM 音频数据（16-bit LE）
  /// 返回 VAD 结果列表
  List<VadResult> process(Uint8List pcmData) {
    final results = <VadResult>[];
    final samples = _pcm16LeToDouble(pcmData);

    int offset = 0;
    while (offset + _frameSamples <= samples.length) {
      final frame = samples.sublist(offset, offset + _frameSamples);
      final energy = _calculateEnergy(frame);
      _recentEnergies.add(energy);

      // 维护一个滑动窗口的能量均值
      if (_recentEnergies.length > 10) {
        _recentEnergies.removeAt(0);
      }

      final currentMs = _frameIndex * frameDurationMs;

      if (!_inSpeech) {
        // 检测语音开始
        if (energy > threshold) {
          _inSpeech = true;
          _silenceFrames = 0;
          _speechStartFrame = max(0, _frameIndex - (preRollMs ~/ frameDurationMs));
          _currentStartMs = _speechStartFrame * frameDurationMs;
        }
      } else {
        // 检测语音结束
        if (energy <= threshold) {
          _silenceFrames++;
          final silenceDurationMs = _silenceFrames * frameDurationMs;
          if (silenceDurationMs >= postRollMs) {
            // 语音结束
            final endMs = (_frameIndex - _silenceFrames) * frameDurationMs;
            results.add(VadResult(
              isSpeech: true,
              startMs: _currentStartMs,
              endMs: endMs,
              energy: _calculateAverageEnergy(),
            ));

            // 添加静音片段
            results.add(VadResult(
              isSpeech: false,
              startMs: endMs,
              endMs: currentMs,
              energy: energy,
            ));

            _inSpeech = false;
            _silenceFrames = 0;
            _currentStartMs = currentMs;
          }
        } else {
          _silenceFrames = 0;
        }
      }

      _frameIndex++;
      offset += _frameSamples;
    }

    // 如果最后还在语音中，添加结束片段
    if (_inSpeech) {
      final endMs = _frameIndex * frameDurationMs;
      results.add(VadResult(
        isSpeech: true,
        startMs: _currentStartMs,
        endMs: endMs,
        energy: _calculateAverageEnergy(),
      ));
    }

    return results;
  }

  /// 重置状态
  void reset() {
    _frameBuffer.clear();
    _recentEnergies.clear();
    _silenceFrames = 0;
    _inSpeech = false;
    _frameIndex = 0;
    _currentStartMs = 0;
  }

  /// 计算帧能量（RMS）
  double _calculateEnergy(List<double> samples) {
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return sqrt(sum / samples.length);
  }

  /// 计算最近帧的平均能量
  double _calculateAverageEnergy() {
    if (_recentEnergies.isEmpty) return 0;
    return _recentEnergies.reduce((a, b) => a + b) / _recentEnergies.length;
  }

  /// PCM 16-bit LE 转换为 Double 数组
  List<double> _pcm16LeToDouble(Uint8List pcmData) {
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

  /// 获取 VAD 结果中的语音片段
  List<VadResult> getSpeechSegments(List<VadResult> results) {
    return results.where((r) => r.isSpeech).toList();
  }

  /// 获取 VAD 结果中的静音片段
  List<VadResult> getSilenceSegments(List<VadResult> results) {
    return results.where((r) => !r.isSpeech).toList();
  }
}
