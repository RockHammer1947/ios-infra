import DaodejingContent
import DesignSystem
import Purchases
import SwiftUI

/// Shown when a reader opens a not-yet-unlocked chapter and still has free
/// reads left: spend one on this chapter, or buy the full unlock.
struct TrialGateCard: View {
    let remaining: Int
    /// Spend a free read on this chapter and reveal it.
    let onRead: () -> Void

    @Environment(StoreModel.self) private var store
    @Environment(\.appLanguage) private var lang
    @State private var working = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 26))
                .foregroundStyle(DSColor.accent)

            VStack(spacing: 6) {
                Text(lang.pick("免费试读", "Free preview"))
                    .font(DSFont.serif(22, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(lang.pick("阅读本章将用掉 1 次试读 · 还剩 \(remaining) 次", "Reading this uses 1 free read · \(remaining) left"))
                    .font(DSFont.sans(12.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DSColor.textTertiary)
            }

            Button(action: onRead) {
                Text(lang.pick("阅读本章", "Read this chapter"))
                    .font(DSFont.sans(14.5, weight: .medium))
                    .foregroundStyle(DSColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(DSColor.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trial-read")

            Button {
                Task { await buy() }
            } label: {
                HStack(spacing: 6) {
                    if working { ProgressView().controlSize(.small) }
                    Text(unlockTitle)
                        .font(DSFont.sans(12.5, weight: .medium))
                }
                .foregroundStyle(DSColor.accentSoft)
            }
            .disabled(working || store.products.isEmpty)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
        .accessibilityIdentifier("trial-gate")
    }

    private var unlockTitle: String {
        let base = lang.pick("解锁全本", "Unlock all")
        if let price = store.primaryDisplayPrice { return "\(base) · \(price)" }
        return base
    }

    private func buy() async {
        guard let product = store.products.first else { return }
        working = true
        defer { working = false }
        _ = await store.purchase(product)
    }
}
