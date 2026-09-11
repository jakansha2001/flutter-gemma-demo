import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemma_vision_demo/utils/audio_converter.dart';

/// The voice loop hands raw PCM between `record`, VoiceSession and just_audio.
/// A malformed recording must produce a clear FormatException, never a
/// RangeError from inside a byte loop.
void main() {
  Uint8List pcmOf(List<int> samples) {
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, samples[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  group('pcmToWav / parseWav', () {
    test('round-trips PCM through a WAV header', () {
      final pcm = pcmOf([0, 1000, -1000, 32767, -32768]);
      final wav = AudioConverter.pcmToWav(pcm, sampleRate: 16000);

      expect(wav.length, pcm.length + 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');

      final parsed = AudioConverter.parseWav(wav);
      expect(parsed.sampleRate, 16000);
      expect(parsed.channels, 1);
      expect(parsed.bitsPerSample, 16);
      expect(parsed.pcm, pcm);
    });

    test('handles a non-canonical chunk layout', () {
      // Recorders often insert a LIST chunk between `fmt ` and `data`; a
      // parser that assumes the 44-byte layout reads garbage here.
      final pcm = pcmOf([5, 6, 7, 8]);
      final canonical = AudioConverter.pcmToWav(pcm, sampleRate: 16000);
      final builder = BytesBuilder()
        ..add(canonical.sublist(0, 36)) // RIFF + fmt
        ..add(Uint8List.fromList('LIST'.codeUnits))
        ..add(_u32(4))
        ..add(Uint8List.fromList('INFO'.codeUnits))
        ..add(canonical.sublist(36)); // data chunk
      final withList = builder.toBytes();
      // Fix up the RIFF size so the file is self-consistent.
      ByteData.sublistView(withList).setUint32(4, withList.length - 8, Endian.little);

      expect(AudioConverter.parseWav(withList).pcm, pcm);
    });

    test('rejects malformed input with FormatException', () {
      expect(
        () => AudioConverter.parseWav(Uint8List(10)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AudioConverter.parseWav(Uint8List.fromList(List.filled(64, 0))),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-16-bit audio', () {
      final wav = AudioConverter.pcmToWav(
        pcmOf([1, 2]),
        sampleRate: 16000,
        bitsPerSample: 8,
      );
      expect(
        () => AudioConverter.parseWav(wav),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('toPcm16kMono', () {
    test('is a no-op when already 16 kHz mono', () {
      final pcm = pcmOf([1, 2, 3, 4]);
      final out = AudioConverter.toPcm16kMono(
        pcm,
        sourceSampleRate: 16000,
        sourceChannels: 1,
      );
      expect(out, pcm);
    });

    test('downmixes stereo to mono by averaging', () {
      // L/R pairs: (100,300) -> 200, (-100,-300) -> -200
      final stereo = pcmOf([100, 300, -100, -300]);
      final out = AudioConverter.toPcm16kMono(
        stereo,
        sourceSampleRate: 16000,
        sourceChannels: 2,
      );
      final samples = ByteData.sublistView(out);
      expect(out.length, stereo.length ~/ 2);
      expect(samples.getInt16(0, Endian.little), 200);
      expect(samples.getInt16(2, Endian.little), -200);
    });

    test('halves the sample count when downsampling 32 kHz to 16 kHz', () {
      final pcm = pcmOf(List.generate(100, (i) => i * 100));
      final out = AudioConverter.toPcm16kMono(
        pcm,
        sourceSampleRate: 32000,
        sourceChannels: 1,
      );
      expect(out.length ~/ 2, 50);
    });

    test('upsamples 8 kHz to 16 kHz', () {
      final pcm = pcmOf(List.generate(50, (i) => i * 10));
      final out = AudioConverter.toPcm16kMono(
        pcm,
        sourceSampleRate: 8000,
        sourceChannels: 1,
      );
      expect(out.length ~/ 2, 100);
    });

    test('an empty buffer does not throw', () {
      expect(
        AudioConverter.toPcm16kMono(
          Uint8List(0),
          sourceSampleRate: 44100,
          sourceChannels: 2,
        ),
        isEmpty,
      );
    });

    test('rejects a nonsensical sample rate', () {
      expect(
        () => AudioConverter.toPcm16kMono(
          pcmOf([1]),
          sourceSampleRate: 0,
          sourceChannels: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('pcmDuration', () {
    test('computes duration from frame count', () {
      // 16000 mono 16-bit frames = exactly one second.
      final pcm = Uint8List(16000 * 2);
      expect(
        AudioConverter.pcmDuration(pcm, sampleRate: 16000),
        const Duration(seconds: 1),
      );
    });

    test('returns zero for an invalid rate instead of dividing by zero', () {
      expect(
        AudioConverter.pcmDuration(Uint8List(100), sampleRate: 0),
        Duration.zero,
      );
    });
  });
}

Uint8List _u32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}
