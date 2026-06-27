import Foundation
import SwiftData

/// What a saved `Mark` represents. The 笔记 screen filters on these.
public enum MarkKind: String, Codable, CaseIterable, Sendable {
    case highlight // 划线 — a passage the reader brushed over
    case note // 笔记 — a highlight plus the reader's own words
    case bookmark // 书签 — a chapter set aside to return to

    public var label: String {
        switch self {
        case .highlight: "划线"
        case .note: "笔记"
        case .bookmark: "书签"
        }
    }
}

/// A reader-authored mark on a chapter. One model covers all three kinds so the
/// 笔记 list can query and sort them together; `kind` drives presentation.
@Model
public final class Mark {
    /// Raw value of `MarkKind` — SwiftData stores the primitive, `kind` wraps it.
    public var kindRaw: String
    public var chapterNumber: Int
    /// The highlighted 译文/原文 passage (empty for a plain bookmark).
    public var excerpt: String
    /// The reader's own annotation (only meaningful for `.note`).
    public var noteText: String
    public var createdAt: Date

    public init(
        kind: MarkKind,
        chapterNumber: Int,
        excerpt: String = "",
        noteText: String = "",
        createdAt: Date = .now
    ) {
        kindRaw = kind.rawValue
        self.chapterNumber = chapterNumber
        self.excerpt = excerpt
        self.noteText = noteText
        self.createdAt = createdAt
    }

    public var kind: MarkKind {
        get { MarkKind(rawValue: kindRaw) ?? .highlight }
        set { kindRaw = newValue.rawValue }
    }
}
