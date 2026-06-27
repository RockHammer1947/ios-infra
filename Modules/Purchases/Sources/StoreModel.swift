import Observation
import StoreKit

/// Reusable StoreKit 2 store: loads products, runs purchases/restore, and tracks
/// entitlements. `isUnlocked` is true once any of the configured products is owned.
@MainActor
@Observable
public final class StoreModel {
    public private(set) var products: [Product] = []
    public private(set) var purchasedIDs: Set<String> = []
    public private(set) var isLoading = false

    private let productIDs: [String]
    private var updatesTask: Task<Void, Never>?

    public init(productIDs: [String]) {
        self.productIDs = productIDs
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case let .verified(transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    /// True when at least one configured product is entitled.
    public var isUnlocked: Bool {
        !purchasedIDs.isDisjoint(with: Set(productIDs))
    }

    /// Localized price of the primary product (e.g. "$6.00" / "¥6.00").
    public var primaryDisplayPrice: String? {
        products.first?.displayPrice
    }

    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        products = await (try? Product.products(for: productIDs)) ?? []
        await refresh()
    }

    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case let .success(verification):
            if case let .verified(transaction) = verification {
                await transaction.finish()
                await refresh()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    public func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    public func refresh() async {
        var ids = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement {
                ids.insert(transaction.productID)
            }
        }
        purchasedIDs = ids
    }
}
