import SwiftUI

// MARK: - WaveformView

/// Seven animated vertical bars driven by an array of scale values (0…1).
struct WaveformView: View {
    var amplitudes: [CGFloat]   // expected length: 7

    private static let barCount = 7

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<WaveformView.barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 4, height: 28)
                    .scaleEffect(
                        y: amplitude(at: i),
                        anchor: .center
                    )
                    .animation(
                        .spring(response: 0.12, dampingFraction: 0.55),
                        value: amplitude(at: i)
                    )
            }
        }
    }

    private func amplitude(at index: Int) -> CGFloat {
        guard index < amplitudes.count else { return 0.1 }
        return max(0.08, min(1.0, amplitudes[index]))
    }
}

// MARK: - RecordingPillView

/// The dark rounded pill shown while recording.
/// Subscribes to AudioRecorder.shared.onRMSUpdate for live amplitude.
struct RecordingPillView: View {

    @State private var amplitudes: [CGFloat] = Array(repeating: 0.1, count: 7)
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50)
                .fill(Color(white: 0.08).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 6) {
                WaveformView(amplitudes: amplitudes)

                Text("listening\u{2026}")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.55))
                    .kerning(0.3)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        .onAppear {
            AudioRecorder.shared.onRMSUpdate = { rms in
                // Spread RMS across bars with per-bar sinusoidal phase variation
                phase += 0.25
                let scaled = CGFloat(rms) * 6.0
                withAnimation {
                    for i in 0..<7 {
                        let offset   = Double(i) * .pi / 3.5
                        let variation = CGFloat((sin(phase + offset) + 1) / 2)
                        amplitudes[i] = scaled * (0.35 + variation * 0.65)
                    }
                }
            }
        }
        .onDisappear {
            AudioRecorder.shared.onRMSUpdate = nil
            amplitudes = Array(repeating: 0.1, count: 7)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingPillView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingPillView()
            .frame(width: 280, height: 90)
            .background(Color.gray)
    }
}
#endif
