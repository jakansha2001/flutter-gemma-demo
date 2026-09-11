import 'dart:collection';

/// Decides when speech starts and stops, from microphone level samples.
///
/// flutter_gemma_speech ships no voice-activity detection, so hands-free has
/// to derive one. `Amplitude.current` is dBFS — 0 is full scale, and a quiet
/// room might sit anywhere from -60 to -30 depending on the microphone and its
/// gain. That is why a FIXED threshold cannot work: the value that triggers
/// reliably on one machine never triggers on another.
///
/// This is a separate, pure class on purpose. Inline in the widget it was
/// untestable, and two different wrong versions shipped before this one.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.pollInterval = const Duration(milliseconds: 150),
    this.minVoiced = const Duration(milliseconds: 350),
    this.silenceToEnd = const Duration(milliseconds: 1900),
    this.marginDb = 9.0,
    this.floorWindow = const Duration(seconds: 5),
    this.minTriggerDb = -52.0,
    this.maxTriggerDb = -26.0,
  });

  /// How often samples arrive. Used to accumulate voiced time.
  final Duration pollInterval;

  /// Sustained loud audio required before it counts as speech. Stops a single
  /// door slam from starting a turn.
  final Duration minVoiced;

  /// Quiet needed to end a turn. Below ~1.5s this cuts people off at ordinary
  /// mid-sentence pauses.
  final Duration silenceToEnd;

  /// How far above the noise floor counts as speech.
  final double marginDb;

  /// How much history the floor is computed from.
  final Duration floorWindow;

  /// The trigger level is clamped into this range, so neither an unusually
  /// quiet nor an unusually noisy room can push it somewhere unreachable.
  final double minTriggerDb;
  final double maxTriggerDb;

  final Queue<double> _window = Queue<double>();
  int _windowCapacity = 0;

  bool _speechStarted = false;
  Duration _voicedFor = Duration.zero;
  Duration _quietFor = Duration.zero;

  int _sampleCount = 0;
  double _peakDb = -160;
  double _lastDb = -160;

  bool get speechStarted => _speechStarted;
  int get sampleCount => _sampleCount;
  double get peakDb => _peakDb;
  double get lastDb => _lastDb;

  /// True once speech has started and then stopped for [silenceToEnd].
  bool get shouldEndTurn => _speechStarted && _quietFor >= silenceToEnd;

  /// The learned noise floor.
  ///
  /// A LOW PERCENTILE of the recent window, not a moving average. An average
  /// (or any EMA that rises) climbs while the user is speaking, dragging the
  /// trigger up with it so it is never crossed — which is exactly how the
  /// previous version failed. A percentile ignores the loud tail entirely.
  double get noiseFloorDb {
    if (_window.isEmpty) return -50;
    final sorted = _window.toList()..sort();
    final index = (sorted.length * 0.25).floor().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  /// The level a sample must exceed to count as speech.
  double get triggerDb =>
      (noiseFloorDb + marginDb).clamp(minTriggerDb, maxTriggerDb);

  /// Feed one level sample.
  void addSample(double db) {
    _sampleCount++;
    _lastDb = db;
    if (db > _peakDb) _peakDb = db;

    if (_windowCapacity == 0) {
      _windowCapacity = (floorWindow.inMilliseconds /
              pollInterval.inMilliseconds.clamp(1, 1 << 30))
          .ceil()
          .clamp(4, 400);
    }
    _window.addLast(db);
    while (_window.length > _windowCapacity) {
      _window.removeFirst();
    }

    if (db > triggerDb) {
      _voicedFor += pollInterval;
      _quietFor = Duration.zero;
      if (!_speechStarted && _voicedFor >= minVoiced) {
        _speechStarted = true;
      }
    } else {
      // Voiced time decays rather than resetting, so a brief dip inside a word
      // does not throw away progress toward [minVoiced].
      _voicedFor = _voicedFor - pollInterval ~/ 2;
      if (_voicedFor < Duration.zero) _voicedFor = Duration.zero;
      if (_speechStarted) _quietFor += pollInterval;
    }
  }

  void reset() {
    _window.clear();
    _speechStarted = false;
    _voicedFor = Duration.zero;
    _quietFor = Duration.zero;
    _sampleCount = 0;
    _peakDb = -160;
    _lastDb = -160;
  }

  /// One-line summary for on-screen diagnostics.
  String describe() =>
      'level ${_lastDb.toStringAsFixed(0)} · floor '
      '${noiseFloorDb.toStringAsFixed(0)} · trigger '
      '${triggerDb.toStringAsFixed(0)} · peak ${_peakDb.toStringAsFixed(0)} dB '
      '· $_sampleCount samples';
}
