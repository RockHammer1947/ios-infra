import SwiftUI

/// Typography for 常道.
///
/// The design calls for 思源宋体 (Noto Serif SC) on titles & 原文, and 思源黑体
/// (Noto Sans SC) on body & UI. Until the bundled font subset is added under
/// `Resources/Fonts`, these map to the system serif / sans designs (which read
/// very close on CJK: Songti / PingFang). Swapping to the bundled faces is a
/// single change in `serif(_:weight:)` / `sans(_:weight:)`.
public enum DSFont {
    /// Serif — chapter titles, 原文, ornamental numerals.
    public static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Sans — body copy, controls, labels.
    public static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // Semantic text styles used across screens.
    public static var displayTitle: Font { serif(34, weight: .semibold) }
    public static var screenTitle: Font { serif(26, weight: .semibold) }
    public static var chapterTitle: Font { serif(27, weight: .semibold) }
    public static var original: Font { serif(16.5, weight: .regular) }
    public static var body: Font { sans(16, weight: .regular) }
    public static var bodyLarge: Font { sans(16.5, weight: .regular) }
    public static var label: Font { sans(13, weight: .medium) }
    public static var caption: Font { sans(11.5, weight: .regular) }
}
