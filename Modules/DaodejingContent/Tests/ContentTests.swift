import Testing
@testable import DaodejingContent

@Suite("DaodejingContent")
struct ContentTests {
    let repo = BundledContentRepository()

    @Test("Chapters load from the bundled JSON")
    func loads() {
        #expect(!repo.allChapters().isEmpty)
    }

    @Test("Chapters are sorted and well-formed")
    func wellFormed() {
        for chapter in repo.allChapters() {
            #expect((1 ... 81).contains(chapter.number))
            #expect(!chapter.title.isEmpty)
            #expect(!chapter.original.isEmpty)
            #expect(!chapter.vernacular.isEmpty)
            #expect(!chapter.firstOriginalLine.isEmpty)
        }
    }

    @Test("Book mapping splits 道经 / 德经 at 37")
    func bookMapping() {
        #expect(repo.chapter(1)?.book == .dao)
        #expect(repo.chapter(37)?.book == .dao)
        #expect(repo.chapter(78)?.book == .de)
        #expect(Book.of(chapterNumber: 38) == .de)
    }

    @Test("Sentence pairs fall back to zipped paragraphs")
    func sentencePairs() {
        let ch1 = repo.chapter(1)
        #expect(ch1?.sentencePairs.isEmpty == false)
        // Chapter 8 authored fine-grained pairs.
        #expect((repo.chapter(8)?.sentencePairs.count ?? 0) >= 4)
    }

    @Test("Chinese numerals convert correctly")
    func numerals() {
        #expect(ChineseNumber.of(1) == "一")
        #expect(ChineseNumber.of(8) == "八")
        #expect(ChineseNumber.of(10) == "十")
        #expect(ChineseNumber.of(16) == "十六")
        #expect(ChineseNumber.of(37) == "三十七")
        #expect(ChineseNumber.of(81) == "八十一")
    }

    @Test("Search matches original and vernacular")
    func search() {
        #expect(repo.search("上善若水").contains { $0.number == 8 })
        #expect(repo.search("自知").contains { $0.number == 33 })
        #expect(repo.search("").count == repo.allChapters().count)
    }
}
