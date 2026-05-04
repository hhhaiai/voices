import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

import '../engines/base/tts_backend.dart';
import '../engines/backends/sherpa_tts_backend.dart';

/// TTS 服务状态
enum TtsServiceState {
  idle,
  loading,
  ready,
  generating,
  playing,
  error,
}

/// TTS 服务
/// 统一管理 TTS 引擎，提供文本转语音能力
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  TtsBackend? _backend;
  final AudioPlayer _player = AudioPlayer();

  TtsBackend get _backendInstance {
    _backend ??= SherpaTtsBackend();
    return _backend!;
  }

  TtsServiceState _state = TtsServiceState.idle;
  String? _errorMessage;
  String? _currentModelPath;
  int _currentSpeaker = 0;
  double _currentSpeed = 1.0;

  /// 可用说话人数量
  int get numSpeakers => _backendInstance.numSpeakers;

  /// 输出采样率
  int get sampleRate => _backendInstance.sampleRate;

  /// 当前服务状态
  TtsServiceState get state => _state;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 是否已加载模型
  bool get isLoaded => _backendInstance.isLoaded;

  /// 加载 TTS 模型
  Future<bool> loadModel(String modelPath) async {
    try {
      _state = TtsServiceState.loading;
      _errorMessage = null;

      final loaded = await _backendInstance.load(modelPath);
      if (loaded) {
        _currentModelPath = modelPath;
        _state = TtsServiceState.ready;
        return true;
      } else {
        _errorMessage = _backendInstance.lastError ?? '模型加载失败';
        _state = TtsServiceState.error;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = TtsServiceState.error;
      return false;
    }
  }

  /// 生成并播放语音
  /// [text] 要转换的文本
  /// [speakerId] 说话人 ID（默认 0）
  /// [speed] 语速（1.0=正常）
  Future<bool> speak(
    String text, {
    int speakerId = 0,
    double speed = 1.0,
  }) async {
    if (!_backendInstance.isLoaded) {
      _errorMessage = 'TTS 模型未加载';
      _state = TtsServiceState.error;
      return false;
    }

    try {
      _state = TtsServiceState.generating;
      _currentSpeaker = speakerId;
      _currentSpeed = speed;

      final result = await _backendInstance.synthesize(
        text,
        sid: speakerId,
        speed: speed,
      );

      if (result == null) {
        _errorMessage = '语音生成失败';
        _state = TtsServiceState.error;
        return false;
      }

      // 转换为 PCM 16-bit 并播放
      final pcmData = _float32ToPcm16Le(result.samples);
      _state = TtsServiceState.playing;

      // 保存到临时文件用于播放
      final tempFile = await _writeWavFile(pcmData, result.sampleRate);
      await _player.setFilePath(tempFile.path);
      await _player.play();

      // 播放完成后删除临时文件
      _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      ).then((_) {
        tempFile.delete().whenComplete(() {});
      });

      _state = TtsServiceState.ready;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = TtsServiceState.error;
      return false;
    }
  }

  /// 生成语音并返回音频数据
  /// 用于预览或保存
  Future<TtsAudioResult?> generate(String text, {int speakerId = 0, double speed = 1.0}) async {
    if (!_backendInstance.isLoaded) {
      _errorMessage = 'TTS 模型未加载';
      return null;
    }

    try {
      _state = TtsServiceState.generating;
      final result = await _backendInstance.synthesize(
        text,
        sid: speakerId,
        speed: speed,
      );
      _state = TtsServiceState.ready;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _state = TtsServiceState.error;
      return null;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
    _state = TtsServiceState.ready;
  }

  /// 卸载模型
  Future<void> unload() async {
    await _player.stop();
    await _backendInstance.unload();
    _currentModelPath = null;
    _state = TtsServiceState.idle;
  }

  /// 预热模型
  Future<bool> warmup() async {
    return _backendInstance.warmup();
  }

  /// 获取状态信息
  Map<String, dynamic> getStatusMap() {
    return {
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': _currentModelPath,
      'numSpeakers': numSpeakers,
      'sampleRate': sampleRate,
      'currentSpeaker': _currentSpeaker,
      'currentSpeed': _currentSpeed,
      'errorMessage': _errorMessage,
    };
  }

  /// 释放资源
  void dispose() {
    unload();
    _player.dispose();
  }

  /// Float32 [-1, 1] 转 PCM 16-bit LE
  Uint8List _float32ToPcm16Le(Float32List floatData) {
    final pcmData = Uint8List(floatData.length * 2);
    for (var i = 0; i < floatData.length; i++) {
      final sample = (floatData[i] * 32767).round().clamp(-32768, 32767);
      pcmData[i * 2] = sample & 0xFF;
      pcmData[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return pcmData;
  }

  /// 写入 WAV 文件
  Future<File> _writeWavFile(Uint8List pcmData, int sampleRate) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');

    // WAV header: 44 bytes
    const headerSize = 44;
    final totalSize = headerSize + pcmData.length;
    final header = Uint8List(headerSize);

    // RIFF header
    header[0] = 0x52; // R
    header[1] = 0x49; // I
    header[2] = 0x46; // F
    header[3] = 0x46; // F
    header[4] = (totalSize - 8) & 0xFF;
    header[5] = ((totalSize - 8) >> 8) & 0xFF;
    header[6] = ((totalSize - 8) >> 16) & 0xFF;
    header[7] = ((totalSize - 8) >> 24) & 0xFF;
    header[8] = 0x57; // W
    header[9] = 0x41; // A
    header[10] = 0x56; // V
    header[11] = 0x45; // E

    // fmt chunk
    header[12] = 0x66; // f
    header[13] = 0x6D; // m
    header[14] = 0x74; // t
    header[15] = 0x20; // space
    header[16] = 0x10; // chunk size (16)
    header[17] = 0x00;
    header[18] = 0x00;
    header[19] = 0x00;
    header[20] = 0x01; // audio format (PCM)
    header[21] = 0x00;
    header[22] = 0x01; // channels (mono)
    header[23] = 0x00;
    header[24] = sampleRate & 0xFF;
    header[25] = (sampleRate >> 8) & 0xFF;
    header[26] = (sampleRate >> 16) & 0xFF;
    header[27] = (sampleRate >> 24) & 0xFF;
    final byteRate = sampleRate * 2; // 16-bit mono
    header[28] = byteRate & 0xFF;
    header[29] = (byteRate >> 8) & 0xFF;
    header[30] = (byteRate >> 16) & 0xFF;
    header[31] = (byteRate >> 24) & 0xFF;
    header[32] = 0x02; // block align (2 bytes)
    header[33] = 0x00;
    header[34] = 0x10; // bits per sample (16)
    header[35] = 0x00;

    // data chunk
    header[36] = 0x64; // d
    header[37] = 0x61; // a
    header[38] = 0x74; // t
    header[39] = 0x61; // a
    header[40] = pcmData.length & 0xFF;
    header[41] = (pcmData.length >> 8) & 0xFF;
    header[42] = (pcmData.length >> 16) & 0xFF;
    header[43] = (pcmData.length >> 24) & 0xFF;

    final wavData = Uint8List(headerSize + pcmData.length);
    wavData.setRange(0, headerSize, header);
    wavData.setRange(headerSize, wavData.length, pcmData);

    await tempFile.writeAsBytes(wavData);
    return tempFile;
  }
}
