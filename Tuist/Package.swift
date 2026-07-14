// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    // Controls how external SPM dependencies are integrated by Tuist.
    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

// External Swift Package Manager dependencies for the whole monorepo.
// Add packages here once and reference them from any app/module via
// `.external(name: "...")`.
let package = Package(
    name: "iOSInfra",
    dependencies: []
)
