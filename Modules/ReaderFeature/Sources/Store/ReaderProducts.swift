import Purchases

/// 常道 monetization: a single non-consumable that unlocks all 81 chapters.
/// Free preview is chapters 1–3; everything else is gated.
enum ReaderProducts {
    /// ⚠️ Must match the IAP product id registered in App Store Connect.
    static let fullAccess = "com.example.daodejing.fullaccess"
    static let all = [fullAccess]
    static let access = AccessPolicy(freeIDs: [1, 2, 3])
}
