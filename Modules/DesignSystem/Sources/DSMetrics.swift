import CoreGraphics

/// Spacing, radii and layout constants from the design spec.
/// "留白即页面" — generous negative space is intentional.
public enum DSMetrics {
    // Spacing scale
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 22
    public static let xl: CGFloat = 28

    /// Standard horizontal screen padding (26–28 in the spec).
    public static let screenPadding: CGFloat = 26

    // Corner radii
    public static let radiusCard: CGFloat = 16
    public static let radiusSmall: CGFloat = 12
    public static let radiusPill: CGFloat = 24
    public static let radiusSheet: CGFloat = 26
}
