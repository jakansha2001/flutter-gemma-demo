import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_speech/flutter_gemma_speech.dart';
import 'package:gemma_vision_demo/gemma/gemma_failure.dart';
import 'package:gemma_vision_demo/gemma/gemma_service.dart';
import 'package:gemma_vision_demo/gemma/model_catalog.dart';
import 'package:gemma_vision_demo/gemma/voice_activity_detector.dart';
import 'package:gemma_vision_demo/gemma/voice_turn.dart';
import 'package:gemma_vision_demo/theme.dart';
import 'package:gemma_vision_demo/utils/audio_converter.dart';
import 'package:gemma_vision_demo/widgets/status_view.dart';
import 'package:gemma_vision_demo/widgets/voice_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Push-to-talk speech → LLM → speech, entirely on-device.
///
/// [VoiceSession] (flutter_gemma_speech) chains the three models into a single
/// `runTurn` that streams [VoiceEvent]s. It owns no microphone and no player,
/// so this screen supplies both: `record` captures 16 kHz mono WAV, and
/// `just_audio` plays the synthesized reply back.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

/// Where a turn currently is, so the UI can narrate the pipeline.
///
/// Order matters: [_PipelineBar] treats a lower index as an earlier step.
/// [armed] sits between idle and recording — hands-free, mic open, waiting for
/// you to start speaking.
enum VoiceStage { idle, armed, recording, transcribing, thinking, speaking }

/// How a turn is started.
enum VoiceMode {
  /// Tap to start, tap to stop. Nothing can trigger it by accident, which is
  /// what you want in a room full of people.
  pushToTalk,

  /// The mic stays open; the turn starts when you speak and ends when you
  /// stop. More natural, but background noise can trigger it.
  handsFree;

  String get label => this == VoiceMode.pushToTalk ? 'Push to talk' : 'Hands-free';
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _recorder = AudioRecorder();
  /// Two players, used alternately. While one is playing a sentence the
  /// other is loading the next, so decoding never lands in the gap between
  /// sentences. One player cannot do this: `setFilePath` on a playing player
  /// would cut it off.
  final _players = [AudioPlayer(), AudioPlayer()];
  int _nextPlayer = 0;

  SpeechRecognizer? _recognizer;
  SpeechSynthesizer? _synth;
  InferenceChat? _chat;
  VoiceTurn? _turn;

  bool _loading = true;
  GemmaFailure? _failure;
  String _setupStage = 'Preparing';
  int? _setupPercent;

  VoiceMode _mode = VoiceMode.pushToTalk;
  VoiceStage _stage = VoiceStage.idle;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // --- Voice activity detection (hands-free only) ----------------------
  // flutter_gemma ships no VAD, so we derive one from the recorder's own
  // amplitude stream. `Amplitude.current` is dBFS: 0 is full scale and
  // quiet rooms sit near -50. These two numbers are the whole heuristic and
  // are the first thing to tune if it misfires in a particular room.
  // Voice activity detection lives in its own tested class — see
  // [VoiceActivityDetector]. Two wrong versions of this shipped while the
  // logic was inline here and untestable.
  final _vad = VoiceActivityDetector();

  static const _amplitudePollInterval = Duration(milliseconds: 150);

  /// How long the mic may stay open hearing nothing before we give up.
  /// Without this, a trigger level that is never crossed leaves hands-free
  /// armed forever with no way to end the turn.
  static const _armedTimeout = Duration(seconds: 15);

  Duration _armedFor = Duration.zero;

  StreamSubscription<Amplitude>? _amplitudeSub;
  double _level = -60;
  // Tied to the STT graph's window — see Models.maxRecordingSeconds.
  static const _maxRecording = Duration(
    seconds: Models.maxRecordingSeconds,
  );

  String? _transcript;

  /// Everything generated so far. Runs ahead of [_spoken].
  String _reply = '';

