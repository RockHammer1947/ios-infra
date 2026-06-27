import SwiftUI

/// Two-or-more segment switch used for 道经 / 德经 and theme selection.
public struct DSSegmentedControl<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Value

    public init(selection: Binding<Value>, options: [(value: Value, label: String)]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Text(option.label)
                    .font(DSFont.sans(13, weight: isOn ? .medium : .regular))
                    .foregroundStyle(isOn ? DSColor.accentBright : DSColor.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isOn ? DSColor.accent.opacity(0.16) : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                    }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DSColor.card)
        )
    }
}

#Preview {
    struct Demo: View {
        @State private var sel = 0
        var body: some View {
            DSSegmentedControl(
                selection: $sel,
                options: [(0, "道经 · 1–37"), (1, "德经 · 38–81")]
            )
            .padding()
            .background(DSColor.background)
        }
    }
    return Demo()
}
