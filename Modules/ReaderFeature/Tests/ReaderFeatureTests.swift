import Testing
@testable import ReaderFeature

@Suite("ReaderFeature")
struct ReaderFeatureTests {
    @Test("Tabs cover the four destinations in order")
    func tabs() {
        #expect(ReaderTab.allCases.count == 4)
        #expect(ReaderTab.allCases.map(\.label) == ["今日", "经文", "笔记", "我的"])
    }

    @Test("Each tab has a symbol")
    func symbols() {
        for tab in ReaderTab.allCases {
            #expect(!tab.symbol.isEmpty)
        }
    }
}
