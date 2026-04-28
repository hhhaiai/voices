import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/models/transcription_result.dart';

void main() {
  group('TranscriptionResult', () {
    test('creates result with required fields', () {
      const result = TranscriptionResult(
        text: 'Hello world',
        confidence: 0.95,
        audioDuration: Duration(seconds: 5),
      );

      expect(result.text, 'Hello world');
      expect(result.confidence, 0.95);
      expect(result.audioDuration.inSeconds, 5);
      expect(result.segments, isNull);
    });

    test('creates result with segments', () {
      const result = TranscriptionResult(
        text: 'Hello world',
        confidence: 0.95,
        audioDuration: Duration(seconds: 5),
        segments: [
          TranscriptionSegment(
            text: 'Hello',
            confidence: 0.9,
            startTime: Duration.zero,
            endTime: Duration(milliseconds: 1500),
          ),
          TranscriptionSegment(
            text: 'world',
            confidence: 0.95,
            startTime: Duration(milliseconds: 1500),
            endTime: Duration(seconds: 5),
          ),
        ],
      );

      expect(result.segments, isNotNull);
      expect(result.segments!.length, 2);
      expect(result.segments![0].text, 'Hello');
      expect(result.segments![1].text, 'world');
    });

    test('toJson serializes correctly', () {
      const result = TranscriptionResult(
        text: 'Test text',
        confidence: 0.9,
        audioDuration: Duration(seconds: 10),
        processingTime: Duration(milliseconds: 500),
        segments: [
          TranscriptionSegment(
            text: 'Test',
            confidence: 0.9,
            startTime: Duration.zero,
            endTime: Duration(seconds: 5),
          ),
        ],
      );

      final json = result.toJson();

      expect(json['text'], 'Test text');
      expect(json['confidence'], 0.9);
      expect(json['audioDurationMs'], 10000);
      expect(json['processingTimeMs'], 500);
      expect(json['segments'], isNotNull);
      expect((json['segments'] as List).length, 1);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'text': 'Parsed text',
        'confidence': 0.85,
        'audioDurationMs': 5000,
        'processingTimeMs': 300,
        'segments': [
          {
            'text': 'Parsed',
            'confidence': 0.85,
            'startTimeMs': 0,
            'endTimeMs': 2500,
          },
        ],
      };

      final result = TranscriptionResult.fromJson(json);

      expect(result.text, 'Parsed text');
      expect(result.confidence, 0.85);
      expect(result.audioDuration.inSeconds, 5);
      expect(result.processingTime.inMilliseconds, 300);
      expect(result.segments, isNotNull);
      expect(result.segments!.first.text, 'Parsed');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'text': 'Simple text',
      };

      final result = TranscriptionResult.fromJson(json);

      expect(result.text, 'Simple text');
      expect(result.confidence, 0.0);
      expect(result.audioDuration, Duration.zero);
      expect(result.segments, isNull);
    });
  });

  group('TranscriptionSegment', () {
    test('creates segment with required fields', () {
      const segment = TranscriptionSegment(
        text: 'Test segment',
        confidence: 0.9,
        startTime: Duration(milliseconds: 1000),
        endTime: Duration(milliseconds: 3000),
      );

      expect(segment.text, 'Test segment');
      expect(segment.confidence, 0.9);
      expect(segment.startTime.inMilliseconds, 1000);
      expect(segment.endTime.inMilliseconds, 3000);
    });

    test('toJson and fromJson roundtrip', () {
      const original = TranscriptionSegment(
        text: 'Roundtrip test',
        confidence: 0.88,
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
      );

      final json = original.toJson();
      final restored = TranscriptionSegment.fromJson(json);

      expect(restored.text, original.text);
      expect(restored.confidence, original.confidence);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
    });
  });
}
