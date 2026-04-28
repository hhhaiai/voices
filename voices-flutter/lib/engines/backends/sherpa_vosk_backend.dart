import 'dart:typed_data';

import '../../services/sherpa_vosk_service.dart';
import '../base/engine_backend.dart';

/// Sherpa Vosk 引擎后端
/// 使用 sherpa_onnx Dart 包进行推理
class SherpaVoskBackend implements EngineBackend {
  final SherpaVoskService _service = SherpaVoskService();

  BackendState _state = BackendState.idle;

  @override
  String get engineId => 'vosk';

  @override
  BackendState get state => _state;

  @override
  bool get isLoaded => _service.isLoaded;

  @override
  String? get lastError => _service.lastError;

  @override
  String? get modelPath => _service.modelPath;

  @override
  Future<bool> load(String modelPath) async {
    _state = BackendState.loading;

    try {
      final result = await _service.loadModel(modelPath);
      if (result) {
        _state = BackendState.ready;
        return true;
      } else {
        _state = BackendState.error;
        return false;
      }
    } catch (e) {
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
    if (!isLoaded) {
      return 'Error: Vosk ONNX 模型未加载';
    }

    _state = BackendState.transcribing;
    try {
      final result = await _service.transcribePcm(pcmData, sampleRate);
      _state = BackendState.ready;
      return result;
    } catch (e) {
      _state = BackendState.error;
      return 'Error: $e';
    }
  }

  @override
  Future<String?> transcribeFile(String filePath) async {
    if (!isLoaded) {
      return 'Error: Vosk ONNX 模型未加载';
    }

    _state = BackendState.transcribing;
    try {
      final result = await _service.transcribeFile(filePath);
      _state = BackendState.ready;
      return result;
    } catch (e) {
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
      'lastError': lastError,
    };
  }

  @override
  bool isErrorResult(String? result) {
    if (result == null) return true;
    return result.startsWith('Error:');
  }

  @override
  String? extractErrorMessage(String? result) {
    if (result == null) return lastError;
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
