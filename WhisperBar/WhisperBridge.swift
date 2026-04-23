import Foundation
import Cocoa

/// Shells out to the whisper-cpp binary, parses stdout / output txt, and
/// shows a friendly alert when the model file cannot be found.
final class WhisperBridge {

    static let shared = WhisperBridge()
    private init() {}

    private let prefs = PreferencesStore.shared
    private let queue = DispatchQueue(label: "com.whisperbar.transcription", qos: .userInitiated)

    // MARK: - Public API

    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let modelPath = self.prefs.modelFilePath(for: self.prefs.selectedModel)

            guard FileManager.default.fileExists(atPath: modelPath) else {
                DispatchQueue.main.async {
                    self.showModelNotFoundAlert(modelPath: modelPath)
                    completion(nil)
                }
                return
            }

            self.run(audioURL: audioURL, modelPath: modelPath, completion: completion)
        }
    }

    // MARK: - Process execution

    private func run(audioURL: URL, modelPath: String, completion: @escaping (String?) -> Void) {
        let binaryPath = prefs.whisperBinaryPath

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            print("[WhisperBridge] Binary not found at \(binaryPath)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "--model",        modelPath,
            "--language",     "auto",
            "--output-txt",
            "--no-timestamps",
            audioURL.path
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError  = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[WhisperBridge] Process launch error: \(error)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // whisper-cpp writes a .txt sidecar when --output-txt is passed
        let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
        if let content = try? String(contentsOf: txtURL, encoding: .utf8) {
            try? FileManager.default.removeItem(at: txtURL)
            let cleaned = clean(content)
            DispatchQueue.main.async { completion(cleaned.isEmpty ? nil : cleaned) }
            return
        }

        // Fall back to stdout
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let cleaned = clean(output)
        DispatchQueue.main.async { completion(cleaned.isEmpty ? nil : cleaned) }
    }

    // MARK: - Output parsing

    private func clean(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { line in
                !line.hasPrefix("whisper_") &&
                !line.hasPrefix("ggml_") &&
                !line.hasPrefix("main:") &&
                !line.hasPrefix("system_info:") &&
                !line.hasPrefix("log:") &&
                !line.hasPrefix("[") // remove leftover timestamp lines
            }
            .joined(separator: " ")
    }

    // MARK: - Model not found alert

    private func showModelNotFoundAlert(modelPath: String) {
        let alert = NSAlert()
        alert.messageText    = "Whisper Model Not Found"
        alert.informativeText =
            "The model file was not found at:\n\(modelPath)\n\n" +
            "Download a ggml model from HuggingFace and update the Models Folder in Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Download from HuggingFace")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            SettingsWindowController.shared.showWindow(nil)
        default:
            break
        }
    }
}
