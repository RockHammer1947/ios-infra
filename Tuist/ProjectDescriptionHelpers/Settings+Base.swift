import Foundation
import ProjectDescription

/// Single source of truth for everything shared across apps and modules.
/// Changing a value here propagates to every target in the monorepo —
/// this is the heart of the "reusable infra".
public enum Constants {
    /// Reverse-DNS organization prefix. Bundle IDs are `"\(organizationIdentifier).<app>"`,
    /// so the app ships as `com.rockhammerlabs.daodejing`.
    public static let organizationIdentifier = "com.rockhammerlabs"

    /// Shown in Xcode's project organization field.
    public static let organizationName = "RockHammer Labs"

    /// Every app/module targets these platforms (native SwiftUI, not Catalyst).
    public static let destinations: Destinations = [.iPhone, .iPad, .mac]

    /// Minimum OS versions. Bump deliberately.
    public static let deploymentTargets: DeploymentTargets = .multiplatform(iOS: "17.0", macOS: "14.0")

    public static let swiftVersion = "6.0"
}

public extension Settings {
    /// Build settings applied to every target. Version numbers are overridable
    /// at build time via xcargs (CI injects the build number from the run id).
    static var base: Settings {
        var settings: SettingsDictionary = [
            "SWIFT_VERSION": SettingValue(stringLiteral: Constants.swiftVersion),
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            // Xcode 16's explicitly-built modules can start compiling a
            // consumer before a dependency framework's .swiftmodule is
            // ready ("no such module"). Fall back to implicit modules,
            // which the build system orders correctly.
            "SWIFT_ENABLE_EXPLICIT_MODULES": "NO",
        ]

        // Real-device signing without committing a Team ID: export
        // DEVELOPMENT_TEAM=XXXXXXXXXX before `tuist generate` and it's baked
        // into the project (durable across regeneration). Absent on CI
        // (simulator) and unset for the match-based release lane, so neither
        // is affected.
        if let team = ProcessInfo.processInfo.environment["DEVELOPMENT_TEAM"], !team.isEmpty {
            settings["DEVELOPMENT_TEAM"] = .string(team)
        }

        return .settings(
            base: settings,
            configurations: [
                .debug(name: "Debug"),
                .release(name: "Release"),
            ]
        )
    }
}
