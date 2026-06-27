import SwiftUI

/// Shared design tokens. Every app draws its look from here so products stay
/// visually consistent and theming changes happen in one place.
public enum DesignSystem {
    public static let spacing: CGFloat = 16
    public static let cornerRadius: CGFloat = 12

    /// Adaptive background that works on both iOS and macOS.
    public static var background: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}
