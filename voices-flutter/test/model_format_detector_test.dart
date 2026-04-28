import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/utils/model_format_detector.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('format_detector_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detect returns null for non-existent path', () async {
    final result = await ModelFormatDetector.detect('/nonexistent/path');
    expect(result, isNull);
  });

  test('detect identifies SenseVoice ONNX with all metadata', () async {
    final dir = Directory('${tempDir.path}/sensevoice-small');
    await dir.create(recursive: true);

    // 创建包含 metadata 的模型文件。
    final modelFile = File('${dir.path}/model_sherpa.onnx');
    final content = StringBuffer();
    content.write('ir_version=7 producer_name=sherpa ');
    for (final key in [
      'vocab_size', 'normalize_samples', 'lfr_window_size', 'lfr_window_shift',
      'with_itn', 'without_itn', 'lang_auto', 'lang_zh', 'lang_en',
      'lang_ja', 'lang_ko', 'lang_yue', 'neg_mean', 'inv_stddev',
    ]) {
      content.write('$key=value ');
    }
    await modelFile.writeAsString(content.toString());
    await File('${dir.path}/tokens.txt').writeAsString('a\nb');

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.senseVoiceOnnx);
    expect(report.engineId, 'sensevoice_onnx');
    expect(report.isCompatible, isTrue);
  });

  test('detect identifies SenseVoice ONNX with missing metadata', () async {
    final dir = Directory('${tempDir.path}/sensevoice-broken');
    await dir.create(recursive: true);

    // 创建缺少 metadata 的模型文件。
    final modelFile = File('${dir.path}/model.onnx');
    await modelFile.writeAsString('ir_version=7 producer_name=funasr');
    await File('${dir.path}/tokens.txt').writeAsString('a\nb');

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.senseVoiceOnnxBroken);
    expect(report.isCompatible, isFalse);
    expect(report.issues, isNotEmpty);
    expect(report.suggestions, isNotEmpty);
  });

  test('detect identifies SenseVoice with model_sherpa.onnx available',
      () async {
    final dir = Directory('${tempDir.path}/sensevoice-dual');
    await dir.create(recursive: true);

    // 创建 broken 和 fixed 两个版本。
    await File('${dir.path}/model.onnx').writeAsString('ir_version=7');
    final sherpaFile = File('${dir.path}/model_sherpa.onnx');
    final content = StringBuffer();
    content.write('ir_version=7 ');
    for (final key in [
      'vocab_size', 'normalize_samples', 'lfr_window_size', 'lfr_window_shift',
      'with_itn', 'without_itn', 'lang_auto', 'lang_zh', 'lang_en',
      'lang_ja', 'lang_ko', 'lang_yue', 'neg_mean', 'inv_stddev',
    ]) {
      content.write('$key=value ');
    }
    await sherpaFile.writeAsString(content.toString());
    await File('${dir.path}/tokens.txt').writeAsString('a\nb');

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.senseVoiceOnnx);
    expect(report.isCompatible, isTrue);
  });

  test('detect identifies Whisper PyTorch format', () async {
    final dir = Directory('${tempDir.path}/whisper-tiny');
    await dir.create(recursive: true);
    await File('${dir.path}/pytorch_model.bin')
        .writeAsBytes(List<int>.filled(100, 1));
    await File('${dir.path}/config.json').writeAsString('{}');

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.whisperPytorch);
    expect(report.engineId, 'whisper');
    expect(report.isCompatible, isFalse);
    expect(report.platformCompat, PlatformCompatibility.needsConversion);
    expect(report.suggestions, isNotEmpty);
  });

  test('detect identifies Vosk Kaldi format', () async {
    final dir = Directory('${tempDir.path}/vosk-model-small-cn-0.22');
    await dir.create(recursive: true);
    await File('${dir.path}/README').writeAsString('vosk model');
    await Directory('${dir.path}/am').create(recursive: true);
    await File('${dir.path}/am/final.mdl').writeAsBytes([1, 2, 3]);

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.voskKaldi);
    expect(report.engineId, 'vosk');
    // Kaldi 兼容性取决于当前平台。
    expect(report.platformCompat, isNotNull);
  });

  test('detect identifies Vosk ONNX format', () async {
    final dir = Directory('${tempDir.path}/vosk-onnx');
    await dir.create(recursive: true);
    await File('${dir.path}/tokens.txt').writeAsString('a\nb');
    await File('${dir.path}/model.onnx').writeAsBytes([1, 2, 3]);

    final report = await ModelFormatDetector.detect(dir.path);
    expect(report, isNotNull);
    expect(report!.format, ModelFormat.voskOnnx);
    expect(report.engineId, 'vosk');
  });

  test('scanDirectory finds multiple models', () async {
    // 创建 SenseVoice 目录。
    final svDir = Directory('${tempDir.path}/sensevoice-small');
    await svDir.create(recursive: true);
    await File('${svDir.path}/model_sherpa.onnx')
        .writeAsString('ir_version=7 vocab_size=25090 normalize_samples=1 '
            'lfr_window_size=7 lfr_window_shift=6 with_itn=1 without_itn=0 '
            'lang_auto=1 lang_zh=2 lang_en=3 lang_ja=4 lang_ko=5 lang_yue=6 '
            'neg_mean=5.426 inv_stddev=5.297');
    await File('${svDir.path}/tokens.txt').writeAsString('a\nb');

    // 创建 Vosk 目录。
    final voskDir = Directory('${tempDir.path}/vosk-model-small-cn-0.22');
    await voskDir.create(recursive: true);
    await File('${voskDir.path}/README').writeAsString('vosk');

    // 创建非模型目录。
    final otherDir = Directory('${tempDir.path}/other-stuff');
    await otherDir.create(recursive: true);
    await File('${otherDir.path}/readme.txt').writeAsString('not a model');

    final reports = await ModelFormatDetector.scanDirectory(tempDir.path);
    expect(reports.length, greaterThanOrEqualTo(2));

    final engineIds = reports.map((r) => r.engineId).toSet();
    expect(engineIds, contains('sensevoice_onnx'));
    expect(engineIds, contains('vosk'));
  });

  test('ModelFormatReport formatName returns readable name', () async {
    const report = ModelFormatReport(
      path: '/test',
      format: ModelFormat.senseVoiceOnnxBroken,
      engineId: 'sensevoice_onnx',
      isCompatible: false,
      platformCompat: PlatformCompatibility.needsConversion,
    );
    expect(report.formatName, contains('需修复'));
    expect(report.statusIcon, '⚠️');
  });
}
