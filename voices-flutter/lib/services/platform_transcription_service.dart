import 'package:flutter/services.dart';

/// 平台通道服务 - 与 Android native 代码通信
class PlatformTranscriptionService {
  static const MethodChannel _channel = MethodChannel('com.sanbo.voices/transcription');

  static final PlatformTranscriptionService _instance = PlatformTranscriptionService._internal();
  factory PlatformTranscriptionService() => _instance;
  PlatformTranscriptionService._internal();

  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  Future<bool> engineLoad({
    required String engineType,
    required String modelPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('engineLoad', {
        'engineType': engineType,
        'modelPath': modelPath,
      });
      _isModelLoaded = result ?? false;
      return _isModelLoaded;
    } on MissingPluginException {
      _isModelLoaded = false;
      return false;
    } catch (_) {
      _isModelLoaded = false;
      return false;
    }
  }

  /// 加载模型 - 使用默认 whisper 引擎
  /// 注意：此便捷方法仅用于兼容旧代码，建议使用 engineLoad 方法
  @Deprecated('请使用 engineLoad 方法指定引擎类型')
  Future<bool> loadModel(String modelPath) async {
    return engineLoad(engineType: 'whisper', modelPath: modelPath);
  }

  /// 转写音频 - 使用默认 whisper 引擎
  /// 注意：此便捷方法仅用于兼容旧代码，建议使用 engineTranscribe 方法
  @Deprecated('请使用 engineTranscribe 方法指定引擎类型')
  Future<String> transcribe(List<double> audioData, {int sampleRate = 16000}) async {
    return engineTranscribe('whisper', audioData, sampleRate: sampleRate);
  }

  /// 转写 PCM 数据 - 使用默认 whisper 引擎
  /// 注意：此便捷方法仅用于兼容旧代码，建议使用 engineTranscribePcm 方法
  @Deprecated('请使用 engineTranscribePcm 方法指定引擎类型')
  Future<String> transcribePcm(Uint8List pcmData, {int sampleRate = 16000}) async {
    return engineTranscribePcm(
      engineType: 'whisper',
      pcmData: pcmData,
      sampleRate: sampleRate,
    );
  }

  /// 转写 PCM 数据
  Future<String> engineTranscribePcm({
    required String engineType,
    required Uint8List pcmData,
    int sampleRate = 16000,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('engineTranscribePcm', {
        'engineType': engineType,
        'pcmData': pcmData,
        'sampleRate': sampleRate,
      });
      return result ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 转写音频文件
  Future<String> engineTranscribeFile({
    required String engineType,
    required String filePath,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('engineTranscribeFile', {
        'engineType': engineType,
        'filePath': filePath,
      });
      return result ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> engineTranscribe(
    String engineType,
    List<double> audioData, {
    int sampleRate = 16000,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('engineTranscribe', {
        'engineType': engineType,
        'audioData': audioData,
        'sampleRate': sampleRate,
      });
      return result ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 检查模型是否已加载
  Future<bool> checkModelLoaded() async {
    try {
      final result = await _channel.invokeMethod<bool>('isModelLoaded');
      _isModelLoaded = result ?? false;
      return _isModelLoaded;
    } catch (e) {
      return false;
    }
  }

  /// 卸载模型
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod('engineUnload');
      _isModelLoaded = false;
    } catch (_) {
      _isModelLoaded = false;
    }
  }
}
