import 'dart:io';

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
    final targetPlatform = platform ?? _currentPlatform;

    // 根据平台和引擎返回对应的后端
    switch (engineId) {
      case 'whisper':
        return _resolveWhisperBackend(targetPlatform);
      case 'vosk':
        return _resolveVoskBackend(targetPlatform);
      case 'sensevoice_onnx':
        return _resolveSenseVoiceBackend(targetPlatform);
      case 'apple_speech':
        return _resolveAppleSpeechBackend(targetPlatform);
      default:
        throw ArgumentError('未知的引擎 ID: $engineId');
    }
  }

  /// 解析 Whisper 后端
  static EngineBackend _resolveWhisperBackend(String platform) {
    if (platform == 'android') {
      return PlatformEngineBackend(engineId: 'whisper');
    }
    // iOS/macOS/Linux/Windows 使用 Sherpa ONNX
    return SherpaWhisperBackend();
  }

  /// 解析 Vosk 后端
  static EngineBackend _resolveVoskBackend(String platform) {
    if (platform == 'android') {
      return PlatformEngineBackend(engineId: 'vosk');
    }
    // iOS/macOS/Linux/Windows 使用 Sherpa ONNX
    return SherpaVoskBackend();
  }

  /// 解析 SenseVoice 后端
  static EngineBackend _resolveSenseVoiceBackend(String platform) {
    // SenseVoice 全平台使用 Sherpa ONNX
    return SenseVoiceBackend();
  }

  /// 解析 Apple Speech 后端
  static EngineBackend _resolveAppleSpeechBackend(String platform) {
    // Apple Speech 仅在 Apple 平台可用
    if (platform == 'ios' || platform == 'macos') {
      return AppleSpeechBackend();
    }
    throw UnsupportedError('Apple Speech 仅支持 iOS 和 macOS 平台');
  }

  /// 获取当前平台
  static String get _currentPlatform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return 'fuchsia';
  }

  /// 检查引擎是否支持指定平台
  static bool isEngineSupportedOnPlatform(String engineId, String platform) {
    switch (engineId) {
      case 'whisper':
        return true; // 所有平台都支持
      case 'vosk':
        return true; // 所有平台都支持
      case 'sensevoice_onnx':
        return true; // 所有平台都支持
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
        return ['android', 'ios', 'macos', 'linux', 'windows'];
      case 'vosk':
        return ['android', 'ios', 'macos', 'linux', 'windows'];
      case 'sensevoice_onnx':
        return ['android', 'ios', 'macos', 'linux', 'windows'];
      case 'apple_speech':
        return ['ios', 'macos'];
      default:
        return [];
    }
  }
}
