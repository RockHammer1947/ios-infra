import SwiftUI

/// Semantic color palette for 常道, derived from the design spec.
/// Every token adapts between the dark (primary) and 宣纸 light themes.
public enum DSColor {
    // Surfaces
    public static let background = Color.adaptive(light: Color(hex: 0xF1EFE4), dark: Color(hex: 0x111312))
    public static let surface = Color.adaptive(light: Color(hex: 0xFFFFFF, opacity: 0.5), dark: Color(hex: 0x1B1E1C))
    public static let card = Color.adaptive(light: Color(hex: 0x4E7160, opacity: 0.07), dark: Color(hex: 0xFFFFFF, opacity: 0.035))
    public static let drawer = Color.adaptive(light: Color(hex: 0xE7E3D6), dark: Color(hex: 0x1B1F1C))
    public static let frame = Color.adaptive(light: Color(hex: 0xCFC7B4), dark: Color(hex: 0x070807))

    // Accent — 竹青 (bamboo green)
    public static let accent = Color.adaptive(light: Color(hex: 0x4E7160), dark: Color(hex: 0x7FAE96))
    public static let accentSoft = Color.adaptive(light: Color(hex: 0x4E7160), dark: Color(hex: 0x9FC9B4))
    public static let accentBright = Color.adaptive(light: Color(hex: 0x4E7160), dark: Color(hex: 0xBFE0CF))
    public static let accentWash = accent.opacity(0.12)

    // Text
    public static let textPrimary = Color.adaptive(light: Color(hex: 0x1F2A23), dark: Color(hex: 0xF3F1E8))
    public static let textBody = Color.adaptive(light: Color(hex: 0x3D473F), dark: Color(hex: 0xC7CABF))
    public static let textSecondary = Color.adaptive(light: Color(hex: 0x7A8278), dark: Color(hex: 0x9DA097))
    public static let textTertiary = Color.adaptive(light: Color(hex: 0x8A9186), dark: Color(hex: 0x7E827A))
    public static let textFaint = Color.adaptive(light: Color(hex: 0x9AA095), dark: Color(hex: 0x5E625B))

    // Hairlines / separators
    public static let separator = Color.adaptive(light: Color(hex: 0x26302A, opacity: 0.08), dark: Color(hex: 0xFFFFFF, opacity: 0.06))
    public static let border = Color.adaptive(light: Color(hex: 0x26302A, opacity: 0.10), dark: Color(hex: 0xFFFFFF, opacity: 0.08))
}
