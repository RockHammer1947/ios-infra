@testable import DesignSystem
import Testing

@Suite("DesignSystem")
struct DesignSystemTests {
    @Test("Spacing and corner radius are positive")
    func tokensArePositive() {
        #expect(DesignSystem.spacing > 0)
        #expect(DesignSystem.cornerRadius > 0)
    }
}
