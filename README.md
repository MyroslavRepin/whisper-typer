# WhisperBar

A native macOS menu bar app that transcribes your voice to text using OpenAI's Whisper model. Press a hotkey, speak, and WhisperBar will automatically type your transcribed speech into any application.

## Features

- **Global hotkey activation** - Press and hold Option+Space (customizable) to record
- **Automatic transcription** - Uses OpenAI's Whisper for accurate speech-to-text
- **Text injection** - Automatically types the transcribed text into your active application
- **Multiple model sizes** - Choose from tiny, base, small, medium, or large models
- **Menu bar interface** - Lightweight, always available from your menu bar
- **Visual feedback** - Waveform overlay shows recording status

## Prerequisites

Before installing WhisperBar, you need to install whisper.cpp and download at least one Whisper model.

### 1. Install whisper.cpp

```bash
# Clone the whisper.cpp repository
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build the binary
make

# Install the binary to /usr/local/bin
sudo cp main /usr/local/bin/whisper-cpp
```

### 2. Download Whisper Models

```bash
# Create models directory
mkdir -p ~/.whisper/models

# Download a model (choose one or more)
# Tiny (fastest, least accurate) - ~75 MB
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin" -o ~/.whisper/models/ggml-tiny.bin

# Base (recommended for most users) - ~140 MB
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" -o ~/.whisper/models/ggml-base.bin

# Small (better accuracy) - ~460 MB
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" -o ~/.whisper/models/ggml-small.bin

# Medium (high accuracy) - ~1.5 GB
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" -o ~/.whisper/models/ggml-medium.bin

# Large (best accuracy) - ~2.9 GB
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin" -o ~/.whisper/models/ggml-large.bin
```

## Installation

### Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/whisper-typer.git
   cd whisper-typer
   ```

2. **Open the Xcode project**
   ```bash
   open WhisperBar.xcodeproj
   ```

3. **Build and run**
   - In Xcode, select your Mac as the target
   - Press `Cmd+R` to build and run
   - Or use `Cmd+B` to build, then find the app in `build/Release/WhisperBar.app`

4. **Optional: Move to Applications**
   ```bash
   # After building in Xcode
   cp -r ~/Library/Developer/Xcode/DerivedData/WhisperBar-*/Build/Products/Release/WhisperBar.app /Applications/
   ```

## First Launch Setup

When you first launch WhisperBar, you'll need to grant permissions:

### 1. Microphone Permission
- WhisperBar will prompt you to allow microphone access
- Grant access in: **System Settings → Privacy & Security → Microphone**
- Check the box next to WhisperBar

### 2. Accessibility Permission
- WhisperBar needs this to type text into other applications
- Grant access in: **System Settings → Privacy & Security → Accessibility**
- Check the box next to WhisperBar

## Usage

1. **Launch WhisperBar**
   - The app will appear in your menu bar with a microphone icon

2. **Start recording**
   - Press and hold **Option+Space** (⌥ Space)
   - A waveform overlay will appear showing your audio input

3. **Speak your text**
   - While holding the hotkey, speak clearly into your microphone

4. **Release to transcribe**
   - Release the hotkey when you're done speaking
   - WhisperBar will transcribe your audio and type the text automatically

## Configuration

Click the microphone icon in your menu bar to access settings:

### Model Selection
- Choose between tiny, base, small, medium, or large models
- Smaller models are faster but less accurate
- Larger models are more accurate but slower

### Settings Window
- **Whisper Binary Path**: Path to your whisper-cpp executable (default: `/usr/local/bin/whisper-cpp`)
- **Models Folder**: Location of your Whisper model files (default: `~/.whisper/models`)
- **Hotkey**: Customize your recording hotkey (default: Option+Space)

## Troubleshooting

### App doesn't respond to hotkey
- Check Accessibility permissions in System Settings
- Try restarting the app

### No transcription or errors
- Verify whisper-cpp is installed: `which whisper-cpp`
- Check that model files exist in `~/.whisper/models/`
- Try the Settings window to verify paths

### Poor transcription quality
- Use a better quality microphone
- Speak clearly and at a moderate pace
- Try a larger model (small or medium)
- Reduce background noise

### App can't type text
- Ensure Accessibility permission is granted
- Some applications may block programmatic text input

## Default Paths

- **Whisper binary**: `/usr/local/bin/whisper-cpp`
- **Models folder**: `~/.whisper/models/`
- **Model files**: `~/.whisper/models/ggml-{model-name}.bin`

## Requirements

- macOS 11.0 or later
- Microphone access
- Accessibility access
- whisper.cpp binary
- At least one Whisper model file

## License

MIT License - feel free to use and modify as needed.

## Credits

- Built with Swift and SwiftUI
- Uses [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- Based on OpenAI's [Whisper](https://github.com/openai/whisper) model
