import Foundation
import SwiftData

/// How far the reader has gotten in a chapter. One row per chapter the reader
/// has opened; `fraction == 1` means read to the end. Drives the 已读 N/81
/// counters and the 圆满 enso on 我的.
@Model
public final class ChapterProgress {
    /// Chapter number (1...81). Unique so opening a chapter upserts one row.
    @Attribute(.unique) public var chapterNumber: Int
    public var fraction: Double
    public var updatedAt: Date

    public init(chapterNumber: Int, fraction: Double = 0, updatedAt: Date = .now) {
        self.chapterNumber = chapterNumber
        self.fraction = fraction
        self.updatedAt = updatedAt
    }

    /// A chapter counts as "read" once the reader reaches ~the end.
    public var isRead: Bool { fraction >= 0.95 }
}
