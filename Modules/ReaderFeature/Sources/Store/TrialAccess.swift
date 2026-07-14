import Foundation
import Observation

/// The reader's free-choice trial state: the set of chapters they've spent a
/// free read on (up to `ReaderProducts.freeReadLimit`). Persisted in
/// UserDefaults and observed by the reader + contents list so lock state and
/// the remaining count update live.
@MainActor
@Observable
final class TrialAccess {
    let limit: Int
    private(set) var unlocked: Set<Int>

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "trial.unlockedChapters"

    init(limit: Int = ReaderProducts.freeReadLimit, defaults: UserDefaults = .standard) {
        self.limit = limit
        self.defaults = defaults
        let stored = defaults.array(forKey: key) as? [Int] ?? []
        unlocked = Set(stored)
    }

    /// Free reads still available.
    var remaining: Int { max(0, limit - unlocked.count) }

    /// The chapter isn't accessible yet — show the gate (a free-read offer while
    /// reads remain, otherwise the paywall). Purchase clears all gates.
    func needsGate(_ chapter: Int, purchased: Bool) -> Bool {
        if purchased { return false }
        return !unlocked.contains(chapter)
    }

    /// A hard paywall: gated with no free reads left.
    func isLocked(_ chapter: Int, purchased: Bool) -> Bool {
        ReaderProducts.access.isLocked(chapter, unlocked: purchased, trialUnlocked: unlocked)
    }

    /// Spend a free read on this chapter. No-op once already spent or full.
    @discardableResult
    func unlock(_ chapter: Int) -> Bool {
        guard !unlocked.contains(chapter), unlocked.count < limit else { return false }
        unlocked.insert(chapter)
        defaults.set(unlocked.sorted(), forKey: key)
        return true
    }
}
