<div align="center">
  <img src="public/icon.png" alt="Dicta" width="100" height="100">

# Dicta

Voice-to-text for macOS. Press a shortcut, speak, and your words appear as text.

[![CI](https://github.com/nitintf/dicta/actions/workflows/ci.yml/badge.svg)](https://github.com/nitintf/dicta/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/nitintf/dicta?label=release)](https://github.com/nitintf/dicta/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/nitintf/dicta/total)](https://github.com/nitintf/dicta/releases)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/github/license/nitintf/dicta)](LICENSE)

</div>

---

## What is Dicta?

Dicta is a native macOS app that transcribes your voice to text. It sits in your menu bar, ready to capture your thoughts with a global keyboard shortcut. The transcribed text is automatically copied to your clipboard or pasted directly into the active application.

**Key highlights:**

- Spotlight-style floating window with real-time waveform
- Multiple transcription engines (cloud and local)
- Text formatting with customizable "vibes" (professional, casual, email styles)
- Full transcription history with search and filtering
- Privacy-focused local processing option

## Installation

### Download

Get the latest release from the [Releases page](https://github.com/nitintf/dicta/releases).

1. Download the `.dmg` file
2. Drag Dicta to your Applications folder
3. If macOS shows a security warning, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Dicta.app
   ```
4. Launch Dicta and grant microphone access when prompted

### Build from source

```bash
git clone https://github.com/nitintf/dicta.git
cd dicta
pnpm install
pnpm tauri build
```

The app bundle will be in `src-tauri/target/release/bundle/macos/`.

## Usage

1. Press `Option + Space` (configurable) to open the voice input window
2. Speak your text
3. Release the shortcut or press it again to stop
4. Text is transcribed and copied to clipboard (or pasted directly)

### Transcription Providers

| Provider | Type | Notes |
|----------|------|-------|
| OpenAI Whisper | Cloud | High accuracy, requires API key |
| Google Speech-to-Text | Cloud | Fast, requires API key |
| AssemblyAI | Cloud | Advanced features, requires API key |
| ElevenLabs | Cloud | High quality, requires API key |
| Local Whisper | Local | Privacy-focused, runs on your Mac |
| Apple Speech | Local | Built-in, no setup required |

### Text Styles (Vibes)

Transform your transcriptions with AI-powered formatting:

- **Professional** — Clean, formal language for work
- **Casual** — Relaxed, conversational tone
- **Email** — Properly formatted email text
- **Custom** — Create your own formatting rules

## Development

### Requirements

- Node.js 20.19+ or 22.12+
- pnpm 8+
- Rust 1.75+
- Xcode Command Line Tools

### Setup

```bash
pnpm install
pnpm tauri dev
```

### Commands

```bash
pnpm tauri dev       # Development mode with hot reload
pnpm tauri build     # Production build
pnpm lint:fix        # Fix linting issues
pnpm format:all      # Format TypeScript and Rust code
```

## Tech Stack

**Frontend:** React 19, TypeScript, Tailwind CSS 4, Radix UI, Zustand

**Backend:** Tauri 2.5, Rust, macOS native APIs (NSPanel, Speech Recognition)

**AI:** OpenAI, Google Cloud, AssemblyAI, ElevenLabs, Local Whisper (whisper.cpp)

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run `pnpm lint:fix && pnpm format:all && pnpm build`
5. Commit with a descriptive message
6. Open a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.
