import Audio
import DaodejingContent
import DesignSystem
import SwiftUI

/// 今日 — the daily chapter, framed by a breathing orb.
struct TodayView: View {
    let repository: any ContentRepository
    @Environment(SpeechPlayer.self) private var speech

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
    }

    private var header: some View {
        HStack {
            Text(chineseDate)
                .font(DSFont.sans(12.5))
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(DSColor.accent).frame(width: 6, height: 6)
                Text("连读 1 天").font(DSFont.sans(12))
            }
            .foregroundStyle(DSColor.accent)
        }
        .padding(.top, 4)
    }

    private func chapterBlock(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("每 日 一 章")
                .font(DSFont.sans(11, weight: .medium))
                .tracking(6)
                .foregroundStyle(DSColor.accent)
                .padding(.top, 42)
            Text(chapter.title)
                .font(DSFont.serif(34, weight: .semibold))
                .foregroundStyle(DSColor.textPrimary)
                .padding(.top, 14)
            Text("第\(chapter.chineseNumeral)章")
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

    private func listenRow(_ chapter: Chapter) -> some View {
        let active = speech.isActive(chapter: chapter.number) && speech.isPlaying
        return HStack(spacing: 13) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    speech.toggle(chapter: chapter.number, lines: chapter.vernacular)
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: active ? "pause.fill" : "play.fill").font(.system(size: 11))
                    Text(active ? "朗读中" : "聆听今日").font(DSFont.sans(13.5, weight: .medium))
                }
                .foregroundStyle(DSColor.accentSoft)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(Capsule().strokeBorder(DSColor.accent.opacity(0.4), lineWidth: 1))
                .background(Capsule().fill(DSColor.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today-listen")

            Text("系统人声朗读").font(DSFont.sans(12)).foregroundStyle(DSColor.textTertiary)
        }
        .padding(.top, 26)
    }

    private var continueCard: some View {
        HStack(spacing: 13) {
            Text("一")
                .font(DSFont.serif(17))
                .foregroundStyle(DSColor.accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(DSColor.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: 6) {
                Text("继续上次 · 第一章 众妙之门")
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
}
