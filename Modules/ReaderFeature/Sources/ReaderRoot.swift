import DaodejingContent
import DesignSystem
import Library
import Purchases
import SwiftUI

/// Top-level entry point the app embeds. Owns the content repository, the
/// in-app-purchase store, and the persisted appearance, and hosts the tab shell.
public struct ReaderRoot: View {
    @AppStorage("theme") private var themeRaw = DSTheme.dark.rawValue
    @State private var store = StoreModel(productIDs: ReaderProducts.all)

    private let repository: any ContentRepository

    public init(repository: any ContentRepository = BundledContentRepository()) {
        self.repository = repository
    }

    private var theme: DSTheme { DSTheme(rawValue: themeRaw) ?? .dark }

    public var body: some View {
        RootTabView(repository: repository)
            .environment(store)
            .modelContainer(LibraryContainer.shared)
            .tint(DSColor.accent)
            .dsTheme(theme)
            .task { await store.loadProducts() }
    }
}

#Preview {
    ReaderRoot()
}
