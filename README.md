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
HUGGINGFACE_TOKEN=hf_your_token_here

### 3. Install dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

### 4. Run

```bash
flutter run
```

## Requirements

- **Android:** minSdk 26+, 6GB+ RAM recommended (8GB+ for live camera)
- **iOS:** 16.0+, tested with free Apple ID signing
- **First-time model download:** ~3 GB (one-time, over Wi-Fi)

## Architecture Notes

- **Model:** Gemma 3n E2B, int4 quantized, MediaPipe `.task` format
- **Backend:** GPU acceleration via MediaPipe GenAI
- **Memory tradeoff:** On 6GB RAM devices, camera capture may be killed by Android's memory manager. Gallery picker is more reliable. Consider 8GB+ RAM for production deployments.

## License

MIT — see LICENSE file.

## Credits

- [flutter_gemma](https://github.com/DenisovAV/flutter_gemma) by Sasha Denisov
- [Gemma](https://ai.google.dev/gemma) by Google DeepMind