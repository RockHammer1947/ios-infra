import DaodejingContent
import DesignSystem
import Purchases
import StoreKit
import SwiftUI

/// The paywall shown when a gated chapter is opened: unlock all 81 chapters.
struct PaywallCard: View {
    @Environment(StoreModel.self) private var store
    @Environment(\.appLanguage) private var lang
    @State private var working = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock")
                .font(.system(size: 26))
                .foregroundStyle(DSColor.accent)

            VStack(spacing: 6) {
                Text(lang.pick("解锁全本", "Unlock the full text"))
                    .font(DSFont.serif(22, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(lang.pick(
                    "免费试读已用完 · 购买后畅读全部 81 章，永久离线",
                    "Free preview used up · read all 81 chapters, forever, offline"
                ))
                .font(DSFont.sans(12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(DSColor.textTertiary)
            }

            Button {
                Task { await buy() }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().controlSize(.small) }
                    Text(buttonTitle)
                        .font(DSFont.sans(14.5, weight: .medium))
                }
                .foregroundStyle(DSColor.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(DSColor.accent))
            }
            .buttonStyle(.plain)
            .disabled(working || store.products.isEmpty)

            Button(lang.pick("恢复购买", "Restore purchase")) {
                Task { await store.restore() }
            }
            .font(DSFont.sans(12))
            .foregroundStyle(DSColor.textTertiary)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
        .accessibilityIdentifier("paywall")
    }

    private var buttonTitle: String {
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
