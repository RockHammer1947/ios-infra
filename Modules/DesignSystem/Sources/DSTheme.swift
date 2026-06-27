import SwiftUI

/// User-selectable appearance. `.system` follows the OS; `.light` is 宣纸,
/// `.dark` is the primary night-reading theme.
public enum DSTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    /// Localized label for the settings segmented control.
    public var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    /// Maps to SwiftUI's `preferredColorScheme` (nil = follow system).
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public extension View {
    /// Apply the persisted theme to a view hierarchy.
    func dsTheme(_ theme: DSTheme) -> some View {
        preferredColorScheme(theme.colorScheme)
    }
}
