import AVFoundation
import Foundation

/// Records microphone input via AVAudioEngine, converts to 16 kHz mono PCM,
/// accumulates Float32 samples, and writes a standard WAV file on stop.
final class AudioRecorder {

    static let shared = AudioRecorder()
    private init() {}

    // MARK: - Public

    /// Called on the main thread with the current RMS amplitude (0…1 range).
    var onRMSUpdate: ((Float) -> Void)?

    // MARK: - Private state

    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var samples: [Float] = []

    private static let targetSampleRate: Double = 16_000
    private static let targetChannels: AVAudioChannelCount = 1

    // MARK: - Start

    func startRecording() {
        samples = []

        let newEngine = AVAudioEngine()
        let inputNode  = newEngine.inputNode
        let hwFormat   = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioRecorder.targetSampleRate,
            channels: AudioRecorder.targetChannels,
            interleaved: false
        ) else {
            print("[AudioRecorder] Could not create target AVAudioFormat")
            return
        }

        guard let cvt = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            print("[AudioRecorder] Could not create AVAudioConverter")
            return
        }
        converter = cvt

        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: hwFormat) { [weak self] buf, _ in
            self?.processBuffer(buf)
        }

        do {
            try newEngine.start()
            engine = newEngine
        } catch {
            print("[AudioRecorder] Engine start failed: \(error)")
        }
    }

    // MARK: - Stop

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let eng = engine else {
            completion(nil)
            return
        }

        eng.inputNode.removeTap(onBus: 0)
        eng.stop()
        engine    = nil
        converter = nil

        let captured = samples
        samples = []

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisperbar_\(Date().timeIntervalSince1970).wav")

        DispatchQueue.global(qos: .userInitiated).async {
            self.writeWAV(samples: captured,
                          sampleRate: Int32(AudioRecorder.targetSampleRate),
                          to: outputURL)
            DispatchQueue.main.async { completion(outputURL) }
        }
    }

    // MARK: - Buffer processing

    private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        // ── RMS for waveform visualisation (use hardware-format samples) ──
        let rms = calcRMS(inputBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.onRMSUpdate?(rms)
        }

        // ── Resample / convert to 16 kHz mono Float32 ────────────────────
        guard let cvt = converter else { return }

        let ratio = AudioRecorder.targetSampleRate / inputBuffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 1)

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: cvt.outputFormat,
                                               frameCapacity: outCapacity) else { return }

        var consumed = false
        var convError: NSError?
        cvt.convert(to: outBuffer, error: &convError) { _, outStatus in
            guard !consumed else {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let err = convError {
            print("[AudioRecorder] Conversion error: \(err)")
            return
        }

        guard let channelData = outBuffer.floatChannelData,
              outBuffer.frameLength > 0 else { return }

        let slice = Array(UnsafeBufferPointer(start: channelData[0],
                                              count: Int(outBuffer.frameLength)))
        samples.append(contentsOf: slice)
    }

    // MARK: - RMS helper

    private func calcRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let ch = buffer.floatChannelData {
            var sum: Float = 0
            for i in 0..<frameLength { sum += ch[0][i] * ch[0][i] }
            return sqrtf(sum / Float(frameLength))
        } else if let ch = buffer.int16ChannelData {
            var sum: Float = 0
            for i in 0..<frameLength {
                let s = Float(ch[0][i]) / 32_768.0
                sum += s * s
            }
            return sqrtf(sum / Float(frameLength))
        }
        return 0
    }

    // MARK: - WAV writer

    /// Writes a standard RIFF/WAVE PCM-16 file at the target sample rate.
    private func writeWAV(samples: [Float], sampleRate: Int32, to url: URL) {
        let numChannels:  Int16 = 1
        let bitsPerSample: Int16 = 16
        let numSamples: Int32 = Int32(samples.count)
        let byteRate: Int32  = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign: Int16 = numChannels * (bitsPerSample / 8)
        let dataSize: Int32  = numSamples * Int32(bitsPerSample / 8)
        let fileSize: Int32  = 36 + dataSize

        var data = Data(capacity: Int(44 + dataSize))

        func w8(_ bytes: [UInt8]) { data.append(contentsOf: bytes) }
        func wStr(_ s: String) { w8(Array(s.utf8)) }
        func w16(_ v: Int16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func w32(_ v: Int32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        // RIFF header
        wStr("RIFF"); w32(fileSize); wStr("WAVE")
        // fmt  chunk
        wStr("fmt "); w32(16)
        w16(1)            // PCM
        w16(numChannels)
        w32(sampleRate)
        w32(byteRate)
        w16(blockAlign)
        w16(bitsPerSample)
        // data chunk
        wStr("data"); w32(dataSize)
        for s in samples {
            w16(Int16(max(-32_768, min(32_767, Int32(s * 32_767)))))
        }

        do {
            try data.write(to: url)
        } catch {
            print("[AudioRecorder] Failed to write WAV: \(error)")
        }
    }
}
