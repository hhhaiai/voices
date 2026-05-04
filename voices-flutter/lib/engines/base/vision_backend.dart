/// Vision 引擎后端状态
enum VisionBackendState {
  /// 空闲，未加载
  idle,

  /// 加载中
  loading,

  /// 已加载就绪
  ready,

  /// 推理中
  inferring,

  /// 错误
  error,
}

/// Vision 推理结果
class VisionResult {
  /// 描述文本
  final String description;

  /// 置信度（0-1）
  final double confidence;

  /// 推理耗时（毫秒）
  final int latencyMs;

  const VisionResult({
    required this.description,
    required this.confidence,
    required this.latencyMs,
  });
}

/// Vision 引擎后端抽象接口
abstract class VisionBackend {
  /// 引擎唯一标识符
  String get engineId;

  /// 当前状态
  VisionBackendState get state;

  /// 是否已加载模型
  bool get isLoaded;

  /// 最后一次错误信息
  String? get lastError;

  /// 模型路径（如果有）
  String? get modelPath;

  /// 模型名称
  String? get modelName;

  /// 支持的图像格式
  List<String> get supportedFormats;

  /// 加载模型
  Future<bool> load(String modelPath);

  /// 卸载模型
  Future<void> unload();

  /// 图像理解
  /// [imagePath] 图像文件路径
  /// [question] 关于图像的问题（可选，默认描述图像）
  /// 返回 VisionResult
  Future<VisionResult?> understand(
    String imagePath, {
    String? question,
  });

  /// 获取详细状态信息
  Map<String, dynamic> statusMap();

  /// 预热模型
  Future<bool> warmup() async => true;

  /// 清理资源
  void dispose();
}
