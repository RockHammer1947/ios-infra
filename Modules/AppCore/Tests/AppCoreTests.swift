@testable import AppCore
import Testing

@Suite("AppCore")
struct AppCoreTests {
    @Test("Version is non-empty")
    func versionIsNotEmpty() {
        #expect(!AppCore.version.isEmpty)
    }

    @Test("Logger is created with category")
    func loggerCreates() {
        _ = AppCore.logger(category: "test")
        #expect(Bool(true))
    }
}
