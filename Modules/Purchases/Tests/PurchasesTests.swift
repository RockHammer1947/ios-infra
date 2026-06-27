import Testing
@testable import Purchases

@Suite("Purchases")
struct PurchasesTests {
    @Test("Free items stay open; gated items unlock only after purchase")
    func gating() {
        let policy = AccessPolicy(freeIDs: [1, 2, 3])
        // Free chapters are never locked.
        #expect(policy.isLocked(1, unlocked: false) == false)
        #expect(policy.isLocked(3, unlocked: false) == false)
        // Gated chapters are locked until unlocked.
        #expect(policy.isLocked(8, unlocked: false) == true)
        #expect(policy.isLocked(81, unlocked: false) == true)
        // Purchasing unlocks everything.
        #expect(policy.isLocked(8, unlocked: true) == false)
        #expect(policy.isLocked(81, unlocked: true) == false)
    }
}
