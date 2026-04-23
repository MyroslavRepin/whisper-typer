import Cocoa
import CoreGraphics

/// Registers a CGEventTap and fires audio-recording start/stop when the
/// configured global hotkey is pressed/released.
final class HotkeyManager {

    private var eventTap: CFMachPort?
    private let prefs = PreferencesStore.shared
    private var isActive = false

    /// Modifier-flag mask: only these bits are compared when matching the hotkey.
    private static let relevantModifiers: CGEventFlags = [
        .maskCommand, .maskShift, .maskControl, .maskAlternate
    ]

    init() {
        registerEventTap()
    }

    deinit {
        removeEventTap()
    }

    // MARK: - Registration

    func reload() {
        removeEventTap()
        registerEventTap()
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func registerEventTap() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return mgr.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyManager] Failed to create CGEventTap — check Accessibility permissions.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
    }

    // MARK: - Event handling

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {

        let keyCode  = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags    = event.flags.intersection(HotkeyManager.relevantModifiers)
        let targetKC = CGKeyCode(prefs.hotkeyKeyCode)
        let targetF  = CGEventFlags(rawValue: UInt64(prefs.hotkeyModifierFlags))
                         .intersection(HotkeyManager.relevantModifiers)

        guard keyCode == targetKC, flags == targetF else {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown && !isActive {
            isActive = true
            DispatchQueue.main.async { self.startRecording() }
            return nil  // consume event
        }

        if type == .keyUp && isActive {
            isActive = false
            DispatchQueue.main.async { self.stopRecording() }
            return nil  // consume event
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - Recording lifecycle

    private func startRecording() {
        AudioRecorder.shared.startRecording()
        OverlayWindowController.shared.showOverlay()
    }

    private func stopRecording() {
        OverlayWindowController.shared.hideOverlay()
        AudioRecorder.shared.stopRecording { wavURL in
            guard let url = wavURL else { return }
            WhisperBridge.shared.transcribe(audioURL: url) { transcript in
                guard let text = transcript, !text.isEmpty else { return }
                TextInjector.shared.inject(text: text)
            }
        }
    }
}
