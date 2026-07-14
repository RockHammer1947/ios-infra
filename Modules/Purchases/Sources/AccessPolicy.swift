import Foundation

/// Decides whether a numbered item (here, a chapter) is locked behind a
/// purchase. Pure and deterministic — the unit-tested core of the paywall.
///
/// The model is "N free reads, reader's choice": the reader may open up to
/// `freeLimit` chapters for free (whichever they pick). A chapter is locked
/// only once those free reads are used up and this one wasn't among them.
public struct AccessPolicy: Sendable, Equatable {
    /// How many chapters may be opened for free before a purchase is required.
    public let freeLimit: Int

    public init(freeLimit: Int) {
        self.freeLimit = freeLimit
    }

    /// Locked (purchase required) when the user hasn't bought the full unlock,
    /// hasn't already spent a free read on this chapter, and has no free reads
    /// left to spend.
    public func isLocked(_ id: Int, unlocked: Bool, trialUnlocked: Set<Int>) -> Bool {
        if unlocked { return false }
        if trialUnlocked.contains(id) { return false }
        return trialUnlocked.count >= freeLimit
    }
}
