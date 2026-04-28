import 'dart:io';
import 'dart:typed_data';

import '../../services/platform_transcription_service.dart';
import '../base/engine_backend.dart';

/// Android 平台引擎后端
/// 使用 MethodChannel 与原生代码通信
class PlatformEngineBackend implements EngineBackend {
  PlatformEngineBackend({this.engineId = 'whisper'});

  final PlatformTranscriptionService _service = PlatformTranscriptionService();

  BackendState _state = BackendState.idle;
  String? _lastError;
  String? _modelPath;

  @override
  final String engineId;

  @override
  BackendState get state => _state;

  @override
  bool get isLoaded => _service.isModelLoaded;

  @override
  String? get lastError => _lastError;

  @override
  String? get modelPath => _modelPath;

  @override
  Future<bool> load(String modelPath) async {
    _state = BackendState.loading;
    _lastError = null;
    _modelPath = modelPath;

    try {
      final result = await _service.engineLoad(
        engineType: engineId,
        modelPath: modelPath,
      );
      if (result) {
        _state = BackendState.ready;
        return true;
      } else {
        _lastError = '加载失败';
        _state = BackendState.error;
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      _state = BackendState.error;
      return false;
    }
  }

  @override
  Future<void> unload() async {
    try {
      await _service.unloadModel();
    } catch (_) {
      // ignore
    } finally {
      _state = BackendState.idle;
      _modelPath = null;
      _lastError = null;
    }
  }

  @override
  Future<String?> transcribePcm(Uint8List pcmData, int sampleRate) async {
    if (!isLoaded) {
      return 'Error: 模型未加载';
    }

    _state = BackendState.transcribing;
    try {
      final result = await _service.engineTranscribePcm(
        engineType: engineId,
        pcmData: pcmData,
        sampleRate: sampleRate,
      );
      _state = BackendState.ready;
      return result;
    } catch (e) {
      _lastError = e.toString();
      _state = BackendState.error;
      return 'Error: $e';
    }
  }

  @override
  Future<String?> transcribeFile(String filePath) async {
    if (!isLoaded) {
      return 'Error: 模型未加载';
    }

    _state = BackendState.transcribing;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'Error: 文件不存在: $filePath';
      }

      final result = await _service.engineTranscribeFile(
        engineType: engineId,
        filePath: filePath,
      );
      _state = BackendState.ready;
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
      'modelPath': _modelPath,
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
