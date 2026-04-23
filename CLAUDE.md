# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhisperBar is a native macOS menu bar application for voice-to-text transcription using OpenAI's Whisper model. It runs as an accessory app (menu bar only, no dock icon) and uses global hotkeys to trigger recording, transcription, and automatic text injection.

## Build and Development Commands

### Building the Application

```bash
# Open in Xcode
open WhisperBar.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project WhisperBar.xcodeproj -scheme WhisperBar -configuration Release build

# Build location
# ~/Library/Developer/Xcode/DerivedData/WhisperBar-*/Build/Products/Release/WhisperBar.app
```

### Testing the App

The app requires:
1. whisper-cpp binary at `/usr/local/bin/whisper-cpp` (or custom path)
2. At least one Whisper model file in `~/.whisper/models/` (or custom path)
3. Microphone and Accessibility permissions granted

See README.md for full setup instructions.

## Architecture Overview

### Core Design Patterns

**Singleton Pattern**: All major services use static `shared` instances (AudioRecorder, WhisperBridge, TextInjector, OverlayWindowController, PreferencesStore).

**AppKit Delegate Pattern**: AppDelegate manages app lifecycle and permission prompts. SettingsWindowController uses NSWindowDelegate to trigger hotkey reload on close.

**Callback-based Async**: Uses completion handlers for async operations (recording, transcription). Threading managed via DispatchQueues.

**SwiftUI + AppKit Bridge**: Settings UI uses SwiftUI with NSViewRepresentable for custom hotkey recorder.

### Application Flow

```
User presses hotkey (default: Option+Space)
  ↓
HotkeyManager (CGEventTap) detects keyDown
  ↓
AudioRecorder starts AVAudioEngine with input tap
  ↓
OverlayWindow shows floating waveform panel
  ↓
User speaks → AudioRecorder accumulates audio buffers
  ↓
User releases hotkey → HotkeyManager detects keyUp
  ↓
AudioRecorder converts Float32 samples to PCM-16 WAV file
  ↓
WhisperBridge spawns whisper-cpp process with model
  ↓
Parses output.txt sidecar or stdout for transcription
  ↓
TextInjector:
  - Snapshots current pasteboard
  - Sets pasteboard to transcribed text
  - Simulates Cmd+V via CGEvent
  - Restores original pasteboard after 100ms
  ↓
Text appears in user's focused application
```

### Component Responsibilities

| Component | File | Responsibility |
|-----------|------|---------------|
| **AppDelegate** | AppDelegate.swift | App lifecycle, permission checks (Accessibility + Microphone) |
| **HotkeyManager** | HotkeyManager.swift | Global hotkey via CGEventTap, triggers recording start/stop |
| **AudioRecorder** | AudioRecorder.swift | Microphone capture via AVAudioEngine, WAV encoding, RMS broadcasts |
| **WhisperBridge** | WhisperBridge.swift | Process spawning for whisper-cpp, output parsing, model validation |
| **TextInjector** | TextInjector.swift | Clipboard manipulation + Cmd+V simulation via CGEvent |
| **StatusBarController** | StatusBarController.swift | Menu bar icon, model selection menu, settings access |
| **OverlayWindow** | OverlayWindow.swift | Floating NSPanel with waveform visualization during recording |
| **PreferencesStore** | PreferencesStore.swift | Centralized UserDefaults access for all settings |
| **SettingsView** | SettingsView.swift | SwiftUI settings interface (paths, hotkey, model folder) |
| **HotkeyRecorderView** | HotkeyRecorderView.swift | NSViewRepresentable for capturing custom hotkey combos |
| **WaveformView** | WaveformView.swift | SwiftUI waveform bars animated by RMS updates |

### State Management

**PreferencesStore (Singleton)**:
- Centralized access to UserDefaults with typed properties
- Keys defined in `PreferencesStore.Keys` enum
- SwiftUI uses `@AppStorage` with same keys (auto-synced)
- Non-SwiftUI code accesses via `PreferencesStore.shared`

**Settings:**
- `selectedModel`: String ("tiny", "base", "small", "medium", "large")
- `whisperBinaryPath`: String (default: "/usr/local/bin/whisper-cpp")
- `modelsFolderPath`: String (default: "~/.whisper/models")
- `hotkeyKeyCode`: Int (virtual key code, default: 49 = Space)
- `hotkeyModifierFlags`: Int (NSEvent.ModifierFlags rawValue, default: 524288 = Option)

**HotkeyManager Reload**:
When settings change, `HotkeyManager.reload()` must be called to re-register the CGEventTap with new hotkey. This is triggered automatically when SettingsWindow closes (via NSWindowDelegate callback).

### Threading Model

- **Main thread**: UI updates, hotkey callbacks, CGEventTap processing
- **User-initiated queue**: Audio recording/processing (AudioRecorder)
- **Custom serial queue**: Transcription (`com.whisperbar.transcription` in WhisperBridge)
- **CFRunLoop (implicit)**: CGEventTap runs on current run loop

### Audio Processing Details

**AudioRecorder Format**:
- Target: 16kHz mono PCM Float32 (whisper-cpp requirement)
- AVAudioEngine input tap processes buffers in real-time
- RMS calculation broadcasts to OverlayWindow for waveform animation
- On stop: converts accumulated Float32 samples to PCM-16 WAV

