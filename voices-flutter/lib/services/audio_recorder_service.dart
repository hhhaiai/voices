import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../models/audio_input.dart';

/// 录音服务
class AudioRecorderService {
  static final AudioRecorderService _instance = AudioRecorderService._internal();
  factory AudioRecorderService() => _instance;
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<Uint8List>? _streamSubscription;
  final ListQueue<Uint8List> _realtimeChunks = ListQueue<Uint8List>();
  final ListQueue<Uint8List> _finalChunks = ListQueue<Uint8List>();
  int _realtimeBytes = 0;
  int _finalBytes = 0;
  int _totalCapturedBytes = 0;
  int _droppedRealtimeBytes = 0;
  int _droppedFinalBytes = 0;
  bool _finalAudioTruncated = false;

  static const int _pcmBytesPerSecond = 16000 * 2; // 16kHz, mono, pcm16
  static const int _maxRealtimeWindowBytes = _pcmBytesPerSecond * 8;
  static const int _maxFinalAudioBytes = _pcmBytesPerSecond * 120;

  /// 是否正在录音
  bool get isRecording => _isRecording;
  int get realtimeWindowBytes => _realtimeBytes;
  int get finalBufferedBytes => _finalBytes;
  int get totalCapturedBytes => _totalCapturedBytes;
  int get droppedRealtimeBytes => _droppedRealtimeBytes;
  int get droppedFinalBytes => _droppedFinalBytes;
  bool get finalAudioTruncated => _finalAudioTruncated;

  /// 是否有麦克风权限
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  /// 获取当前录音的振幅 (0.0 - 1.0)
  Future<double> getAmplitude() async {
    if (!_isRecording) return 0.0;
    try {
      final amplitude = await _recorder.getAmplitude();
      // 将分贝转换为 0-1 范围
      // typical range is -60 to 0 dB
      final db = amplitude.current;
      if (db == double.negativeInfinity || db < -60) return 0.0;
      return ((db + 60) / 60).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  /// 获取当前已录制的音频数据（用于实时转写）
  /// 注意：为了保持实时转写速度，只返回最近 30 秒的音频数据
  Future<AudioInput?> getCurrentAudio() async {
    if (!_isRecording) return null;
    final bytes = _flattenChunks(_realtimeChunks, _realtimeBytes);
    if (bytes.isEmpty) {
      return null;
    }

    // 只使用最近 30 秒的音频数据（30秒 * 16000采样率 * 2字节 = 960000字节）
    const maxAudioBytes = 30 * 16000 * 2;
    final recentBytes = bytes.length > maxAudioBytes
        ? bytes.sublist(bytes.length - maxAudioBytes)
        : bytes;

    return AudioInput.fromPcm(recentBytes);
  }

  /// 开始录音
  Future<void> startRecording({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    if (_isRecording) return;

    if (!await hasPermission()) {
      throw Exception('没有麦克风权限');
    }

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _realtimeChunks.clear();
    _finalChunks.clear();
    _realtimeBytes = 0;
    _finalBytes = 0;
    _totalCapturedBytes = 0;
    _droppedRealtimeBytes = 0;
    _droppedFinalBytes = 0;
    _finalAudioTruncated = false;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
      ),
    );
    _streamSubscription = stream.listen((chunk) {
      if (chunk.isNotEmpty) {
        final copied = Uint8List.fromList(chunk);
        _pushChunk(_realtimeChunks, copied, isFinalBuffer: false);
        _pushChunk(_finalChunks, copied, isFinalBuffer: true);
        _totalCapturedBytes += copied.length;
      }
    });

    _isRecording = true;
  }

  /// 停止录音
  Future<AudioInput?> stopRecording() async {
    if (!_isRecording) return null;

    await _recorder.stop();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _isRecording = false;

    final bytes = _flattenChunks(_finalChunks, _finalBytes);
    _realtimeChunks.clear();
    _finalChunks.clear();
    _realtimeBytes = 0;
    _finalBytes = 0;
    _droppedRealtimeBytes = 0;
    _droppedFinalBytes = 0;
    if (bytes.isEmpty) return null;
    return AudioInput.fromPcm(bytes);
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    await _recorder.stop();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _isRecording = false;
    _realtimeChunks.clear();
    _finalChunks.clear();
    _realtimeBytes = 0;
    _finalBytes = 0;
    _totalCapturedBytes = 0;
    _droppedRealtimeBytes = 0;
    _droppedFinalBytes = 0;
    _finalAudioTruncated = false;
  }

  /// 获取音频流
  Stream<Uint8List>? get audioStream => null;

  /// 释放资源
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    await _streamSubscription?.cancel();
    _realtimeChunks.clear();
    _finalChunks.clear();
    _realtimeBytes = 0;
    _finalBytes = 0;
    _totalCapturedBytes = 0;
    _droppedRealtimeBytes = 0;
    _droppedFinalBytes = 0;
    _finalAudioTruncated = false;
    await _recorder.dispose();
  }

  void _pushChunk(
    ListQueue<Uint8List> target,
    Uint8List chunk, {
    required bool isFinalBuffer,
  }) {
    target.addLast(chunk);
    if (isFinalBuffer) {
      _finalBytes += chunk.length;
    } else {
      _realtimeBytes += chunk.length;
    }

    final maxBytes = isFinalBuffer ? _maxFinalAudioBytes : _maxRealtimeWindowBytes;
    while ((isFinalBuffer ? _finalBytes : _realtimeBytes) > maxBytes && target.isNotEmpty) {
      final removed = target.removeFirst();
      if (isFinalBuffer) {
        _finalBytes -= removed.length;
        _droppedFinalBytes += removed.length;
        _finalAudioTruncated = true;
      } else {
        _realtimeBytes -= removed.length;
        _droppedRealtimeBytes += removed.length;
      }
    }
  }

  Uint8List _flattenChunks(ListQueue<Uint8List> chunks, int totalBytes) {
    if (chunks.isEmpty || totalBytes <= 0) {
      return Uint8List(0);
    }
    final output = Uint8List(totalBytes);
    int offset = 0;
    for (final chunk in chunks) {
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return output;
  }
}
