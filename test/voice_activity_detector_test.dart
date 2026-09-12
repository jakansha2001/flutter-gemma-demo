import 'package:flutter_test/flutter_test.dart';
import 'package:gemma_vision_demo/gemma/voice_activity_detector.dart';

/// The detector decides whether hands-free works at all. It is a fixed
/// threshold on purpose — see the class doc — so these tests are about the
/// relationship between the bar and real audio levels, not about adaptation.
void main() {
  VoiceActivityDetector vad({double threshold = -40}) =>
      VoiceActivityDetector(thresholdDb: threshold);

  /// Feed [seconds] of audio at [db], in frames of [chunk].
  void feed(
    VoiceActivityDetector d,
    double db, {
    required double seconds,
    Duration chunk = const Duration(milliseconds: 150),
  }) {
    final count = (seconds * 1000 / chunk.inMilliseconds).round();
    for (var i = 0; i < count; i++) {
      d.addSample(db, duration: chunk);
    }
  }

  group('the bar never moves', () {
    test('a long utterance does not shift the threshold', () {
      // The whole reason this is fixed. Every adaptive version eventually
      // drifted upward while the user was speaking.
      final d = vad();
      final before = d.triggerDb;
      feed(d, -50, seconds: 3);
      feed(d, -18, seconds: 20);
      feed(d, -50, seconds: 3);
      expect(d.triggerDb, before);
    });

    test('the threshold is exactly what was configured', () {
      expect(vad(threshold: -30).triggerDb, -30);
      expect(vad(threshold: -45).triggerDb, -45);
    });
  });

  group('detecting speech', () {
    test('normal speech above the bar starts a turn', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      feed(d, -22, seconds: 1);
      expect(d.speechStarted, isTrue);
    });

    test('silence never starts a turn', () {
      final d = vad();
      feed(d, -55, seconds: 20);
      expect(d.speechStarted, isFalse);
      expect(d.shouldEndTurn, isFalse);
    });

    test('a fan or humming below the bar never starts a turn', () {
      final d = vad();
      feed(d, -48, seconds: 20);
      expect(d.speechStarted, isFalse);
    });

    test('noise above the bar DOES count — raise the bar for that room', () {
      // Honest about the trade a fixed threshold makes.
      final tooLow = vad(threshold: -40);
      feed(tooLow, -28, seconds: 5);
      expect(tooLow.speechStarted, isTrue);

      final raised = vad(threshold: -22);
      feed(raised, -28, seconds: 5);
      expect(raised.speechStarted, isFalse);
      feed(raised, -16, seconds: 2);
      expect(raised.speechStarted, isTrue);
    });

    test('a single loud frame is not speech', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      d.addSample(-10);
      expect(d.speechStarted, isFalse);
    });
  });

  group('ending a turn', () {
    test('ends after a sustained pause', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      feed(d, -20, seconds: 2);
      expect(d.shouldEndTurn, isFalse);
      feed(d, -50, seconds: 3.2);
      expect(d.shouldEndTurn, isTrue);
    });

    test('breathing mid-sentence does not end it', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      for (var i = 0; i < 12; i++) {
        feed(d, -20, seconds: 2.0); // a clause
        feed(d, -50, seconds: 0.9); // breath
      }
      expect(d.shouldEndTurn, isFalse);
    });

    test('a long thinking pause mid-sentence does not end it', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      feed(d, -20, seconds: 2);
      feed(d, -50, seconds: 2.0); // "umm..."
      feed(d, -20, seconds: 2);
      expect(d.shouldEndTurn, isFalse);
    });

    test('syllable-level variation does not end it', () {
      final d = vad();
      feed(d, -50, seconds: 2);
      for (var i = 0; i < 40; i++) {
        feed(d, -18, seconds: 0.3); // syllables
        feed(d, -46, seconds: 0.2); // gaps between words
      }
      expect(d.shouldEndTurn, isFalse);
    });

    test('silence before any speech never ends a turn', () {
      final d = vad();
      feed(d, -60, seconds: 30);
      expect(d.shouldEndTurn, isFalse);
    });
  });

  group('robustness at a real chunk cadence', () {
    // The recorder streams far faster than the nominal poll interval, and
    // sizing anything in frame COUNTS rather than duration broke this twice.
    const fast = Duration(milliseconds: 10);

    test('detects speech and the pause at 10ms frames', () {
      final d = vad();
      feed(d, -50, seconds: 2, chunk: fast);
      feed(d, -20, seconds: 2, chunk: fast);
      expect(d.speechStarted, isTrue);
      feed(d, -50, seconds: 3.2, chunk: fast);
      expect(d.shouldEndTurn, isTrue);
    });

    test('one blip does not restart the pause timer', () {
      final d = vad();
      feed(d, -50, seconds: 2, chunk: fast);
      feed(d, -20, seconds: 2, chunk: fast);
      feed(d, -52, seconds: 1.6, chunk: fast);
      d.addSample(-18, duration: fast); // a click
      feed(d, -52, seconds: 1.6, chunk: fast);
      expect(d.shouldEndTurn, isTrue);
    });

    test('resumed speech does cancel the pause', () {
      final d = vad();
      feed(d, -50, seconds: 2, chunk: fast);
      feed(d, -20, seconds: 2, chunk: fast);
      feed(d, -52, seconds: 2.0, chunk: fast);
      feed(d, -20, seconds: 1, chunk: fast);
      expect(d.shouldEndTurn, isFalse);
      expect(d.quietProgress, lessThan(0.2));
    });
  });

  group('hysteresis', () {
    test('audio between the two levels holds state', () {
      // -42 is below the -40 bar but above the -44 quiet level.
      final d = vad();
      expect(d.quietBelowDb, -44);
      feed(d, -50, seconds: 2);
      feed(d, -20, seconds: 2);
      final progressBefore = d.quietProgress;
      feed(d, -42, seconds: 2);
      expect(d.quietProgress, progressBefore);
      expect(d.shouldEndTurn, isFalse);
    });
  });

  group('bookkeeping', () {
    test('quietProgress fills up during a pause', () {
      final d = vad();
      expect(d.quietProgress, 0);
      feed(d, -50, seconds: 2);
      feed(d, -20, seconds: 1);
      feed(d, -50, seconds: 1.3);
      expect(d.quietProgress, greaterThan(0.3));
      expect(d.quietProgress, lessThan(1.0));
      feed(d, -50, seconds: 2.0);
      expect(d.quietProgress, 1.0);
    });

    test('reset clears everything', () {
      final d = vad();
      feed(d, -20, seconds: 3);
      d.reset();
      expect(d.speechStarted, isFalse);
      expect(d.sampleCount, 0);
      expect(d.shouldEndTurn, isFalse);
      expect(d.quietProgress, 0);
    });

    test('describe() reports the level and the bar', () {
      final d = vad();
      feed(d, -40, seconds: 1);
      expect(d.describe(), contains('samples'));
      expect(d.describe(), contains('-40'));
    });
  });
}
