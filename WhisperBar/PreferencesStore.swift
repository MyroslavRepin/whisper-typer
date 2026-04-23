import Foundation

/// Central access point for all persisted user preferences.
/// Non-SwiftUI code uses this; SwiftUI views may use @AppStorage directly
/// (same UserDefaults keys keep them in sync).
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard

    private init() {
        // Register fallback defaults for all keys so that computed properties
        // always return sensible values even before the user opens Settings.
        defaults.register(defaults: [
            Keys.selectedModel:       "base",
            Keys.whisperBinaryPath:   "/usr/local/bin/whisper-cpp",
            Keys.modelsFolderPath:    (NSHomeDirectory() as NSString)
                                        .appendingPathComponent(".whisper/models"),
            Keys.hotkeyKeyCode:       PreferencesStore.defaultHotkeyKeyCode,
            Keys.hotkeyModifierFlags: PreferencesStore.defaultHotkeyModifierFlags
        ])
    }

    // MARK: - Model

    var selectedModel: String {
        get { defaults.string(forKey: Keys.selectedModel) ?? "base" }
        set { defaults.set(newValue, forKey: Keys.selectedModel) }
    }

    let availableModels: [String] = ["tiny", "base", "small", "medium", "large"]

    func modelFilePath(for modelName: String) -> String {
        URL(fileURLWithPath: modelsFolderPath)
            .appendingPathComponent("ggml-\(modelName).bin")
            .path
    }

    // MARK: - Paths

    var whisperBinaryPath: String {
        get { defaults.string(forKey: Keys.whisperBinaryPath) ?? "/usr/local/bin/whisper-cpp" }
        set { defaults.set(newValue, forKey: Keys.whisperBinaryPath) }
    }

    var modelsFolderPath: String {
        get {
            defaults.string(forKey: Keys.modelsFolderPath)
                ?? (NSHomeDirectory() as NSString).appendingPathComponent(".whisper/models")
        }
        set { defaults.set(newValue, forKey: Keys.modelsFolderPath) }
    }

    // MARK: - Hotkey
    // keyCode: virtual key code (CGKeyCode); modifierFlags: NSEvent.ModifierFlags rawValue
    // (masked to command / shift / control / option bits only).

    var hotkeyKeyCode: Int {
        get { defaults.integer(forKey: Keys.hotkeyKeyCode) }
        set { defaults.set(newValue, forKey: Keys.hotkeyKeyCode) }
    }

    var hotkeyModifierFlags: Int {
        get { defaults.integer(forKey: Keys.hotkeyModifierFlags) }
        set { defaults.set(newValue, forKey: Keys.hotkeyModifierFlags) }
    }

    // MARK: - Keys

    enum Keys {
        static let selectedModel       = "selectedModel"
        static let whisperBinaryPath   = "whisperBinaryPath"
        static let modelsFolderPath    = "modelsFolderPath"
        static let hotkeyKeyCode       = "hotkeyKeyCode"
        static let hotkeyModifierFlags = "hotkeyModifierFlags"
    }

    // MARK: - Defaults (exposed so SwiftUI @AppStorage can reuse them)

    /// Default hotkey: Space bar
    static let defaultHotkeyKeyCode: Int = 49
    /// Default modifier: Option key (⌥). Equals NSEvent.ModifierFlags.option.rawValue == 524_288.
    static let defaultHotkeyModifierFlags: Int = 524_288
}
