import Purchases

/// 常道 monetization: a single non-consumable that unlocks all 81 chapters.
/// Free preview is any 5 chapters (reader's choice); the rest need a purchase.
enum ReaderProducts {
    /// ⚠️ Must match the IAP product id registered in App Store Connect.
    static let fullAccess = "com.rockhammerlabs.daodejing.fullaccess"
    static let all = [fullAccess]
    /// Free reads before a purchase is required.
    static let freeReadLimit = 5
    static let access = AccessPolicy(freeLimit: freeReadLimit)
}
