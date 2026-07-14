import DaodejingContent
import DesignSystem
import Library
import SwiftData
import SwiftUI

/// 笔记 — the reader's highlights, notes and bookmarks, persisted with
/// SwiftData. Filter chips narrow by kind; swipe a card to delete.
struct NotesView: View {
    let repository: any ContentRepository

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var lang
    @Query(sort: \Mark.createdAt, order: .reverse) private var marks: [Mark]
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable, Identifiable {
        case all, highlight, note, bookmark
        var id: String { rawValue }
        func label(_ lang: ContentLanguage) -> String {
            switch self {
            case .all: lang.pick("全部", "All")
            case .highlight: lang.pick("划线", "Highlights")
            case .note: lang.pick("笔记", "Notes")
            case .bookmark: lang.pick("书签", "Bookmarks")
            }
        }

        var kind: MarkKind? {
            switch self {
            case .all: nil
            case .highlight: .highlight
            case .note: .note
            case .bookmark: .bookmark
            }
        }
    }

    private var shown: [Mark] {
        guard let kind = filter.kind else { return marks }
        return marks.filter { $0.kind == kind }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.pick("笔记", "Notes")).font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                .padding(.top, 10)

            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    DSTag(item.label(lang), selected: item == filter)
                        .onTapGesture { filter = item }
                }
            }
            .padding(.top, 16)

            if shown.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(.horizontal, DSMetrics.screenPadding)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(shown) { mark in
                    NavigationLink(value: mark.chapterNumber) {
                        MarkCard(mark: mark, title: repository.chapter(mark.chapterNumber)?.title ?? "", lang: lang)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(mark)
                        } label: {
                            Label(lang.pick("删除", "Delete"), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 96)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "highlighter").font(.system(size: 30)).foregroundStyle(DSColor.textFaint)
                Text(lang.pick("还没有笔记", "No notes yet")).font(DSFont.sans(14)).foregroundStyle(DSColor.textTertiary)
                Text(lang.pick("长按译文即可划线，存入此处", "Long-press a line to save a highlight here")).font(DSFont.sans(12))
                    .foregroundStyle(DSColor.textFaint)
            }
            .frame(maxWidth: .infinity)
            Spacer()
            Spacer()
        }
    }
}

/// One saved mark, styled by kind: a brushed highlight, an annotated note, or a
/// bare bookmark row.
private struct MarkCard: View {
    let mark: Mark
    let title: String
    let lang: ContentLanguage

    private var kindLabel: String {
        switch mark.kind {
        case .highlight: lang.pick("划线", "Highlight")
        case .note: lang.pick("笔记", "Note")
        case .bookmark: lang.pick("书签", "Bookmark")
        }
    }

    private var chapterLine: String {
        lang.pick("第\(ChineseNumber.of(mark.chapterNumber))章 · \(title)", "Chapter \(mark.chapterNumber) · \(title)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(kindLabel)
                    .font(DSFont.sans(10, weight: .medium))
                    .foregroundStyle(DSColor.accent)
                    .padding(.horizontal, 7).frame(height: 18)
                    .background(Capsule().fill(DSColor.accent.opacity(0.12)))
                Text(chapterLine)
                    .font(DSFont.sans(11.5)).foregroundStyle(DSColor.textTertiary)
                Spacer()
            }

            if !mark.excerpt.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Capsule().fill(DSColor.accent.opacity(0.55)).frame(width: 2.5)
                    Text(mark.excerpt)
                        .font(DSFont.serif(14)).lineSpacing(5)
                        .foregroundStyle(DSColor.textBody)
                }
            }

            if !mark.noteText.isEmpty {
                Text(mark.noteText)
                    .font(DSFont.sans(13)).lineSpacing(4)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
    }
}
