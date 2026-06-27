#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif
import SwiftUI

public extension Color {
    /// Create a color from a 24-bit RGB hex value, e.g. `Color(hex: 0x7FAE96)`.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// A color that resolves to `light` or `dark` based on the active appearance,
    /// so the whole palette adapts automatically to the color scheme.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return isDark ? NSColor(dark) : NSColor(light)
            })
        #else
            return dark
        #endif
    }
}
