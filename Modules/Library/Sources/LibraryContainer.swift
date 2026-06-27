import Foundation
import SwiftData

/// The persistence schema and `ModelContainer` factories. The app injects the
/// shared container with `.modelContainer(LibraryContainer.shared)`; tests and
/// previews use an in-memory one so nothing touches disk.
public enum LibraryContainer {
    /// Every `@Model` the library persists. New models get added here once.
    public static let schema = Schema([Mark.self, ChapterProgress.self])

    /// On-disk container backing the running app. Falls back to in-memory if the
    /// store can't be opened so the app still launches (worst case: marks don't
    /// persist across launches rather than a crash).
    public static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            assertionFailure("Library store unavailable: \(error)")
            return inMemory()
        }
    }()

    /// A throwaway container for tests and previews.
    public static func inMemory() -> ModelContainer {
        // swiftlint:disable:next force_try
        try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
