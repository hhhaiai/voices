import 'dart:typed_data';

/// TTS 引擎后端状态
enum TtsBackendState {
  /// 空闲，未加载
  idle,

  /// 加载中
  loading,

  /// 已加载就绪
  ready,

  /// 生成中
  generating,

  /// 错误
  error,
}

/// TTS 引擎后端抽象接口
abstract class TtsBackend {
  /// 引擎唯一标识符
  String get engineId;

  /// 当前状态
  TtsBackendState get state;

  /// 是否已加载模型
  bool get isLoaded;

  /// 最后一次错误信息
  String? get lastError;

  /// 模型路径（如果有）
  String? get modelPath;

  /// 可用说话人数量
  int get numSpeakers;

  /// 输出采样率
  int get sampleRate;

  /// 加载模型
  Future<bool> load(String modelPath);

  /// 卸载模型
  Future<void> unload();

  /// 生成语音
  /// [text] 要转换的文本
  /// [sid] 说话人 ID（0=默认）
  /// [speed] 语速（1.0=正常）
  /// 返回音频数据（Float32List normalized to [-1, 1]）和采样率
  Future<TtsAudioResult?> synthesize(String text, {int sid = 0, double speed = 1.0});

  /// 获取详细状态信息
  Map<String, dynamic> statusMap();

  /// 预热模型
  Future<bool> warmup() async => true;

  /// 清理资源
  void dispose();
}

/// TTS 音频结果
class TtsAudioResult {
  /// 音频数据（Float32List, normalized to [-1, 1]）
  final Float32List samples;

  /// 采样率
  final int sampleRate;

  /// 音频时长（秒）
  final double duration;

  const TtsAudioResult({
    required this.samples,
    required this.sampleRate,
  }) : duration = samples.length / sampleRate;
}
