# Gemma Vision Demo

On-device AI Flutter app using Google's Gemma 3n E2B multimodal model.

Built for **"No Server. No Bills. No Internet. No Problem."** — a talk at Build with AI New Delhi 2026.

## What This Does

- 💬 Text chat with streaming responses
- 🖼️ Image understanding (multimodal vision)
- ✈️ Works completely offline
- 🔒 Data never leaves the device

All powered by Google's open-source [Gemma 3n E2B](https://huggingface.co/google/gemma-3n-E2B-it-litert-preview) running locally via [flutter_gemma](https://pub.dev/packages/flutter_gemma).

## Setup

### 1. Get a Hugging Face access token

- Sign up at [huggingface.co](https://huggingface.co)
- Create a token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
- Request access to [google/gemma-3n-E2B-it-litert-preview](https://huggingface.co/google/gemma-3n-E2B-it-litert-preview)

### 2. Add your token

Create a `.env` file in the project root:
```
HUGGINGFACE_TOKEN=hf_your_token_here
```

This file is gitignored by default.

### 3. Install dependencies

```bash
flutter pub get
```

For iOS:

```bash
cd ios
pod install --repo-update
cd ..
```

### 4. Run

```bash
flutter run
```
Select your Android or iOS device. The first launch will download the ~3GB model — this is a one-time download that persists on the device.

## Screenshots

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/79e1dd38-cef2-4f2b-bc2c-eaa872ed5f2c" width="200"/></td>
    <td><img src="https://github.com/user-attachments/assets/0fb32580-e8e8-4b96-893a-9ef7dc79ed98" width="200"/></td>
    <td><img src="https://github.com/user-attachments/assets/91928737-51aa-4459-8f14-adde546a8c9c" width="200"/></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/5d6d755d-add9-4294-954c-70b31d28464e" width="200"/></td>
    <td><img src="https://github.com/user-attachments/assets/2d223caa-36de-48aa-9145-507881015ec5" width="200"/></td>
    <td><img src="https://github.com/user-attachments/assets/bde31f20-730a-4307-9035-419c9658ef43" width="200"/></td>
  </tr>
</table>

## Requirements

- **Flutter:** 3.24+ (tested on 3.38.10)
- **Android:** minSdk 26+, 6GB+ RAM recommended (8GB+ for live camera)
- **iOS:** 16.0+, tested with free Apple ID signing
- **First-time model download:** ~3 GB (one-time, over Wi-Fi)

## Project Structure

```
lib/
├── main.dart                          # App entry, dotenv + FlutterGemma init
└── screens/
    ├── home_screen.dart               # Landing screen with branding
    ├── model_download_screen.dart     # Model download UI with progress
    └── chat_screen.dart               # Multimodal chat with streaming
```

## Architecture Notes

- **Model:** Gemma 3n E2B, int4 quantized, MediaPipe `.task` format
- **Backend:** GPU acceleration via MediaPipe GenAI
- **Inference:** Streaming via `generateChatResponseAsync`
- **State:** Simple StatefulWidgets, no state management library needed for a demo

## Memory Tradeoffs

On 6GB RAM devices (like Redmi Note 7 Pro), launching the native camera app can cause Android to kill the Flutter app to free memory for the camera — because Gemma 3n E2B already occupies ~3GB of RAM.

- **Workaround in this demo:** use gallery picker instead of camera.
- **Production recommendation:** either use an in-app camera via the `camera` package, target 8GB+ RAM devices, or use a smaller model.

This is a real constraint of on-device AI that cloud-based AI doesn't have.

## Key Dependencies

- [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) — Core on-device inference
- [`flutter_dotenv`](https://pub.dev/packages/flutter_dotenv) — Token management
- [`image_picker`](https://pub.dev/packages/image_picker) — Gallery/camera access
- [`path_provider`](https://pub.dev/packages/path_provider) — Model file paths

## About the Talk

This demo was built for a talk at Build with AI New Delhi 2026, covering:

- What on-device AI is and why it matters
- Gemma vs Gemini — the two model families
- Parameters, tokens, context windows, quantization explained
- Mixture of Experts vs Dense model architectures
- Real tradeoffs — memory, battery, model update lifecycle
- Building and shipping on-device AI features in Flutter

## Credits

- [flutter_gemma](https://github.com/DenisovAV/flutter_gemma) by Sasha Denisov
- [Gemma](https://ai.google.dev/gemma) by Google DeepMind
- [MediaPipe](https://developers.google.com/mediapipe) for on-device inference

## Author

**Akansha Jain** — Senior Software Engineer, Google Women Techmakers Ambassador, Co-organizer of Flutter Conf India and Flutter Delhi.
