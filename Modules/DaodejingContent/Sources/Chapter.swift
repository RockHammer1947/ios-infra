import Foundation

/// One 原文 sentence paired with its 白话 translation (逐句对照).
public struct SentencePair: Codable, Sendable, Hashable, Identifiable {
    public let index: Int
    public let original: String
    public let vernacular: String

    public var id: Int { index }

    public init(index: Int, original: String, vernacular: String) {
        self.index = index
        self.original = original
        self.vernacular = vernacular
    }
}

/// A 「注」 annotation attached to a phrase in the chapter.
public struct ChapterNote: Codable, Sendable, Hashable, Identifiable {
    public let index: Int
    public let ref: String
    public let text: String

    public var id: Int { index }

    public init(index: Int, ref: String, text: String) {
        self.index = index
        self.ref = ref
        self.text = text
    }
}

/// One section of a chapter's 详细解读 — a heading, the 原文 phrase it
/// interprets (optional), and one or more paragraphs of commentary.
public struct InterpretationSection: Codable, Sendable, Hashable, Identifiable {
    public let index: Int
    public let heading: String
    /// The 原文 this section reads closely; `nil` for overview/summary sections.
    public let quote: String?
    public let paragraphs: [String]

    public var id: Int { index }

    public init(index: Int, heading: String, quote: String? = nil, paragraphs: [String]) {
        self.index = index
        self.heading = heading
        self.quote = quote
        self.paragraphs = paragraphs
    }
}

/// A single chapter of the 道德经 with original text, 白话 paragraphs, a
/// sentence-by-sentence pairing, annotations, and an optional 详细解读.
public struct Chapter: Codable, Sendable, Identifiable, Hashable {
    public let number: Int
    public let title: String
    public let original: [String]
    public let vernacular: [String]
    public let pairs: [SentencePair]
    public let notes: [ChapterNote]
    public let interpretation: [InterpretationSection]

    public var id: Int { number }
    public var book: Book { .of(chapterNumber: number) }
    public var chineseNumeral: String { ChineseNumber.of(number) }

    /// First line of 原文 — shown as a teaser in lists and the 今日 card.
    public var firstOriginalLine: String { original.first ?? "" }

    /// Pairs for the 逐句对照 view: authored `pairs` if present, otherwise the
    /// paragraph-level original/vernacular zipped together.
    public var sentencePairs: [SentencePair] {
        if !pairs.isEmpty { return pairs }
        let count = min(original.count, vernacular.count)
        return (0 ..< count).map {
            SentencePair(index: $0, original: original[$0], vernacular: vernacular[$0])
        }
    }

    public init(
        number: Int,
        title: String,
        original: [String],
        vernacular: [String],
        pairs: [SentencePair] = [],
        notes: [ChapterNote] = [],
        interpretation: [InterpretationSection] = []
    ) {
        self.number = number
        self.title = title
        self.original = original
        self.vernacular = vernacular
        self.pairs = pairs
        self.notes = notes
        self.interpretation = interpretation
    }

    enum CodingKeys: String, CodingKey {
        case number, title, original, vernacular, pairs, notes, interpretation
    }

    /// Custom decoding so chapters authored before a field existed still load:
    /// `pairs`, `notes`, and `interpretation` default to empty when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number = try c.decode(Int.self, forKey: .number)
        title = try c.decode(String.self, forKey: .title)
        original = try c.decode([String].self, forKey: .original)
        vernacular = try c.decode([String].self, forKey: .vernacular)
        pairs = try c.decodeIfPresent([SentencePair].self, forKey: .pairs) ?? []
        notes = try c.decodeIfPresent([ChapterNote].self, forKey: .notes) ?? []
        interpretation = try c.decodeIfPresent([InterpretationSection].self, forKey: .interpretation) ?? []
    }
}
