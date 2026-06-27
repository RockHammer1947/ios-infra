import SwiftUI

/// A small pill used for tags and filter chips (静·一屏一念, 划线, 书签…).
public struct DSTag: View {
    private let text: String
    private let selected: Bool

    public init(_ text: String, selected: Bool = false) {
        self.text = text
        self.selected = selected
    }

    public var body: some View {
        Text(text)
            .font(DSFont.sans(12))
            .foregroundStyle(selected ? DSColor.accentBright : DSColor.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(selected ? DSColor.accent.opacity(0.16) : .clear)
            )
            .overlay(
                Capsule().strokeBorder(selected ? .clear : DSColor.border, lineWidth: 1)
            )
    }
}

#Preview {
    HStack {
        DSTag("全部", selected: true)
        DSTag("划线")
        DSTag("书签")
    }
    .padding()
    .background(DSColor.background)
}
