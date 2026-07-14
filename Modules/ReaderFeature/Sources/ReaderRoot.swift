import Audio
import DaodejingContent
import DesignSystem
import Library
import Purchases
import SwiftUI

/// Top-level entry point the app embeds. Owns the content repository, the
/// in-app-purchase store, and the persisted appearance, and hosts the tab shell.
public struct ReaderRoot: View {
    @AppStorage("theme") private var themeRaw = DSTheme.dark.rawValue
    @AppStorage("contentLanguage") private var langRaw = ContentLanguage.deviceDefault.rawValue
    @State private var store = StoreModel(productIDs: ReaderProducts.all)
    @State private var speech = SpeechPlayer()
    @State private var trial = TrialAccess()
    // Skipped under UI tests (they can't tap the "开启智慧" gate on the
    // now-infinite splash loop) via the `skip-launch-animation` launch arg.
    @State private var showLaunch = !ProcessInfo.processInfo.arguments.contains("skip-launch-animation")

    @State private var repository: any ContentRepository

    public init(repository: (any ContentRepository)? = nil) {
        _repository = State(initialValue: repository ?? BundledContentRepository(language: .zh))
    }

    private var theme: DSTheme { DSTheme(rawValue: themeRaw) ?? .dark }
    private var lang: ContentLanguage { ContentLanguage(rawValue: langRaw) ?? .zh }

    public var body: some View {
        ZStack {
            RootTabView(repository: repository)
                .id(lang) // rebuild the tree when the edition changes
                .environment(store)
                .environment(speech)
                .environment(trial)
                .environment(\.appLanguage, lang)
                .modelContainer(LibraryContainer.shared)
                .tint(DSColor.accent)
                .dsTheme(theme)
                .task {
                    // Under unit tests (app as TEST_HOST), stay off StoreKit:
                    // a test's SKTestSession must be the process's first
                    // StoreKit contact or it never takes effect. UI-test
                    // launches run in a separate process and are unaffected.
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                    else { return }
                    await store.loadProducts()
                }
                .task(id: langRaw) {
                    if (repository as? BundledContentRepository)?.language != lang {
                        repository = BundledContentRepository(language: lang)
                    }
                }

            #if canImport(UIKit)
                // Video splash sits on top; the real UI is already live underneath,
                // so the fade-out reveals a ready app with no second load.
                if showLaunch {
                    LaunchScreenView {
                        withAnimation(.easeOut(duration: 0.45)) { showLaunch = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            #endif
        }
    }
}

#Preview {
    ReaderRoot()
}
