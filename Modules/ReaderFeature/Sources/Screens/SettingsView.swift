import DesignSystem
import SwiftUI

/// 设置 — appearance, reading size, 朗读 speed, and the daily reminder. Every
/// control here drives real state: theme + font scale + speech rate via
/// `@AppStorage`, the reminder via `ReminderScheduler`.
struct SettingsView: View {
    @AppStorage("theme") private var themeRaw = DSTheme.dark.rawValue
    @AppStorage("fontScale") private var fontScale = 1.0
    @AppStorage("speechRate") private var speechRate = 1.0
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @Environment(\.dismiss) private var dismiss

    private var themeBinding: Binding<DSTheme> {
        Binding(
            get: { DSTheme(rawValue: themeRaw) ?? .dark },
            set: { themeRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        appearanceCard
                        readingCard
                        speechCard
                        reminderCard
                    }
                    .padding(.horizontal, DSMetrics.screenPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("设置").font(DSFont.serif(22, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button("完成") { dismiss() }
                .font(DSFont.sans(14, weight: .medium))
                .foregroundStyle(DSColor.accent)
                .accessibilityIdentifier("settings-done")
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var appearanceCard: some View {
        card("外观") {
            DSSegmentedControl(
                selection: themeBinding,
                options: DSTheme.allCases.map { ($0, $0.label) }
            )
        }
    }

    private var readingCard: some View {
        card("正文字号") {
            VStack(alignment: .leading, spacing: 8) {
                Slider(value: $fontScale, in: 0.85 ... 1.3, step: 0.05)
                    .tint(DSColor.accent)
                Text("示例：上善若水，水善利万物而不争。")
                    .font(DSFont.sans(15.5 * fontScale))
                    .foregroundStyle(DSColor.textBody)
            }
        }
    }

    private var speechCard: some View {
        card("朗读语速") {
            VStack(alignment: .leading, spacing: 6) {
                Slider(value: $speechRate, in: 0.7 ... 1.3, step: 0.1)
                    .tint(DSColor.accent)
                HStack {
                    Text("慢").font(DSFont.sans(11)).foregroundStyle(DSColor.textFaint)
                    Spacer()
                    Text(speedLabel).font(DSFont.sans(11)).foregroundStyle(DSColor.textTertiary)
                    Spacer()
                    Text("快").font(DSFont.sans(11)).foregroundStyle(DSColor.textFaint)
                }
            }
        }
    }

    private var reminderCard: some View {
        card("每日提醒") {
            VStack(spacing: 14) {
                Toggle(isOn: $reminderOn) {
                    Text("开启每日提醒").font(DSFont.sans(14)).foregroundStyle(DSColor.textBody)
                }
                .tint(DSColor.accent)
                .accessibilityIdentifier("settings-reminder")
                .onChange(of: reminderOn) { _, on in applyReminder(on: on, hour: reminderHour) }

                if reminderOn {
                    Stepper(value: $reminderHour, in: 6 ... 23) {
                        Text("每天 \(String(format: "%02d", reminderHour)):00")
                            .font(DSFont.sans(13)).foregroundStyle(DSColor.textSecondary)
                    }
                    .onChange(of: reminderHour) { _, hour in applyReminder(on: reminderOn, hour: hour) }
                }
            }
        }
    }

    private var speedLabel: String {
        switch speechRate {
        case ..<0.9: "较慢"
        case 0.9 ... 1.1: "正常"
        default: "较快"
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
