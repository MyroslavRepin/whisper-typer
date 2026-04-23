import Cocoa
import AVFoundation

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController?
    var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (belt-and-suspenders alongside LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        checkAccessibilityPermissions()
        requestMicrophonePermission()

        statusBarController = StatusBarController()
        hotkeyManager       = HotkeyManager()
    }

    // MARK: - Permissions

    private func checkAccessibilityPermissions() {
        guard !AXIsProcessTrusted() else { return }

        let alert = NSAlert()
        alert.messageText    = "Accessibility Access Required"
        alert.informativeText =
            "WhisperBar needs Accessibility access to inject transcribed text into " +
            "other applications. Please grant access in:\n" +
            "System Settings › Privacy & Security › Accessibility"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText    = "Microphone Access Required"
                    alert.informativeText =
                        "WhisperBar needs access to the microphone to record audio for transcription. " +
                        "Please grant access in:\n" +
                        "System Settings › Privacy & Security › Microphone"
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Later")
                    if alert.runModal() == .alertFirstButtonReturn {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
