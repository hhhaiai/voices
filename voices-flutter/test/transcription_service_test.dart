import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voices_app/models/audio_input.dart';
import 'package:voices_app/models/engine_instance.dart';
import 'package:voices_app/services/transcription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('TranscriptionService', () {
    late TranscriptionService service;

    setUp(() async {
      service = TranscriptionService();
      await service.unloadEngine();
    });

    test('initial state is idle', () {
      expect(service.state, TranscriptionServiceState.idle);
      expect(service.isReady, false);
      expect(service.errorMessage, isNull);
    });
  });

  group('TranscriptionServiceState', () {
    test('has all expected values', () {
      expect(TranscriptionServiceState.values.length, 5);
      expect(TranscriptionServiceState.idle.name, 'idle');
      expect(TranscriptionServiceState.loading.name, 'loading');
      expect(TranscriptionServiceState.ready.name, 'ready');
      expect(TranscriptionServiceState.transcribing.name, 'transcribing');
      expect(TranscriptionServiceState.error.name, 'error');
    });
  });

  group('Fallback behavior without loaded engine', () {
    late TranscriptionService service;

    setUp(() async {
      service = TranscriptionService();
      await service.unloadEngine();
    });

    test('transcribe returns guidance text when engine is not loaded', () async {
      final audio = AudioInput.fromPcm(Uint8List(32000), sampleRate: 16000);

      final result = await service.transcribe(audio);

      expect(result.text, '请先在设置中选择并加载模型');
      expect(result.confidence, 0.0);
      expect(result.segments, isEmpty);
      expect(service.state, TranscriptionServiceState.idle);
    });

    test('transcribeFile returns guidance text when engine is not loaded',
        () async {
      final result = await service.transcribeFile('/tmp/not-used.wav');

      expect(result.text, '请先在设置中选择并加载模型');
      expect(result.confidence, 0.0);
      expect(result.segments, isEmpty);
      expect(service.state, TranscriptionServiceState.idle);
    });
  });

  group('SenseVoice load failure should surface error message', () {
    late TranscriptionService service;

    setUp(() async {
      service = TranscriptionService();
      await service.unloadEngine();
    });

    test('loadEngine records error and transcribe returns Error prefix',
        () async {
      const instance = EngineInstance(
        id: 'sensevoice-test-instance',
        engineId: 'sensevoice_onnx',
        version: 'test',
        localPath: '/tmp/definitely-not-a-real-sensevoice-model',
      );

      await service.loadEngine(instance);

      expect(service.state, TranscriptionServiceState.error);
      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!, isNotEmpty);

      final audio = AudioInput.fromPcm(Uint8List(32000), sampleRate: 16000);
      final result = await service.transcribe(audio);

      expect(result.text, startsWith('Error: '));
      expect(result.confidence, 0.0);
      expect(result.segments, isEmpty);
    });
  });

  group('Whisper load failure should surface error message', () {
    late TranscriptionService service;

    setUp(() async {
      service = TranscriptionService();
      await service.unloadEngine();
    });

    test('loadEngine records error and transcribe returns Error prefix',
        () async {
      const instance = EngineInstance(
        id: 'whisper-test-instance',
        engineId: 'whisper',
        version: 'test',
        localPath: '/tmp/definitely-not-a-real-whisper-model',
      );

      await service.loadEngine(instance);

      expect(service.state, TranscriptionServiceState.error);
      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!, isNotEmpty);

      final audio = AudioInput.fromPcm(Uint8List(32000), sampleRate: 16000);
      final result = await service.transcribe(audio);

      expect(result.text, startsWith('Error: '));
      expect(result.confidence, 0.0);
      expect(result.segments, isEmpty);
    });
  });

  group('Vosk load failure should surface error message', () {
    late TranscriptionService service;

    setUp(() async {
      service = TranscriptionService();
      await service.unloadEngine();
    });

    test('loadEngine records error and transcribe returns Error prefix',
        () async {
      const instance = EngineInstance(
        id: 'vosk-test-instance',
        engineId: 'vosk',
        version: 'test',
        localPath: '/tmp/definitely-not-a-real-vosk-model',
      );

      await service.loadEngine(instance);

      expect(service.state, TranscriptionServiceState.error);
      expect(service.errorMessage, isNotNull);
      expect(service.errorMessage!, isNotEmpty);

      final audio = AudioInput.fromPcm(Uint8List(32000), sampleRate: 16000);
      final result = await service.transcribe(audio);

      expect(result.text, startsWith('Error: '));
      expect(result.confidence, 0.0);
      expect(result.segments, isEmpty);
    });
  });
}
