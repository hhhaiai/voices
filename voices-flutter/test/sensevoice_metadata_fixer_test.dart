import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/utils/sensevoice_metadata_fixer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sv_fixer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('isAlreadyFixed returns false for empty file', () async {
    final file = File('${tempDir.path}/empty.onnx');
    await file.writeAsBytes([]);

    final result = await SenseVoiceMetadataFixer.isAlreadyFixed(file.path);
    expect(result, isFalse);
  });

  test('isAlreadyFixed returns true when all keys present', () async {
    // 创建一个包含所有必需 metadata 键的模拟文件。
    final file = File('${tempDir.path}/fixed.onnx');
    final content = StringBuffer();
    content.write('vocab_size=25090');
    content.write('normalize_samples=1');
    content.write('lfr_window_size=7');
    content.write('lfr_window_shift=6');
    content.write('with_itn=1');
    content.write('without_itn=0');
    content.write('lang_auto=1');
    content.write('lang_zh=2');
    content.write('lang_en=3');
    content.write('lang_ja=4');
    content.write('lang_ko=5');
    content.write('lang_yue=6');
    content.write('neg_mean=5.426265');
    content.write('inv_stddev=5.297379');
    await file.writeAsString(content.toString());

    final result = await SenseVoiceMetadataFixer.isAlreadyFixed(file.path);
    expect(result, isTrue);
  });

  test('isAlreadyFixed returns false when keys missing', () async {
    final file = File('${tempDir.path}/broken.onnx');
    await file.writeAsString('ir_version=7 producer_name=funasr');

    final result = await SenseVoiceMetadataFixer.isAlreadyFixed(file.path);
    expect(result, isFalse);
  });

  test('getMissingKeys returns all keys for file without metadata', () async {
    final file = File('${tempDir.path}/no_meta.onnx');
    await file.writeAsString('ir_version=7');

    final missing = await SenseVoiceMetadataFixer.getMissingKeys(file.path);
    expect(missing.length, 14);
    expect(missing, contains('vocab_size'));
  });

  test('getMissingKeys returns empty for fully fixed file', () async {
    final file = File('${tempDir.path}/complete.onnx');
    final content = StringBuffer();
    for (final key in [
      'vocab_size', 'normalize_samples', 'lfr_window_size', 'lfr_window_shift',
      'with_itn', 'without_itn', 'lang_auto', 'lang_zh', 'lang_en',
      'lang_ja', 'lang_ko', 'lang_yue', 'neg_mean', 'inv_stddev',
    ]) {
      content.write('$key=value ');
    }
    await file.writeAsString(content.toString());

    final missing = await SenseVoiceMetadataFixer.getMissingKeys(file.path);
    expect(missing, isEmpty);
  });

  test('fixModel returns null for non-existent file', () async {
    final result = await SenseVoiceMetadataFixer.fixModel(
      onnxPath: '/nonexistent/model.onnx',
      outputDir: tempDir.path,
    );
    expect(result, isNull);
  });

  test('fixModel returns path for file that already has all metadata',
      () async {
    final file = File('${tempDir.path}/already_fixed.onnx');
    // 构建包含 ONNX 标记和所有 metadata 的最小文件。
    final content = StringBuffer();
    content.write('ir_version=7 opset_import=1 producer_name=sherpa ');
    for (final key in [
      'vocab_size', 'normalize_samples', 'lfr_window_size', 'lfr_window_shift',
      'with_itn', 'without_itn', 'lang_auto', 'lang_zh', 'lang_en',
      'lang_ja', 'lang_ko', 'lang_yue', 'neg_mean', 'inv_stddev',
    ]) {
      content.write('$key=value ');
    }
    await file.writeAsString(content.toString());

    final result = await SenseVoiceMetadataFixer.fixModel(
      onnxPath: file.path,
      outputDir: '${tempDir.path}/output',
    );
    expect(result, isNotNull);
    expect(result, contains('already_fixed.onnx'));
  });
}
