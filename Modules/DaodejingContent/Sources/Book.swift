import Foundation

/// The two volumes of the 道德经. 道经 is chapters 1–37, 德经 is 38–81.
public enum Book: String, Codable, Sendable, CaseIterable, Identifiable {
    case dao
    case de

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dao: "道经"
        case .de: "德经"
        }
    }

    /// Label used by the contents segmented control, e.g. "道经 · 1–37".
    public var rangeLabel: String {
        switch self {
        case .dao: "道经 · 1–37"
        case .de: "德经 · 38–81"
        }
    }

    public var range: ClosedRange<Int> {
        switch self {
        case .dao: 1 ... 37
        case .de: 38 ... 81
        }
    }

    public static func of(chapterNumber: Int) -> Book {
        chapterNumber <= 37 ? .dao : .de
    }
}
