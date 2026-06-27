@testable import DaodejingReader
import Testing

@Suite("DaodejingReader smoke tests")
struct DaodejingReaderTests {
    @Test("Root view is constructible")
    func rootViewConstructs() {
        _ = RootView()
        #expect(Bool(true))
    }
}
