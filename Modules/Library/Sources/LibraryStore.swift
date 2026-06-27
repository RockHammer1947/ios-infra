import Foundation
import SwiftData

/// Mutations on the library, kept out of the views so they can be unit-tested
/// against an in-memory container. A thin wrapper over a `ModelContext`.
@MainActor
public struct LibraryStore {
    private let context: ModelContext

    public init(_ context: ModelContext) {
        self.context = context
    }

    // MARK: Marks

    /// Save a 划线 (or 笔记 when `note` is non-empty).
    @discardableResult
    public func addHighlight(chapterNumber: Int, excerpt: String, note: String = "") -> Mark {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let mark = Mark(
            kind: trimmed.isEmpty ? .highlight : .note,
            chapterNumber: chapterNumber,
            excerpt: excerpt,
            noteText: trimmed
        )
        context.insert(mark)
        return mark
    }

    public func delete(_ mark: Mark) {
        context.delete(mark)
    }

    /// Is this chapter bookmarked?
    public func isBookmarked(_ chapterNumber: Int) -> Bool {
        bookmark(for: chapterNumber) != nil
    }

    /// Flip a chapter's 书签 on or off; returns the new state.
    @discardableResult
    public func toggleBookmark(_ chapterNumber: Int) -> Bool {
        if let existing = bookmark(for: chapterNumber) {
            context.delete(existing)
            return false
        }
        context.insert(Mark(kind: .bookmark, chapterNumber: chapterNumber))
        return true
    }

    private func bookmark(for chapterNumber: Int) -> Mark? {
        let bookmarkRaw = MarkKind.bookmark.rawValue
        let descriptor = FetchDescriptor<Mark>(
            predicate: #Predicate { $0.chapterNumber == chapterNumber && $0.kindRaw == bookmarkRaw }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: Reading progress

    /// Record how far the reader has gotten in a chapter (upsert by number).
    public func recordProgress(chapterNumber: Int, fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        if let existing = progress(for: chapterNumber) {
            // Progress only moves forward — never regress a finished chapter.
            existing.fraction = max(existing.fraction, clamped)
            existing.updatedAt = .now
        } else {
            context.insert(ChapterProgress(chapterNumber: chapterNumber, fraction: clamped))
        }
    }

    /// Count of chapters read to the end.
    public func readCount() -> Int {
        let descriptor = FetchDescriptor<ChapterProgress>(
            predicate: #Predicate { $0.fraction >= 0.95 }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func progress(for chapterNumber: Int) -> ChapterProgress? {
        let descriptor = FetchDescriptor<ChapterProgress>(
            predicate: #Predicate { $0.chapterNumber == chapterNumber }
        )
        return try? context.fetch(descriptor).first
    }
}
