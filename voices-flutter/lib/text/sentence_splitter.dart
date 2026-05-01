import 'dart:math';

/// 句子分割结果
class Sentence {
  /// 句子文本
  final String text;

  /// 起始字符索引
  final int startIndex;

  /// 结束字符索引
  final int endIndex;

  /// 句子类型
  final SentenceType type;

  const Sentence({
    required this.text,
    required this.startIndex,
    required this.endIndex,
    required this.type,
  });

  @override
  String toString() => 'Sentence(text: "$text", type: $type)';
}

/// 句子类型
enum SentenceType {
  /// 陈述句
  statement,

  /// 疑问句
  question,

  /// 感叹句
  exclamation,

  /// 命令句
  command,

  /// 不确定
  unknown,
}

/// 句子分割器
/// 基于标点和语气检测句子边界
class SentenceSplitter {
  /// 中文标点正则
  static final _chinesePunctuation = RegExp(r'[。！？]');

  /// 英文标点正则
  static final _englishPunctuation = RegExp(r'[.!?]');

  /// 中文问号
  static final _chineseQuestion = RegExp(r'[？?]');

  /// 中文感叹号
  static final _chineseExclamation = RegExp(r'[！!]');

  /// 中文连词（用于断句后添加标点）
  static final _conjunctions = RegExp(
    r'(然后|但是|所以|因为|而且|并且|不过|另外|其次|然而|因此|虽然|即使|若是|若干|要么)',
  );

  /// 句子分割
  List<Sentence> split(String text) {
    if (text.isEmpty) return [];

    final sentences = <Sentence>[];
    int currentStart = 0;
    int i = 0;

    while (i < text.length) {
      final char = text[i];

      // 检测中文标点
      if (_chinesePunctuation.hasMatch(char)) {
        final sentenceText = text.substring(currentStart, i + 1).trim();
        if (sentenceText.isNotEmpty) {
          sentences.add(Sentence(
            text: sentenceText,
            startIndex: currentStart,
            endIndex: i + 1,
            type: _detectSentenceType(sentenceText),
          ));
        }
        currentStart = i + 1;
      }
      // 检测英文标点
      else if (_englishPunctuation.hasMatch(char)) {
        // 排除缩写（如 i.e., e.g.）
        if (!_isAbbreviation(text, i)) {
          final sentenceText = text.substring(currentStart, i + 1).trim();
          if (sentenceText.isNotEmpty) {
            sentences.add(Sentence(
              text: sentenceText,
              startIndex: currentStart,
              endIndex: i + 1,
              type: _detectSentenceType(sentenceText),
            ));
          }
          currentStart = i + 1;
        }
      }
      // 检测换行（作为可选断句点）
      else if (char == '\n' || char == '\r') {
        final sentenceText = text.substring(currentStart, i).trim();
        if (sentenceText.isNotEmpty && !_endsWithPunctuation(sentenceText)) {
          sentences.add(Sentence(
            text: sentenceText,
            startIndex: currentStart,
            endIndex: i,
            type: _detectSentenceType(sentenceText),
          ));
          currentStart = i + 1;
        }
      }

      i++;
    }

    // 处理最后一段
    if (currentStart < text.length) {
      final sentenceText = text.substring(currentStart).trim();
      if (sentenceText.isNotEmpty) {
        sentences.add(Sentence(
          text: sentenceText,
          startIndex: currentStart,
          endIndex: text.length,
          type: _detectSentenceType(sentenceText),
        ));
      }
    }

    return sentences;
  }

  /// 检测句子类型
  SentenceType _detectSentenceType(String sentence) {
    // 检查是否以问号结尾
    if (_chineseQuestion.hasMatch(sentence) ||
        RegExp(r'\?$', caseSensitive: false).hasMatch(sentence)) {
      return SentenceType.question;
    }

    // 检查是否以感叹号结尾
    if (_chineseExclamation.hasMatch(sentence) ||
        RegExp(r'!$', caseSensitive: false).hasMatch(sentence)) {
      return SentenceType.exclamation;
    }

    // 检查是否为命令句
    if (RegExp(r'^[给让请帮教指示命令]').hasMatch(sentence)) {
      return SentenceType.command;
    }

    // 默认为陈述句
    return SentenceType.statement;
  }

  /// 检查是否是缩写
  bool _isAbbreviation(String text, int index) {
    // 检查 i.e. 或 e.g.
    if (index >= 2) {
      final sub = text.substring(max(0, index - 2), index + 1).toLowerCase();
      if (sub == 'e.g' || sub == 'i.e') {
        return true;
      }
    }
    return false;
  }

  /// 检查是否以标点结尾
  bool _endsWithPunctuation(String text) {
    if (text.isEmpty) return false;
    final lastChar = text[text.length - 1];
    return _chinesePunctuation.hasMatch(lastChar) ||
        _englishPunctuation.hasMatch(lastChar);
  }

  /// 为句子添加适当的标点
  String punctuate(String sentence) {
    if (sentence.isEmpty) return sentence;

    // 已经是标点结尾则直接返回
    if (_endsWithPunctuation(sentence)) {
      return sentence;
    }

    // 检测问句
    if (_isQuestion(sentence)) {
      return '$sentence？';
    }

    // 检测感叹句
    if (_isExclamation(sentence)) {
      return '$sentence！';
    }

    // 检查中文连词，添加逗号
    if (_conjunctions.hasMatch(sentence)) {
      // 连词在中间的情况
      final match = _conjunctions.firstMatch(sentence);
      if (match != null && match.start > 0) {
        // 已经在句中，不需要再添加
      }
    }

    // 默认添加句号
    return '$sentence。';
  }

  /// 检测是否为问句
  bool _isQuestion(String text) {
    final questionPatterns = [
      RegExp(r'(吗|么|呢|是否|是不是|为什么|怎么|如何|几时|多少|哪|谁|什么|怎|\bdo\b|\bdoes\b|\bdid\b|\bwill\b|\bcan\b|\bcould\b|\bwould\b|\bshould\b|\bhow\b|\bwhat\b|\bwhen\b|\bwhere\b|\bwhy\b)', caseSensitive: false),
    ];

    for (final pattern in questionPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// 检测是否为感叹句
  bool _isExclamation(String text) {
    final exclaimPatterns = [
      RegExp(r'(太|真|好|棒|厉害|赞|牛|强|酷|哇|呀|啊|wow|amazing|great|awesome|\!)', caseSensitive: false),
    ];

    for (final pattern in exclaimPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }
}
