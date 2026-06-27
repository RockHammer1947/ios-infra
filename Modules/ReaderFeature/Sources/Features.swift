/// Compile-time flags for features that aren't finished yet. Their entry points
/// stay hidden so the shipped build has no dead buttons (App Review 2.1). Flip
/// each to `true` as the milestone lands: M9 audio (done), M8 settings.
enum Features {
    static let audio = true
    static let settings = false
}