**WAV Encoding**:
- Manual WAV header construction (not AVAudioFile)
- Direct Float32 → Int16 conversion with clamping
- Output to `/tmp/whisperbar_[timestamp].wav`

### Text Injection Strategy

**Why clipboard + Cmd+V instead of AXUIElement.setValue?**
- More universal (works with more applications)
- Keyboard-layout independent
- Simpler than Accessibility API attribute manipulation

**Pasteboard Preservation**:
1. Snapshot current pasteboard items (all types)
2. Clear and set new text
3. Simulate Cmd+V (virtual key code 0x09, command modifier)
4. Restore original pasteboard after 100ms delay

**AX Verification** (best-effort):
- Checks if focused element has AXValue attribute
- Non-blocking (still pastes even if verification fails)
- Prevents false negatives for apps with non-standard AX implementations

### Error Handling

**Model File Missing**:
- WhisperBridge checks `FileManager.fileExists` before spawning process
- Shows NSAlert with options: Download from HuggingFace, Open Settings, Cancel

**Binary Missing**:
- WhisperBridge prints to console, returns nil completion (silent failure)

**Permission Denied**:
- AppDelegate checks on launch, shows alerts with deep links to System Settings

**Process Failures**:
- WhisperBridge catches Process launch errors, returns nil completion

### Key Constants and Defaults

**Audio**:
- `AudioRecorder.targetSampleRate = 16_000.0` (Hz)
- `AudioRecorder.targetFormat = Float32, mono, 16kHz`

**Hotkey**:
- Default key code: 49 (Space bar)
- Default modifiers: 524288 (Option key = NSEvent.ModifierFlags.option.rawValue)
- Relevant modifiers mask: Command, Shift, Control, Option

**Paths**:
- Default binary: `/usr/local/bin/whisper-cpp`
- Default models: `~/.whisper/models/`
- Model naming: `ggml-{modelName}.bin` (e.g., `ggml-base.bin`)
- Temp audio: `/tmp/whisperbar_*.wav`

**Overlay**:
- Panel size: 280×90 points
- Position: 20pt above dock, horizontally centered
- Collection behavior: canJoinAllSpaces, stationary, ignoresCycle

### Permission Requirements

**Accessibility** (required for):
- CGEventTap (global hotkey detection)
- AXUIElement verification (TextInjector)
- Checked via `AXIsProcessTrusted()`

**Microphone** (required for):
- AVAudioEngine input node
- Checked via `AVCaptureDevice.requestAccess(for: .audio)`

**No Sandbox**:
- App runs without sandbox (entitlements: `com.apple.security.app-sandbox = false`)
- Reasons: CGEventTap needs system-wide access, Process spawning, cross-app AX

### Info.plist Configuration

```xml
LSUIElement: true  <!-- Menu bar only, no dock icon -->
NSMicrophoneUsageDescription: "WhisperBar records your voice..."
NSAppleEventsUsageDescription: "WhisperBar uses Accessibility..."
```

### whisper-cpp Integration

**Process Invocation**:
```swift
process.arguments = [
    "--model",        modelPath,
    "--language",     "auto",
    "--output-txt",              // Generates .txt sidecar
    "--no-timestamps",
    audioURL.path
]
```

**Output Parsing**:
1. First try reading `.txt` sidecar (same name as audio file)
2. Fallback to stdout if sidecar not found
3. Clean output: filter lines starting with `whisper_`, `ggml_`, `main:`, `[`, etc.
4. Join remaining lines with spaces

**Model File Resolution**:
```swift
// PreferencesStore.modelFilePath(for: "base")
// Returns: "{modelsFolderPath}/ggml-base.bin"
```

### SwiftUI + AppKit Interop

**Settings Window**:
- SettingsView (SwiftUI) hosted in NSHostingController
- SettingsWindowController manages NSWindow lifecycle
- Window delegate triggers `HotkeyManager.reload()` on close

**HotkeyRecorderView**:
- NSViewRepresentable wrapping custom NSView
- Captures keyDown events with modifiers
- Callback: `onRecorded(keyCode: Int, modifierFlags: Int)`

**RecordingPillView** (in OverlayWindow):
- Pure SwiftUI view with WaveformView child
- Uses `@Published` subscription to AudioRecorder.onRMSUpdate
- Animates waveform bars in real-time

### Code Style Notes

From commit 875843b ("Polish: named constants, modifier docs, literal ellipsis, key code explanation"):
- Use named constants instead of magic numbers
- Add explanatory comments for virtual key codes and modifier flags
- Use literal `…` (ellipsis character) in UI strings, not "..."
- Document complex bitwise operations (modifier masks, CGEventFlags)

### Development Workflow

**Making Changes**:
1. Edit Swift files in Xcode or external editor
2. Build with Cmd+R or xcodebuild
3. Test with proper permissions granted
4. Ensure whisper-cpp and models are available

**Hotkey Changes**:
- Edit HotkeyManager to change detection logic
- PreferencesStore defaults change requires updating both `register(defaults:)` and static constants
- SettingsWindowController.windowWillClose triggers reload

**Audio Changes**:
- AudioRecorder owns AVAudioEngine lifecycle
- Format changes require updating both targetFormat and WAV encoding
- RMS callback frequency affects waveform smoothness

**UI Changes**:
- SwiftUI changes in SettingsView/WaveformView/RecordingPillView
- AppKit changes in OverlayWindow/StatusBarController
- Use NSViewRepresentable for custom AppKit controls in SwiftUI
