import Testing
@testable import Purchases

@Suite("Purchases")
struct PurchasesTests {
    @Test("Free-choice trial: N free reads, then a purchase is required")
    func gating() {
        let policy = AccessPolicy(freeLimit: 5)
        // Purchasing unlocks everything, regardless of trial state.
        #expect(policy.isLocked(8, unlocked: true, trialUnlocked: []) == false)
        #expect(policy.isLocked(81, unlocked: true, trialUnlocked: [1, 2, 3, 4, 5]) == false)
        // Free reads still available → nothing is locked (any chapter is openable).
        #expect(policy.isLocked(8, unlocked: false, trialUnlocked: []) == false)
        #expect(policy.isLocked(8, unlocked: false, trialUnlocked: [1, 2, 3, 4]) == false)
        // Free reads used up: a chapter already spent on stays open…
        #expect(policy.isLocked(3, unlocked: false, trialUnlocked: [3, 7, 9, 20, 42]) == false)
        // …but a new chapter is now locked.
        #expect(policy.isLocked(8, unlocked: false, trialUnlocked: [3, 7, 9, 20, 42]) == true)
    }
}
