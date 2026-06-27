import DaodejingContent
import DesignSystem
import Purchases
import SwiftUI

/// 经文 — the table of contents, split into 道经 / 德经 with search.
struct ContentsView: View {
    let repository: any ContentRepository
    @Environment(StoreModel.self) private var store
    @State private var book: Book = .dao
    @State private var query = ""

    private var listed: [Chapter] {
        let base = query.isEmpty ? repository.chapters(in: book) : repository.search(query)
        return base.sorted { $0.number < $1.number }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("经文").font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            }
            .padding(.top, 10)

            DSSegmentedControl(
                selection: $book,
                options: [(Book.dao, Book.dao.rangeLabel), (Book.de, Book.de.rangeLabel)]
            )
            .padding(.top, 18)

            HStack(spacing: 10) {
                Text("已读 0 / 81").font(DSFont.sans(11.5)).foregroundStyle(DSColor.textTertiary)
                DSProgressBar(progress: 0, height: 2)
            }
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(listed) { chapter in
                        NavigationLink(value: chapter.number) {
                            ChapterRow(
                                chapter: chapter,
                                locked: ReaderProducts.access.isLocked(chapter.number, unlocked: store.isUnlocked)
                            )
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(DSColor.separator).frame(height: 1)
                    }
                }
                .padding(.bottom, 96)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, DSMetrics.screenPadding)
    }
}

/// One row in the contents list: numeral · title · 原文 teaser · read dot.
private struct ChapterRow: View {
    let chapter: Chapter
    let locked: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(chapter.chineseNumeral)
                .font(DSFont.serif(chapter.chineseNumeral.count > 2 ? 15 : 18))
                .foregroundStyle(DSColor.accentSoft)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title).font(DSFont.sans(14.5)).foregroundStyle(DSColor.textBody)
                Text(chapter.firstOriginalLine)
                    .font(DSFont.sans(11))
                    .foregroundStyle(DSColor.textFaint)
                    .lineLimit(1)
            }
            Spacer()
            if locked {
                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(DSColor.textFaint)
            } else {
                Circle().strokeBorder(DSColor.border, lineWidth: 1).frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
