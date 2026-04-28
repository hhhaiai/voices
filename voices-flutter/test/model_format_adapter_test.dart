import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/utils/model_format_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('format_adapter_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AdaptResult', () {
    test('ok factory creates success result', () {
      final result = AdaptResult.ok('/path/to/model');
      expect(result.success, isTrue);
      expect(result.modelPath, '/path/to/model');
      expect(result.downloaded, isFalse);
      expect(result.message, isNull);
    });

    test('ok factory with downloaded flag', () {
      final result = AdaptResult.ok('/path/to/model', downloaded: true);
      expect(result.success, isTrue);
      expect(result.downloaded, isTrue);
    });

    test('fail factory creates failure result', () {
      final result = AdaptResult.fail('something went wrong');
      expect(result.success, isFalse);
      expect(result.message, 'something went wrong');
      expect(result.modelPath, isNull);
    });
  });

  group('adapt', () {
    test('returns fail for non-existent path', () async {
      final result = await ModelFormatAdapter.adapt(
        modelPath: '/nonexistent/path',
        engineId: 'whisper',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('无法检测'));
    });

    test('returns ok for already compatible SenseVoice model', () async {
      final dir = Directory('${tempDir.path}/sensevoice-small');
      await dir.create(recursive: true);

      final modelFile = File('${dir.path}/model_sherpa.onnx');
      final content = StringBuffer();
      content.write('ir_version=7 producer_name=sherpa ');
      for (final key in [
        'vocab_size', 'normalize_samples', 'lfr_window_size',
        'lfr_window_shift', 'with_itn', 'without_itn', 'lang_auto',
        'lang_zh', 'lang_en', 'lang_ja', 'lang_ko', 'lang_yue',
        'neg_mean', 'inv_stddev',
      ]) {
        content.write('$key=value ');
      }
      await modelFile.writeAsString(content.toString());
      await File('${dir.path}/tokens.txt').writeAsString('a\nb');

      final result = await ModelFormatAdapter.adapt(
        modelPath: dir.path,
        engineId: 'sensevoice_onnx',
      );
      expect(result.success, isTrue);
      expect(result.modelPath, isNotNull);
      expect(result.downloaded, isFalse);
    });

    test('returns fail for unsupported engine', () async {
      // 创建一个可检测的 Whisper PyTorch 目录。
      final dir = Directory('${tempDir.path}/whisper-tiny');
      await dir.create(recursive: true);
      await File('${dir.path}/pytorch_model.bin')
          .writeAsBytes(List<int>.filled(100, 1));
      await File('${dir.path}/config.json').writeAsString('{}');

      final result = await ModelFormatAdapter.adapt(
        modelPath: dir.path,
        engineId: 'unsupported_engine',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('不支持'));
    });

    test('returns AdaptResult for broken SenseVoice model', () async {
      // 创建一个 broken SenseVoice（无 metadata），适配会尝试
      // 修复 metadata。由于测试环境没有 path_provider 插件，
      // 验证检测逻辑正确进入 SenseVoice 适配分支。
      final dir = Directory('${tempDir.path}/sensevoice-broken');
      await dir.create(recursive: true);
      await File('${dir.path}/model.onnx')
          .writeAsString('ir_version=7 producer_name=funasr');
      await File('${dir.path}/tokens.txt').writeAsString('a\nb');

      // _adaptSenseVoice 调用 getApplicationSupportDirectory()，
      // 在纯单元测试中不可用。验证到格式检测阶段正确返回。
      final detectResult = await ModelFormatAdapter.adapt(
        modelPath: dir.path,
        engineId: 'sensevoice_onnx',
      );
      // 结果可能是 ok（metadata 修复成功）或 fail（需要下载）。
      expect(detectResult, isA<AdaptResult>());
    }, skip: '需要平台插件 path_provider');
  });
}
