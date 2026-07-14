import Audio
import DaodejingContent
import DesignSystem
import Purchases
import SwiftUI

/// 今日 — the daily chapter, framed by a breathing orb.
struct TodayView: View {
    let repository: any ContentRepository
    @Environment(SpeechPlayer.self) private var speech
    @Environment(StoreModel.self) private var store
    @Environment(TrialAccess.self) private var trial
    @Environment(\.appLanguage) private var lang
    @AppStorage("speechRate") private var speechRate = 1.0
    @State private var resumePrompt: (lines: [String], spoken: Int, total: Int)?
    @State private var showResumePrompt = false

    private var chapters: [Chapter] { repository.allChapters() }

    /// Deterministic "chapter of the day" from the chapters we have.
    private var daily: Chapter? {
        let all = chapters
        guard !all.isEmpty else { return nil }
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[(day - 1) % all.count]
    }

    var body: some View {
        ZStack(alignment: .top) {
            BreathingOrb(size: 300)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: 120)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let daily {
                        NavigationLink(value: daily.number) {
                            chapterBlock(daily)
                        }
                        .buttonStyle(.plain)
                        if Features.audio { listenRow(daily) }
                    }
                    Spacer(minLength: 24)
                    NavigationLink(value: 1) { continueCard }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, DSMetrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
        }
        .confirmationDialog(
            lang.pick("上次播放到一半", "Resume where you left off?"),
            isPresented: $showResumePrompt,
            titleVisibility: .visible
        ) {
            if let prompt = resumePrompt, let daily {
                Button(lang.pick(
                    "继续播放（第 \(prompt.spoken + 1)/\(prompt.total) 句）",
                    "Resume (line \(prompt.spoken + 1)/\(prompt.total))"
                )) {
                    start(daily, from: prompt.spoken)
                }
                Button(lang.pick("从头开始", "Start over")) {
                    start(daily, from: 0)
                }
                Button(lang.pick("取消", "Cancel"), role: .cancel) {}
            }
        }
    }

    private var header: some View {
        HStack {
            Text(lang.pick(chineseDate, englishDate))
                .font(DSFont.sans(12.5))
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(DSColor.accent).frame(width: 6, height: 6)
                Text(lang.pick("连读 1 天", "1 day streak")).font(DSFont.sans(12))
            }
            .foregroundStyle(DSColor.accent)
        }
        .padding(.top, 4)
    }

    private func chapterBlock(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.pick("每 日 一 章", "DAILY CHAPTER"))
                .font(DSFont.sans(11, weight: .medium))
                .tracking(6)
                .foregroundStyle(DSColor.accent)
                .padding(.top, 42)
            Text(chapter.title)
                .font(DSFont.serif(34, weight: .semibold))
                .foregroundStyle(DSColor.textPrimary)
                .padding(.top, 14)
            Text(lang.pick("第\(chapter.chineseNumeral)章", "Chapter \(chapter.number)"))
                .font(DSFont.serif(12.5))
                .foregroundStyle(DSColor.textFaint)
                .padding(.top, 7)
            Text(chapter.vernacular.first ?? "")
                .font(DSFont.sans(15.5))
                .lineSpacing(8)
                .foregroundStyle(DSColor.textBody)
                .padding(.top, 20)
            Text(chapter.firstOriginalLine)
                .font(DSFont.serif(13.5))
                .foregroundStyle(DSColor.textFaint)
                .padding(.top, 14)
        }
    }

    /// 聆听 follows the same access rule as reading: a chapter must be
    /// trial-unlocked or purchased before it can be read aloud. Gated tap
    /// routes into the chapter, where the trial gate / paywall lives.
    private func listenRow(_ chapter: Chapter) -> some View {
        let gated = trial.needsGate(chapter.number, purchased: store.isUnlocked)
        let active = speech.isActive(chapter: chapter.number) && speech.isPlaying
        return HStack(spacing: 13) {
            if gated {
                NavigationLink(value: chapter.number) {
                    listenLabel(icon: "lock", text: lang.pick("聆听今日", "Listen"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today-listen")

                Text(lang.pick("解锁本章后可聆听", "Unlock this chapter to listen"))
                    .font(DSFont.sans(12)).foregroundStyle(DSColor.textTertiary)
            } else {
                Button {
                    listen(chapter)
                } label: {
                    listenLabel(
                        icon: active ? "pause.fill" : "play.fill",
                        text: active ? lang.pick("朗读中", "Playing") : lang.pick("聆听今日", "Listen")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today-listen")
            }
        }
        .padding(.top, 26)
    }

    /// 今日 reads the chapter's 白话. A saved part-way point asks 继续/从头 first.
    private func listen(_ chapter: Chapter) {
        speech.rateScale = speechRate
        if speech.isActive(chapter: chapter.number, mode: .vernacular) {
            withAnimation(.easeOut(duration: 0.25)) {
                speech.toggle(chapter: chapter.number, mode: .vernacular, lines: chapter.vernacular)
            }
            return
        }
        if let saved = speech.savedProgress(chapter: chapter.number, mode: .vernacular) {
            resumePrompt = (chapter.vernacular, saved.spoken, saved.total)
            showResumePrompt = true
            return
        }
        start(chapter, from: 0)
    }

    private func start(_ chapter: Chapter, from index: Int) {
        withAnimation(.easeOut(duration: 0.25)) {
            speech.start(chapter: chapter.number, mode: .vernacular, lines: chapter.vernacular, startIndex: index)
        }
    }

    private func listenLabel(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(DSFont.sans(13.5, weight: .medium))
        }
        .foregroundStyle(DSColor.accentSoft)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(Capsule().strokeBorder(DSColor.accent.opacity(0.4), lineWidth: 1))
        .background(Capsule().fill(DSColor.accent.opacity(0.12)))
    }

    private var continueCard: some View {
        HStack(spacing: 13) {
            Text(lang.pick("一", "1"))
                .font(DSFont.serif(17))
                .foregroundStyle(DSColor.accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(DSColor.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.pick("继续上次 · 第一章 众妙之门", "Continue · Chapter 1"))
                    .font(DSFont.sans(11))
                    .foregroundStyle(DSColor.textTertiary)
                DSProgressBar(progress: 0.42)
            }
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(DSColor.textFaint)
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
    }

    private var chineseDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .chinese)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "U年 · MMMd"
        return formatter.string(from: Date())
    }

    private var englishDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}
