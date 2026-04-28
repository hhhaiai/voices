# voices_app

Flutter speech-to-text app with multiple local engines:

- `whisper` on Android via `whisper.cpp`
- `vosk` on Android via native Vosk
- `sensevoice_onnx` via `sherpa_onnx`
- `apple_speech` on iOS/macOS for file transcription

## Model Bundle Profiles

The Flutter asset bundle can be switched before build:

```bash
dart run tool/set_model_bundle_profile.dart --list
dart run tool/set_model_bundle_profile.dart local-all
dart run tool/set_model_bundle_profile.dart release-whisper
dart run tool/set_model_bundle_profile.dart release-whisper-sensevoice
flutter pub get
```

Profiles:

- `local-all`: bundle all currently supported built-in STT models
- `release-whisper`: only bundle `Whisper tiny` (`ggml-tiny.bin`)
- `release-whisper-sensevoice`: bundle `Whisper tiny` plus `SenseVoice`

## Verification

```bash
flutter analyze
flutter test
```
