import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/models/engine_definition.dart';

void main() {
  group('EngineDefinition', () {
    test('creates engine definition with required fields', () {
      const engine = EngineDefinition(
        id: 'test-engine',
        name: 'Test Engine',
        description: 'A test engine for unit testing',
        category: EngineCategory.offline,
        version: '1.0.0',
        languages: ['en', 'zh'],
        isFree: true,
        sizeMB: 100,
      );

      expect(engine.id, 'test-engine');
      expect(engine.name, 'Test Engine');
      expect(engine.category, EngineCategory.offline);
      expect(engine.version, '1.0.0');
      expect(engine.languages, ['en', 'zh']);
      expect(engine.isFree, true);
      expect(engine.sizeMB, 100);
    });

    test('toJson serializes correctly', () {
      const engine = EngineDefinition(
        id: 'whisper',
        name: 'Whisper Tiny',
        description: 'Whisper tiny model',
        category: EngineCategory.offline,
        version: '1.0.0',
        languages: ['en', 'zh'],
        isFree: true,
        sizeMB: 75,
        downloadUrl: 'https://example.com/model.bin',
        checksum: 'abc123',
      );

      final json = engine.toJson();

      expect(json['id'], 'whisper');
      expect(json['name'], 'Whisper Tiny');
      expect(json['category'], 'offline');
      expect(json['version'], '1.0.0');
      expect(json['languages'], ['en', 'zh']);
      expect(json['isFree'], true);
      expect(json['sizeMB'], 75);
      expect(json['downloadUrl'], 'https://example.com/model.bin');
      expect(json['checksum'], 'abc123');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'vosk',
        'name': 'Vosk',
        'description': 'Vosk offline model',
        'category': 'offline',
        'version': '2.0.0',
        'languages': ['en', 'zh', 'es'],
        'isFree': true,
        'sizeMB': 50,
        'downloadUrl': 'https://example.com/vosk.zip',
        'checksum': 'def456',
      };

      final engine = EngineDefinition.fromJson(json);

      expect(engine.id, 'vosk');
      expect(engine.name, 'Vosk');
      expect(engine.category, EngineCategory.offline);
      expect(engine.version, '2.0.0');
      expect(engine.languages, ['en', 'zh', 'es']);
      expect(engine.isFree, true);
      expect(engine.sizeMB, 50);
      expect(engine.downloadUrl, 'https://example.com/vosk.zip');
      expect(engine.checksum, 'def456');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test',
        'name': 'Test',
        'description': 'Test description',
        'category': 'offline',
        'version': '1.0.0',
        'languages': ['en'],
      };

      final engine = EngineDefinition.fromJson(json);

      expect(engine.id, 'test');
      expect(engine.isFree, true); // default
      expect(engine.sizeMB, 0); // default
      expect(engine.downloadUrl, isNull);
      expect(engine.checksum, isNull);
    });

    test('fromJson handles api category', () {
      final json = {
        'id': 'openai',
        'name': 'OpenAI Whisper API',
        'description': 'OpenAI API',
        'category': 'api',
        'version': '1.0.0',
        'languages': ['en'],
      };

      final engine = EngineDefinition.fromJson(json);

      expect(engine.category, EngineCategory.api);
    });

    test('fromJson defaults to offline for unknown category', () {
      final json = {
        'id': 'unknown',
        'name': 'Unknown',
        'description': 'Unknown engine',
        'category': 'unknown_category',
        'version': '1.0.0',
        'languages': ['en'],
      };

      final engine = EngineDefinition.fromJson(json);

      expect(engine.category, EngineCategory.offline);
    });
  });

  group('EngineCategory', () {
    test('has correct values', () {
      expect(EngineCategory.offline.name, 'offline');
      expect(EngineCategory.api.name, 'api');
    });
  });
}
