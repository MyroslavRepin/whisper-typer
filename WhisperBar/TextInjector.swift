import Cocoa
import ApplicationServices
import CoreGraphics

/// Injects text into the frontmost application.
/// Uses AXUIElement to verify focus where possible,
/// then always falls back to clipboard + CGEvent Cmd+V.
final class TextInjector {

    static let shared = TextInjector()
    private init() {}

    // MARK: - Public

    func inject(text: String) {
        // Best-effort AX verification (non-blocking)
        let hasFocus = verifyFocusedTextElement()
        if !hasFocus {
            // No focused text element detected, but paste anyway —
            // the user presumably triggered the hotkey from a text context.
        }
        pasteViaClipboard(text: text)
    }

    // MARK: - AXUIElement verification

    @discardableResult
    private func verifyFocusedTextElement() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success else { return false }

        // AXUIElement is a CoreFoundation type; use conditional cast for safety
        guard let focused = focusedRef as? AXUIElement else { return false }
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else { return false }

        return role == kAXTextFieldRole
            || role == kAXTextAreaRole
            || role == "AXComboBox"
            || role == "AXSearchField"
    }

    // MARK: - Clipboard paste

    private func pasteViaClipboard(text: String) {
        let pb = NSPasteboard.general
        let savedContents = snapshotPasteboard(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)

        simulateCmdV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restorePasteboard(pb, from: savedContents)
        }
    }

    // MARK: - CGEvent Cmd+V

    private func simulateCmdV() {
        // Virtual key 0x09 = 'v' on US layout
        let src = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags   = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Pasteboard snapshot / restore

    private struct PasteboardSnapshot {
        let items: [(types: [NSPasteboard.PasteboardType], data: [NSPasteboard.PasteboardType: Data])]
    }

    private func snapshotPasteboard(_ pb: NSPasteboard) -> PasteboardSnapshot {
        let items = (pb.pasteboardItems ?? []).map { item -> (types: [NSPasteboard.PasteboardType], data: [NSPasteboard.PasteboardType: Data]) in
            var dataMap: [NSPasteboard.PasteboardType: Data] = [:]
            for type_ in item.types {
                if let d = item.data(forType: type_) {
                    dataMap[type_] = d
                }
            }
            return (types: item.types, data: dataMap)
        }
        return PasteboardSnapshot(items: items)
    }

    private func restorePasteboard(_ pb: NSPasteboard, from snapshot: PasteboardSnapshot) {
        pb.clearContents()
        guard !snapshot.items.isEmpty else { return }

        var newItems: [NSPasteboardItem] = []
        for entry in snapshot.items {
            let item = NSPasteboardItem()
            for (type_, data) in entry.data {
                item.setData(data, forType: type_)
            }
            newItems.append(item)
        }
        pb.writeObjects(newItems)
    }
}
