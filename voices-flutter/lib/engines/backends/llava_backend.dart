import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../base/vision_backend.dart';

/// LLaVA 多模态后端
/// 使用 llama_cpp_dart 进行图像理解推理
class LlavaBackend implements VisionBackend {
  LlamaParent? _llama;
  VisionBackendState _state = VisionBackendState.idle;
  String? _modelPath;
  String? _modelName;
  String? _errorMessage;

  @override
  String get engineId => 'llava';

  @override
  VisionBackendState get state => _state;

  @override
  bool get isLoaded => _llama != null;

  @override
  String? get lastError => _errorMessage;

  @override
  String? get modelPath => _modelPath;

  @override
  String? get modelName => _modelName;

  @override
  List<String> get supportedFormats => ['png', 'jpg', 'jpeg', 'webp', 'bmp'];

  @override
  Future<bool> load(String modelPath) async {
    await unload();
    _state = VisionBackendState.loading;
    _errorMessage = null;

    try {
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        _errorMessage = '模型文件不存在: $modelPath';
        _state = VisionBackendState.error;
        return false;
      }

      final modelParams = ModelParams();
      final contextParams = ContextParams();
      contextParams.nCtx = 4096;
      contextParams.nThreads = 4;

      final samplingParams = SamplerParams();
      samplingParams.temp = 0.7;
      samplingParams.topK = 40;
      samplingParams.topP = 0.95;

      // LLaVA 使用 ChatML 格式
      final format = ChatMLFormat();

      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
      );

      _llama = LlamaParent(loadCommand, format);
      await _llama!.init();

      _modelName = _extractModelName(modelPath);
      _modelPath = modelPath;

      _state = VisionBackendState.ready;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = VisionBackendState.error;
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
      _state = VisionBackendState.idle;
    }
  }

  @override
  Future<VisionResult?> understand(
    String imagePath, {
    String? question,
  }) async {
    final llama = _llama;
    if (llama == null) {
      _errorMessage = '模型未加载';
      return null;
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      _errorMessage = '图像文件不存在: $imagePath';
      return null;
    }

    _state = VisionBackendState.inferring;
    final startTime = DateTime.now();

    try {
      // 构建 prompt
      final prompt = question ?? '请描述这张图片的内容。';
      final fullPrompt = '<|user|>\n<|image|>\n$prompt<|end|>\n<|assistant|>';

      // 创建图像输入
      final llamaImage = LlamaImage.fromFile(imageFile);

      // 收集输出
      final buffer = StringBuffer();
      final subscription = llama.stream.listen(
        (text) => buffer.write(text),
        onError: (e) {
          _errorMessage = e.toString();
          _state = VisionBackendState.error;
        },
        onDone: () {},
      );

      // 发送带图像的 prompt
      llama.sendPromptWithImages(fullPrompt, [llamaImage]);

      // 等待完成
      await for (final _ in llama.stream) {
        if (!llama.isGenerating) break;
      }

      await subscription.cancel();

      final totalMs = DateTime.now().difference(startTime).inMilliseconds;
      final description = buffer.toString().trim();

      _state = VisionBackendState.ready;
      return VisionResult(
        description: description,
        confidence: 0.0, // LLaVA 不提供置信度
        latencyMs: totalMs,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _state = VisionBackendState.error;
      return null;
    }
  }

  @override
  Map<String, dynamic> statusMap() {
    return {
      'engineId': engineId,
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': modelPath,
      'modelName': modelName,
      'supportedFormats': supportedFormats,
      'lastError': lastError,
    };
  }

  @override
  Future<bool> warmup() async {
    final llama = _llama;
    if (llama == null) return false;

    try {
      // 预热：发送简单文本 prompt（无图像）
      llama.sendPrompt('<|user|>\nHello<|end|>\n<|assistant|>');
      await for (final _ in llama.stream) {
        if (!llama.isGenerating) break;
      }
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
