import Foundation

/// Read-only access to the 道德经 chapters.
public protocol ContentRepository: Sendable {
    func allChapters() -> [Chapter]
    func chapter(_ number: Int) -> Chapter?
    /// Chapters in a given volume (道经 / 德经).
    func chapters(in book: Book) -> [Chapter]
    /// Full-text search over title / 原文 / 白话.
    func search(_ query: String) -> [Chapter]
}

public extension ContentRepository {
    func chapters(in book: Book) -> [Chapter] {
        allChapters().filter { $0.book == book }
    }

    func search(_ query: String) -> [Chapter] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return allChapters() }
        return allChapters().filter { chapter in
            chapter.title.contains(needle)
                || chapter.original.contains { $0.contains(needle) }
                || chapter.vernacular.contains { $0.contains(needle) }
        }
    }
}

/// Loads chapters from the bundled `chapters.json`.
public struct BundledContentRepository: ContentRepository {
    private let chapters: [Chapter]

    public init() {
        chapters = Self.load()
    }

    public func allChapters() -> [Chapter] { chapters }

    public func chapter(_ number: Int) -> Chapter? {
        chapters.first { $0.number == number }
    }

    private struct ChaptersFile: Codable { let chapters: [Chapter] }

    private static func load() -> [Chapter] {
        guard
            let url = Bundle.module.url(forResource: "chapters", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(ChaptersFile.self, from: data)
        else {
            assertionFailure("chapters.json missing or invalid")
            return []
        }
        return file.chapters.sorted { $0.number < $1.number }
    }
}
