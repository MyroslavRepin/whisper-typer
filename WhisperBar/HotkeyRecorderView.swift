import SwiftUI
import AppKit
import CoreGraphics

// MARK: - HotkeyRecorderView (NSViewRepresentable)

/// A SwiftUI wrapper around HotkeyRecorderNSView.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifierFlags: Int

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onRecorded = { kc, mf in
            self.keyCode       = kc
            self.modifierFlags = mf
        }
        view.currentKeyCode       = keyCode
        view.currentModifierFlags = modifierFlags
        view.refreshLabel()
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentKeyCode       = keyCode
        nsView.currentModifierFlags = modifierFlags
        nsView.refreshLabel()
    }
}

// MARK: - HotkeyRecorderNSView

final class HotkeyRecorderNSView: NSView {

    var onRecorded: ((Int, Int) -> Void)?
    var currentKeyCode: Int       = 49   // Space
    var currentModifierFlags: Int = 0

    private(set) var isRecording = false

    private let label  = NSTextField(labelWithString: "")
    private let button = NSButton()

    // MARK: Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius  = 6
        layer?.borderWidth   = 1
        layer?.borderColor   = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.isEditable          = false
        label.isBordered          = false
        label.backgroundColor     = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        button.title      = "Record"
        button.bezelStyle = .rounded
        button.target     = self
        button.action     = #selector(toggleRecording)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -8),

            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 72)
        ])
    }

    // MARK: Recording toggle

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            button.title = "Cancel"
            label.stringValue = "Press a key combo…"
            window?.makeFirstResponder(self)
        } else {
            button.title = "Record"
            refreshLabel()
        }
    }

    // MARK: Key events

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Ignore pure-modifier key presses.
        // Key codes: 54/55 = Cmd, 56/60 = Shift, 57 = CapsLock,
        //            58/61 = Option, 59/62 = Control, 63 = Fn
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modifierKeyCodes.contains(event.keyCode) else { return }

        // Escape cancels recording
        if event.keyCode == 53 {
            isRecording  = false
            button.title = "Record"
            refreshLabel()
            return
        }

        let kc = Int(event.keyCode)
        let mf = Int(event.modifierFlags
            .intersection([.command, .shift, .control, .option])
            .rawValue)

        currentKeyCode       = kc
        currentModifierFlags = mf
        isRecording          = false
        button.title         = "Record"
        refreshLabel()
        onRecorded?(kc, mf)
    }

    // MARK: Display

    func refreshLabel() {
        guard !isRecording else { return }
        label.stringValue = hotkeyString(keyCode: currentKeyCode, modifiers: currentModifierFlags)
    }

    private func hotkeyString(keyCode: Int, modifiers: Int) -> String {
        var s = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += keyLabel(for: keyCode)
        return s
    }

    private func keyLabel(for keyCode: Int) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            // Resolve via CGEvent
            let src = CGEventSource(stateID: .hidSystemState)
            if let ev = CGEvent(keyboardEventSource: src,
                                virtualKey: CGKeyCode(keyCode),
                                keyDown: true) {
                ev.flags = []
                var length: Int = 0
                var chars = [UniChar](repeating: 0, count: 4)
                ev.keyboardGetUnicodeString(
                    maxStringLength: 4,
                    actualStringLength: &length,
                    unicodeString: &chars
                )
                if length > 0, let scalar = Unicode.Scalar(chars[0]) {
                    return String(scalar).uppercased()
                }
            }
            return "(\(keyCode))"
        }
    }
}
