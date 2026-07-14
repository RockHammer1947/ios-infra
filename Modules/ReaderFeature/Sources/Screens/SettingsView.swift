import Audio
import DaodejingContent
import DesignSystem
import SwiftUI

/// 设置 — language, appearance, reading size, 朗读 speed + voice, and the daily
/// reminder. Every control drives real state via `@AppStorage`, the reminder
/// via `ReminderScheduler`. The speech engine itself is not user-facing: the
/// bundled MeloTTS voice is simply how the app reads.
struct SettingsView: View {
    @AppStorage("theme") private var themeRaw = DSTheme.dark.rawValue
    @AppStorage("contentLanguage") private var langRaw = ContentLanguage.deviceDefault.rawValue
    @AppStorage("fontScale") private var fontScale = 1.0
    @AppStorage("speechRate") private var speechRate = 1.0
    @AppStorage("ttsVoice.zh") private var voiceZhId = TTSVoice.fallback(for: .zh).id
    @AppStorage("ttsVoice.en") private var voiceEnId = TTSVoice.fallback(for: .en).id
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.appLanguage) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var audition = VoiceAudition()

    private var themeBinding: Binding<DSTheme> {
        Binding(
            get: { DSTheme(rawValue: themeRaw) ?? .dark },
            set: { themeRaw = $0.rawValue }
        )
    }

    private var langBinding: Binding<ContentLanguage> {
        Binding(
            get: { ContentLanguage(rawValue: langRaw) ?? .zh },
            set: { langRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        languageCard
                        appearanceCard
                        readingCard
                        speechCard
                        voiceCard
                        reminderCard
                    }
                    .padding(.horizontal, DSMetrics.screenPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
        }
        .onDisappear { audition.stop() }
    }

    private var header: some View {
        HStack {
            Text(lang.pick("设置", "Settings")).font(DSFont.serif(22, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button(lang.pick("完成", "Done")) { dismiss() }
                .font(DSFont.sans(14, weight: .medium))
                .foregroundStyle(DSColor.accent)
                .accessibilityIdentifier("settings-done")
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var languageCard: some View {
        card(lang.pick("语言", "Language")) {
            DSSegmentedControl(
                selection: langBinding,
                options: ContentLanguage.allCases.map { ($0, $0.displayName) }
            )
        }
    }

    private var appearanceCard: some View {
        card(lang.pick("外观", "Appearance")) {
            DSSegmentedControl(
                selection: themeBinding,
                options: DSTheme.allCases.map { ($0, $0.label) }
            )
        }
    }

    private var readingCard: some View {
        card(lang.pick("正文字号", "Text size")) {
            VStack(alignment: .leading, spacing: 8) {
                Slider(value: $fontScale, in: 0.85 ... 1.3, step: 0.05)
                    .tint(DSColor.accent)
                Text(lang.pick("示例：上善若水，水善利万物而不争。", "Sample: The highest good is like water."))
                    .font(DSFont.sans(15.5 * fontScale))
                    .foregroundStyle(DSColor.textBody)
            }
        }
    }

    private var speechCard: some View {
        card(lang.pick("朗读语速", "Reading speed")) {
            VStack(alignment: .leading, spacing: 6) {
                Slider(value: $speechRate, in: 0.7 ... 1.3, step: 0.1)
                    .tint(DSColor.accent)
                HStack {
                    Text(lang.pick("慢", "Slow")).font(DSFont.sans(11)).foregroundStyle(DSColor.textFaint)
                    Spacer()
                    Text(speedLabel).font(DSFont.sans(11)).foregroundStyle(DSColor.textTertiary)
                    Spacer()
                    Text(lang.pick("快", "Fast")).font(DSFont.sans(11)).foregroundStyle(DSColor.textFaint)
                }
            }
        }
    }

    // MARK: - 朗读音色

    /// Content language currently being read (drives which voices show).
    private var contentLang: TTSLanguage { langRaw == "en" ? .en : .zh }
    private var selectedVoiceId: String { contentLang == .en ? voiceEnId : voiceZhId }

    private func selectVoice(_ voice: TTSVoice) {
        if contentLang == .en { voiceEnId = voice.id } else { voiceZhId = voice.id }
    }

    /// 朗读音色 — pick the reading voice for the current content language.
    /// Every row auditions a short on-device sample so the choice is by ear.
    private var voiceCard: some View {
        card(lang.pick("朗读音色", "Reading voice")) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(TTSVoice.all(for: contentLang)) { voice in
                    voiceRow(voice)
                }
                Text(lang.pick("点 ▶ 试听 · 点名称选用", "Tap ▶ to preview · tap a name to select"))
                    .font(DSFont.sans(11)).foregroundStyle(DSColor.textFaint)
                    .padding(.top, 8)
            }
        }
    }

    private func voiceRow(_ voice: TTSVoice) -> some View {
        HStack(spacing: 12) {
            Button {
                // Don't audition over chapter playback.
                if speech.isPlaying { speech.pause() }
                audition.toggle(voice, language: contentLang)
            } label: {
                Image(systemName: audition.playingVoiceID == voice.id ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 21))
                    .foregroundStyle(DSColor.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice-audition-\(voice.id)")

            Button { selectVoice(voice) } label: {
                HStack {
                    Text(voice.name(contentLang))
                        .font(DSFont.sans(14))
                        .foregroundStyle(DSColor.textBody)
                    Spacer()
                    if voice.id == selectedVoiceId {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DSColor.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice-\(voice.id)")
        }
        .padding(.vertical, 8)
    }

    private var reminderCard: some View {
        card(lang.pick("每日提醒", "Daily reminder")) {
            VStack(spacing: 14) {
                Toggle(isOn: $reminderOn) {
                    Text(lang.pick("开启每日提醒", "Enable daily reminder")).font(DSFont.sans(14)).foregroundStyle(DSColor.textBody)
                }
                .tint(DSColor.accent)
                .accessibilityIdentifier("settings-reminder")
                .onChange(of: reminderOn) { _, on in applyReminder(on: on, hour: reminderHour) }

                if reminderOn {
                    Stepper(value: $reminderHour, in: 6 ... 23) {
                        Text(lang.pick(
                            "每天 \(String(format: "%02d", reminderHour)):00",
                            "Every day at \(String(format: "%02d", reminderHour)):00"
                        ))
                        .font(DSFont.sans(13)).foregroundStyle(DSColor.textSecondary)
                    }
                    .onChange(of: reminderHour) { _, hour in applyReminder(on: reminderOn, hour: hour) }
                }
            }
        }
    }

    private var speedLabel: String {
        switch speechRate {
        case ..<0.9: lang.pick("较慢", "Slow")
        case 0.9 ... 1.1: lang.pick("正常", "Normal")
        default: lang.pick("较快", "Fast")
        }
    }

    private func applyReminder(on: Bool, hour: Int) {
        if on {
            ReminderScheduler.enable(hour: hour)
        } else {
            ReminderScheduler.disable()
        }
    }

    @ViewBuilder
    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DSFont.sans(11.5, weight: .medium)).tracking(2)
                .foregroundStyle(DSColor.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
    }
}
