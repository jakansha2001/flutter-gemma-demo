# flutter_gemma 0.13.6 → 1.8.0: what changed

Everything below is drawn from the package's own CHANGELOG, README and source
at version 1.8.0 (published 2026-09-10), plus the companion packages' pubspecs.
Where something is a judgement call rather than a documented fact, it says so.

This demo was pinned at **0.13.6** (April 2026). That is roughly **45 releases**
behind, spanning a **1.0 major rewrite**. The short version: the package that
used to be one monolith is now a small core plus opt-in packages, and it grew
speech, agents and a real desktop story along the way.

---

## 1. The breaking change that matters: the package split (1.0.0)

Before 1.0, `flutter_gemma` was one package containing every engine and every
backend. Adding it meant shipping MediaPipe **and** LiteRT-LM native code
whether you used them or not.

Since 1.0, `flutter_gemma` is a **core with no inference engine at all**. You
add the engine packages you need and register them at startup.

```dart
// ❌ 0.13.x — core carried the engines implicitly
FlutterGemma.initialize(huggingFaceToken: token, maxDownloadRetries: 10);

// ✅ 1.x — you declare what you shipped
await FlutterGemma.initialize(
  inferenceEngines: const [LiteRtLmEngine()],   // flutter_gemma_litertlm
  sttBackends:      const [LiteRtSttBackend()], // flutter_gemma_speech
  ttsBackends:      const [LiteRtTtsBackend()],
  maxDownloadRetries: 10,
);
```

**The failure mode is nasty if you miss it**: everything compiles, and
`getActiveModel()` throws at runtime with a "no engine registered" error. There
is no compile-time signal.

### The package menu

| Package | Version used here | What it gives you |
|---|---|---|
| `flutter_gemma` | 1.8.0 | Core: model management, chat, sessions, download. No engine. |
| `flutter_gemma_litertlm` | 1.6.3 | `.litertlm` engine over `dart:ffi`. Android, iOS, macOS, Windows, Linux, Web. |
| `flutter_gemma_mediapipe` | 1.0.5 | `.task` / `.bin` engine. Mobile + web only — **cannot run on desktop**. |
| `flutter_gemma_speech` | 0.5.0 | STT, TTS and the `VoiceSession` loop. Native only. |
| `flutter_gemma_agent` | 0.2.5 | `SKILL.md` agent skills executed via tool-calling. |
| `flutter_gemma_onnx` | 0.3.3 | ONNX Runtime engine + embeddings. |
| `flutter_gemma_rag_qdrant` | 1.3.0 | RAG vector store (qdrant-edge, native). |
| `flutter_gemma_rag_sqlite` | 1.3.1 | RAG vector store (`sqlite-vec`), all six platforms. |
| `flutter_gemma_builtin_ai` | 0.2.1 | OS models — Gemini Nano, Apple Foundation Models. |

**This demo deliberately uses only `litertlm` + `speech`.** One model file
(`.litertlm`) then covers Android, iOS and macOS from a single code path, and
we never pull MediaPipe's native weight in at all.

### Toolchain floor

1.0 raised the floor to **Dart 3.12 / Flutter 3.44**, because the native
libraries are now delivered through Dart's **Native Assets** build hooks
(`hook/build.dart`) rather than platform-specific setup scripts. This project
pins **Flutter 3.47.3** via FVM (`.fvmrc`), so it does not disturb your other
projects — run everything as `fvm flutter …`.

---

## 2. Gemma 4 replaced Gemma 3n as the model to reach for

| | v1 of this demo | Now |
|---|---|---|
| Model | Gemma 3n E2B | **Gemma 4 E2B** |
| Format | `.task` (MediaPipe) | `.litertlm` (LiteRT-LM) |
| Repo | `google/gemma-3n-E2B-it-litert-preview` | `litert-community/gemma-4-E2B-it-litert-lm` |
| HF token | **Required** — gated repo | **Not required** — public |
| Thinking mode | ✗ | ✓ |
| Function calling | via prompt engineering | **native tool-call tokens** |
| Desktop | ✗ (`.task` is mobile/web only) | ✓ |

I verified the access difference directly: the old URL returns **HTTP 401**,
the new one returns **HTTP 200** as an anonymous request. That is why
`flutter_dotenv`, the `.env` file and the entire "get a Hugging Face token"
setup step are gone from this project.

### Two settings that are easy to get wrong

```dart
await FlutterGemma.installModel(
  modelType: ModelType.gemma4,          // NOT gemmaIt
  fileType:  ModelFileType.litertlm,    // NOT inferred from the filename
).fromNetwork(url).install();
```

- **`ModelType.gemma4`** (new in 0.14.1) routes tool declarations through
  LiteRT-LM's own chat template, so the model emits native
  `<|tool_call>…<tool_call|>` tokens that the plugin parses for you. Leave it
  on `gemmaIt` and function calling silently falls back to Dart-side prompt
  engineering that Gemma 4 was not trained for.
