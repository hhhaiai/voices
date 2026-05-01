/// 文本规范化器
/// 增强的文本规范化，包括全角/半角转换等
class TextNormalizer {
  /// 全角转半角映射表
  static final _fullWidthToHalfWidth = <int, int>{
    0x3000: 0x0020, // 全角空格 -> 半角空格
    0x3001: 0x002C, // 、 -> ,
    0x3002: 0x002E, // 。 -> .
    0x3003: 0x0022, // ' -> "
    0x3008: 0x003C, // < -> <
    0x3009: 0x003E, // > -> >
    0x300A: 0x005B, // 【 -> [
    0x300B: 0x005D, // 】 -> ]
    0x3010: 0x005B, // [ -> [
    0x3011: 0x005D, // ] -> ]
    0xFF01: 0x0021, // ！ -> !
    0xFF02: 0x0022, // " -> "
    0xFF03: 0x0023, // # -> #
    0xFF04: 0x0024, // $ -> $
    0xFF05: 0x0025, // % -> %
    0xFF06: 0x0026, // & -> &
    0xFF07: 0x0027, // ' -> '
    0xFF08: 0x0028, // （ -> (
    0xFF09: 0x0029, // ） -> )
    0xFF0A: 0x002A, // * -> *
    0xFF0B: 0x002B, // + -> +
    0xFF0C: 0x002C, // ， -> ,
    0xFF0D: 0x002D, // - -> -
    0xFF0E: 0x002E, // 。 -> .
    0xFF0F: 0x002F, // / -> /
    0xFF1A: 0x003A, // : -> :
    0xFF1B: 0x003B, // ； -> ;
    0xFF1C: 0x003C, // < -> <
    0xFF1D: 0x003D, // = -> =
    0xFF1E: 0x003E, // > -> >
    0xFF1F: 0x003F, // ？ -> ?
    0xFF20: 0x0040, // @ -> @
    0xFF3B: 0x005B, // [ -> [
    0xFF3C: 0x005C, // \ -> \
    0xFF3D: 0x005D, // ] -> ]
    0xFF3E: 0x005E, // ^ -> ^
    0xFF3F: 0x005F, // _ -> _
    0xFF40: 0x0060, // ` -> `
    0xFF5B: 0x007B, // { -> {
    0xFF5C: 0x007C, // | -> |
    0xFF5D: 0x007D, // } -> }
    0xFF5E: 0x007E, // ~ -> ~
  };

  /// 规范化文本
  String normalize(String text, {bool stripTrailingPunctuation = false}) {
    if (text.isEmpty) return text;

    var result = text;

    // 全角转半角
    result = _fullWidthToHalfWidthConvert(result);

    // 清理多余空格
    result = _normalizeSpaces(result);

    // 清理标点周围空格
    result = _normalizePunctuationSpaces(result);

    // 清理中文字符间的点号噪声（如"你。好。吗"）
    result = _normalizeChineseDots(result);

    // 清理特殊字符
    result = _cleanSpecialChars(result);

    // 规范化引号
    result = _normalizeQuotes(result);

    // 短文本实时片段经常带尾部点号，先去掉，最终句号由停录后统一补齐
    if (stripTrailingPunctuation && result.length <= 12) {
      result = result.replaceAll(RegExp(r'[。\.]$'), '');
    }

    return result.trim();
  }

  /// 全角转半角
  String _fullWidthToHalfWidthConvert(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      final converted = _fullWidthToHalfWidth[char];
      if (converted != null) {
        buffer.writeCharCode(converted);
      } else if (char >= 0xFF01 && char <= 0xFF5E) {
        // 大写/小写字母和数字的全角形式
        if (char >= 0xFF21 && char <= 0xFF3A) {
          // 全角大写字母 -> 半角
          buffer.writeCharCode(char - 0xFEE0);
        } else if (char >= 0xFF41 && char <= 0xFF5A) {
          // 全角小写字母 -> 半角
          buffer.writeCharCode(char - 0xFEE0);
        } else if (char >= 0xFF10 && char <= 0xFF19) {
          // 全角数字 -> 半角
          buffer.writeCharCode(char - 0xFEE0);
        } else {
          buffer.writeCharCode(char);
        }
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }

  /// 规范化空格
  String _normalizeSpaces(String text) {
    // 多个空格合并为一个
    var result = text.replaceAll(RegExp(r'\s+'), ' ');

    // 清理行首行尾空格
    result = result.trim();

    return result;
  }

  /// 规范化标点周围空格
  String _normalizePunctuationSpaces(String text) {
    // 标点前无空格
    var result = text.replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1');
    // 标点后无空格（如果是句尾）
    result = result.replaceAll(RegExp(r'([,.:;!?])\s+(?=[,.:;!?)\]}])'), r'$1');
    // ( 前无空格
    result = result.replaceAll(RegExp(r'\s+\('), '(');
    // ) 前无空格
    result = result.replaceAll(RegExp(r'\s+\)'), ')');

    return result;
  }

  /// 清理中文字符间的点号噪声
  String _normalizeChineseDots(String text) {
    // 清理"你。好。吗"样式
    var result = text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fff])[。\.]+\s*([\u4e00-\u9fff])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // 循环处理多次
    while (RegExp(r'[\u4e00-\u9fff][。\.]\s*[\u4e00-\u9fff]').hasMatch(result)) {
      result = result.replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff])[。\.]+\s*([\u4e00-\u9fff])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }

    return result;
  }

  /// 清理特殊字符
  String _cleanSpecialChars(String text) {
    // 移除控制字符
    var result = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 保留中文、英文、数字、常用标点
    // 清理 emoji 和特殊符号（使用 Unicode 码点）
    result = _removeEmojiRange(result, 0x1F600, 0x1F64F); // emoticons
    result = _removeEmojiRange(result, 0x1F300, 0x1F5FF); // misc symbols
    result = _removeEmojiRange(result, 0x1F680, 0x1F6FF); // transport

    return result;
  }

  /// 移除指定 Unicode 范围内的字符
  String _removeEmojiRange(String text, int start, int end) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code < start || code > end) {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// 规范化引号
  String _normalizeQuotes(String text) {
    // 将中文引号转换为标准引号
    var result = text;
    result = result.replaceAll('"', '"').replaceAll('"', '"');
    result = result.replaceAll(''', "'").replaceAll(''', "'");

    return result;
  }

  /// 规范化英文大小写
  String normalizeEnglish(String text) {
    // 句子首字母大写
    if (text.isEmpty) return text;

    final words = text.split(' ');
    if (words.isEmpty) return text;

    final result = <String>[];
    var capitalizeNext = true;

    for (final word in words) {
      if (word.isEmpty) continue;

      if (capitalizeNext) {
        result.add(word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : ''));
        capitalizeNext = false;
      } else {
        result.add(word.toLowerCase());
      }

      // 句号、问号、感叹号后下一个词首字母大写
      if (RegExp(r'[.!?]$').hasMatch(word)) {
        capitalizeNext = true;
      }
    }

    return result.join(' ');
  }
}
