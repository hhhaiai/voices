import 'dart:io';
import 'dart:typed_data';

/// SenseVoice ONNX 模型元数据修复器。
///
/// SenseVoice 模型在 sherpa-onnx 中加载时需要特定 metadata 字段
/// （如 vocab_size、lfr_window_size、with_itn 等）。
/// 部分模型（如 FunASR 导出的原始 ONNX）缺少这些字段，
/// 本工具可将缺失字段注入到 ONNX 文件的 metadata_props 区段。
class SenseVoiceMetadataFixer {
  SenseVoiceMetadataFixer._();

  /// sherpa-onnx SenseVoice 所需的全部 metadata 键。
  static const List<String> _requiredKeys = [
    'vocab_size',
    'normalize_samples',
    'lfr_window_size',
    'lfr_window_shift',
    'with_itn',
    'without_itn',
    'lang_auto',
    'lang_zh',
    'lang_en',
    'lang_ja',
    'lang_ko',
    'lang_yue',
    'neg_mean',
    'inv_stddev',
  ];

  /// SenseVoice 模型的默认 metadata 值。
  /// 这些值来自 sherpa-onnx 官方转换脚本。
  static const Map<String, String> _defaultMetadata = {
    'vocab_size': '25090',
    'normalize_samples': '1',
    'lfr_window_size': '7',
    'lfr_window_shift': '6',
    'with_itn': '1',
    'without_itn': '0',
    'lang_auto': '1',
    'lang_zh': '2',
    'lang_en': '3',
    'lang_ja': '4',
    'lang_ko': '5',
    'lang_yue': '6',
    'neg_mean': '5.426265',
    'inv_stddev': '5.297379',
  };

  /// 检查 ONNX 文件是否已包含所有必需的 SenseVoice metadata。
  static Future<bool> isAlreadyFixed(String onnxPath) async {
    final file = File(onnxPath);
    if (!await file.exists()) return false;

    for (final key in _requiredKeys) {
      final found = await _fileContainsAsciiPattern(file, key);
      if (!found) return false;
    }
    return true;
  }

  /// 获取缺失的 metadata 键列表。
  static Future<List<String>> getMissingKeys(String onnxPath) async {
    final file = File(onnxPath);
    if (!await file.exists()) return List.unmodifiable(_requiredKeys);

    final missing = <String>[];
    for (final key in _requiredKeys) {
      final found = await _fileContainsAsciiPattern(file, key);
      if (!found) missing.add(key);
    }
    return missing;
  }

  /// 尝试修复 SenseVoice ONNX 模型的 metadata。
  ///
  /// 返回修复后的文件路径，如果修复失败返回 null。
  /// 原始文件不会被修改，修复后的文件保存到 [outputDir]。
  static Future<String?> fixModel({
    required String onnxPath,
    required String outputDir,
  }) async {
    final inputFile = File(onnxPath);
    if (!await inputFile.exists()) return null;

    final bytes = await inputFile.readAsBytes();
    if (bytes.length < 16) return null;

    // 检查是否已经是有效的 ONNX 文件。
    if (!_looksLikeOnnxFile(bytes)) return null;

    // 查找缺失的 metadata 键。
    final missing = <String>[];
    for (final key in _requiredKeys) {
      if (!_bytesContainAscii(bytes, key)) {
        missing.add(key);
      }
    }
    if (missing.isEmpty) {
      // 已经包含所有必需 metadata，直接复制。
      return _copyToOutput(inputFile, outputDir);
    }

    // 构建需要注入的 metadata 条目。
    final entries = <_MetadataEntry>[];
    for (final key in missing) {
      final value = _defaultMetadata[key];
      if (value == null) continue;
      entries.add(_MetadataEntry(key: key, value: value));
    }

    if (entries.isEmpty) return null;

    // 注入 metadata。
    final fixedBytes = _injectMetadata(bytes, entries);
    if (fixedBytes == null) return null;

    // 写入输出文件。
    final outputDir_ = Directory(outputDir);
    if (!await outputDir_.exists()) {
      await outputDir_.create(recursive: true);
    }
    final baseName = inputFile.uri.pathSegments.last;
    final outputPath = '$outputDir/$baseName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(fixedBytes, flush: true);

    // 验证修复后的文件。
    final isFixed = await isAlreadyFixed(outputPath);
    if (!isFixed) return null;

    return outputPath;
  }

