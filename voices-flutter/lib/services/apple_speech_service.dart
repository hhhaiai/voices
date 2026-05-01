import 'dart:async';
import 'package:flutter/services.dart';

typedef PartialResultCallback = void Function(String text);

class AppleSpeechService {
  static const MethodChannel _channel =
      MethodChannel('com.sanbo.voices/apple_speech');
  static const EventChannel _eventChannel =
      EventChannel('com.sanbo.voices/apple_speech_events');

  static final AppleSpeechService _instance = AppleSpeechService._internal();
  factory AppleSpeechService() => _instance;
  AppleSpeechService._internal();

  StreamSubscription? _eventSubscription;
  PartialResultCallback? _onPartialResult;

  /// 设置实时转写部分结果回调
  void setPartialResultCallback(PartialResultCallback? callback) {
    _onPartialResult = callback;
    if (callback != null) {
      _ensureEventSubscription();
    } else {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    }
  }

  void _ensureEventSubscription() {
    _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String && _onPartialResult != null) {
          _onPartialResult!(event);
        }
      },
      onError: (error) {
        _onPartialResult?.call('Error: $error');
      },
    );
  }

  Future<String> transcribeFile(String filePath) async {
    try {
      final result = await _channel.invokeMethod<String>('transcribeFile', {
        'filePath': filePath,
      });
      return result ?? '';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// 启动实时麦克风转写
  Future<bool> startPcmTranscription() async {
    try {
      await _channel.invokeMethod('startPcmTranscription');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 停止实时麦克风转写
  Future<String?> stopPcmTranscription() async {
    try {
      final result = await _channel.invokeMethod<String>('stopPcmTranscription');
      return result;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> unload() async {
    await stopPcmTranscription();
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _onPartialResult = null;
  }
}
