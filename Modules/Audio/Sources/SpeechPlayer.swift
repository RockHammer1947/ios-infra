import AVFoundation
import Observation

/// Reads chapter text aloud. A thin, observable controller the reader UI binds
/// to: play / pause / resume / stop plus segment-level progress for the
/// waveform.
///
/// Playback identity is (chapter, mode): the 原文 and its 解读 are separate
/// readings with separate caches and separate resume points. Synthesis always
/// runs on the bundled MeloTTS model for the current content language; the
/// provider is rebuilt when that language changes.
///
/// Progress is persisted per (chapter, mode) after every finished segment, so
/// the UI can offer 继续播放 across pauses, chapter switches, and relaunches
/// (see `savedProgress` / the `startIndex` parameter). It clears itself on
/// completion.
@MainActor
@Observable
public final class SpeechPlayer {
    /// True while audio is actively speaking (false when paused or stopped).
    public private(set) var isPlaying = false
    /// Which chapter/text is loaded, if any.
    public private(set) var chapterNumber: Int?
    public private(set) var mode: ReadingMode?
    /// Segments spoken so far, and the total queued — drives `progress`.
    public private(set) var spokenCount = 0
    public private(set) var totalCount = 0

    /// Speed multiplier applied at playback time (1.0 = normal). Settings
    /// drives this; synthesis itself is always 1.0× so caches stay valid.
    public var rateScale: Double = 1.0

    @ObservationIgnored private var provider: NeuralSpeechProvider
    /// The content language the current provider/engine was built for, so a
    /// language switch rebuilds it against the right model + voice.
    @ObservationIgnored private var providerLanguage: TTSLanguage

    /// `engine` is injectable for tests; nil uses the real per-language engine.
    public init(engine: (any NeuralTTSEngine)? = nil) {
        // Eager: building the provider here starts the model warm-up at app
        // launch, off the critical path of the first tap on 聆听.
        providerLanguage = .current
        testEngine = engine
        provider = NeuralSpeechProvider(engine: engine)
        wire(provider)
    }

    @ObservationIgnored private let testEngine: (any NeuralTTSEngine)?

    /// 0…1 across the chapter's segments.
    public var progress: Double {
        totalCount == 0 ? 0 : min(1, Double(spokenCount) / Double(totalCount))
    }

    public func isActive(chapter: Int) -> Bool { chapterNumber == chapter }
    public func isActive(chapter: Int, mode: ReadingMode) -> Bool {
        chapterNumber == chapter && self.mode == mode
    }

    /// A saved part-way point for this reading, if any — the UI uses it to
    /// offer 继续播放 vs 从头开始 before calling `start`.
    public func savedProgress(chapter: Int, mode: ReadingMode) -> (spoken: Int, total: Int)? {
        PlaybackProgress.saved(chapter: chapter, mode: mode)
    }

    /// Primary control: start this reading, or pause/resume if it's already loaded.
    public func toggle(chapter: Int, mode: ReadingMode, lines: [String], startIndex: Int = 0) {
        if isActive(chapter: chapter, mode: mode) {
            if isPlaying { pause(); return }
            if provider.isPaused { resume(); return }
        }
        start(chapter: chapter, mode: mode, lines: lines, startIndex: startIndex)
    }

    public func start(chapter: Int, mode: ReadingMode, lines: [String], startIndex: Int = 0) {
        stop()
        let segments = SpeechScript.segments(from: lines)
        guard !segments.isEmpty else { return }
        configureSession()
        resolveProvider()
        let request = SpeechRequest(
            chapter: chapter,
            mode: mode,
            language: providerLanguage,
            voice: .selected(for: providerLanguage),
            segments: segments
        )
        chapterNumber = chapter
        self.mode = mode
        totalCount = segments.count
        spokenCount = min(max(startIndex, 0), segments.count)
        guard provider.speak(request: request, from: spokenCount, rateScale: rateScale) else {
            // The audio engine refused to start: reset instead of showing a
            // zombie "playing" bar that never advances.
            spokenCount = 0
            totalCount = 0
            chapterNumber = nil
            self.mode = nil
            return
        }
        isPlaying = true
    }

    public func pause() {
        provider.pause()
        isPlaying = false
        persistProgress()
    }

    public func resume() {
        provider.resume()
        isPlaying = true
    }

    public func stop() {
        persistProgress()
        provider.stop()
        isPlaying = false
        spokenCount = 0
        totalCount = 0
        chapterNumber = nil
        mode = nil
    }

    /// Rebuild the provider when the content language changed, so the engine
    /// runs that language's model and selected voice.
    private func resolveProvider() {
        let language = TTSLanguage.current
        guard language != providerLanguage else { return }
        provider.onSegmentFinished = nil
        provider = NeuralSpeechProvider(engine: testEngine)
        providerLanguage = language
        wire(provider)
    }

    private func wire(_ provider: NeuralSpeechProvider) {
        provider.onSegmentFinished = { [weak self] in self?.advance() }
    }

    private func advance() {
        spokenCount += 1
        persistProgress()
        if spokenCount >= totalCount, totalCount > 0 {
            // Natural completion: fully stop — halts the audio engine (battery),
            // clears the resume point, and frees the scheduler's active slot so
            // the idle-time filler can run. The bar disappears with it.
            stop()
        }
    }

    /// Record (or clear, on completion) the resume point for this reading.
    private func persistProgress() {
        guard let chapterNumber, let mode, totalCount > 0 else { return }
        PlaybackProgress.update(
            chapter: chapterNumber, mode: mode, language: providerLanguage,
            spoken: spokenCount, total: totalCount
        )
    }

    private func configureSession() {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)
        #endif
    }
}
