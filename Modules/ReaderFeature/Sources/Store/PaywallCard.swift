import DesignSystem
import Purchases
import StoreKit
import SwiftUI

/// The paywall shown when a gated chapter is opened: unlock all 81 chapters.
struct PaywallCard: View {
    @Environment(StoreModel.self) private var store
    @State private var working = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock")
                .font(.system(size: 26))
                .foregroundStyle(DSColor.accent)

            VStack(spacing: 6) {
                Text("解锁全本")
                    .font(DSFont.serif(22, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text("免费试读前三章 · 购买后畅读全部 81 章，永久离线")
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

            Button("恢复购买") {
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
        if let price = store.primaryDisplayPrice { return "解锁全本 · \(price)" }
        return "解锁全本"
    }

    private func buy() async {
        guard let product = store.products.first else { return }
        working = true
        defer { working = false }
        _ = await store.purchase(product)
    }
}
