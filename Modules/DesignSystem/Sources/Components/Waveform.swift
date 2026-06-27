import SwiftUI

/// Decorative audio waveform for the 聆听 player. Bars play a gentle wave when
/// `isPlaying`; `progress` (0…1) tints the leading bars with the accent.
public struct Waveform: View {
    private let isPlaying: Bool
    private let progress: Double
    private let barCount: Int

    // Fixed pseudo-random heights keep the shape stable across redraws.
    private static let heights: [CGFloat] = [
        0.5, 0.8, 0.4, 0.95, 0.6, 0.35, 0.7, 0.45, 0.85, 0.3,
        0.65, 0.5, 0.9, 0.4, 0.75, 0.55, 0.35, 0.8, 0.5, 0.7,
    ]

    public init(isPlaying: Bool, progress: Double = 0, barCount: Int = 20) {
        self.isPlaying = isPlaying
        self.progress = max(0, min(1, progress))
        self.barCount = min(barCount, Self.heights.count)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0 ..< barCount, id: \.self) { index in
                let played = Double(index) / Double(barCount) <= progress
                Capsule()
                    .fill(played ? DSColor.accent : DSColor.accent.opacity(0.18))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16 * Self.heights[index])
                    .scaleEffect(y: isPlaying ? 1 : 0.7, anchor: .center)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 1.1 + Double(index % 3) * 0.15)
                            .repeatForever(autoreverses: true)
                            : .default,
                        value: isPlaying
                    )
            }
        }
        .frame(height: 16)
    }
}

#Preview {
    Waveform(isPlaying: true, progress: 0.35)
        .padding()
        .background(DSColor.background)
}
