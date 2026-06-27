import Testing
@testable import Audio

@Suite("Audio")
struct AudioTests {
    @Test("Lines split on sentence punctuation; blanks are dropped")
    func segmentsSplitAndSkipBlanks() {
        let lines = ["道可道，非常道。名可名，非常名。", "", "  玄之又玄  "]
        let segments = SpeechScript.segments(from: lines)
        #expect(segments.count == 3)
        #expect(segments[0] == "道可道，非常道。")
        #expect(segments[1] == "名可名，非常名。")
        #expect(segments[2] == "玄之又玄")
    }

    @Test("All-blank input yields no segments")
    func blankInputIsEmpty() {
        #expect(SpeechScript.segments(from: ["", "   ", "\n"]).isEmpty)
    }

    @Test("A line without terminal punctuation stays one segment")
    func unterminatedLineStaysWhole() {
        #expect(SpeechScript.split("上善若水") == ["上善若水"])
    }
}
