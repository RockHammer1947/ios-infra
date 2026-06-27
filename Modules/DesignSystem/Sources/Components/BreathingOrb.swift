import SwiftUI

/// A soft 竹青 light orb that slowly breathes — used behind 今日 and during
/// listening to guide the reader's breath ("呼吸感").
public struct BreathingOrb: View {
    private let size: CGFloat
    @State private var phase = false

    public init(size: CGFloat = 300) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [DSColor.accent.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 6)
            .scaleEffect(phase ? 1.16 : 1.0)
            .opacity(phase ? 0.85 : 0.45)
            .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: phase)
            .onAppear { phase = true }
            .allowsHitTesting(false)
    }
}

#Preview {
    BreathingOrb()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
}
