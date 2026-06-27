import DesignSystem
import SwiftUI

/// 笔记 — highlights, notes and bookmarks. Persistence arrives in M7; for now
/// the filter chips and an empty state.
struct NotesView: View {
    @State private var filter = "全部"
    private let filters = ["全部", "划线", "笔记", "书签"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("笔记").font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "plus").foregroundStyle(DSColor.accentSoft)
            }
            .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { name in
                    DSTag(name, selected: name == filter)
                        .onTapGesture { filter = name }
                }
            }
            .padding(.top, 16)

            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "highlighter").font(.system(size: 30)).foregroundStyle(DSColor.textFaint)
                Text("还没有笔记").font(DSFont.sans(14)).foregroundStyle(DSColor.textTertiary)
                Text("长按译文即可划线，存入此处").font(DSFont.sans(12)).foregroundStyle(DSColor.textFaint)
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, DSMetrics.screenPadding)
    }
}
