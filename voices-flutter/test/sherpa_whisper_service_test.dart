import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/services/sherpa_whisper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SherpaWhisperService', () {
    late SherpaWhisperService service;

    setUp(() async {
      service = SherpaWhisperService();
      await service.unload();
    });

    test('loadModel returns false with invalid path and exposes lastError',
        () async {
      final loaded =
          await service.loadModel('/tmp/definitely-not-a-real-whisper-onnx-dir');

      expect(loaded, isFalse);
      expect(service.isLoaded, isFalse);
      expect(service.lastError, isNotNull);
      expect(service.lastError!, isNotEmpty);
    });

    test('unload clears loaded status and error state', () async {
      await service.loadModel('/tmp/definitely-not-a-real-whisper-onnx-dir');

      await service.unload();

      expect(service.isLoaded, isFalse);
      expect(service.modelDir, isNull);
      expect(service.tokensPath, isNull);
      expect(service.lastError, isNull);
    });
  });
}
