import ProjectDescription

// Global Tuist configuration shared by every project in the workspace.
let config = Config(
    compatibleXcodeVersions: .upToNextMajor("16.0"),
    generationOptions: .options(
        // Keep generated build settings clean and explicit.
        enforceExplicitDependencies: true
    )
)
