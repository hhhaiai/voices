import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/models/engine_definition.dart';
import 'package:voices_app/models/engine_instance.dart';

void main() {
  group('EngineInstance', () {
    test('creates instance with required fields', () {
      const instance = EngineInstance(
        id: 'instance-123',
        engineId: 'whisper',
        version: '1.0.0',
      );

      expect(instance.id, 'instance-123');
      expect(instance.engineId, 'whisper');
      expect(instance.version, '1.0.0');
      expect(instance.state, EngineInstanceState.notDownloaded);
      expect(instance.downloadProgress, 0.0);
      expect(instance.localPath, isNull);
      expect(instance.errorMessage, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = EngineInstance(
        id: 'instance-123',
        engineId: 'whisper',
        version: '1.0.0',
      );

      final updated = original.copyWith(
        state: EngineInstanceState.ready,
        localPath: '/path/to/model',
      );

      expect(updated.id, original.id);
      expect(updated.engineId, original.engineId);
      expect(updated.version, original.version);
      expect(updated.state, EngineInstanceState.ready);
      expect(updated.localPath, '/path/to/model');
    });

    test('toJson serializes correctly', () {
      final instance = EngineInstance(
        id: 'instance-456',
        engineId: 'vosk',
        version: '2.0.0',
        state: EngineInstanceState.downloaded,
        downloadProgress: 0.5,
        downloadedAt: DateTime(2024, 1, 15),
        localPath: '/models/vosk',
        errorMessage: 'Some error',
      );

      final json = instance.toJson();

      expect(json['id'], 'instance-456');
      expect(json['engineId'], 'vosk');
      expect(json['version'], '2.0.0');
      expect(json['state'], 'downloaded');
      expect(json['downloadProgress'], 0.5);
      expect(json['downloadedAt'], '2024-01-15T00:00:00.000');
      expect(json['localPath'], '/models/vosk');
      expect(json['errorMessage'], 'Some error');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'instance-789',
        'engineId': 'sensevoice',
        'version': '3.0.0',
        'state': 'loading',
        'downloadProgress': 0.75,
        'downloadedAt': '2024-02-20T10:30:00.000',
        'localPath': '/models/sensevoice',
        'errorMessage': null,
      };

      final instance = EngineInstance.fromJson(json);

      expect(instance.id, 'instance-789');
      expect(instance.engineId, 'sensevoice');
      expect(instance.version, '3.0.0');
      expect(instance.state, EngineInstanceState.loading);
      expect(instance.downloadProgress, 0.75);
      expect(instance.downloadedAt?.year, 2024);
      expect(instance.downloadedAt?.month, 2);
      expect(instance.downloadedAt?.day, 20);
      expect(instance.localPath, '/models/sensevoice');
      expect(instance.errorMessage, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'instance-000',
        'engineId': 'whisper',
        'version': '1.0.0',
      };

      final instance = EngineInstance.fromJson(json);

      expect(instance.state, EngineInstanceState.notDownloaded);
      expect(instance.downloadProgress, 0.0);
      expect(instance.downloadedAt, isNull);
      expect(instance.localPath, isNull);
      expect(instance.errorMessage, isNull);
    });

    test('fromJson handles unknown state', () {
      final json = {
        'id': 'instance-001',
        'engineId': 'test',
        'version': '1.0.0',
        'state': 'unknown_state',
      };

      final instance = EngineInstance.fromJson(json);

      expect(instance.state, EngineInstanceState.notDownloaded);
    });
  });

  group('EngineInstanceState', () {
    test('has all expected values', () {
      expect(EngineInstanceState.values.length, 6);
      expect(EngineInstanceState.notDownloaded.name, 'notDownloaded');
      expect(EngineInstanceState.downloading.name, 'downloading');
      expect(EngineInstanceState.downloaded.name, 'downloaded');
      expect(EngineInstanceState.loading.name, 'loading');
      expect(EngineInstanceState.ready.name, 'ready');
      expect(EngineInstanceState.error.name, 'error');
    });
  });
}
