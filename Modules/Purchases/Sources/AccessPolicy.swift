import Foundation

/// Decides which numbered items (here, chapters) are free vs gated behind a
/// purchase. Pure and deterministic — the unit-tested core of the paywall.
public struct AccessPolicy: Sendable, Equatable {
    public let freeIDs: Set<Int>

    public init(freeIDs: Set<Int>) {
        self.freeIDs = freeIDs
    }

    /// An item is locked when the user hasn't unlocked and it isn't in the free set.
    public func isLocked(_ id: Int, unlocked: Bool) -> Bool {
        if unlocked { return false }
        return !freeIDs.contains(id)
    }
}
