import 'dart:io';

/// 平台检测工具类
/// 集中管理平台判断逻辑，避免各文件重复 Platform.isXxx 检查
class PlatformUtils {
  const PlatformUtils._();

  /// 当前平台标识
  static String get currentPlatform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return 'fuchsia';
  }

  /// 是否为移动平台（Android/iOS）
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// 是否为桌面平台（macOS/Linux/Windows）
  static bool get isDesktop => Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// 是否为 Apple 平台（iOS/macOS）
  static bool get isApple => Platform.isIOS || Platform.isMacOS;

  /// 是否使用 sherpa_onnx Dart FFI 后端（非 Android 平台）
  /// Android 使用 MethodChannel → whisper.cpp JNI / vosk-android
  /// 其他平台使用 sherpa_onnx Dart 包
  static bool get usesSherpaOnnx => !Platform.isAndroid;

  /// 是否支持 Apple Speech 引擎
  static bool get supportsAppleSpeech => Platform.isIOS || Platform.isMacOS;

  /// 获取适合当前平台的模型存储目录名
  static String get modelStorageDescription {
    if (Platform.isAndroid) return '应用外部存储/models/';
    if (Platform.isIOS || Platform.isMacOS) return '应用 Documents/models/';
    if (Platform.isLinux) return '~/.local/share/voices/models/';
    if (Platform.isWindows) return '%APPDATA%\\voices\\models\\';
    return '应用文档目录/models/';
  }
}
