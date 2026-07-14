import DaodejingContent
import DesignSystem
import Library
import Purchases
import SwiftData
import SwiftUI

/// 经文 — the table of contents, split into 道经 / 德经 with search.
struct ContentsView: View {
    let repository: any ContentRepository
    @Environment(StoreModel.self) private var store
    @Environment(TrialAccess.self) private var trial
    @Environment(\.appLanguage) private var lang
    @Query(filter: #Predicate<ChapterProgress> { $0.fraction >= 0.95 }) private var read: [ChapterProgress]
    @State private var book: Book = .dao
    @State private var query = ""

    private var listed: [Chapter] {
        let base = query.isEmpty ? repository.chapters(in: book) : repository.search(query)
        return base.sorted { $0.number < $1.number }
    }

    private var readNumbers: Set<Int> { Set(read.map(\.chapterNumber)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.pick("经文", "Text")).font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            }
            .padding(.top, 10)

            DSSegmentedControl(
                selection: $book,
                options: [
                    (Book.dao, lang.pick(Book.dao.rangeLabel, "Book of the Way · 1–37")),
                    (Book.de, lang.pick(Book.de.rangeLabel, "Book of Virtue · 38–81")),
                ]
            )
            .padding(.top, 18)

            HStack(spacing: 10) {
                Text(lang.pick("已读 \(readNumbers.count) / 81", "\(readNumbers.count) / 81 read")).font(DSFont.sans(11.5))
                    .foregroundStyle(DSColor.textTertiary)
                DSProgressBar(progress: Double(readNumbers.count) / 81, height: 2)
            }
            .padding(.top, 16)

            if !store.isUnlocked {
                Text(
                    trial.remaining > 0
                        ? lang.pick("免费试读 · 还剩 \(trial.remaining) 章（任意选）", "Free preview · \(trial.remaining) chapters left (your pick)")
                        : lang.pick("免费试读已用完 · 购买后畅读全本", "Free preview used up · unlock the full text")
                )
                .font(DSFont.sans(11))
                .foregroundStyle(DSColor.accentSoft)
                .padding(.top, 10)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(listed) { chapter in
                        NavigationLink(value: chapter.number) {
                            ChapterRow(
                                chapter: chapter,
                                numeral: lang.pick(chapter.chineseNumeral, "\(chapter.number)"),
                                locked: trial.isLocked(chapter.number, purchased: store.isUnlocked),
                                read: readNumbers.contains(chapter.number)
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
    let numeral: String
    let locked: Bool
    let read: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(numeral)
                .font(DSFont.serif(numeral.count > 2 ? 15 : 18))
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
            } else if read {
                Circle().fill(DSColor.accent).frame(width: 7, height: 7)
            } else {
                Circle().strokeBorder(DSColor.border, lineWidth: 1).frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
