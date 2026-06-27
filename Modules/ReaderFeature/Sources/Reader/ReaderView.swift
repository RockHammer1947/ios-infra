import DaodejingContent
import DesignSystem
import SwiftUI

/// How the 原文 returns alongside the 白话 — the three patterns from the design.
enum ReadMode: String, CaseIterable, Identifiable {
    case vernacular // 白话 + 行内渗开
    case sentence // 逐句对照
    case annotated // 原文 + 注释

    var id: String { rawValue }
    var label: String {
        switch self {
        case .vernacular: "白话"
        case .sentence: "逐句"
        case .annotated: "原文注释"
        }
    }
}

/// 阅读 — vernacular-first reading with inline original reveal, sentence
/// comparison, and an annotated original view.
struct ReaderView: View {
    let repository: any ContentRepository

    @State private var currentNumber: Int
    @State private var mode: ReadMode = .vernacular
    @State private var revealed: Set<Int> = []
    @State private var bookmarked = false
    @AppStorage("fontScale") private var fontScale = 1.0
    @Environment(\.dismiss) private var dismiss

    init(repository: any ContentRepository, startNumber: Int) {
        self.repository = repository
        _currentNumber = State(initialValue: startNumber)
    }

    private var numbers: [Int] { repository.allChapters().map(\.number).sorted() }
    private var chapter: Chapter? { repository.chapter(currentNumber) }
    private var bodySize: CGFloat { CGFloat(16.5 * fontScale) }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                modeSwitcher
                ScrollView {
                    if let chapter {
                        content(chapter)
                            .padding(.horizontal, DSMetrics.screenPadding)
                            .padding(.top, 18)
                            .padding(.bottom, 40)
                    }
                }
                footer
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Bars

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").foregroundStyle(DSColor.textBody)
            }
            .accessibilityIdentifier("reader-back")
            Spacer()
            VStack(spacing: 1) {
                Text("第\(ChineseNumber.of(currentNumber))章")
                    .font(DSFont.serif(14)).foregroundStyle(DSColor.textBody)
                Text("\(currentNumber) / 81").font(DSFont.sans(9.5)).foregroundStyle(DSColor.textFaint)
            }
            Spacer()
            HStack(spacing: 16) {
                Button { bookmarked.toggle() } label: {
                    Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(bookmarked ? DSColor.accent : DSColor.textBody)
                }
                Button { cycleFontScale() } label: {
                    Text("Aa").font(DSFont.serif(15)).foregroundStyle(DSColor.textBody)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 18) {
            ForEach(ReadMode.allCases) { item in
                Button { withAnimation(.easeOut(duration: 0.2)) { mode = item } } label: {
                    Text(item.label)
                        .font(DSFont.sans(12.5, weight: mode == item ? .medium : .regular))
                        .foregroundStyle(mode == item ? DSColor.accent : DSColor.textTertiary)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            navButton(systemImage: "chevron.left", label: "上一章", disabled: !hasNeighbor(-1)) { step(-1) }
            Spacer()
            navButton(systemImage: "chevron.right", label: "下一章", trailing: true, disabled: !hasNeighbor(1)) { step(1) }
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.separator).frame(height: 1) }
    }

    // MARK: Content modes

    @ViewBuilder
    private func content(_ chapter: Chapter) -> some View {
        Text(chapter.book.title + " · 第\(chapter.chineseNumeral)章")
            .font(DSFont.sans(11, weight: .medium)).tracking(4)
            .foregroundStyle(DSColor.accent)
        Text(chapter.title)
            .font(DSFont.serif(27, weight: .semibold))
            .foregroundStyle(DSColor.textPrimary)
            .padding(.top, 12)
            .padding(.bottom, 8)

        switch mode {
        case .vernacular: vernacularBody(chapter)
        case .sentence: sentenceBody(chapter)
        case .annotated: annotatedBody(chapter)
        }
    }

    private func vernacularBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(chapter.vernacular.indices, id: \.self) { index in
                let paragraph = chapter.vernacular[index]
                VStack(alignment: .leading, spacing: 12) {
                    Text(paragraph)
                        .font(DSFont.sans(bodySize))
                        .lineSpacing(9)
                        .foregroundStyle(DSColor.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { toggleReveal(index) }
                    if revealed.contains(index), index < chapter.original.count {
                        HStack(alignment: .top, spacing: 12) {
                            Capsule().fill(DSColor.accent.opacity(0.6)).frame(width: 2.5)
                            Text(chapter.original[index])
                                .font(DSFont.serif(bodySize - 0.5))
                                .lineSpacing(6)
                                .foregroundStyle(DSColor.accentSoft)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            Text("点按译文 · 原文就地渗开")
                .font(DSFont.sans(12)).foregroundStyle(DSColor.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func sentenceBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(chapter.sentencePairs) { pair in
                VStack(alignment: .leading, spacing: 7) {
                    Text(pair.original)
                        .font(DSFont.serif(bodySize)).foregroundStyle(DSColor.accentSoft)
                    Text(pair.vernacular)
                        .font(DSFont.sans(bodySize - 2)).lineSpacing(5)
                        .foregroundStyle(DSColor.textBody)
                }
            }
        }
    }

    private func annotatedBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(chapter.original.indices, id: \.self) { index in
                let line = chapter.original[index]
                VStack(alignment: .leading, spacing: 11) {
                    if index < chapter.vernacular.count {
                        Text(chapter.vernacular[index])
                            .font(DSFont.sans(bodySize)).lineSpacing(7)
                            .foregroundStyle(DSColor.textBody)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Capsule().fill(DSColor.accent.opacity(0.55)).frame(width: 2.5)
                        Text(line)
                            .font(DSFont.serif(bodySize)).lineSpacing(6)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    ForEach(chapter.notes.filter { $0.index == index }) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Text("注")
                                .font(DSFont.serif(11)).foregroundStyle(DSColor.accent)
                                .padding(.horizontal, 5).frame(height: 18)
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(DSColor.accent.opacity(0.4)))
                            Text(note.text)
                                .font(DSFont.sans(12.5)).lineSpacing(4)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func navButton(
        systemImage: String,
        label: String,
        trailing: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if !trailing { Image(systemName: systemImage).font(.system(size: 12)) }
                Text(label).font(DSFont.sans(12.5))
                if trailing { Image(systemName: systemImage).font(.system(size: 12)) }
            }
            .foregroundStyle(disabled ? DSColor.textFaint : DSColor.accentSoft)
        }
        .disabled(disabled)
    }

    private func toggleReveal(_ index: Int) {
        withAnimation(.easeOut(duration: 0.3)) {
            if revealed.contains(index) { revealed.remove(index) } else { revealed.insert(index) }
        }
    }

    private func cycleFontScale() {
        let scales = [0.9, 1.0, 1.15]
        let next = (scales.firstIndex(of: fontScale).map { $0 + 1 } ?? 1) % scales.count
        fontScale = scales[next]
    }

    private func hasNeighbor(_ delta: Int) -> Bool {
        guard let idx = numbers.firstIndex(of: currentNumber) else { return false }
        return numbers.indices.contains(idx + delta)
    }

    private func step(_ delta: Int) {
        guard let idx = numbers.firstIndex(of: currentNumber),
              numbers.indices.contains(idx + delta) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            revealed.removeAll()
            currentNumber = numbers[idx + delta]
        }
    }
}
