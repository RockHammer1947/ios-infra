import Foundation
import SwiftUI

/// 圆满进度 — the 81 chapters as dots around a circle (enso). Read chapters
/// light up in 竹青; a full ring means one complete pass through the text.
public struct EnsoProgress: View {
    private let total: Int
    private let read: Int

    public init(total: Int, read: Int) {
        self.total = max(1, total)
        self.read = max(0, min(read, total))
    }

    public var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - 6
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ForEach(0 ..< total, id: \.self) { index in
                let angle = Double(index) / Double(total) * 2 * .pi - .pi / 2
                Circle()
                    .fill(index < read ? DSColor.accent : DSColor.accent.opacity(0.18))
                    .frame(width: 5, height: 5)
                    .position(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
            }
        }
    }
}

#Preview {
    EnsoProgress(total: 81, read: 12)
        .frame(width: 180, height: 180)
        .padding()
        .background(DSColor.background)
}
