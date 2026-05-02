import '../utils/platform_utils.dart';
import 'base/engine_backend.dart';
import 'backends/platform_engine_backend.dart';
import 'backends/sherpa_whisper_backend.dart';
import 'backends/sherpa_vosk_backend.dart';
import 'backends/sensevoice_backend.dart';
import 'backends/apple_speech_backend.dart';

/// 引擎后端解析器
/// 根据 engineId 和 platform 返回正确的 EngineBackend 实例
class BackendResolver {
  const BackendResolver();

  /// 根据引擎 ID 和平台解析后端
  /// [engineId] 引擎 ID (whisper, vosk, sensevoice_onnx, apple_speech)
  /// [platform] 平台标识 (android, ios, macos, linux, windows, fuchsia)
  static EngineBackend resolve(String engineId, [String? platform]) {
    final targetPlatform = platform ?? PlatformUtils.currentPlatform;

    switch (engineId) {
      case 'whisper':
        return _resolveWhisperBackend(targetPlatform);
      case 'vosk':
        return _resolveVoskBackend(targetPlatform);
      case 'sensevoice_onnx':
        return SenseVoiceBackend();
      case 'apple_speech':
        return _resolveAppleSpeechBackend(targetPlatform);
      default:
        throw ArgumentError('未知的引擎 ID: $engineId');
    }
  }

  static EngineBackend _resolveWhisperBackend(String platform) {
    if (platform == 'android') {
      return PlatformEngineBackend(engineId: 'whisper');
    }
    return SherpaWhisperBackend();
  }

  static EngineBackend _resolveVoskBackend(String platform) {
    if (platform == 'android') {
      return PlatformEngineBackend(engineId: 'vosk');
    }
    return SherpaVoskBackend();
  }

  static EngineBackend _resolveAppleSpeechBackend(String platform) {
    if (platform == 'ios' || platform == 'macos') {
      return AppleSpeechBackend();
    }
    throw UnsupportedError('Apple Speech 仅支持 iOS 和 macOS 平台');
  }

  /// 检查引擎是否支持指定平台
  static bool isEngineSupportedOnPlatform(String engineId, String platform) {
    switch (engineId) {
      case 'whisper':
      case 'vosk':
      case 'sensevoice_onnx':
        return true;
      case 'apple_speech':
        return platform == 'ios' || platform == 'macos';
      default:
        return false;
    }
  }

  /// 获取引擎支持的平台列表
  static List<String> getSupportedPlatforms(String engineId) {
    switch (engineId) {
      case 'whisper':
      case 'vosk':
      case 'sensevoice_onnx':
        return ['android', 'ios', 'macos', 'linux', 'windows'];
      case 'apple_speech':
        return ['ios', 'macos'];
      default:
        return [];
    }
  }
}
