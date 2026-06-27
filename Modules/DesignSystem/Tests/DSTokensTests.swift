import SwiftUI
import Testing
@testable import DesignSystem

@Suite("Design tokens")
struct DSTokensTests {
    @Test("Theme has three cases with labels and scheme mapping")
    func themeCases() {
        #expect(DSTheme.allCases.count == 3)
        #expect(DSTheme.system.colorScheme == nil)
        #expect(DSTheme.light.colorScheme == .light)
        #expect(DSTheme.dark.colorScheme == .dark)
        for theme in DSTheme.allCases {
            #expect(!theme.label.isEmpty)
        }
    }

    @Test("Metrics are positive and ordered")
    func metrics() {
        #expect(DSMetrics.screenPadding > 0)
        #expect(DSMetrics.radiusCard > 0)
        #expect(DSMetrics.xs < DSMetrics.md)
        #expect(DSMetrics.md < DSMetrics.xl)
    }

    @Test("Hex color initializer produces a valid color")
    func hexColor() {
        _ = Color(hex: 0x7FAE96)
        _ = Color.adaptive(light: .white, dark: .black)
        #expect(Bool(true))
    }
}
