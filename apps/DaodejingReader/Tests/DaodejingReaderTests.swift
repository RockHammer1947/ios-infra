import Testing
@testable import DaodejingReader

@Suite("DaodejingReader app")
struct DaodejingReaderTests {
    @Test("App type is available")
    func appExists() {
        _ = DaodejingReaderApp.self
        #expect(Bool(true))
    }
}
