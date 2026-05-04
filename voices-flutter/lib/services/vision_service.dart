import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../engines/backends/llava_backend.dart';
import '../engines/base/vision_backend.dart';

/// Vision 服务状态
enum VisionServiceState {
  idle,
  loading,
  ready,
  inferring,
  error,
}

/// Vision 服务
/// 统一管理 Vision 引擎，提供图像理解能力
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  final VisionBackend _backend = LlavaBackend();

  VisionServiceState _state = VisionServiceState.idle;
  String? _errorMessage;
  String? _currentModelPath;

  /// 当前服务状态
  VisionServiceState get state => _state;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 是否已加载模型
  bool get isLoaded => _backend.isLoaded;

  /// 模型名称
  String? get modelName => _backend.modelName;

  /// 支持的图像格式
  List<String> get supportedFormats => _backend.supportedFormats;

  /// 加载 Vision 模型
  Future<bool> loadModel(String modelPath) async {
    try {
      _state = VisionServiceState.loading;
      _errorMessage = null;

      final loaded = await _backend.load(modelPath);
      if (loaded) {
        _currentModelPath = modelPath;
        _state = VisionServiceState.ready;
        return true;
      } else {
        _errorMessage = _backend.lastError ?? '模型加载失败';
        _state = VisionServiceState.error;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = VisionServiceState.error;
      return false;
    }
  }

  /// 理解图像
  /// [imagePath] 图像路径
  /// [question] 问题（可选）
  Future<VisionResult?> understand(
    String imagePath, {
    String? question,
  }) async {
    if (!_backend.isLoaded) {
      _errorMessage = 'Vision 模型未加载';
      _state = VisionServiceState.error;
      return null;
    }

    _state = VisionServiceState.inferring;

    try {
      final result = await _backend.understand(
        imagePath,
        question: question,
      );

      _state = VisionServiceState.ready;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _state = VisionServiceState.error;
      return null;
    }
  }

  /// 选择并理解图像（通过文件选择器）
  Future<VisionResult?> pickAndUnderstand({String? question}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final path = result.files.first.path;
      if (path == null) {
        _errorMessage = '无法获取文件路径';
        return null;
      }

      return understand(path, question: question);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  /// 卸载模型
  Future<void> unload() async {
    await _backend.unload();
    _currentModelPath = null;
    _state = VisionServiceState.idle;
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
      'supportedFormats': supportedFormats,
      'errorMessage': _errorMessage,
    };
  }

  /// 释放资源
  void dispose() {
    unload();
  }
}
