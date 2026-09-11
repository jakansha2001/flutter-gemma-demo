import 'package:flutter_test/flutter_test.dart';
import 'package:gemma_vision_demo/gemma/voice_activity_detector.dart';

/// The detector is the piece that decides whether hands-free works at all.
/// Every case here is a room it has to cope with — including the two that
/// broke it in practice: a noisy microphone, and a floor that climbed while
/// the user was speaking.
void main() {
  VoiceActivityDetector vad() => VoiceActivityDetector();

  /// Feed [seconds] worth of samples at [db].
  void feed(VoiceActivityDetector d, double db, {double seconds = 1}) {
    final count = (seconds * 1000 / d.pollInterval.inMilliseconds).round();
    for (var i = 0; i < count; i++) {
      d.addSample(db);
    }
  }

  group('quiet rooms', () {
    test('silence alone never starts a turn', () {
      final d = vad();
      feed(d, -55, seconds: 10);
      expect(d.speechStarted, isFalse);
      expect(d.shouldEndTurn, isFalse);
    });

    test('detects normal speech over a quiet floor', () {
      final d = vad();
      feed(d, -55, seconds: 2); // ambient
      feed(d, -25, seconds: 1); // talking
      expect(d.speechStarted, isTrue);
    });
  });

  group('noisy rooms', () {
    test('detects speech over a LOUD floor', () {
      // The failure mode that made hands-free unusable: a high noise floor
      // pushed the trigger somewhere the voice never reached.
      final d = vad();
      feed(d, -34, seconds: 3); // noisy ambient
      feed(d, -18, seconds: 1); // talking over it
      expect(d.speechStarted, isTrue);
    });

    test('the trigger never exceeds the ceiling', () {
      final d = vad();
      feed(d, -5, seconds: 4); // absurdly loud room
      expect(d.triggerDb, lessThanOrEqualTo(d.maxTriggerDb));
    });

    test('the trigger never drops below the floor limit', () {
      final d = vad();
      feed(d, -140, seconds: 4); // effectively dead mic
      expect(d.triggerDb, greaterThanOrEqualTo(d.minTriggerDb));
    });

    test('steady noise on its own does not start a turn', () {
      final d = vad();
      feed(d, -34, seconds: 12);
      expect(d.speechStarted, isFalse);
    });
  });

  group('the floor must not chase the voice', () {
    test('a long utterance keeps the trigger below the speech level', () {
      // Regression: an averaging floor climbed during speech, pulling the
      // trigger up with it, so speech stopped registering partway through.
      final d = vad();
      feed(d, -55, seconds: 1);
      feed(d, -22, seconds: 8); // a long answer
      expect(d.speechStarted, isTrue);
      expect(
        d.triggerDb,
        lessThan(-22),
        reason: 'trigger ${d.triggerDb} climbed above the speaking level',
      );
    });
  });

  group('ending a turn', () {
    test('ends after a sustained pause', () {
      final d = vad();
      feed(d, -55, seconds: 1);
      feed(d, -25, seconds: 1);
      expect(d.shouldEndTurn, isFalse);
      feed(d, -55, seconds: 2.5);
      expect(d.shouldEndTurn, isTrue);
    });

    test('a short mid-sentence pause does NOT end the turn', () {
      final d = vad();
      feed(d, -55, seconds: 1);
      feed(d, -25, seconds: 1);
      feed(d, -55, seconds: 0.8); // thinking pause
      feed(d, -25, seconds: 1); // carries on
      expect(d.shouldEndTurn, isFalse);
    });

    test('silence before any speech never ends a turn', () {
      final d = vad();
      feed(d, -60, seconds: 30);
      expect(d.shouldEndTurn, isFalse);
    });
  });

  group('robustness', () {
    test('a single spike is not speech', () {
      final d = vad();
      feed(d, -55, seconds: 2);
      d.addSample(-10); // one loud frame: a door slam
      expect(d.speechStarted, isFalse);
    });

    test('a brief dip inside a word does not lose progress', () {
      final d = vad();
      feed(d, -55, seconds: 2);
      d
        ..addSample(-22)
        ..addSample(-22)
        ..addSample(-45) // consonant gap
        ..addSample(-22)
        ..addSample(-22);
      expect(d.speechStarted, isTrue);
    });

    test('reset clears everything', () {
      final d = vad();
      feed(d, -25, seconds: 3);
      d.reset();
      expect(d.speechStarted, isFalse);
      expect(d.sampleCount, 0);
      expect(d.shouldEndTurn, isFalse);
    });

    test('describe() reports counts for on-screen diagnostics', () {
      final d = vad();
      feed(d, -40, seconds: 1);
      expect(d.describe(), contains('samples'));
      expect(d.sampleCount, greaterThan(0));
    });
  });
}
