/// 转写结果
class TranscriptionResult {
  final String text;
  final double confidence;
  final Duration audioDuration;
  final Duration processingTime;
  final List<TranscriptionSegment>? segments;

  const TranscriptionResult({
    required this.text,
    this.confidence = 0.0,
    this.audioDuration = Duration.zero,
    this.processingTime = Duration.zero,
    this.segments,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'audioDurationMs': audioDuration.inMilliseconds,
    'processingTimeMs': processingTime.inMilliseconds,
    'segments': segments?.map((s) => s.toJson()).toList(),
  };

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
    TranscriptionResult(
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      audioDuration: Duration(milliseconds: json['audioDurationMs'] ?? 0),
      processingTime: Duration(milliseconds: json['processingTimeMs'] ?? 0),
      segments: json['segments'] != null
          ? (json['segments'] as List)
              .map((s) => TranscriptionSegment.fromJson(s))
              .toList()
          : null,
    );
}

/// 转写片段
class TranscriptionSegment {
  final String text;
  final double confidence;
  final Duration startTime;
  final Duration endTime;

  const TranscriptionSegment({
    required this.text,
    this.confidence = 0.0,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'startTimeMs': startTime.inMilliseconds,
    'endTimeMs': endTime.inMilliseconds,
  };

  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) =>
    TranscriptionSegment(
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      startTime: Duration(milliseconds: json['startTimeMs'] ?? 0),
      endTime: Duration(milliseconds: json['endTimeMs'] ?? 0),
    );
}
