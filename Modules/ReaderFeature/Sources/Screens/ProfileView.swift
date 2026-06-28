import DaodejingContent
import DesignSystem
import Library
import SwiftData
import SwiftUI

/// 我的 — reading progress (圆满进度 enso), a few stats, and 设置.
struct ProfileView: View {
    let repository: any ContentRepository
    @Query(filter: #Predicate<ChapterProgress> { $0.fraction >= 0.95 }) private var read: [ChapterProgress]
    @Query private var marks: [Mark]
    @State private var showSettings = false

    private var readCount: Int { read.count }
    private var noteCount: Int { marks.filter { $0.kind == .highlight || $0.kind == .note }.count }
    private var bookmarkCount: Int { marks.filter { $0.kind == .bookmark }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("我的").font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                .padding(.top, 10)

            VStack(spacing: 14) {
                EnsoProgress(total: 81, read: readCount)
                    .frame(width: 180, height: 180)
                Text("通读 \(readCount) / 81").font(DSFont.sans(13)).foregroundStyle(DSColor.textSecondary)
                Text("八十一点连成一圆，读毕则一点亮起")
                    .font(DSFont.sans(11.5)).foregroundStyle(DSColor.textFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)

            statsRow
                .padding(.top, 28)

            Spacer()

            if Features.settings {
                settingsRow
                    .padding(.bottom, 96)
            } else {
                Spacer().frame(height: 96)
            }
        }
        .padding(.horizontal, DSMetrics.screenPadding)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("已读", readCount)
            stat("笔记", noteCount)
            stat("书签", bookmarkCount)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 5) {
            Text("\(value)").font(DSFont.serif(22, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
            Text(label).font(DSFont.sans(11.5)).foregroundStyle(DSColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
    }

    private var settingsRow: some View {
        Button { showSettings = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "gearshape").foregroundStyle(DSColor.accentSoft)
                Text("设置").font(DSFont.sans(14)).foregroundStyle(DSColor.textBody)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(DSColor.textFaint)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
            .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-settings")
    }
}
