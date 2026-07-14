import Audio
import DaodejingContent
import DesignSystem
import Library
import Purchases
import SwiftData
import SwiftUI

/// The two reading surfaces: 原文 (tap a line to reveal its 白话) and 详细解读.
enum ReadMode: String, CaseIterable, Identifiable {
    case original // 原文 · 点按渗出白话
    case interpretation // 详细解读

    var id: String { rawValue }
    func label(_ lang: ContentLanguage) -> String {
        switch self {
        case .original: lang.pick("原文", "Text")
        case .interpretation: lang.pick("解读", "Reflection")
        }
    }
}

/// 阅读 — 原文-first reading with inline 白话 reveal, plus a 详细解读 view.
/// Horizontal swipes page through 原文 ↔ 解读 and across chapters.
struct ReaderView: View {
    let repository: any ContentRepository

    @State private var currentNumber: Int
    @State private var mode: ReadMode = .original
    @State private var revealed: Set<Int> = []
    @State private var bookmarked = false
    @State private var savedToast = false
    /// A pending 聆听 start that has a saved part-way point: ask 继续/从头.
    @State private var resumePrompt: (mode: ReadingMode, lines: [String], spoken: Int, total: Int)?
    @State private var showResumePrompt = false
    @AppStorage("fontScale") private var fontScale = 1.0
    @AppStorage("speechRate") private var speechRate = 1.0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreModel.self) private var store
    @Environment(SpeechPlayer.self) private var speech
    @Environment(TrialAccess.self) private var trial
    @Environment(\.appLanguage) private var lang

    private var library: LibraryStore { LibraryStore(modelContext) }

    init(repository: any ContentRepository, startNumber: Int) {
        self.repository = repository
        _currentNumber = State(initialValue: startNumber)
    }

    private var numbers: [Int] { repository.allChapters().map(\.number).sorted() }
    private var chapter: Chapter? { repository.chapter(currentNumber) }
    private var bodySize: CGFloat { CGFloat(16.5 * fontScale) }
    /// The current chapter isn't accessible yet — show the gate, not content.
    private var needsGate: Bool { trial.needsGate(currentNumber, purchased: store.isUnlocked) }

    /// The 解读 tab only appears for chapters that actually have a 详细解读.
    private var hasInterpretation: Bool { !(chapter?.interpretation.isEmpty ?? true) }
    private var availableModes: [ReadMode] {
        ReadMode.allCases.filter { $0 != .interpretation || hasInterpretation }
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                if !needsGate { modeSwitcher }
                ScrollView {
                    if let chapter {
                        content(chapter)
                            .padding(.horizontal, DSMetrics.screenPadding)
                            .padding(.top, 18)
                            .padding(.bottom, 40)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24).onEnded { handleSwipe($0.translation) }
                )
                if Features.audio, speech.isActive(chapter: currentNumber) {
                    ListenBar(chapter: currentNumber)
                }
                footer
            }
            .overlay(alignment: .bottom) { savedBanner }
        }
        .dsHideNavigationChrome()
        .confirmationDialog(
            lang.pick("上次播放到一半", "Resume where you left off?"),
            isPresented: $showResumePrompt,
            titleVisibility: .visible
        ) {
            if let prompt = resumePrompt {
                Button(lang.pick(
                    "继续播放（第 \(prompt.spoken + 1)/\(prompt.total) 句）",
                    "Resume (line \(prompt.spoken + 1)/\(prompt.total))"
                )) {
                    startListening(mode: prompt.mode, lines: prompt.lines, from: prompt.spoken)
                }
                Button(lang.pick("从头开始", "Start over")) {
                    startListening(mode: prompt.mode, lines: prompt.lines, from: 0)
                }
                Button(lang.pick("取消", "Cancel"), role: .cancel) {}
            }
        }
        .onAppear { enterChapter() }
        .onChange(of: currentNumber) { _, _ in enterChapter() }
    }

    @ViewBuilder
    private var savedBanner: some View {
        if savedToast {
            Text(lang.pick("已存入笔记", "Saved to notes"))
                .font(DSFont.sans(12.5, weight: .medium))
                .foregroundStyle(DSColor.textPrimary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(DSColor.card))
                .overlay(Capsule().strokeBorder(DSColor.accent.opacity(0.4), lineWidth: 1))
                .padding(.bottom, 80)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: Bars

    private var navBar: some View {
        HStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(DSColor.textBody)
                }
                .accessibilityIdentifier("reader-back")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 1) {
                Text(lang.pick("第\(ChineseNumber.of(currentNumber))章", "Chapter \(currentNumber)"))
                    .font(DSFont.serif(14)).foregroundStyle(DSColor.textBody)
                Text("\(currentNumber) / 81").font(DSFont.sans(9.5)).foregroundStyle(DSColor.textFaint)
            }
            .multilineTextAlignment(.center)

            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    if Features.audio, !needsGate {
                        Button { listen() } label: {
                            Image(
                                systemName: speech.isActive(chapter: currentNumber) && speech.isPlaying
                                    ? "speaker.wave.2.fill" : "speaker.wave.2"
                            )
                            .foregroundStyle(
                                speech.isActive(chapter: currentNumber)
                                    ? DSColor.accent : DSColor.textBody
                            )
                        }
                        .accessibilityIdentifier("reader-listen")
                    }
                    Button { toggleBookmark() } label: {
                        Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(bookmarked ? DSColor.accent : DSColor.textBody)
                    }
                    .accessibilityIdentifier("reader-bookmark")
                    Button { cycleFontScale() } label: {
                        Text("Aa").font(DSFont.serif(15)).foregroundStyle(DSColor.textBody)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 18) {
            ForEach(availableModes) { item in
                Button { setMode(item) } label: {
                    Text(item.label(lang))
                        .font(DSFont.sans(12.5, weight: mode == item ? .medium : .regular))
                        .foregroundStyle(mode == item ? DSColor.accent : DSColor.textTertiary)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            navButton(systemImage: "chevron.left", label: lang.pick("上一章", "Previous"), disabled: !hasNeighbor(-1)) { goToChapter(-1) }
            Spacer()
            navButton(systemImage: "chevron.right", label: lang.pick("下一章", "Next"), trailing: true, disabled: !hasNeighbor(1)) {
                goToChapter(1)
            }
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.separator).frame(height: 1) }
    }

    // MARK: Content modes

    @ViewBuilder
    private func content(_ chapter: Chapter) -> some View {
        Text(lang.pick(chapter.book.title + " · 第\(chapter.chineseNumeral)章", "Tao Te Ching · Chapter \(chapter.number)"))
            .font(DSFont.sans(11, weight: .medium)).tracking(4)
            .foregroundStyle(DSColor.accent)
        Text(chapter.title)
            .font(DSFont.serif(27, weight: .semibold))
            .foregroundStyle(DSColor.textPrimary)
            .padding(.top, 12)
            .padding(.bottom, 8)

        if needsGate {
            gateBody(chapter)
        } else {
            switch mode {
            case .original: originalBody(chapter)
            case .interpretation: interpretationBody(chapter)
            }
        }
    }

    /// Free teaser (first 白话 paragraph) above the trial gate / paywall.
    private func gateBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let teaser = chapter.vernacular.first {
                Text(teaser)
                    .font(DSFont.sans(bodySize)).lineSpacing(9)
                    .foregroundStyle(DSColor.textBody)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            if trial.remaining > 0 {
                TrialGateCard(remaining: trial.remaining) { spendFreeRead() }
                    .padding(.top, 4)
            } else {
                PaywallCard()
                    .padding(.top, 4)
            }
        }
    }

    /// Spend one of the reader's free reads on this chapter, revealing it.
    private func spendFreeRead() {
        withAnimation(.easeInOut(duration: 0.3)) { trial.unlock(currentNumber) }
        library.recordProgress(chapterNumber: currentNumber, fraction: 0.25)
    }

    private func originalBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(chapter.original.indices, id: \.self) { index in
                let line = chapter.original[index]
                VStack(alignment: .leading, spacing: 12) {
                    Text(line)
                        .font(DSFont.serif(bodySize + 1))
                        .lineSpacing(9)
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { toggleReveal(index) }
                        .onLongPressGesture { highlight(line) }
                    if revealed.contains(index), index < chapter.vernacular.count {
                        HStack(alignment: .top, spacing: 12) {
                            Capsule().fill(DSColor.accent.opacity(0.6)).frame(width: 2.5)
                            Text(chapter.vernacular[index])
                                .font(DSFont.sans(bodySize - 1.5))
                                .lineSpacing(7)
                                .foregroundStyle(DSColor.textBody)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            Text(lang.pick("点按原文 · 白话就地渗开", "Tap a line to reveal its plain meaning"))
                .font(DSFont.sans(12)).foregroundStyle(DSColor.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func interpretationBody(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(chapter.interpretation) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.heading)
                        .font(DSFont.serif(bodySize + 2.5, weight: .semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    if let quote = section.quote, !quote.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Capsule().fill(DSColor.accent.opacity(0.55)).frame(width: 2.5)
                            Text(quote)
                                .font(DSFont.serif(bodySize)).lineSpacing(6)
                                .foregroundStyle(DSColor.accentSoft)
                        }
                    }
                    ForEach(section.paragraphs.indices, id: \.self) { i in
                        Text(section.paragraphs[i])
                            .font(DSFont.sans(bodySize - 1)).lineSpacing(8)
                            .foregroundStyle(DSColor.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onLongPressGesture { highlight(section.paragraphs[i]) }
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

    /// Sync the bookmark icon and record that this chapter was opened.
    private func enterChapter() {
        bookmarked = library.isBookmarked(currentNumber)
        // Fall back to 原文 if the chapter we landed on has no 解读.
        if !availableModes.contains(mode) { mode = .original }
        guard !needsGate else { return }
        library.recordProgress(chapterNumber: currentNumber, fraction: 0.25)
    }

    private func toggleBookmark() {
        bookmarked = library.toggleBookmark(currentNumber)
    }

    /// The reading mode for speech follows the visible tab: 原文 reads the
    /// classical text, 解读 reads the interpretation.
    private var readingMode: ReadingMode { mode == .interpretation ? .interpretation : .original }

    /// Lines to read aloud for the current tab.
    private func listenLines(_ chapter: Chapter) -> [String] {
        switch readingMode {
        case .interpretation:
            chapter.interpretation.flatMap { [$0.heading] + $0.paragraphs }
        default:
            chapter.original
        }
    }

    /// Start (or pause/resume) reading the current tab's text aloud. A saved
    /// part-way point asks 继续播放 or 从头开始 first.
    private func listen() {
        guard let chapter else { return }
        speech.rateScale = speechRate
        // Already loaded in this mode → plain pause/resume.
        if speech.isActive(chapter: currentNumber, mode: readingMode) {
            withAnimation(.easeOut(duration: 0.25)) {
                speech.toggle(chapter: currentNumber, mode: readingMode, lines: listenLines(chapter))
            }
            return
        }
        let lines = listenLines(chapter)
        if let saved = speech.savedProgress(chapter: currentNumber, mode: readingMode) {
            resumePrompt = (readingMode, lines, saved.spoken, saved.total)
            showResumePrompt = true
            return
        }
        startListening(mode: readingMode, lines: lines, from: 0)
    }

    private func startListening(mode: ReadingMode, lines: [String], from index: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
            speech.start(chapter: currentNumber, mode: mode, lines: lines, startIndex: index)
        }
    }

    /// Long-press a 译文 paragraph to brush a 划线 into 笔记.
    private func highlight(_ excerpt: String) {
        guard !needsGate else { return }
        library.addHighlight(chapterNumber: currentNumber, excerpt: excerpt)
        withAnimation(.easeOut(duration: 0.2)) { savedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeIn(duration: 0.3)) { savedToast = false }
        }
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

    private func setMode(_ target: ReadMode) {
        guard target != mode else { return }
        withAnimation(.easeOut(duration: 0.2)) { mode = target }
    }

    /// Horizontal paging. Left = forward (原文 → 解读 → 下一章的原文),
    /// right = back (解读 → 原文 → 上一章的解读). When gated, swipes just
    /// move between chapters.
    private func handleSwipe(_ t: CGSize) {
        guard abs(t.width) > abs(t.height), abs(t.width) > 55 else { return }
        let forward = t.width < 0
        if needsGate {
            goToChapter(forward ? 1 : -1)
            return
        }
        switch (forward, mode) {
        case (true, .original): setMode(.interpretation)
        case (true, .interpretation): goToChapter(1, landing: .original)
        case (false, .interpretation): setMode(.original)
        case (false, .original): goToChapter(-1, landing: .interpretation)
        }
    }

    private func goToChapter(_ delta: Int, landing: ReadMode = .original) {
        guard let idx = numbers.firstIndex(of: currentNumber),
              numbers.indices.contains(idx + delta) else { return }
        let target = numbers[idx + delta]
        let targetHasInterp = !(repository.chapter(target)?.interpretation.isEmpty ?? true)
        // Reaching the next/previous chapter counts the one we leave as read.
        if !needsGate { library.recordProgress(chapterNumber: currentNumber, fraction: 1.0) }
        withAnimation(.easeInOut(duration: 0.25)) {
            revealed.removeAll()
            currentNumber = target
            mode = (landing == .interpretation && !targetHasInterp) ? .original : landing
        }
    }
}
