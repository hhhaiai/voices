import 'package:flutter/services.dart';

class AppleSpeechService {
  static const MethodChannel _channel =
      MethodChannel('com.sanbo.voices/apple_speech');

  static final AppleSpeechService _instance = AppleSpeechService._internal();
  factory AppleSpeechService() => _instance;
  AppleSpeechService._internal();

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

  Future<void> unload() async {}
}
