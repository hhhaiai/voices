import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/models/model_registry.dart';

void main() {
  group('ModelRegistry', () {
    test('downloadableModels contains multiple whisper entries', () {
      final whisper = ModelRegistry.downloadableModels
          .where((m) => m.engineId == 'whisper')
          .toList();

      expect(whisper.length, greaterThanOrEqualTo(4));
      for (final item in whisper) {
        expect(item.downloadUrl, startsWith('https://'));
        expect(item.sizeMB, greaterThan(0));
        expect(item.allowedHosts, contains('huggingface.co'));
      }
    });

    test('downloadableModels contains vosk and sensevoice entries', () {
      final vosk = ModelRegistry.downloadableModels
          .where((m) => m.engineId == 'vosk')
          .toList();
      final sensevoice = ModelRegistry.downloadableModels
          .where((m) => m.engineId == 'sensevoice_onnx')
          .toList();

      expect(vosk, isNotEmpty);
      expect(sensevoice, isNotEmpty);

      for (final item in [...vosk, ...sensevoice]) {
        expect(item.downloadUrl, startsWith('https://'));
        expect(item.extraDownloadUrls, isNotEmpty);
        for (final extra in item.extraDownloadUrls) {
          expect(extra, startsWith('https://'));
        }
      }
    });

    test('multi-file models provide unique file names', () {
      final multiFileModels = ModelRegistry.downloadableModels
          .where((m) => m.extraDownloadUrls.isNotEmpty)
          .toList();

      expect(multiFileModels, isNotEmpty);

      for (final model in multiFileModels) {
        final fileNames = <String>{};
        final allUrls = [model.downloadUrl, ...model.extraDownloadUrls];

        for (final url in allUrls) {
          final uri = Uri.parse(url);
          expect(uri.pathSegments, isNotEmpty);
          final fileName = uri.pathSegments.last;
          expect(fileName.isNotEmpty, isTrue);
          fileNames.add(fileName);
        }

        expect(fileNames.length, equals(allUrls.length));
      }
    });

    test('multi-file model urls are unique and trusted', () {
      final multiFileModels = ModelRegistry.downloadableModels
          .where((m) => m.extraDownloadUrls.isNotEmpty)
          .toList();

      expect(multiFileModels, isNotEmpty);

      for (final model in multiFileModels) {
        final allUrls = [model.downloadUrl, ...model.extraDownloadUrls];
        expect(allUrls.toSet().length, equals(allUrls.length));

        for (final url in allUrls) {
          final host = Uri.parse(url).host;
          expect(model.allowedHosts, contains(host));
        }
      }
    });

    test('modelsForEngine filters by engineId', () {
      final whisperModels = ModelRegistry.modelsForEngine('whisper');
      final voskModels = ModelRegistry.modelsForEngine('vosk');

      expect(
        whisperModels.every((m) => m.engineId == 'whisper'),
        isTrue,
      );
      expect(voskModels.every((m) => m.engineId == 'vosk'), isTrue);
    });

    test('apple whisper metadata includes decoder and tokens extras', () {
      final model = ModelRegistry.downloadableModels.firstWhere(
        (m) => m.id == 'whisper-tiny-onnx-apple',
      );

      expect(model.engineId, 'whisper');
      expect(model.extraDownloadUrls.length, 2);
      expect(model.extraDownloadUrls.any((u) => u.endsWith('/tiny-decoder.int8.onnx')),
          isTrue);
      expect(model.extraDownloadUrls.any((u) => u.endsWith('/tiny-tokens.txt')),
          isTrue);
    });

    test('vosk and sensevoice metadata include tokens config file', () {
      final vosk = ModelRegistry.downloadableModels.firstWhere(
        (m) => m.id == 'vosk-paraformer-zh-small-onnx',
      );
      final sensevoice = ModelRegistry.downloadableModels.firstWhere(
        (m) => m.id == 'sensevoice-onnx-int8',
      );

      expect(vosk.extraDownloadUrls, hasLength(1));
      expect(vosk.extraDownloadUrls.single, endsWith('/tokens.txt'));

      expect(sensevoice.extraDownloadUrls, hasLength(1));
      expect(sensevoice.extraDownloadUrls.single, endsWith('/tokens.txt'));
    });

    test('builtin sensevoice bundles model and extra config files locally', () {
      final builtin = ModelRegistry.builtinModels.firstWhere(
        (m) => m.engineId == 'sensevoice_onnx',
      );

      expect(builtin.assetBasePath, equals('assets/models/sensevoice-onnx'));
      expect(builtin.modelRelativePath, equals('model_quant.onnx'));
      expect(
        builtin.requiredAssetFiles,
        containsAll([
          'model_quant.onnx',
          'tokens.txt',
          'tokens.json',
          'config.yaml',
          'configuration.json',
          'am.mvn',
        ]),
      );
    });
  });
}
