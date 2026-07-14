import Foundation

/// The reader's two content languages, each backed by its own bundled MeloTTS
/// model. Derived from the persisted `contentLanguage` so audio follows the text.
public enum TTSLanguage: String, Sendable, CaseIterable {
    case zh, en

    public static var current: TTSLanguage {
        UserDefaults.standard.string(forKey: "contentLanguage") == "en" ? .en : .zh
    }
}

/// Voice language for the macOS placeholder synthesizer, following the
/// reader's content language.
enum SpeechLanguage {
    static var current: String {
        UserDefaults.standard.string(forKey: "contentLanguage") == "en" ? "en-US" : "zh-CN"
    }
}

/// A selectable voice within a language's model (a sherpa-onnx speaker id plus
/// display names). MeloTTS Chinese ships one voice; English ships five accents.
public struct TTSVoice: Identifiable, Sendable, Equatable {
    public let id: String // stable, persisted
    public let sid: Int32
    public let zhName: String
    public let enName: String

    public func name(_ lang: TTSLanguage) -> String { lang == .en ? enName : zhName }

    /// Short line each voice reads when auditioned from Settings.
    public static func sampleText(for lang: TTSLanguage) -> String {
        lang == .en
            ? "The highest good is like water."
            : "上善若水，水善利万物而不争。"
    }
}

public extension TTSVoice {
    static let chinese: [TTSVoice] = [
        .init(id: "zh-standard", sid: 0, zhName: "普通话 · 女声", enName: "Mandarin · Female"),
    ]

    // MeloTTS English speaker order (canonical): US, BR, India, AU, Default.
    static let english: [TTSVoice] = [
        .init(id: "en-us", sid: 0, zhName: "美式英语", enName: "American"),
        .init(id: "en-br", sid: 1, zhName: "英式英语", enName: "British"),
        .init(id: "en-in", sid: 2, zhName: "印度英语", enName: "Indian"),
        .init(id: "en-au", sid: 3, zhName: "澳式英语", enName: "Australian"),
        .init(id: "en-default", sid: 4, zhName: "默认英语", enName: "Default"),
    ]

    static func all(for lang: TTSLanguage) -> [TTSVoice] { lang == .en ? english : chinese }
    static func fallback(for lang: TTSLanguage) -> TTSVoice { all(for: lang)[0] }

    /// The reader's chosen voice for `lang` (persisted per language).
    static func selected(for lang: TTSLanguage) -> TTSVoice {
        let id = UserDefaults.standard.string(forKey: defaultsKey(lang))
        return all(for: lang).first { $0.id == id } ?? fallback(for: lang)
    }

    static func select(_ voice: TTSVoice, for lang: TTSLanguage) {
        UserDefaults.standard.set(voice.id, forKey: defaultsKey(lang))
    }

    static func defaultsKey(_ lang: TTSLanguage) -> String { "ttsVoice.\(lang.rawValue)" }
}

/// Locates the MeloTTS models shipped inside the app bundle (staged by
/// `scripts/fetch-tts-models.sh` into the git-ignored `BundledTTS/` folder
/// reference). No download, no install state: the models are simply there.
public enum BundledTTSModels {
    /// Bundle-relative folder holding one subdirectory per language model.
    static let folderName = "BundledTTS"

    public static func directory(for language: TTSLanguage) -> URL {
        (Bundle.main.resourceURL ?? Bundle.main.bundleURL)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("melo-\(language.rawValue)", isDirectory: true)
    }

    /// True when the language's model is present in the bundle (always true on
    /// a correctly built iOS app; false on macOS, which uses the placeholder).
    public static func isAvailable(for language: TTSLanguage) -> Bool {
        MeloModelLayout(directory: directory(for: language)).isComplete
    }
}

/// Maps a MeloTTS (VITS) model directory to the paths sherpa-onnx needs.
/// Pure Foundation so it compiles everywhere and is unit-testable. Optional
/// pieces (dict, rule FSTs) are only present in the bilingual zh model.
public struct MeloModelLayout: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public var model: URL { directory.appendingPathComponent("model.onnx") }
    public var lexicon: URL { directory.appendingPathComponent("lexicon.txt") }
    public var tokens: URL { directory.appendingPathComponent("tokens.txt") }

    /// jieba dict dir — only the bilingual zh model ships one.
    public var dictDir: URL? { existing("dict", isDirectory: true) }

    /// Text-normalization FSTs, in sherpa-onnx's expected order. Only the zh
    /// model ships them; English needs none.
    public var ruleFSTs: [URL] {
        ["phone.fst", "date.fst", "number.fst", "new_heteronym.fst"].compactMap { existing($0) }
    }

    public var isComplete: Bool {
        ["model.onnx", "lexicon.txt", "tokens.txt"].allSatisfy {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }

    private func existing(_ name: String, isDirectory: Bool = false) -> URL? {
        let url = directory.appendingPathComponent(name, isDirectory: isDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
