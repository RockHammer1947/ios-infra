import DaodejingContent
import DesignSystem
import SwiftUI

/// Top-level entry point the app embeds. Owns the content repository and the
/// persisted appearance, and hosts the tab shell.
public struct ReaderRoot: View {
    @AppStorage("theme") private var themeRaw = DSTheme.dark.rawValue

    private let repository: any ContentRepository

    public init(repository: any ContentRepository = BundledContentRepository()) {
        self.repository = repository
    }

    private var theme: DSTheme { DSTheme(rawValue: themeRaw) ?? .dark }

    public var body: some View {
        RootTabView(repository: repository)
            .tint(DSColor.accent)
            .dsTheme(theme)
    }
}

#Preview {
    ReaderRoot()
}