- **`ModelFileType`** selects the engine and is **never** inferred from the
  file extension. It defaults to `.task`, so omitting it hands a `.litertlm`
  blob to MediaPipe, which fails with "Invalid magic number".

### `maxTokens` is not the reply length

A long-standing confusion the docs now call out explicitly:

```dart
final model = await FlutterGemma.getActiveModel(maxTokens: 4096); // CONTEXT window
final chat  = await model.openChat(maxOutputTokens: 110);         // REPLY cap
```

`maxTokens` is the KV-cache size — input + history + output combined.
`maxOutputTokens` (added in 1.0.2) is what caps generation. `.litertlm`
requires a context of at least 1024 and now clamps smaller values up
automatically instead of crashing.

---

## 3. New capability: on-device speech (1.4.0 / 1.4.1 / 1.4.2)

`flutter_gemma_speech` is entirely new since this demo was written. It gives
three things, all offline, all native-only (no web yet):

```dart
// Speech-to-text — two artefacts: the model AND its tokenizer.
await FlutterGemma.installStt()
    .modelFromNetwork(modelUrl)
    .tokenizerFromNetwork(tokenizerUrl)
    .ofType(SttModelType.whisper)     // or .moonshine, .parakeet
    .install();
final recognizer = await FlutterGemma.getActiveStt();

// Text-to-speech — one base URL, the bundle is fetched from it.
await FlutterGemma.installTts()
    .fromNetwork(baseUrl)
    .ofType(TtsModelType.matcha)      // or .inflect, .qwen3
    .install();
final synth = await FlutterGemma.getActiveTts();
```

### The voice loop

`VoiceSession` (1.4.2) chains all three models into one push-to-talk turn:

```dart
final session = VoiceSession.fromChat(
  recognizer: recognizer, chat: chat, synthesizer: synth);

await for (final event in session.runTurn(pcm16kMono)) {
  switch (event) {
    case VoiceTranscriptEvent(:final text):            // what you said
    case VoiceReplyTextEvent(:final chunk):            // streamed reply
    case VoiceReplyAudioEvent(:final pcm, :final sampleRate): // speak it
    case VoiceTurnInterruptedEvent():                  // barge-in
    case VoiceTurnCompleteEvent():
    case VoiceErrorEvent():
  }
}
```

**`VoiceSession` owns no microphone and no player.** It takes 16 kHz mono
16-bit PCM in and hands PCM back. The app supplies both ends — here,
`package:record` for capture and `just_audio` for playback, bridged by
[`lib/utils/audio_converter.dart`](lib/utils/audio_converter.dart).

Two constraints worth knowing:
- `VoiceSession.fromChat` rejects a chat that has tools unless you also pass
  `onToolCall`.
- Whisper is multilingual and its output language is a **per-call** knob —
  `getActiveStt(language: 'de')` or `transcribe(pcm, language: 'fr')`, neither
  of which reloads the model (1.8.0). Moonshine and Parakeet have no language
  token and throw `ArgumentError` instead of ignoring the value.

**What this demo ended up using**, after testing them against each other:

- **Whisper Tiny** (151 MB) for STT, not the smaller Moonshine Tiny (109 MB).
  Read Moonshine's filename: `moonshine_tiny_5s_f32.tflite`. It is a fixed
  *five second* graph, so anything longer is silently truncated and the end of
  your sentence disappears. Whisper's is 30 seconds.
- **Matcha-TTS** (94 MB), not Inflect-Nano-v2 (8 MB, ~90x real time). Inflect
  is far more tempting on paper, but its speech came out unintelligible on
  device. Qwen3-TTS is multilingual and good, but runs *slower than real time*,
  which stalls a live demo.

**And it does not use `VoiceSession` in the end.** `synthesize` is batch — full
text in, full audio out, per its own dartdoc — and `VoiceSession` emits a single
audio event at the very end of the turn. So the complete reply finishes printing
and the user then waits again, in silence, while the whole thing is synthesized.
Driving the three models directly allows cutting the reply into sentences and
synthesizing each as it completes, so audio starts after the *first* sentence.
See `lib/gemma/voice_turn.dart`.

The package also ships no voice-activity detection, so hands-free needs its own
— see `lib/gemma/voice_activity_detector.dart`. A fixed dB threshold does not
work: the level a quiet room sits at depends entirely on the microphone and its
gain.

---

## 4. Function calling got a driver loop (1.5.3)

Previously every app hand-rolled the tool loop: read the stream, spot a
`FunctionCallResponse`, run the tool, push a `Message.toolResponse`, call
generate again, repeat. `generateChatResponseWithTools` does that for you:

