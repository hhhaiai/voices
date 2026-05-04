/// LLM 引擎后端状态
enum LlmBackendState {
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

/// LLM 消息角色
enum LlmMessageRole {
  system,
  user,
  assistant,
}

/// LLM 对话消息
class LlmMessage {
  final LlmMessageRole role;
  final String content;

  const LlmMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'content': content,
      };

  static LlmMessage fromMap(Map<String, dynamic> map) {
    return LlmMessage(
      role: LlmMessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => LlmMessageRole.user,
      ),
      content: map['content'] as String? ?? '',
    );
  }
}

/// LLM 流式推理结果
class LlmStreamResult {
  /// 增量输出的文本片段
  final String delta;

  /// 是否已完成
  final bool done;

  /// 完整输出（仅 done=true 时有效）
  final String? fullText;

  /// 推理耗时（毫秒）
  final int latencyMs;

  const LlmStreamResult({
    required this.delta,
    required this.done,
    this.fullText,
    required this.latencyMs,
  });
}

/// LLM 推理统计
class LlmStats {
  /// 生成的 token 数量
  final int tokensGenerated;

  /// 推理耗时（毫秒）
  final int latencyMs;

  /// 每秒生成的 token 数
  final double tokensPerSecond;

  const LlmStats({
    required this.tokensGenerated,
    required this.latencyMs,
    required this.tokensPerSecond,
  });
}

/// LLM 引擎后端抽象接口
abstract class LlmBackend {
  /// 引擎唯一标识符
  String get engineId;

  /// 当前状态
  LlmBackendState get state;

  /// 是否已加载模型
  bool get isLoaded;

  /// 最后一次错误信息
  String? get lastError;

  /// 模型路径（如果有）
  String? get modelPath;

  /// 模型名称（如 "Qwen2-0.5B"）
  String? get modelName;

  /// 上下文窗口大小
  int get contextLength;

  /// 加载模型
  Future<bool> load(String modelPath);

  /// 卸载模型
  Future<void> unload();

  /// 流式推理
  /// [messages] 对话历史
  /// [temperature] 温度参数（0.0-2.0）
  /// [maxTokens] 最大生成 token 数（0=无限制）
  /// 返回 Stream of LlmStreamResult
  Stream<LlmStreamResult> streamInfer(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 0,
  });

  /// 同步推理（非流式）
  /// [messages] 对话历史
  /// [temperature] 温度参数
  /// [maxTokens] 最大生成 token 数
  /// 返回完整推理结果
  Future<LlmStreamResult> infer(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 0,
  });

  /// 获取详细状态信息
  Map<String, dynamic> statusMap();

  /// 预热模型
  Future<bool> warmup() async => true;

  /// 清理资源
  void dispose();
}
