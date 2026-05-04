import 'dart:async';

import '../engines/base/llm_backend.dart';
import '../engines/backends/gguf_llm_backend.dart';

/// LLM 服务状态
enum LlmServiceState {
  idle,
  loading,
  ready,
  inferring,
  error,
}

/// LLM 对话会话
class LlmSession {
  final String id;
  final List<LlmMessage> messages;
  final DateTime createdAt;

  LlmSession({
    required this.id,
    List<LlmMessage>? messages,
    DateTime? createdAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  LlmSession copyWith({
    String? id,
    List<LlmMessage>? messages,
    DateTime? createdAt,
  }) {
    return LlmSession(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// LLM 服务
/// 统一管理 LLM 引擎，提供本地 GGUF 模型推理能力
class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  final LlmBackend _backend = GgufLlmBackend();

  LlmServiceState _state = LlmServiceState.idle;
  String? _errorMessage;
  String? _currentModelPath;
  LlmSession? _currentSession;

  /// 流式推理订阅
  StreamSubscription<LlmStreamResult>? _inferSubscription;

  /// 当前服务状态
  LlmServiceState get state => _state;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 是否已加载模型
  bool get isLoaded => _backend.isLoaded;

  /// 模型名称
  String? get modelName => _backend.modelName;

  /// 上下文窗口大小
  int get contextLength => _backend.contextLength;

  /// 当前会话
  LlmSession? get currentSession => _currentSession;

  /// 加载 LLM 模型
  Future<bool> loadModel(String modelPath) async {
    try {
      _state = LlmServiceState.loading;
      _errorMessage = null;

      final loaded = await _backend.load(modelPath);
      if (loaded) {
        _currentModelPath = modelPath;
        _currentSession = LlmSession(id: _generateSessionId());
        _state = LlmServiceState.ready;
        return true;
      } else {
        _errorMessage = _backend.lastError ?? '模型加载失败';
        _state = LlmServiceState.error;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = LlmServiceState.error;
      return false;
    }
  }

  /// 创建新会话
  LlmSession createSession() {
    _currentSession = LlmSession(id: _generateSessionId());
    return _currentSession!;
  }

  /// 流式推理（用于实时显示）
  /// [text] 用户输入
  /// [temperature] 温度参数
  /// [maxTokens] 最大 token 数
  /// 返回 Stream，用于实时获取推理结果
  Stream<LlmStreamResult> streamInfer(
    String text, {
    double temperature = 0.7,
    int maxTokens = 0,
  }) {
    if (!_backend.isLoaded) {
      return Stream.error('LLM 模型未加载');
    }

    _state = LlmServiceState.inferring;

    final messages = [
      ...?_currentSession?.messages,
      LlmMessage(role: LlmMessageRole.user, content: text),
    ];

    return _backend.streamInfer(
      messages,
      temperature: temperature,
      maxTokens: maxTokens,
    ).map((result) {
      // 更新会话历史
      if (result.done && result.fullText != null) {
        _currentSession = _currentSession?.copyWith(
          messages: [
            ...?_currentSession?.messages,
            LlmMessage(role: LlmMessageRole.user, content: text),
            LlmMessage(
              role: LlmMessageRole.assistant,
              content: result.fullText!,
            ),
          ],
        );
        _state = LlmServiceState.ready;
      }
      return result;
    });
  }

  /// 同步推理
  /// [text] 用户输入
  /// [temperature] 温度参数
  /// [maxTokens] 最大 token 数
  Future<String?> infer(
    String text, {
    double temperature = 0.7,
    int maxTokens = 0,
  }) async {
    if (!_backend.isLoaded) {
      _errorMessage = 'LLM 模型未加载';
      _state = LlmServiceState.error;
      return null;
    }

    _state = LlmServiceState.inferring;

    try {
      final messages = [
        ...?_currentSession?.messages,
        LlmMessage(role: LlmMessageRole.user, content: text),
      ];

      final result = await _backend.infer(
        messages,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      if (result.fullText != null) {
        _currentSession = _currentSession?.copyWith(
          messages: [
            ...?_currentSession?.messages,
            LlmMessage(role: LlmMessageRole.user, content: text),
            LlmMessage(
              role: LlmMessageRole.assistant,
              content: result.fullText!,
            ),
          ],
        );
      }

      _state = LlmServiceState.ready;
      return result.fullText ?? result.delta;
    } catch (e) {
      _errorMessage = e.toString();
      _state = LlmServiceState.error;
      return null;
    }
  }

  /// 文本翻译
  /// [text] 要翻译的文本
  /// [sourceLang] 源语言（如 'zh', 'en'）
  /// [targetLang] 目标语言（如 'en', 'zh'）
  Future<String?> translateText(
    String text, {
    String sourceLang = 'auto',
    String targetLang = 'en',
  }) async {
    if (!_backend.isLoaded) {
      _errorMessage = 'LLM 模型未加载';
      _state = LlmServiceState.error;
      return null;
    }

    _state = LlmServiceState.inferring;

    // 构建翻译 prompt
    String prompt;
    if (sourceLang == 'auto') {
      prompt = '请将以下文本翻译成$targetLang，只输出翻译结果，不要解释：\n$text';
    } else {
      prompt = '请将以下$sourceLang文本翻译成$targetLang，只输出翻译结果，不要解释：\n$text';
    }

    try {
      final messages = [
        LlmMessage(role: LlmMessageRole.user, content: prompt),
      ];

      final result = await _backend.infer(
        messages,
        temperature: 0.3,
        maxTokens: 1024,
      );

      _state = LlmServiceState.ready;
      return result.fullText ?? result.delta;
    } catch (e) {
      _errorMessage = e.toString();
      _state = LlmServiceState.error;
      return null;
    }
  }

  /// 停止当前推理
  void stopInference() {
    _inferSubscription?.cancel();
    _inferSubscription = null;
    _state = LlmServiceState.ready;
  }

  /// 卸载模型
  Future<void> unload() async {
    await _backend.unload();
    _currentModelPath = null;
    _currentSession = null;
    _state = LlmServiceState.idle;
  }

  /// 预热模型
  Future<bool> warmup() async {
    return _backend.warmup();
  }

  /// 获取状态信息
  Map<String, dynamic> getStatusMap() {
    return {
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': _currentModelPath,
      'modelName': modelName,
      'contextLength': contextLength,
      'errorMessage': _errorMessage,
    };
  }

  /// 释放资源
  void dispose() {
    stopInference();
    unload();
  }

  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
