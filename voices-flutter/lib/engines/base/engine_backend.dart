import 'dart:typed_data';

/// 引擎后端状态
enum BackendState {
  /// 空闲，未加载
  idle,

  /// 加载中
  loading,

  /// 已加载就绪
  ready,

  /// 转写中
  transcribing,

  /// 错误
  error,
}

/// 引擎后端抽象接口
/// 定义所有 STT 引擎后端需要实现的统一接口
abstract class EngineBackend {
  /// 引擎唯一标识符
  String get engineId;

  /// 当前状态
  BackendState get state;

  /// 是否已加载模型
  bool get isLoaded;

  /// 最后一次错误信息
  String? get lastError;

  /// 模型路径（如果有）
  String? get modelPath;

  /// 加载模型
  /// [modelPath] 模型文件或目录的路径
  /// 返回是否加载成功
  Future<bool> load(String modelPath);

  /// 卸载模型
  Future<void> unload();

  /// 转写 PCM 音频数据
  /// [pcmData] PCM 原始音频数据（16-bit LE）
  /// [sampleRate] 采样率
  /// 返回转写文本，失败返回 null 或带 Error: 前缀的字符串
  Future<String?> transcribePcm(Uint8List pcmData, int sampleRate);

  /// 转写音频文件
  /// [filePath] 音频文件路径
  /// 返回转写文本，失败返回 null 或带 Error: 前缀的字符串
  Future<String?> transcribeFile(String filePath);

  /// 获取详细状态信息
  Map<String, dynamic> statusMap();

  /// 解析转写结果
  /// 将引擎返回的原始结果解析为标准格式
  /// 默认实现处理 "Error:" 前缀的情况
  bool isErrorResult(String? result) {
    if (result == null) return true;
    return result.startsWith('Error:');
  }

  /// 提取错误消息
  /// 如果结果是以 "Error:" 开头，返回错误消息部分
  String? extractErrorMessage(String? result) {
    if (result == null) return lastError;
    if (result.startsWith('Error:')) {
      return result.substring('Error:'.length).trim();
    }
    return null;
  }

  /// 清理资源
  void dispose();
}
