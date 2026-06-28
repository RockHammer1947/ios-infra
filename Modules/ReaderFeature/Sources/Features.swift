/// Compile-time flags for features that aren't finished yet. Their entry points
/// stay hidden so the shipped build has no dead buttons (App Review 2.1).
/// M9 audio and M8 settings have landed.
enum Features {
    static let audio = true
    static let settings = true
}
