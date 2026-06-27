import DaodejingContent
import DesignSystem
import SwiftUI

/// 我的 — reading progress (圆满进度 enso) and an entry to 设置.
struct ProfileView: View {
    let repository: any ContentRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("我的").font(DSFont.serif(26, weight: .semibold)).foregroundStyle(DSColor.textPrimary)
                .padding(.top, 10)

            VStack(spacing: 14) {
                EnsoProgress(total: 81, read: 0)
                    .frame(width: 180, height: 180)
                Text("通读 0 / 81").font(DSFont.sans(13)).foregroundStyle(DSColor.textSecondary)
                Text("八十一点连成一圆，读毕则一点亮起")
                    .font(DSFont.sans(11.5)).foregroundStyle(DSColor.textFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 36)

            Spacer()

            settingsRow
                .padding(.bottom, 96)
        }
        .padding(.horizontal, DSMetrics.screenPadding)
    }

    private var settingsRow: some View {
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
}
