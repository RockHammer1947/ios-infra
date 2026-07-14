import Foundation
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

    // MARK: - Bundled models + voices

    @Test("Each language resolves its own bundled model directory")
    func bundledModelDirectories() {
        #expect(BundledTTSModels.directory(for: .zh).lastPathComponent == "melo-zh")
        #expect(BundledTTSModels.directory(for: .en).lastPathComponent == "melo-en")
        #expect(
            BundledTTSModels.directory(for: .zh).deletingLastPathComponent().lastPathComponent
                == "BundledTTS"
        )
    }

    @Test("Per-language voices: zh has one, en has five accents")
    func perLanguageVoices() {
        #expect(TTSVoice.all(for: .zh).count == 1)
        #expect(TTSVoice.all(for: .en).count == 5)
        #expect(TTSVoice.fallback(for: .en).sid == 0)
        #expect(Set(TTSVoice.english.map(\.sid)).count == 5, "speaker ids must be distinct")
        #expect(Set(TTSVoice.english.map(\.id)).count == 5, "persisted ids must be distinct")
    }

    @Test("Melo layout only reports complete when the core files exist")
    func meloLayoutCompleteness() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("melo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let layout = MeloModelLayout(directory: dir)
        #expect(!layout.isComplete)
        for name in ["model.onnx", "lexicon.txt", "tokens.txt"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        #expect(layout.isComplete)
        #expect(layout.model.lastPathComponent == "model.onnx")
        #expect(layout.dictDir == nil, "no dict on disk → nil, engine must skip it")
        #expect(layout.ruleFSTs.isEmpty, "no FSTs on disk → empty, engine must skip them")
    }

    @Test("Selected voice persists per language and falls back when unset")
    func voiceSelectionPersistence() {
        let keys = [TTSVoice.defaultsKey(.zh), TTSVoice.defaultsKey(.en)]
        let originals = keys.map { UserDefaults.standard.string(forKey: $0) }
        defer { for (k, v) in zip(keys, originals) {
            UserDefaults.standard.set(v, forKey: k)
        } }

        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        #expect(TTSVoice.selected(for: .en).id == TTSVoice.fallback(for: .en).id)

        TTSVoice.select(TTSVoice.english[3], for: .en) // en-au
        #expect(TTSVoice.selected(for: .en).id == "en-au")
        #expect(TTSVoice.selected(for: .zh).id == TTSVoice.fallback(for: .zh).id) // independent
    }

    @Test("Voice sample text follows the language")
    func voiceSampleText() {
        #expect(TTSVoice.sampleText(for: .zh).contains("上善若水"))
        #expect(TTSVoice.sampleText(for: .en).contains("water"))
    }

    // MARK: - Cache keys + progress memory

    @Test("Cache key path separates language, voice, chapter, and mode")
    func cacheKeyPath() {
        let key = TTSCacheKey(language: .zh, voiceID: "zh-standard", chapter: 8, mode: .interpretation)
        #expect(key.relativePath == "zh/zh-standard/ch8-interpretation")
        let other = TTSCacheKey(language: .zh, voiceID: "zh-standard", chapter: 8, mode: .original)
        #expect(key != other, "modes must cache separately")
    }

    @Test("Content hash is stable and order/content sensitive")
    func contentHash() {
        let a = TTSCache.contentHash(of: ["道可道", "非常道"])
        #expect(a == TTSCache.contentHash(of: ["道可道", "非常道"]))
        #expect(a != TTSCache.contentHash(of: ["非常道", "道可道"]))
        #expect(a != TTSCache.contentHash(of: ["道可道", "非常道。"]))
    }

    @Test("Playback progress: saved mid-way, cleared on completion")
    func playbackProgressMemory() {
        let chapter = 979 // unlikely to collide with real state
        defer { PlaybackProgress.clear(chapter: chapter, mode: .original, language: .zh) }

        #expect(PlaybackProgress.saved(chapter: chapter, mode: .original, language: .zh) == nil)

        PlaybackProgress.update(chapter: chapter, mode: .original, language: .zh, spoken: 3, total: 9)
        let saved = PlaybackProgress.saved(chapter: chapter, mode: .original, language: .zh)
        #expect(saved?.spoken == 3)
        #expect(saved?.total == 9)
        // Modes are independent.
        #expect(PlaybackProgress.saved(chapter: chapter, mode: .interpretation, language: .zh) == nil)

        // Completion clears the resume point.
        PlaybackProgress.update(chapter: chapter, mode: .original, language: .zh, spoken: 9, total: 9)
        #expect(PlaybackProgress.saved(chapter: chapter, mode: .original, language: .zh) == nil)
    }

    @Test("Cache round-trip: store a segment, read back the same samples")
    func cacheRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ttscache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = TTSCache(root: root)
        let request = SpeechRequest(
            chapter: 1, mode: .original, language: .zh,
            voice: .fallback(for: .zh), segments: ["道可道。", "名可名。"]
        )

        // Fresh dir: nothing cached, both segments missing.
        #expect(await cache.preparedIndices(for: request).isEmpty)
        #expect(await cache.missingIndices(for: request) == [0, 1])

        // Store one segment; 16-bit round-trip keeps values within tolerance.
        let audio = SpeechAudio(
            samples: (0 ..< 4410).map { Float(sin(Double($0) * 0.05)) * 0.5 }, sampleRate: 44100
        )
        await cache.storeSegment(key: request.cacheKey, index: 0, audio: audio)
        #expect(await cache.missingIndices(for: request) == [1])
        let loaded = try #require(await cache.loadSegment(key: request.cacheKey, index: 0))
        #expect(loaded.samples.count == audio.samples.count)
        #expect(loaded.sampleRate == 44100)
        let maxError = zip(loaded.samples, audio.samples).map { abs($0 - $1) }.max() ?? 1
        #expect(maxError < 0.001, "16-bit quantization error should be tiny")

        // Changed text (content hash) invalidates the directory.
        let changed = SpeechRequest(
            chapter: 1, mode: .original, language: .zh,
            voice: .fallback(for: .zh), segments: ["道可道，非常道。", "名可名。"]
        )
        #expect(await cache.preparedIndices(for: changed).isEmpty)
        #expect(await cache.missingIndices(for: changed) == [0, 1])
    }
}
