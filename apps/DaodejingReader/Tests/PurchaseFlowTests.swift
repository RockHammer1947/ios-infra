import Foundation
import Purchases
import StoreKit
import StoreKitTest
import Testing
@testable import DaodejingReader

/// The app's purchase flow, end to end against its own StoreKit configuration:
/// load → $2.99 price → purchase → entitlement.
///
/// ⚠️ Run these from Xcode (Cmd+U): the CLI `xcodebuild` does not push StoreKit
/// test configurations to the simulator, so SKTestSession silently serves
/// nothing there — the suite is opt-in via RUN_STOREKIT_FLOW_TESTS=1 to keep
/// CI green. The always-on StoreKitConfigurationTests below pins the config
/// file itself.
@Suite(
    "Purchase flow",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_STOREKIT_FLOW_TESTS"] == "1")
)
struct PurchaseFlowTests {
    private static let productID = "com.rockhammerlabs.daodejing.fullaccess"

    /// StoreKit/Configuration.storekit, located relative to this source file
    /// (tests run on the simulator, which shares the host filesystem).
    private static var configurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // DaodejingReader/
            .appendingPathComponent("StoreKit/Configuration.storekit")
    }

    @Test("Product loads from the configuration at $2.99")
    @MainActor
    func productLoadsWithPrice() async throws {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = StoreModel(productIDs: [Self.productID])
        await store.loadProducts()

        #expect(store.products.count == 1)
        let product = try #require(store.products.first)
        #expect(product.id == Self.productID)
        #expect(product.price == 2.99)
        #expect(store.primaryDisplayPrice?.contains("2.99") == true)
    }

    @Test("Purchasing unlocks; entitlement survives a fresh store")
    @MainActor
    func purchaseUnlocks() async throws {
        let session = try SKTestSession(contentsOf: Self.configurationURL)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = StoreModel(productIDs: [Self.productID])
        await store.loadProducts()
        let product = try #require(store.products.first)

        #expect(!store.isUnlocked)
        let bought = await store.purchase(product)
        #expect(bought)
        #expect(store.isUnlocked)

        // A fresh model (new launch) sees the entitlement after refresh.
        let fresh = StoreModel(productIDs: [Self.productID])
        await fresh.refresh()
        #expect(fresh.isUnlocked)
    }
}

/// Pins the shape of the app's StoreKit configuration file itself.
@Suite("StoreKit configuration")
struct StoreKitConfigurationTests {
    @Test("Full-access product is a $2.99 non-consumable with the registered id")
    func configurationMatchesProduct() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Configuration.storekit")
        let data = try Data(contentsOf: url)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try #require(json["products"] as? [[String: Any]])
        #expect(products.count == 1)

        let product = try #require(products.first)
        #expect(product["productID"] as? String == "com.rockhammerlabs.daodejing.fullaccess")
        #expect(product["displayPrice"] as? String == "2.99")
        #expect(product["type"] as? String == "NonConsumable")
    }
}