```dart
await for (final r in chat.generateChatResponseWithTools(
  onToolCall: (call) => runMyTool(call),   // returns Map<String, dynamic>
  maxToolTurns: 5,
  isCancelled: () => _disposed,
  onMaxToolTurns: () => showStuckWarning(),
)) { /* stream text as usual */ }
```

**flutter_gemma parses and drives; it never executes.** Tools are app actions,
so running them — and deciding what failure looks like — is yours. In this demo
[`DemoTools.execute`](lib/gemma/demo_tools.dart) never throws: it returns an
`{'error': ...}` map instead, because a thrown exception would tear down the
generation stream, whereas an error *value* goes back to the model, which can
apologise or retry.

Related additions: `ToolChoice.auto/required/none` (0.12.8),
`ParallelFunctionCallResponse` for multiple calls in one response, and
per-model parsers for Qwen/DeepSeek/Llama/Phi/FunctionGemma.

---

## 5. Everything else worth knowing

**Responses are a sealed type.** `ModelResponse` is
`TextResponse | FunctionCallResponse | ParallelFunctionCallResponse |
ThinkingResponse`. Switch on it exhaustively — a future variant then fails to
compile rather than silently vanishing.

**Thinking mode.** `openChat(isThinking: true)` makes the stream emit
`ThinkingResponse` alongside text. Supported on Gemma 4, DeepSeek R1, Qwen3,
SmolLM3 and Phi-4 Mini Reasoning — not on Web.

**Concurrent sessions (0.16.2).** `openChat()` / `openSession()` give
independent conversations over one loaded model. Weights load once (the
expensive part); each session only adds its own context. This demo uses that —
[`GemmaService`](lib/gemma/gemma_service.dart) owns one model and every screen
opens its own chat.

**Typed download errors.** `DownloadException` wraps a sealed `DownloadError`
(401/403/404/429/5xx/network/cancelled) with `toTitle()`, `toUserMessage()`,
`isRetryable` and `requiresUserAction`. No more substring-matching error text.
Note the `ModelException` family is *not* exported from the public barrel, so it
cannot be matched by type from an app — see
[`gemma_failure.dart`](lib/gemma/gemma_failure.dart).

**`stopGeneration()`** reaches the native decoder, unlike cancelling the Dart
stream. Since 1.0.1 a stopped turn no longer leaves an empty assistant message
in the history.

**Logging.** `FlutterGemma.logLevel = GemmaLogLevel.verbose` prints prompts and
generated tokens in debug builds. Release builds are always silent, so prompts
cannot leak into production logs.

**Desktop is real now (0.12.0, rewritten in 0.14.0).** macOS, Windows and Linux
run LiteRT-LM directly through `dart:ffi`. The old architecture bundled a JRE
and ran a gRPC server; engine creation went from ~10–15 s to ~2 s.

**Also shipped, not used here:** RAG with a payload-aware `Filter` DSL, text
embeddings on all platforms, agent skills (`SKILL.md`), ONNX / Transformers.js,
NPU acceleration (Qualcomm, Intel LunarLake/PantherLake), speculative decoding,
and Genkit integration.

---

## 6. Platform gotchas this project had to handle

**Android**
- `libvndksupport.so` must be declared in the manifest. Without it the OpenCL
  loader cannot `dlopen` the vendor driver, the engine falls back to WebGPU, and
  some Mali GPUs **hard-freeze** in the vision encoder (issue #324).
- `foreground: true` downloads **crash on Android 14+** unless the app declares
  `FOREGROUND_SERVICE_DATA_SYNC` *and* overrides WorkManager's
  `SystemForegroundService` with `foregroundServiceType="dataSync"`. Both are in
  our manifest.
- `.litertlm` is **arm64-only**. The build is restricted with `abiFilters` so
  the Play Store cannot offer a broken APK — and so an x86_64 emulator fails
  fast instead of dying at engine init.

**iOS**
- Floor is 15.0 as of 1.6.4 (16.0 only if you use `flutter_gemma_mediapipe`).
- `.litertlm` gets Metal GPU on device; the **Simulator is CPU-only** because
  Metal's simulator has a 256 MB single-allocation cap.
- No `post_install` block needed — that was fixed in 0.14.1.

**macOS**
- Apple Silicon only, deployment target 12.0.
- Does need a `post_install` block: three upstream Apple dylibs were linked
  without `-Wl,-headerpad_max_install_names`, so Native Assets cannot rewrite
  their install_name and the plugin stages them via an Xcode build phase
  instead (issue #247). The block is in `macos/Podfile`.
- Sandbox entitlements need JIT, library validation disabled, unsigned
  executable memory, network client, and extended virtual addressing for a
  2.4 GB model.

---

## 7. Reading list

- Package: <https://pub.dev/packages/flutter_gemma>
- Docs site: <https://fluttergemma.dev>
- Repo + CHANGELOG: <https://github.com/DenisovAV/flutter_gemma>
- Models: <https://huggingface.co/litert-community>
