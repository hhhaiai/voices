import 'dart:typed_data';

/// 音频输入
class AudioInput {
  final Uint8List data;
  final int sampleRate;
  final int numChannels;
  final Duration duration;

  const AudioInput({
    required this.data,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.duration = Duration.zero,
  });

  /// 从 PCM bytes 创建
  factory AudioInput.fromPcm(Uint8List pcmData, {int sampleRate = 16000}) {
    final duration = Duration(
      milliseconds: (pcmData.length ~/ 2) * 1000 ~/ sampleRate,
    );
    return AudioInput(
      data: pcmData,
      sampleRate: sampleRate,
      duration: duration,
    );
  }

  /// 获取 float 格式的音频数据 (用于模型输入)
  List<double> toFloatList() {
    final int16List = data.buffer.asInt16List();
    return int16List.map((e) => e / 32768.0).toList();
  }
}
