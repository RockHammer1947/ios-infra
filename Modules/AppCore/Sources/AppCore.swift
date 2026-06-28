import Foundation
import OSLog

/// Cross-app foundation: a place for logging, configuration and dependency
/// stubs that every app shares. Intentionally minimal — extend per product.
public enum AppCore {
    /// Marketing version surfaced to placeholder UI; real value comes from the
    /// bundle at runtime in shipping apps.
    public static let version = "0.1.0"

    /// A namespaced logger every module/app can reuse.
    public static func logger(category: String) -> Logger {
        Logger(subsystem: "com.rockhammerlabs.appcore", category: category)
    }
}
