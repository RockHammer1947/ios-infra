import DaodejingContent
import SwiftUI

/// The active UI language, threaded through the environment so every view can
/// localize its chrome. Driven by `ReaderRoot` from the saved setting.
private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: ContentLanguage = .zh
}

public extension EnvironmentValues {
    var appLanguage: ContentLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

public extension ContentLanguage {
    /// Pick the string for this language: `lang.pick("原文", "Text")`.
    func pick(_ zh: String, _ en: String) -> String { self == .zh ? zh : en }
}
