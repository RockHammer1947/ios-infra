import Foundation

/// One synthesized (or cache-loaded) piece of speech: mono float PCM.
public struct SpeechAudio: Sendable {
    public let samples: [Float]
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

/// Which text of a chapter is being read aloud. Each mode is cached and
/// progress-tracked independently: the 原文 and its 解读 are different audio.
public enum ReadingMode: String, Sendable, CaseIterable {
    case original // 原文
    case vernacular // 白话（今日页）
    case interpretation // 详细解读
}

/// Everything the speech pipeline needs to read one chapter-text aloud.
/// `segments` are sentence-level pieces (see `SpeechScript`); synthesis always
/// runs at speed 1.0 so cached audio is valid at every playback rate.
public struct SpeechRequest: Sendable, Equatable {
    public let chapter: Int
    public let mode: ReadingMode
    public let language: TTSLanguage
    public let voice: TTSVoice
    public let segments: [String]

    public init(chapter: Int, mode: ReadingMode, language: TTSLanguage, voice: TTSVoice, segments: [String]) {
        self.chapter = chapter
        self.mode = mode
        self.language = language
        self.voice = voice
        self.segments = segments
    }

    /// Stable identity for caching and task bookkeeping.
    public var cacheKey: TTSCacheKey {
        TTSCacheKey(language: language, voiceID: voice.id, chapter: chapter, mode: mode)
    }
}

/// Identity of one cached chapter-reading: language / voice / chapter / mode.
public struct TTSCacheKey: Hashable, Sendable {
    public let language: TTSLanguage
    public let voiceID: String
    public let chapter: Int
    public let mode: ReadingMode

    /// Relative directory for this key inside the cache root.
    public var relativePath: String {
        "\(language.rawValue)/\(voiceID)/ch\(chapter)-\(mode.rawValue)"
    }
}

/// Remembers how far each chapter-reading got, so a re-tap can offer
/// 继续播放 instead of restarting. Cleared automatically on completion.
public enum PlaybackProgress {
    static func key(chapter: Int, mode: ReadingMode, language: TTSLanguage) -> String {
        "tts.progress.\(language.rawValue).\(chapter).\(mode.rawValue)"
    }

    /// Segments already spoken and the total, if playback stopped part-way.
    public static func saved(chapter: Int, mode: ReadingMode, language: TTSLanguage = .current) -> (spoken: Int, total: Int)? {
        let stored = UserDefaults.standard.array(forKey: key(chapter: chapter, mode: mode, language: language)) as? [Int]
        guard let stored, stored.count == 2, stored[0] > 0, stored[0] < stored[1] else { return nil }
        return (stored[0], stored[1])
    }

    public static func update(chapter: Int, mode: ReadingMode, language: TTSLanguage = .current, spoken: Int, total: Int) {
        let defaults = UserDefaults.standard
        let storageKey = key(chapter: chapter, mode: mode, language: language)
        if spoken >= total || spoken <= 0 {
            defaults.removeObject(forKey: storageKey) // finished (or not started) → no resume point
        } else {
            defaults.set([spoken, total], forKey: storageKey)
        }
    }

    public static func clear(chapter: Int, mode: ReadingMode, language: TTSLanguage = .current) {
        UserDefaults.standard.removeObject(forKey: key(chapter: chapter, mode: mode, language: language))
    }
}
