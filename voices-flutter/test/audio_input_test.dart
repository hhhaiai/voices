import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:voices_app/models/audio_input.dart';

void main() {
  group('AudioInput', () {
    test('fromPcm creates AudioInput with correct duration', () {
      // 16kHz, mono, 16-bit: 16000 samples = 1 second = 32000 bytes
      final pcmData = Uint8List(32000);
      final audio = AudioInput.fromPcm(pcmData, sampleRate: 16000);

      expect(audio.sampleRate, 16000);
      expect(audio.numChannels, 1);
      expect(audio.duration.inMilliseconds, 1000);
    });

    test('toFloatList converts PCM16 to float correctly', () {
      // Create PCM data with max amplitude (32767)
      final pcmData = Uint8List(4);
      pcmData[0] = 0xFF; // LSB
      pcmData[1] = 0x7F; // MSB (32767)
      pcmData[2] = 0xFF; // LSB
      pcmData[3] = 0x7F; // MSB

      final audio = AudioInput.fromPcm(pcmData, sampleRate: 16000);
      final floatList = audio.toFloatList();

      expect(floatList.length, 2);
      expect(floatList[0], closeTo(1.0, 0.01));
      expect(floatList[1], closeTo(1.0, 0.01));
    });

    test('handles empty PCM data', () {
      final pcmData = Uint8List(0);
      final audio = AudioInput.fromPcm(pcmData, sampleRate: 16000);

      expect(audio.data.length, 0);
      expect(audio.duration.inMilliseconds, 0);
    });

    test('handles different sample rates', () {
      // 8kHz, 1 second = 16000 bytes
      final pcmData = Uint8List(16000);
      final audio = AudioInput.fromPcm(pcmData, sampleRate: 8000);

      expect(audio.duration.inMilliseconds, 1000);
    });
  });
}
