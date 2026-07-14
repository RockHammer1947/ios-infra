import ProjectDescription

// Global Tuist configuration shared by every project in the workspace.
let config = Config(
    // CI pins Xcode 16.x; local dev may run a newer Xcode (e.g. 26.x).
    compatibleXcodeVersions: [.upToNextMajor("16.0"), .upToNextMajor("26.0")]
)
