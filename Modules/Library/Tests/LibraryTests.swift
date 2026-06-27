import SwiftData
import Testing
@testable import Library

@MainActor
@Suite("Library")
struct LibraryTests {
    private func freshStore() -> (LibraryStore, ModelContext) {
        let context = ModelContext(LibraryContainer.inMemory())
        return (LibraryStore(context), context)
    }

    @Test("A highlight with text becomes a 笔记, without becomes a 划线")
    func highlightVsNote() {
        let (store, _) = freshStore()
        let plain = store.addHighlight(chapterNumber: 1, excerpt: "道可道")
        let annotated = store.addHighlight(chapterNumber: 1, excerpt: "玄之又玄", note: "记一笔")
        #expect(plain.kind == .highlight)
        #expect(annotated.kind == .note)
        #expect(annotated.noteText == "记一笔")
    }

    @Test("Bookmark toggles on and off and is queryable")
    func bookmarkToggle() {
        let (store, _) = freshStore()
        #expect(store.isBookmarked(8) == false)
        #expect(store.toggleBookmark(8) == true)
        #expect(store.isBookmarked(8) == true)
        #expect(store.toggleBookmark(8) == false)
        #expect(store.isBookmarked(8) == false)
    }

    @Test("Progress upserts by chapter, only moves forward, and counts reads")
    func progress() {
        let (store, _) = freshStore()
        store.recordProgress(chapterNumber: 1, fraction: 0.4)
        store.recordProgress(chapterNumber: 1, fraction: 1.0)
        // A later, smaller fraction must not regress a finished chapter.
        store.recordProgress(chapterNumber: 1, fraction: 0.2)
        store.recordProgress(chapterNumber: 2, fraction: 0.5)
        #expect(store.readCount() == 1)
    }

    @Test("Deleting a mark removes it from the context")
    func deleteMark() throws {
        let (store, context) = freshStore()
        let mark = store.addHighlight(chapterNumber: 3, excerpt: "无为")
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Mark>()) == 1)
        store.delete(mark)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Mark>()) == 0)
    }
}