  /// 在 ONNX 文件的 metadata_props 区段注入新的 key-value 条目。
  ///
  /// 算法：
  /// 1. 搜索 metadata_props 字段（field 14, tag 0x72）
  /// 2. 在该字段内容末尾追加新条目
  /// 3. 更新 metadata_props 长度前缀
  /// 4. 更新父消息（ModelProto）长度前缀
  static Uint8List? _injectMetadata(
    Uint8List bytes,
    List<_MetadataEntry> entries,
  ) {
    // 编码新条目的 protobuf 字节。
    final entriesBytes = _encodeMetadataEntries(entries);
    if (entriesBytes.isEmpty) return null;

    // 搜索 metadata_props 字段。
    const metadataPropsTag = 0x72; // field 14, wire type 2 (length-delimited)
    int metadataPropsOffset = -1;
    for (var i = 0; i < bytes.length - 1; i++) {
      if (bytes[i] == metadataPropsTag) {
        metadataPropsOffset = i;
        break;
      }
    }
    if (metadataPropsOffset < 0) return null;

    // 读取 metadata_props 的长度。
    final lengthResult = _readVarint(bytes, metadataPropsOffset + 1);
    if (lengthResult == null) return null;
    final metadataPropsLength = lengthResult.value;
    final lengthVarintSize = lengthResult.bytesRead;
    final contentStartOffset =
        metadataPropsOffset + 1 + lengthVarintSize;

    // 新条目将追加到 metadata_props 内容的末尾。
    final insertOffset = contentStartOffset + metadataPropsLength;
    if (insertOffset > bytes.length) return null;

    // 计算新的 metadata_props 长度。
    final newMetadataPropsLength = metadataPropsLength + entriesBytes.length;
    final newLengthVarint = _encodeVarint(newMetadataPropsLength);

    // 计算长度差。
    final lengthDelta =
        entriesBytes.length + (newLengthVarint.length - lengthVarintSize);

    // 构建新的文件字节数组。
    final newBytes = Uint8List(bytes.length + lengthDelta);

    // 复制 metadata_props 长度前缀之前的部分。
    var destOffset = 0;
    newBytes.setRange(0, metadataPropsOffset + 1, bytes);
    destOffset = metadataPropsOffset + 1;

    // 写入新的 metadata_props 长度。
    newBytes.setRange(destOffset, destOffset + newLengthVarint.length, newLengthVarint);
    destOffset += newLengthVarint.length;

    // 复制 metadata_props 原有内容。
    final originalContentLength = metadataPropsLength;
    newBytes.setRange(
      destOffset,
      destOffset + originalContentLength,
      bytes.sublist(contentStartOffset, contentStartOffset + originalContentLength),
    );
    destOffset += originalContentLength;

    // 追加新条目。
    newBytes.setRange(destOffset, destOffset + entriesBytes.length, entriesBytes);
    destOffset += entriesBytes.length;

    // 复制 metadata_props 之后的剩余部分。
    final remainingStart = contentStartOffset + metadataPropsLength;
    if (remainingStart < bytes.length) {
      newBytes.setRange(destOffset, newBytes.length, bytes.sublist(remainingStart));
    }

    // 更新父消息（ModelProto）的长度前缀。
    // ONNX 文件的顶层结构是 ModelProto，其 tag 和长度在文件开头。
    _updateParentMessageLength(newBytes, lengthDelta);

    return newBytes;
  }

  /// 更新父消息的长度前缀。
  static void _updateParentMessageLength(Uint8List bytes, int delta) {
    if (bytes.length < 4) return;

    // ModelProto 的 tag 是 0x0A（field 1, wire type 2）。
    // 但 ONNX 文件直接以 ModelProto 开头，没有外层 tag。
    // 实际上 ONNX 文件就是序列化后的 ModelProto 字节，
    // 没有外层的 tag+length 包装。
    //
    // 所以不需要更新父消息长度——ONNX 文件本身就是一个
    // 完整的 protobuf 消息，没有外层包装。
    //
    // 但 metadata_props 的长度前缀必须正确，
    // 否则解析器会读错位置。
    //
    // 这里我们已经在 _injectMetadata 中更新了 metadata_props 的长度，
    // 所以不需要额外操作。
  }

