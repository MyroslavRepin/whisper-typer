import SwiftUI
import Cocoa

// MARK: - SettingsWindowController

/// Opens a single persistent settings window (creates on first call).
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private init() {
        let view = SettingsView()
        let hvc  = NSHostingController(rootView: view)
        let win  = NSWindow(contentViewController: hvc)
        win.title     = "WhisperBar Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        super.init(window: win)
        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Reload hotkey when settings window closes
        (NSApp.delegate as? AppDelegate)?.hotkeyManager?.reload()
    }
}

// MARK: - SettingsView

struct SettingsView: View {

    // Mirror PreferencesStore keys so @AppStorage updates stay in sync
    @AppStorage(PreferencesStore.Keys.selectedModel)
    private var selectedModel: String = "base"

    @AppStorage(PreferencesStore.Keys.whisperBinaryPath)
    private var whisperBinaryPath: String = "/usr/local/bin/whisper-cpp"

    @AppStorage(PreferencesStore.Keys.modelsFolderPath)
    private var modelsFolderPath: String =
        (NSHomeDirectory() as NSString).appendingPathComponent(".whisper/models")

    @AppStorage(PreferencesStore.Keys.hotkeyKeyCode)
    private var hotkeyKeyCode: Int = PreferencesStore.defaultHotkeyKeyCode

    @AppStorage(PreferencesStore.Keys.hotkeyModifierFlags)
    private var hotkeyModifierFlags: Int = PreferencesStore.defaultHotkeyModifierFlags

    private let availableModels = ["tiny", "base", "small", "medium", "large"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Title bar area ─────────────────────────────────────────
            Text("WhisperBar Settings")
                .font(.title3.weight(.semibold))
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)

            Divider()

            // ── Form ───────────────────────────────────────────────────
            Form {
                Section {
                    LabeledContent("Hotkey") {
                        HotkeyRecorderView(
                            keyCode: $hotkeyKeyCode,
                            modifierFlags: $hotkeyModifierFlags
                        )
                        .frame(height: 30)
                    }
                } header: {
                    Text("Recording").font(.headline).padding(.bottom, 4)
                }

                Divider().padding(.vertical, 4)

                Section {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { m in
                            Text(m.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Whisper").font(.headline).padding(.bottom, 4)
                }

                LabeledContent("Binary path") {
                    HStack {
                        TextField("/usr/local/bin/whisper-cpp", text: $whisperBinaryPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") { browseBinary() }
                    }
                }

                LabeledContent("Models folder") {
                    HStack {
                        TextField("~/.whisper/models", text: $modelsFolderPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") { browseModelsFolder() }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // ── Footer ─────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Done") {
                    SettingsWindowController.shared.window?.close()
                }
                .keyboardShortcut(.defaultAction)
                .padding([.bottom, .trailing], 16)
                .padding(.top, 12)
            }
        }
        .frame(width: 460, height: 380)
    }

    // MARK: - Browse helpers

    private func browseBinary() {
        let panel = NSOpenPanel()
        panel.title                    = "Select whisper-cpp binary"
        panel.canChooseFiles           = true
        panel.canChooseDirectories     = false
        panel.allowsMultipleSelection  = false
        if panel.runModal() == .OK, let url = panel.url {
            whisperBinaryPath = url.path
        }
    }

    private func browseModelsFolder() {
        let panel = NSOpenPanel()
        panel.title                    = "Select models folder"
        panel.canChooseFiles           = false
        panel.canChooseDirectories     = true
        panel.allowsMultipleSelection  = false
        if panel.runModal() == .OK, let url = panel.url {
            modelsFolderPath = url.path
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
