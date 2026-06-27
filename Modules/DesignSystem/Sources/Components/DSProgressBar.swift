import SwiftUI

/// A thin reading-progress bar (continue-reading card, 已读 N/81…).
public struct DSProgressBar: View {
    private let progress: Double
    private let height: CGFloat

    public init(progress: Double, height: CGFloat = 3) {
        self.progress = max(0, min(1, progress))
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.accent.opacity(0.15))
                Capsule().fill(DSColor.accent).frame(width: geo.size.width * progress)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    DSProgressBar(progress: 0.42)
        .padding()
        .background(DSColor.background)
}
