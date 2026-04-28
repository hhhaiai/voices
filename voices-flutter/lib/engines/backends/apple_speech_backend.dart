import 'dart:io';
import 'dart:typed_data';

import '../../services/apple_speech_service.dart';
import '../base/engine_backend.dart';

/// Apple Speech 引擎后端
/// 使用 iOS/macOS 系统 Speech 框架
class AppleSpeechBackend implements EngineBackend {
  final AppleSpeechService _service = AppleSpeechService();

  BackendState _state = BackendState.idle;
  String? _lastError;

  @override
  String get engineId => 'apple_speech';

  @override
  BackendState get state => _state;

  @override
  bool get isLoaded => _state == BackendState.ready;

  @override
  String? get lastError => _lastError;

  @override
  String? get modelPath => null; // Apple Speech 不需要模型文件

  @override
  Future<bool> load(String modelPath) async {
    // Apple Speech 不需要加载模型，检查可用性即可
    _state = BackendState.loading;
    _lastError = null;

    try {
      // Apple Speech 始终可用（在支持的平台上）
      _state = BackendState.ready;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _state = BackendState.error;
      return false;
    }
  }

  @override
  Future<void> unload() async {
    await _service.unload();
    _state = BackendState.idle;
  }

  @override
  Future<String?> transcribePcm(Uint8List pcmData, int sampleRate) async {
    // Apple Speech 不支持实时 PCM 流转写
    return 'Error: Apple Speech 当前不支持实时麦克风转写，仅支持音频文件转写';
  }

  @override
  Future<String?> transcribeFile(String filePath) async {
    _state = BackendState.transcribing;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'Error: 文件不存在: $filePath';
      }

      final result = await _service.transcribeFile(filePath);
      _state = BackendState.ready;

      if (result.startsWith('Error:')) {
        _lastError = result;
      }
      return result;
    } catch (e) {
      _lastError = e.toString();
      _state = BackendState.error;
      return 'Error: $e';
    }
  }

  @override
  Map<String, dynamic> statusMap() {
    return {
      'engineId': engineId,
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': modelPath,
      'lastError': _lastError,
    };
  }

  @override
  bool isErrorResult(String? result) {
    if (result == null) return true;
    return result.startsWith('Error:');
  }

  @override
  String? extractErrorMessage(String? result) {
    if (result == null) return _lastError;
    if (result.startsWith('Error:')) {
      return result.substring('Error:'.length).trim();
    }
    return null;
  }

  @override
  void dispose() {
    unload();
  }
}
