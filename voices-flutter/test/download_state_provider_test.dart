import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voices_app/models/engine_definition.dart';
import 'package:voices_app/models/model_registry.dart';
import 'package:voices_app/providers/providers.dart';

void main() {
  group('ModelDownloadState', () {
    test('itemFor returns idle state when key does not exist', () {
      const state = ModelDownloadState();
      final item = state.itemFor('whisper', '1.0.0');

      expect(item.status, ModelDownloadStatus.idle);
      expect(item.progress, 0.0);
      expect(item.errorMessage, isNull);
    });

    test('put stores item and itemFor reads it back', () {
      const initial = ModelDownloadState();
      final next = initial.put(
        'whisper',
        '1.0.0',
        const ModelDownloadItemState(
          status: ModelDownloadStatus.downloading,
          progress: 0.4,
        ),
      );

      final item = next.itemFor('whisper', '1.0.0');
      expect(item.status, ModelDownloadStatus.downloading);
      expect(item.progress, 0.4);
    });

    test('remove clears existing item', () {
      final withItem = const ModelDownloadState().put(
        'whisper',
        '1.0.0',
        const ModelDownloadItemState(status: ModelDownloadStatus.success),
      );
      final cleared = withItem.remove('whisper', '1.0.0');

      final item = cleared.itemFor('whisper', '1.0.0');
      expect(item.status, ModelDownloadStatus.idle);
    });
  });

  group('modelDownloadStateProvider', () {
    test('initial provider state is empty map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(modelDownloadStateProvider);
      expect(state.items, isEmpty);
    });

    test('notifier clearState removes only target key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(modelDownloadStateProvider.notifier);
      notifier.state = notifier.state.put(
        'whisper',
        '1.0.0',
        const ModelDownloadItemState(status: ModelDownloadStatus.success),
      );
      notifier.state = notifier.state.put(
        'vosk',
        '1.0.0',
        const ModelDownloadItemState(status: ModelDownloadStatus.error),
      );

      notifier.clearState(engineId: 'whisper', version: '1.0.0');

      final state = container.read(modelDownloadStateProvider);
      expect(
          state.itemFor('whisper', '1.0.0').status, ModelDownloadStatus.idle);
      expect(state.itemFor('vosk', '1.0.0').status, ModelDownloadStatus.error);
    });
  });

  group('ModelRegistry + EngineDefinition compatibility', () {
    test('registry model can pair with engine definition', () {
      const engine = EngineDefinition(
        id: 'whisper',
        name: 'Whisper Tiny',
        description: 'test',
        category: EngineCategory.offline,
        version: '1.0.0',
        languages: ['zh'],
        isFree: true,
        sizeMB: 75,
      );

      final models = ModelRegistry.modelsForEngine(engine.id);
      if (models.isNotEmpty) {
        expect(models.first.engineId, engine.id);
      }
    });
  });
}