  /// 编码 metadata 条目为 protobuf 字节。
  static Uint8List _encodeMetadataEntries(List<_MetadataEntry> entries) {
    final parts = <List<int>>[];
    var totalLength = 0;

    for (final entry in entries) {
      final keyBytes = entry.key.codeUnits;
      final valueBytes = entry.value.codeUnits;

      // StringEntry 内部：field 1 (key), field 2 (value)。
      final keyField = _encodeLengthDelimited(1, keyBytes);
      final valueField = _encodeLengthDelimited(2, valueBytes);

      // StringEntry 外层：tag 0x0A + length。
      final entryContentLength = keyField.length + valueField.length;
      final entryTag = [0x0A];
      final entryLength = _encodeVarint(entryContentLength);

      final entryBytes = <int>[];
      entryBytes.addAll(entryTag);
      entryBytes.addAll(entryLength);
      entryBytes.addAll(keyField);
      entryBytes.addAll(valueField);

      parts.add(entryBytes);
      totalLength += entryBytes.length;
    }

    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  /// 编码 length-delimited protobuf 字段。
  static List<int> _encodeLengthDelimited(int fieldNumber, List<int> data) {
    final tag = (fieldNumber << 3) | 2;
    final length = _encodeVarint(data.length);
    final result = <int>[tag];
    result.addAll(length);
    result.addAll(data);
    return result;
  }

  /// 编码 varint。
  static List<int> _encodeVarint(int value) {
    if (value < 0) return [0];
    final result = <int>[];
    var v = value;
    while (v >= 0x80) {
      result.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    result.add(v & 0x7F);
    return result;
  }

  /// 读取 varint。
  static _VarintResult? _readVarint(Uint8List bytes, int offset) {
    var value = 0;
    var shift = 0;
    var bytesRead = 0;
    while (offset + bytesRead < bytes.length) {
      final byte = bytes[offset + bytesRead];
      value |= (byte & 0x7F) << shift;
      bytesRead++;
      if ((byte & 0x80) == 0) {
        return _VarintResult(value: value, bytesRead: bytesRead);
      }
      shift += 7;
      if (shift > 35) return null;
    }
    return null;
  }

  /// 检查字节数组是否包含 ASCII 模式。
  static bool _bytesContainAscii(Uint8List bytes, String pattern) {
    final needle = pattern.codeUnits;
    if (needle.isEmpty) return true;
    if (needle.length > bytes.length) return false;

    for (var i = 0; i <= bytes.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  /// 检查文件是否包含 ASCII 模式（流式读取，避免大文件内存问题）。
  static Future<bool> _fileContainsAsciiPattern(
    File file,
    String pattern,
  ) async {
    final needle = pattern.codeUnits;
    if (needle.isEmpty) return true;

    var carry = <int>[];
    await for (final chunk in file.openRead()) {
      final data = Uint8List(carry.length + chunk.length);
      data.setRange(0, carry.length, carry);
      data.setRange(carry.length, data.length, chunk);

      for (var i = 0; i <= data.length - needle.length; i++) {
        var match = true;
        for (var j = 0; j < needle.length; j++) {
          if (data[i + j] != needle[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }

      final keep = needle.length - 1;
      if (keep > 0 && data.length >= keep) {
        carry = data.sublist(data.length - keep);
      } else {
        carry = <int>[];
      }
    }
    return false;
  }

  /// 检查字节数组是否看起来像 ONNX 文件。
  static bool _looksLikeOnnxFile(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // ONNX 文件是 protobuf 格式，检查是否包含 ONNX 特有的字符串。
    return _bytesContainAscii(bytes, 'ir_version') ||
        _bytesContainAscii(bytes, 'opset_import') ||
        _bytesContainAscii(bytes, 'producer_name');
  }

  /// 复制文件到输出目录。
  static Future<String?> _copyToOutput(
    File inputFile,
    String outputDir,
  ) async {
    final outputDir_ = Directory(outputDir);
    if (!await outputDir_.exists()) {
      await outputDir_.create(recursive: true);
    }
    final baseName = inputFile.uri.pathSegments.last;
    final outputPath = '$outputDir/$baseName';
    await inputFile.copy(outputPath);
    return outputPath;
  }
}

class _MetadataEntry {
  const _MetadataEntry({required this.key, required this.value});
  final String key;
  final String value;
}

class _VarintResult {
  const _VarintResult({required this.value, required this.bytesRead});
  final int value;
  final int bytesRead;
}
