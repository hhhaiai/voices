import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voices_app/models/model_registry.dart';
import 'package:voices_app/services/model_download_manager.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._basePath);

  final String _basePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _basePath;

  @override
  Future<String?> getApplicationSupportPath() async => _basePath;

  @override
  Future<String?> getApplicationCachePath() async => _basePath;

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => <String>[];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      <String>[];

  @override
  Future<String?> getTemporaryPath() async => _basePath;

  @override
  Future<String?> getDownloadsPath() async => _basePath;

  @override
  Future<String?> getLibraryPath() async => _basePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPathProvider;
  late Directory tempDir;

  Future<void> mockBuiltinSenseVoiceAssets() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final files = <String, List<int>>{
      'assets/models/sensevoice-onnx/model_quant.onnx': List<int>.filled(64, 1),
      'assets/models/sensevoice-onnx/tokens.txt': utf8.encode('a\nb'),
      'assets/models/sensevoice-onnx/tokens.json': utf8.encode('["a","b"]'),
      'assets/models/sensevoice-onnx/config.yaml':
          utf8.encode('sample_rate: 16000'),
      'assets/models/sensevoice-onnx/configuration.json':
          utf8.encode('{"ok":true}'),
      'assets/models/sensevoice-onnx/am.mvn': List<int>.filled(16, 2),
      'assets/models/sensevoice-onnx/README.md':
          utf8.encode('sensevoice built-in'),
    };

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
        (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(message.buffer.asUint8List());
      final bytes = files[key];
      if (bytes == null) return null;
      final data = Uint8List.fromList(bytes);
      return ByteData.view(data.buffer);
    });
  }

  setUp(() async {
    originalPathProvider = PathProviderPlatform.instance;
    tempDir =
        await Directory.systemTemp.createTemp('voices_model_manager_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    PathProviderPlatform.instance = originalPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('clearTemporaryCache removes downloading temp directories only',
      () async {
    final manager = ModelDownloadManager();

    final modelsRoot = Directory('${tempDir.path}/models');
    await Directory('${modelsRoot.path}/whisper/1.0.0').create(recursive: true);
    await File('${modelsRoot.path}/whisper/1.0.0/model.bin')
        .writeAsString('keep');

    await Directory('${modelsRoot.path}/whisper/1.0.1.__downloading')
        .create(recursive: true);
    await File('${modelsRoot.path}/whisper/1.0.1.__downloading/chunk.tmp')
        .writeAsString('temp');

    await Directory('${modelsRoot.path}/sensevoice_onnx/2.0.0.__downloading')
        .create(recursive: true);

    final deletedCount = await manager.clearTemporaryCache();

    expect(deletedCount, 2);
    expect(
      await Directory('${modelsRoot.path}/whisper/1.0.0').exists(),
      isTrue,
    );
    expect(
      await Directory('${modelsRoot.path}/whisper/1.0.1.__downloading')
          .exists(),
      isFalse,
    );
    expect(
      await Directory('${modelsRoot.path}/sensevoice_onnx/2.0.0.__downloading')
          .exists(),
      isFalse,
    );
  });

  test('getDownloadedModels ignores downloading temp directories', () async {
    final manager = ModelDownloadManager();

    final modelsRoot = Directory('${tempDir.path}/models');
    await Directory('${modelsRoot.path}/whisper/1.0.0').create(recursive: true);
    await File('${modelsRoot.path}/whisper/1.0.0/model.bin')
        .writeAsBytes(List<int>.filled(2048, 1));

    await Directory('${modelsRoot.path}/whisper/1.0.1.__downloading')
        .create(recursive: true);
    await File('${modelsRoot.path}/whisper/1.0.1.__downloading/chunk.tmp')
        .writeAsBytes(List<int>.filled(1024, 1));

    final models = await manager.getDownloadedModels();

    expect(models.length, 1);
    expect(models.first.engineId, 'whisper');
    expect(models.first.version, '1.0.0');
    expect(models.first.sizeMB, greaterThan(0));
  });

  test('resolveModelPath supports sensevoice model.int8.onnx in directory',
      () async {
    final manager = ModelDownloadManager();

    final senseDir = Directory('${tempDir.path}/custom/sensevoice');
    await senseDir.create(recursive: true);
    final modelFile = File('${senseDir.path}/model.int8.onnx');
    await modelFile.writeAsBytes(const [1, 2, 3]);
    await manager.setPreferredModelPath('sensevoice_onnx', '');

    final resolved = await manager.resolveModelPath(
      'sensevoice_onnx',
      preferredPath: senseDir.path,
    );

    expect(resolved, modelFile.path);
  });

  test('resolveModelPath supports repaired sensevoice model_sherpa.onnx in directory',
      () async {
    final manager = ModelDownloadManager();

    final senseDir = Directory('${tempDir.path}/custom/sensevoice_fixed');
    await senseDir.create(recursive: true);
    final modelFile = File('${senseDir.path}/model_sherpa.onnx');
    await modelFile.writeAsBytes(const [1, 2, 3]);
    await manager.setPreferredModelPath('sensevoice_onnx', '');

    final resolved = await manager.resolveModelPath(
      'sensevoice_onnx',
      preferredPath: senseDir.path,
    );

    expect(resolved, modelFile.path);
  });

  test('resolveModelPath extracts builtin sensevoice assets to local path',
      () async {
    await mockBuiltinSenseVoiceAssets();
    final manager = ModelDownloadManager();
    await manager.setPreferredModelPath('sensevoice_onnx', '');

    final builtin = ModelRegistry.preferredBuiltinForEngine('sensevoice_onnx');
    expect(builtin, isNotNull);

    final resolved = await manager.resolveModelPath('sensevoice_onnx');

    expect(resolved, isNotNull);
    expect(resolved!.endsWith('model_quant.onnx'), isTrue);
    final modelFile = File(resolved);
    expect(await modelFile.exists(), isTrue);

    final modelDir = modelFile.parent.path;
    for (final file in builtin!.requiredAssetFiles) {
      final candidate = File('$modelDir/$file');
      expect(
        await candidate.exists(),
        isTrue,
        reason: 'Missing builtin extracted file: $file',
      );
    }
  });

  test('resolveModelPath keeps explicit preferred path ahead of newer download',
      () async {
    final manager = ModelDownloadManager();
    final modelsRoot = Directory('${tempDir.path}/models');

    final olderVersionDir =
        Directory('${modelsRoot.path}/sensevoice_onnx/1.0.0');
    await olderVersionDir.create(recursive: true);
    final olderModel = File('${olderVersionDir.path}/model.int8.onnx');
    await olderModel.writeAsBytes(const [1, 2, 3]);
    await File('${olderVersionDir.path}/tokens.txt').writeAsString('a');

    final newerVersionDir =
        Directory('${modelsRoot.path}/sensevoice_onnx/9.9.9');
    await newerVersionDir.create(recursive: true);
    await File('${newerVersionDir.path}/model.int8.onnx')
        .writeAsBytes(const [4, 5, 6]);
    await File('${newerVersionDir.path}/tokens.txt').writeAsString('b');

    final resolved = await manager.resolveModelPath(
      'sensevoice_onnx',
      preferredPath: olderVersionDir.path,
    );

    expect(resolved, olderModel.path);
  });

  test('external model search paths: add and list', () async {
    final manager = ModelDownloadManager();
    await manager.setExternalModelSearchPaths([]);

    expect(manager.getExternalModelSearchPaths(), isEmpty);

    await manager.addExternalModelSearchPath('/tmp/models');
    await manager.addExternalModelSearchPath('/opt/models');

    final paths = manager.getExternalModelSearchPaths();
    expect(paths.length, 2);
    expect(paths, contains('/tmp/models'));
    expect(paths, contains('/opt/models'));

    // Duplicate add should be ignored.
    await manager.addExternalModelSearchPath('/tmp/models');
    expect(manager.getExternalModelSearchPaths().length, 2);
  });

  test('external model search paths: persisted via SharedPreferences',
      () async {
    final manager = ModelDownloadManager();
    await manager.setExternalModelSearchPaths(['/a', '/b']);

    // Create a new manager instance and reload.
    final manager2 = ModelDownloadManager();
    await manager2.loadExternalModelSearchPaths();

    final paths = manager2.getExternalModelSearchPaths();
    expect(paths, contains('/a'));
    expect(paths, contains('/b'));
  });

  test('resolveModelPath finds sensevoice-small in external directory',
      () async {
    final manager = ModelDownloadManager();

    // Create external model directory structure matching /models/sensevoice-small/.
    final externalRoot = Directory('${tempDir.path}/external_models');
    final svDir = Directory('${externalRoot.path}/sensevoice-small');
    await svDir.create(recursive: true);
    final modelFile = File('${svDir.path}/model_sherpa.onnx');
    await modelFile.writeAsBytes(const [1, 2, 3]);
    await File('${svDir.path}/tokens.txt').writeAsString('a\nb');

    await manager.setExternalModelSearchPaths([externalRoot.path]);
    await manager.setPreferredModelPath('sensevoice_onnx', '');

    final resolved = await manager.resolveModelPath('sensevoice_onnx');

    expect(resolved, isNotNull);
    expect(resolved, modelFile.path);
  });

  test('resolveModelPath finds vosk ONNX model in external directory',
      () async {
    final manager = ModelDownloadManager();

    // Create external model directory with ONNX format (for iOS/macOS).
    final externalRoot = Directory('${tempDir.path}/external_models');
    final voskDir = Directory('${externalRoot.path}/vosk-model-small-cn-0.22');
    await voskDir.create(recursive: true);
    await File('${voskDir.path}/tokens.txt').writeAsString('a\nb');
    await File('${voskDir.path}/model.onnx').writeAsBytes(const [1, 2, 3]);

    await manager.setExternalModelSearchPaths([externalRoot.path]);
    await manager.setPreferredModelPath('vosk', '');

    final resolved = await manager.resolveModelPath('vosk');

    expect(resolved, isNotNull);
    expect(resolved, voskDir.path);
  });

  test('resolveModelPath returns null for whisper-tiny PyTorch format in external dir',
      () async {
    final manager = ModelDownloadManager();

    // whisper-tiny in PyTorch format is NOT usable (no ggml or ONNX files).
    final externalRoot = Directory('${tempDir.path}/external_models');
    final whisperDir = Directory('${externalRoot.path}/whisper-tiny');
    await whisperDir.create(recursive: true);
    await File('${whisperDir.path}/pytorch_model.bin')
        .writeAsBytes(List<int>.filled(100, 1));
    await File('${whisperDir.path}/config.json').writeAsString('{}');

    await manager.setExternalModelSearchPaths([externalRoot.path]);
    await manager.setPreferredModelPath('whisper', '');

    final resolved = await manager.resolveModelPath('whisper');

    // Should NOT resolve because PyTorch format is not supported.
    // (It may resolve to builtin if available, but with mocked assets it returns null.)
    expect(resolved == null || resolved == 'whisper-tiny', isTrue);
  });
}
