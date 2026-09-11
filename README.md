# Gemma On-Device Demo

A Flutter app that runs Google's Gemma 4 E2B locally — vision, reasoning,
function calling and a voice loop, with no server involved. The network is used
once, to download the model. After that you can put the device in airplane mode
and everything still works.

Built on [flutter_gemma](https://pub.dev/packages/flutter_gemma) 1.8.

## What's in it

**Vision chat** — attach a photo and ask about it. Streaming, multimodal.

**Thinking mode** — the same model with `isThinking: true`, so the reasoning
arrives on a separate channel from the answer and renders in its own collapsible
block.

**Function calling** — six tools that act on live app state. Ask it to add a
task and then read your list back, and it chains two calls in one turn.

**Voice loop** — speak, and it transcribes, answers, and speaks back. Three
models on device, in push-to-talk or hands-free.

## Running it

The project pins Flutter 3.47.3 with [FVM](https://fvm.app), so it won't
disturb your other projects. flutter_gemma 1.x needs Dart 3.12 / Flutter 3.44 or
newer.

```bash
dart pub global activate fvm   # if you don't have it
fvm install                    # reads .fvmrc
fvm flutter pub get
fvm flutter run -d macos       # or a connected phone
```

Use `fvm flutter`, not `flutter` — an older SDK on your PATH will refuse the
dependencies.

There's no Hugging Face token to set up. Every model here lives in a public
repo.

## Models

| | Model | Size |
|---|---|---|
| LLM | Gemma 4 E2B (`.litertlm`) | 2.4 GB |
| Speech-to-text | Whisper Tiny (30s window) | 151 MB |
| Text-to-speech | Matcha-TTS | 94 MB |

The LLM downloads on first use and is shared by all four demos. The speech
models only download if you open the voice demo.

A few notes on why these specific builds:

- `.litertlm` rather than `.task` — one file covers Android, iOS and macOS
  through the same FFI engine, so the app never needs `flutter_gemma_mediapipe`
  at all. `.task` is MediaPipe-only and can't load on desktop.
- Whisper Tiny over the smaller Moonshine Tiny, because Moonshine's shipped
  graph is a fixed **five second** window. Anything longer is silently
  truncated, which makes a conversational turn impossible.
- Matcha over Inflect-Nano-v2. Inflect is 8 MB and roughly 90x real time, which
  is tempting, but its output was unintelligible in testing.

## Requirements

**Android** — arm64 device, API 26+, ~3 GB free RAM. x86_64 emulators won't
work: the LiteRT-LM engine ships arm64 prebuilts only, and the build is
restricted with `abiFilters` so you find out at build time instead of at engine
init.

**iOS** — 15.0+, arm64 device. The Simulator runs CPU-only, because Metal's
simulator caps single allocations at 256 MB and the model's tensors exceed
that.

**macOS** — Apple Silicon, 12.0+. Metal GPU, engine starts in about two
seconds. This is the easiest target to develop against.

Web isn't supported here. `.litertlm` on web is a text-only preview, so vision
would need a separate MediaPipe build and a second engine.

## Layout

```
lib/
├── main.dart                 FlutterGemma.initialize — engine registration
├── theme.dart                design tokens and shared widgets
├── gemma/
│   ├── model_catalog.dart    every model URL and setting, in one place
│   ├── gemma_service.dart    loads the weights once, hands out chats
│   ├── demo_tools.dart       tool declarations and their implementations
│   ├── gemma_failure.dart    exceptions → something a user can act on
│   ├── model_text.dart       strips protocol noise from the text channel
│   ├── sentence_chunker.dart splits a streaming reply into speakable units
│   ├── voice_activity_detector.dart  when speech starts and stops
│   └── voice_turn.dart       transcribe → generate → speak, overlapped
├── screens/                  home, download gate, chat, tools, voice
├── widgets/                  bubbles, composer, state views, voice controls
└── utils/audio_converter.dart  WAV ⇄ PCM
```

## Things worth knowing if you're reading the code

**The model loads once.** `GemmaService` owns the single `InferenceModel` and
each screen calls `openChat()` for its own conversation on top. Weights are the
expensive part; a session is just its own context. Screens close their chat on
dispose and never close the model.

**Except for vision.** On the `.litertlm` engine, concurrent sessions replay
their history as text when the engine switches between them, so they reject
images outright. Multimodal has to go through `createChat()`, which owns the
model's primary session. `GemmaService.openChat` branches on that. It's safe
here because the app is a navigation stack — only one screen holds a chat at a
time.

**Two settings that are easy to get wrong.** `ModelType.gemma4`, not
`gemmaIt` — it routes tool declarations through Gemma 4's native chat template.
And `ModelFileType.litertlm` explicitly, because the file type selects the
engine and is never inferred from the filename; it defaults to `.task`, which
fails on a `.litertlm` file with "Invalid magic number".

**Don't trust the text channel.** Gemma 4 sends tool calls and reasoning
through the same stream as the answer. flutter_gemma strips the markers, but it
classifies a turn by its first character — so a turn that starts with text and
then emits a tool-call JSON leaks the whole thing. `ModelText.sanitize` cleans
the accumulated buffer (not individual tokens; a marker can span two).

**Tools never throw.** `DemoTools.execute` returns an `{'error': ...}` map
instead. A thrown exception tears down the generation stream, whereas an error
*value* goes back to the model, which can correct itself.

**The voice loop doesn't use `VoiceSession`.** The package ships one, and it's
the right starting point, but `synthesize` is batch — full text in, full audio
out — so it can't speak until generation finishes. That's several seconds of
dead air with the finished reply already on screen. `VoiceTurn` drives the
three models directly, cutting the reply into sentences and synthesizing each
as it completes, so audio starts after the first sentence. Synthesis of
sentence N+1 overlaps playback of N.

**Voice activity detection is ours.** The package ships none. A fixed dB
threshold doesn't work, because the level a quiet room sits at depends entirely
on the microphone and its gain. `VoiceActivityDetector` learns the room's noise
floor as a low percentile of a rolling window — deliberately not an average,
which climbs while you're speaking and drags the trigger up with it.

**Sampling is narrower than Google's defaults.** They publish temperature 1.0 /
topK 64 / topP 0.95 for Gemma 4. On a 2B multilingual model that width causes
code switching: the vocabulary holds the same concept in many languages, and a
non-English token can outrank the English one mid-sentence. 0.7 / 40 / 0.9 plus
a language instruction makes it rare. The cost is slightly less varied phrasing.

## Tests

```bash
fvm flutter test
```

100 tests. They cover the parts where being wrong is invisible until someone
notices at the worst moment: the tool executor's contract that it never throws
whatever the model sends it, WAV/PCM conversion including malformed input, the
sentence splitter's refusal to break on `3.14` or `Dr. Bhatt`, the text
sanitizer against real leaked output, voice activity detection across quiet and
noisy rooms, and the voice pipeline end to end with fake models — where every
test asserts the stream actually terminates, because a controller that never
closes looks exactly like a slow model.

## Platform setup that isn't obvious

**Android** needs `libvndksupport.so` declared in the manifest. Without it the
OpenCL loader can't open the vendor driver, the engine falls back to WebGPU,
and some Mali GPUs hard-freeze in the vision encoder.

**Android 14+** crashes on `foreground: true` downloads unless the app declares
`FOREGROUND_SERVICE_DATA_SYNC` and overrides WorkManager's
`SystemForegroundService` with `foregroundServiceType="dataSync"`. Both are in
the manifest.

**macOS** needs the `post_install` block in `macos/Podfile`. Three upstream
Apple dylibs were linked without `-Wl,-headerpad_max_install_names`, so Native
Assets can't rewrite their install names and the plugin stages them through an
Xcode build phase instead. The sandbox entitlements also need JIT, library
validation disabled and unsigned executable memory.

The iOS-only `com.apple.developer.kernel.*` entitlements are deliberately
absent from the macOS build — they do nothing there and force Xcode to demand a
development signing certificate.

## Credits

[flutter_gemma](https://github.com/DenisovAV/flutter_gemma) by Sasha Denisov.
[Gemma](https://ai.google.dev/gemma) by Google DeepMind. Model builds from
[litert-community](https://huggingface.co/litert-community).

## License

MIT
