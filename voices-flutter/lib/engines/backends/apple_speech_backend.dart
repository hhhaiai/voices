import 'dart:async';
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
  final StreamController<String> _partialResultController =
      StreamController<String>.broadcast();

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

  /// Partial results stream for real-time transcription
  Stream<String> get partialResults => _partialResultController.stream;

  @override
  Future<bool> load(String modelPath) async {
    _state = BackendState.loading;
    _lastError = null;

    try {
      // 启动 native 实时语音识别
      final ok = await _service.startPcmTranscription();
      if (!ok) {
        _lastError = '启动实时语音识别失败';
        _state = BackendState.error;
        return false;
      }

      // 设置 partial results 回调
      _service.setPartialResultCallback((text) {
        _partialResultController.add(text);
      });

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
    _partialResultController.add(''); // 清空 partial results
    await _service.unload();
    _service.setPartialResultCallback(null);
    _state = BackendState.idle;
  }

  @override
  Future<String?> transcribePcm(Uint8List pcmData, int sampleRate) async {
    // Apple Speech 实时模式下，音频由 AVAudioEngine 在 native 端直接捕获
    // 此方法不需要处理 PCM，results 通过 partialResults stream 推送
    // 返回空字符串，实际识别结果通过 stream 获取
    return '';
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
    _partialResultController.close();
    unload();
  }
}
