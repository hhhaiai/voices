import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../base/llm_backend.dart';

/// GGUF 格式 LLM 后端
/// 使用 llama_cpp_dart 包进行 GGUF 模型推理
class GgufLlmBackend implements LlmBackend {
  LlamaParent? _llama;
  LlmBackendState _state = LlmBackendState.idle;
  String? _modelPath;
  String? _modelName;
  String? _errorMessage;
  int _contextLength = 4096;

  @override
  String get engineId => 'gguf_llm';

  @override
  LlmBackendState get state => _state;

  @override
  bool get isLoaded => _llama != null;

  @override
  String? get lastError => _errorMessage;

  @override
  String? get modelPath => _modelPath;

  @override
  String? get modelName => _modelName;

  @override
  int get contextLength => _contextLength;

  @override
  Future<bool> load(String modelPath) async {
    await unload();
    _state = LlmBackendState.loading;
    _errorMessage = null;

    try {
      final contextParams = ContextParams();
      contextParams.nCtx = 4096;
      contextParams.nThreads = 4;

      final samplingParams = SamplerParams();
      samplingParams.temp = 0.7;
      samplingParams.topK = 40;
      samplingParams.topP = 0.95;

      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: ModelParams(),
        contextParams: contextParams,
        samplingParams: samplingParams,
      );

      _llama = LlamaParent(loadCommand);
      await _llama!.init();

      _modelName = _extractModelName(modelPath);
      _modelPath = modelPath;

      _state = LlmBackendState.ready;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = LlmBackendState.error;
      return false;
    }
  }

  String _extractModelName(String path) {
    final fileName = path.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      return fileName.substring(0, dotIndex);
    }
    return fileName;
  }

  @override
  Future<void> unload() async {
    try {
      await _llama?.dispose();
    } catch (_) {
      // ignore
    } finally {
      _llama = null;
      _modelPath = null;
      _modelName = null;
      _contextLength = 4096;
      _state = LlmBackendState.idle;
    }
  }

  @override
  Stream<LlmStreamResult> streamInfer(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 0,
  }) async* {
    final llama = _llama;
    if (llama == null) {
      yield const LlmStreamResult(
        delta: '',
        done: true,
        fullText: '',
        latencyMs: 0,
      );
      return;
    }

    _state = LlmBackendState.inferring;
    final startTime = DateTime.now();

    try {
      final prompt = _buildPrompt(messages);

      // 收集所有输出
      final buffer = StringBuffer();
      final completer = <String>[];

      // 监听流
      final subscription = llama.stream.listen(
        (text) {
          buffer.write(text);
          completer.add(text);
        },
        onError: (e) {
          _errorMessage = e.toString();
          _state = LlmBackendState.error;
        },
        onDone: () {},
      );

      // 发送 prompt
      llama.sendPrompt(prompt);

      // 等待流完成（通过检查 isGenerating）
      await for (final _ in llama.stream) {
        final lastDelta =
            completer.isNotEmpty ? completer.last : '';

        yield LlmStreamResult(
          delta: lastDelta,
          done: false,
          latencyMs: DateTime.now().difference(startTime).inMilliseconds,
        );

        if (!llama.isGenerating) {
          break;
        }

        if (maxTokens > 0 && buffer.length > maxTokens) {
          await llama.stop();
          break;
        }
      }

      await subscription.cancel();

      final totalMs = DateTime.now().difference(startTime).inMilliseconds;
      final fullText = buffer.toString();

      _state = LlmBackendState.ready;
      yield LlmStreamResult(
        delta: '',
        done: true,
        fullText: fullText,
        latencyMs: totalMs,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _state = LlmBackendState.error;
      yield LlmStreamResult(
        delta: '',
        done: true,
        latencyMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  @override
  Future<LlmStreamResult> infer(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 0,
  }) async {
    final startTime = DateTime.now();
    String fullText = '';

    await for (final result in streamInfer(
      messages,
      temperature: temperature,
      maxTokens: maxTokens,
    )) {
      if (result.done) {
        fullText = result.fullText ?? '';
        return LlmStreamResult(
          delta: fullText,
          done: true,
          fullText: fullText,
          latencyMs: DateTime.now().difference(startTime).inMilliseconds,
        );
      }
    }

    return LlmStreamResult(
      delta: fullText,
      done: true,
      fullText: fullText,
      latencyMs: DateTime.now().difference(startTime).inMilliseconds,
    );
  }

  String _buildPrompt(List<LlmMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      switch (msg.role) {
        case LlmMessageRole.system:
          buffer.write('<|system|>\n${msg.content}<|end|>\n');
        case LlmMessageRole.user:
          buffer.write('<|user|>\n${msg.content}<|end|>\n');
        case LlmMessageRole.assistant:
          buffer.write('<|assistant|>\n${msg.content}<|end|>\n');
      }
    }
    buffer.write('<|assistant|>\n');
    return buffer.toString();
  }

  @override
  Map<String, dynamic> statusMap() {
    return {
      'engineId': engineId,
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': modelPath,
      'modelName': modelName,
      'contextLength': contextLength,
      'lastError': lastError,
    };
  }

  @override
  Future<bool> warmup() async {
    final llama = _llama;
    if (llama == null) return false;

    try {
      final warmupMessages = [
        const LlmMessage(role: LlmMessageRole.user, content: 'Hi'),
      ];

      await for (final _ in streamInfer(warmupMessages, maxTokens: 5)) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    unload();
  }
}
