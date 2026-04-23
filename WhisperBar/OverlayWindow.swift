import Cocoa
import SwiftUI

/// Singleton that manages the floating recording overlay NSPanel.
final class OverlayWindowController {

    static let shared = OverlayWindowController()
    private init() {}

    private var panel: NSPanel?

    // MARK: - Show / Hide

    func showOverlay() {
        if panel == nil { buildPanel() }
        panel?.orderFrontRegardless()
    }

    func hideOverlay() {
        // Clear waveform callback immediately so no stale updates fire
        AudioRecorder.shared.onRMSUpdate = nil
        panel?.orderOut(nil)
    }

    // MARK: - Panel construction

    private func buildPanel() {
        let pillWidth:  CGFloat = 280
        let pillHeight: CGFloat = 90

        // Position: bottom-center of the main screen, just above the dock
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let vf     = screen.visibleFrame   // excludes menu bar + dock
        let origin = CGPoint(
            x: vf.midX - pillWidth / 2,
            y: vf.minY + 20               // 20 pt above the dock / bottom edge
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: pillWidth, height: pillHeight)),
            styleMask:   [.nonactivatingPanel, .borderless],
            backing:     .buffered,
            defer:       false
        )

        panel.level                       = .floating
        panel.isOpaque                    = false
        panel.backgroundColor             = .clear
        panel.isMovableByWindowBackground = false
        panel.hasShadow                   = false
        // Keep out of Mission Control / Exposé / window cycle
        panel.collectionBehavior          = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed        = false

        let hostView = NSHostingView(rootView: RecordingPillView())
        hostView.frame = NSRect(origin: .zero, size: CGSize(width: pillWidth, height: pillHeight))
        panel.contentView = hostView

        self.panel = panel
    }
}