  /// The portion that has actually been read aloud. Rendering the two
  /// differently is what stops the text looking like it "finished" long
  /// before the audio did.
  String _spoken = '';
  String? _turnError;


  /// Guards the async gap between tapping and `_stage` actually flipping — a
  /// fast double-tap would otherwise start two recordings.
  bool _starting = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _failure = null;
      _setupPercent = null;
    });

    // Promoted to fields only at the end, so anything already opened must be
    // closed by hand if we bail out early — otherwise a failed init leaks a
    // recognizer/synth/chat on every retry.
    SpeechRecognizer? recognizer;
    SpeechSynthesizer? synth;
    InferenceChat? chat;
    Future<void> closePartial() async {
      await recognizer?.close();
      await synth?.close();
      await chat?.close();
    }

    try {
      // --- 1. Speech-to-text. Needs two files: model + tokenizer. ---------
      _setStage('Downloading ${Models.sttDisplayName} · ${Models.sttSize}');
      await FlutterGemma.installStt()
          .modelFromNetwork(Models.sttModelUrl)
          .tokenizerFromNetwork(Models.sttTokenizerUrl)
          .ofType(Models.sttModelType)
          .withModelProgress(_setPercent)
          .withTokenizerProgress(_setPercent)
          .install();
      if (_disposed) {
        await closePartial();
        return;
      }
      // Pin the output language. Whisper is multilingual and will otherwise
      // drift — it can render English speech into another language. This is
      // a per-call knob (flutter_gemma 1.8.0): it never reloads the model.
      recognizer = await FlutterGemma.getActiveStt(
        language: Models.sttLanguage,
      );

      // --- 2. Text-to-speech. One base URL; the bundle is fetched from it. -
      _setStage('Downloading ${Models.ttsDisplayName} · ${Models.ttsSize}');
      await FlutterGemma.installTts()
          .fromNetwork(Models.ttsBaseUrl)
          .ofType(Models.ttsModelType)
          .withProgress(_setPercent)
          .install();
      if (_disposed) {
        await closePartial();
        return;
      }
      synth = await FlutterGemma.getActiveTts();

      // --- 3. The LLM in the middle. -------------------------------------
      _setStage('Loading ${Models.llmDisplayName}');
      chat = await GemmaService.instance.openChat(
        // VoiceSession.fromChat rejects a tools-enabled chat unless you also
        // give it an onToolCall handler, so keep this one plain.
        tools: const [],
        // The reply is spoken, so cap it hard — a 400-token answer would take
        // most of a minute to read out.
        maxOutputTokens: 110,
        systemInstruction:
            'Your reply will be read aloud by an English speech '
            'synthesizer. Answer in one or two short, plain sentences. '
            'No lists, no markdown, no emoji, no special characters. '
            '${Models.languagePin}',
      );
      if (_disposed) {
        await closePartial();
        return;
      }

      // Driving the three models ourselves, rather than VoiceSession — see
      // the VoiceTurn class doc for why (batch TTS means VoiceSession cannot
      // start speaking until the whole reply is generated).
      final recognizerRef = recognizer;
      final synthRef = synth;
      final chatRef = chat;
      final turn = VoiceTurn(
        transcribe: (pcm) =>
            recognizerRef.transcribe(pcm, language: Models.sttLanguage),
        respond: (prompt) async* {
          await chatRef.addQueryChunk(Message.text(text: prompt, isUser: true));
          await for (final r in chatRef.generateChatResponseAsync()) {
            // Only the text channel is spoken. Thinking and tool calls are
            // not part of a voice turn.
            if (r is TextResponse) yield r.token;
          }
        },
        synthesize: synthRef.synthesize,
        synthesizerSampleRate: synthRef.sampleRate,
        prepareClip: _prepareClip,
        playClip: _playClip,
        stopPlayback: _stopAllPlayers,
      );

      if (!mounted) {
        await closePartial();
        return;
      }
      setState(() {
        _recognizer = recognizer;
        _synth = synth;
        _chat = chat;
        _turn = turn;
        _loading = false;
      });
    } catch (e) {
      await closePartial();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = GemmaFailure.from(e);
      });
    }
  }

  void _setStage(String label) {
    if (!mounted) return;
    setState(() {
      _setupStage = label;
      _setupPercent = null;
    });
  }

  void _setPercent(int percent) {
    if (!mounted) return;
    setState(() => _setupPercent = percent);
  }

  Future<void> _setMode(VoiceMode mode) async {
    if (_mode == mode) return;
    // Leaving hands-free must close the open mic, or it keeps listening.
    await _stopListening();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _stage = VoiceStage.idle;
      _elapsed = Duration.zero;
    });
    if (mode == VoiceMode.handsFree) await _start(handsFree: true);
  }

  /// Tear down the mic and the amplitude subscription, whatever state we are
  /// in. Safe to call repeatedly.
  Future<void> _stopListening() async {
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _armedFor = Duration.zero;
    _vad.reset();
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {
      // Nothing useful to do if the recorder is already gone.
    }
  }

  // --- recording ----------------------------------------------------------

  Future<bool> _ensureMicPermission() async {
    // permission_handler covers Android/iOS; on desktop the entitlement does
    // the work and the plugin may throw, so fall back to the recorder's own
    // check rather than blocking the user.
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (!mounted) return false;
          _toast(
            status.isPermanentlyDenied
                ? 'Microphone access is blocked. Enable it in Settings.'
                : 'Microphone permission is required to speak.',
            action: status.isPermanentlyDenied
                ? SnackBarAction(
                    label: 'SETTINGS',
                    onPressed: openAppSettings,
                  )
                : null,
          );
          return false;
        }
      }
    } catch (_) {
      // Fall through to the recorder check below.
    }

    try {
      // On macOS this triggers the system permission prompt on first use.
      // A timeout matters: if the prompt never resolves we must not leave
      // `_starting` latched, which would make every later tap a no-op.
      final granted = await _recorder
          .hasPermission()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (!granted) {
        if (mounted) {
          setState(
            () => _turnError =
                'Microphone permission was denied. Allow it in System '
                'Settings → Privacy & Security → Microphone, then try again.',
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) setState(() => _turnError = 'Could not access the microphone: $e');
      return false;
    }
    return true;
  }

  Future<void> _toggle() async {
    // Hands-free: the button pauses / resumes listening entirely.
    if (_mode == VoiceMode.handsFree) {
      if (_stage == VoiceStage.armed || _stage == VoiceStage.recording) {
        await _stopListening();
        if (mounted) setState(() => _stage = VoiceStage.idle);
      } else if (_stage == VoiceStage.idle) {
        await _start(handsFree: true);
      }
      return;
    }

    if (_stage == VoiceStage.recording) {
      await _stopAndRun();
      return;
    }
    if (_stage != VoiceStage.idle || _starting) return;
    _starting = true;
    try {
      await _start();
    } finally {
      _starting = false;
    }
  }

  Future<void> _start({bool handsFree = false}) async {
    if (!await _ensureMicPermission()) {
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_input.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        // Hands-free opens the mic but does not consider the turn started
        // until it actually hears you.
        _stage = handsFree ? VoiceStage.armed : VoiceStage.recording;
        _elapsed = Duration.zero;
        _transcript = null;
        _reply = '';
        _turnError = null;
        _armedFor = Duration.zero;
      });
      _vad.reset();

      if (handsFree) {
        await _amplitudeSub?.cancel();
        _amplitudeSub = _recorder
            .onAmplitudeChanged(_amplitudePollInterval)
            .listen(_onAmplitude, onError: (Object _) {
              // An amplitude failure must not strand the mic open with no way
              // to end the turn — fall back to the duration cap below.
            });
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_stage == VoiceStage.recording) {
          setState(() => _elapsed += const Duration(seconds: 1));
          // Hard stop at the STT graph's window. Recording past it does not
          // fail — it silently truncates, which is worse.
          if (_elapsed >= _maxRecording) _stopAndRun();
        } else if (_stage == VoiceStage.armed) {
          _armedFor += const Duration(seconds: 1);
          // Safety net. If the trigger level is wrong for this room, speech
          // is never detected, so nothing else would ever end this turn and
          // hands-free would hang with the mic open.
          if (_armedFor >= _armedTimeout) {
            final diagnostics = _vad.describe();
            unawaited(_stopListening());
            if (mounted) {
              setState(() {
                _stage = VoiceStage.idle;
                // Report the NUMBERS, not just "I could not hear you". If no
                // samples arrived at all, the microphone stream is the
                // problem; if they arrived but stayed below the trigger, the
                // level is.
                _turnError = _vad.sampleCount == 0
                    ? 'No microphone level data arrived, so speech could '
                          'never be detected. Push-to-talk still works.'
                    : 'Did not detect speech in '
                          '${_armedTimeout.inSeconds}s.\n$diagnostics';
              });
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = VoiceStage.idle;
        // Surface it in the panel too — a snackbar is easy to miss, and a
        // button that appears to do nothing is the worst possible outcome.
        _turnError = 'Could not start recording: $e';
      });
    }
  }

  /// The voice-activity heuristic: accumulate loud time until it clears
  /// [_minVoicedDuration] (so a single spike is not "speech"), then end the
  /// turn after a sustained run of quiet.
  void _onAmplitude(Amplitude amplitude) {
    if (!mounted) return;
    final wasSpeaking = _vad.speechStarted;
    _vad.addSample(amplitude.current);

    setState(() {
      _level = amplitude.current;
      if (_vad.speechStarted && !wasSpeaking) _stage = VoiceStage.recording;
    });

    if (_vad.speechStarted && !wasSpeaking) {
    }
    if (_vad.shouldEndTurn) _stopAndRun();
  }

  Future<void> _stopAndRun() async {
    _timer?.cancel();
    _timer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _armedFor = Duration.zero;
    _vad.reset();

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      if (mounted) {
        setState(() => _stage = VoiceStage.idle);
        _toast('Recording failed: $e');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _stage = VoiceStage.idle);
    if (path == null) return;

    Uint8List pcm;
    try {
      final bytes = await File(path).readAsBytes();
      final wav = AudioConverter.parseWav(bytes);
      pcm = AudioConverter.toPcm16kMono(
        wav.pcm,
        sourceSampleRate: wav.sampleRate,
        sourceChannels: wav.channels,
      );
      final duration = AudioConverter.pcmDuration(pcm, sampleRate: 16000);
      if (duration < const Duration(milliseconds: 400)) {
        // In hands-free this is usually a door slam, not speech: re-arm
        // silently rather than nagging the user about it.
        if (_mode == VoiceMode.handsFree) {
          await _rearmIfHandsFree();
        } else {
          _toast('That was too short — tap and speak.');
        }
        return;
      }
    } catch (e) {
      _toast('Could not read the recording: $e');
      return;
    }

    await _runTurn(pcm);
  }

  Future<void> _runTurn(Uint8List pcm) async {
    final turn = _turn;
    if (turn == null || _stage != VoiceStage.idle) return;

    setState(() {
      _stage = VoiceStage.transcribing;
      _transcript = null;
      _reply = '';
      _spoken = '';
      _turnError = null;
    });

    var heardNothing = false;
    try {
      await for (final event in turn.run(pcm)) {
        if (!mounted) return;
        switch (event) {
          case VoicePhaseChanged(:final phase):
            setState(() {
              _stage = switch (phase) {
                VoicePhase.transcribing => VoiceStage.transcribing,
                VoicePhase.thinking => VoiceStage.thinking,
                VoicePhase.speaking => VoiceStage.speaking,
                VoicePhase.done => VoiceStage.idle,
              };
            });
          case VoiceTranscript(:final text):
            setState(() => _transcript = text);
          case VoiceReplyText(:final fullText):
            setState(() => _reply = fullText);
          case VoiceSpokenText(:final spokenSoFar):
            setState(() => _spoken = spokenSoFar);
          case VoiceHeardNothing():
            heardNothing = true;
            if (_mode == VoiceMode.pushToTalk) {
              // Push-to-talk has no retry loop, so say so rather than
              // silently returning to idle as if nothing happened.
              _toast('I did not catch that — try speaking a little louder.');
            }
          case VoiceSynthesisSkipped():
            // The sentence is still on screen; it just was not spoken. Not
            // worth interrupting the turn for, so nothing to do here.
            break;
          case VoiceTurnFailed(:final error):
            final f = GemmaFailure.from(error);
            setState(() => _turnError = '${f.title}: ${f.message}');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final f = GemmaFailure.from(e);
      setState(() => _turnError = '${f.title}: ${f.message}');
    } finally {
      if (mounted) setState(() => _stage = VoiceStage.idle);
      // The reply has finished playing by the time the stream closes, so this
      // is the point at which it is safe to listen again. We deliberately do
      // NOT keep the mic open during playback: without echo cancellation the
      // speaker talks straight into the microphone and the model answers
      // itself.
      await _rearmIfHandsFree(heardNothing: heardNothing);
    }
  }

  /// Consecutive turns where nothing intelligible was heard. Hands-free stops
  /// itself rather than looping forever in a noisy room.
  int _silentTurns = 0;
  static const _maxSilentTurns = 3;

  /// Start the next turn automatically, in hands-free mode only.
  Future<void> _rearmIfHandsFree({bool heardNothing = false}) async {
    if (!mounted || _mode != VoiceMode.handsFree) return;
    if (_stage != VoiceStage.idle) return;

    if (heardNothing) {
      _silentTurns++;
      if (_silentTurns >= _maxSilentTurns) {
        _silentTurns = 0;
        if (mounted) {
          setState(() => _stage = VoiceStage.idle);
          _toast('Stopped listening — I could not hear anything.');
        }
        return;
      }
    } else {
      _silentTurns = 0;
    }
    await _start(handsFree: true);
  }

  /// Monotonic counter so every clip gets its own filename — see below.
  int _clipCounter = 0;

  Future<void> _stopAllPlayers() async {
    for (final player in _players) {
      try {
        await player.stop();
      } catch (_) {
        // Stopping an idle player is not an error worth surfacing.
      }
    }
  }

  /// Write the clip and load it into the next free player.
  ///
  /// Returns the player itself as the opaque handle [VoiceTurn] hands back to
  /// [_playClip].
  Future<Object> _prepareClip(Uint8List pcm, int sampleRate) async {
    final wav = AudioConverter.pcmToWav(pcm, sampleRate: sampleRate);
    final dir = await getTemporaryDirectory();

    // A UNIQUE path per clip, deliberately. just_audio caches by URI, so
    // reusing one filename meant the second sentence either replayed the
    // first one's audio or returned instantly.
    final file = File('${dir.path}/voice_reply_${_clipCounter++}.wav');
    await file.writeAsBytes(wav);

    final player = _players[_nextPlayer];
    _nextPlayer = (_nextPlayer + 1) % _players.length;
    await player.stop();
    await player.setFilePath(file.path);

    unawaited(file.delete().catchError((Object _) => file));
    return player;
  }

  Future<void> _playClip(Object clip) async {
    if (!mounted || clip is! AudioPlayer) return;
    try {
      // Completes when playback finishes, which is what paces the turn.
      await clip.play();
    } catch (e) {
      if (mounted) _toast('Could not play the reply aloud: $e');
    }
  }

  /// Barge-in: stop speaking immediately and abandon the rest of the turn.
  Future<void> _bargeIn() async {
    await _turn?.cancel();
    await _stopAllPlayers();
    if (mounted) setState(() => _stage = VoiceStage.idle);
  }

  /// Always available: stop everything and return to idle, from any state.
  /// Hands-free previously had no way out mid-loop except leaving the screen.
  Future<void> _stopEverything() async {
    _silentTurns = 0;
    await _turn?.cancel();
    await _stopAllPlayers();
    await _stopListening();
    if (mounted) setState(() => _stage = VoiceStage.idle);
  }

  void _toast(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    for (final p in _players) {
      p.dispose();
    }
    _recognizer?.close();
    _synth?.close();
    _chat?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice loop', style: AppText.heading),
            Text(
              '${Models.sttDisplayName} → Gemma 4 → ${Models.ttsDisplayName}',
              style: AppText.caption,
            ),
          ],
        ),
        actions: [
          if (!_loading && _failure == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ModeToggle(
                mode: _mode,
                // Changing mode mid-turn would cut the model off mid-sentence.
                enabled: _stage == VoiceStage.idle ||
                    _stage == VoiceStage.armed ||
                    _stage == VoiceStage.recording,
                onChanged: _setMode,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? LoadingView(
                title: _setupStage,
                accent: AppColors.voice,
                progress: _setupPercent == null ? null : _setupPercent! / 100,
                subtitle: _setupPercent == null
                    ? 'Three models, all running locally.'
                    : '$_setupPercent%',
              )
            : _failure != null
            ? ErrorView(failure: _failure!, onRetry: _init)
            : _body(),
      ),
    );
  }

  Widget _body() {
    // `armed` and `recording` are both interactive states — the button
    // stops them. Only the model-bound phases disable it.
    final busy = _stage == VoiceStage.transcribing ||
        _stage == VoiceStage.thinking ||
        _stage == VoiceStage.speaking;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PipelineBar(stage: _stage),
                Gap.lg,
                if (_transcript == null && _reply.isEmpty && _turnError == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: EmptyView(
                      icon: Icons.mic_none_rounded,
                      accent: AppColors.voice,
                      title: _mode == VoiceMode.handsFree
                          ? 'Just start talking'
                          : 'Tap the mic and talk',
                      subtitle: _mode == VoiceMode.handsFree
                          ? 'The mic is open. It answers when you stop '
                                'speaking, then listens again.'
                          : 'Your voice is transcribed, answered and spoken '
                                'back without a single network call.',
                    ),
                  ),
                if (_transcript != null)
                  VoicePanel(
                    label: 'YOU SAID',
                    color: AppColors.voice,
                    child: Text(
                      _transcript!.trim().isEmpty
                          ? "(nothing recognised — try speaking a little louder)"
                          : _transcript!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (_reply.isNotEmpty) ...[
                  Gap.md,
                  VoicePanel(
                    label: _stage == VoiceStage.speaking
                        ? 'GEMMA IS SAYING'
                        : 'GEMMA REPLIED',
                    color: AppColors.accent,
                    child: SpokenText(full: _reply, spoken: _spoken),
                  ),
                ],
                if (_turnError != null) ...[
                  Gap.md,
                  VoicePanel(
                    label: 'ERROR',
                    color: AppColors.danger,
                    child: Text(
                      _turnError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        MicControl(
          mode: _mode,
          stage: _stage,
          level: _level,
          triggerDb: _vad.triggerDb,
          elapsed: _elapsed,
          maxDuration: _maxRecording,
          onTap: busy ? null : _toggle,
          onBargeIn: _bargeIn,
          // Always live, in every state — hands-free previously had no way
          // out of the loop except leaving the screen.
          onStop: _stage == VoiceStage.idle ? null : _stopEverything,
        ),
      ],
    );
  }
}
