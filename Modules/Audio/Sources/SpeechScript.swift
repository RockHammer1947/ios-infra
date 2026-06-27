import Foundation

/// Turns a chapter's lines into speakable segments. Kept free of AVFoundation so
/// the segmentation logic is unit-testable without an audio engine.
public enum SpeechScript {
    /// Sentence-terminating punctuation we break on (keeping the mark attached).
    private static let terminators: Set<Character> = ["。", "！", "？", "；"]

    /// Flatten lines into segments: blank lines are dropped, and each line is
    /// split after sentence punctuation so playback progress advances smoothly.
    public static func segments(from lines: [String]) -> [String] {
        lines.flatMap { line -> [String] in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : split(trimmed)
        }
    }

    static func split(_ text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if terminators.contains(character) {
                segments.append(current)
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { segments.append(tail) }
        return segments.isEmpty ? [text] : segments
    }
}
