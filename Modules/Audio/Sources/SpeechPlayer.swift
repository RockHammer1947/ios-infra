import AVFoundation
import Observation

/// Reads chapter text aloud with the system speech synthesizer (zh-CN). A thin,
/// observable controller the reader UI binds to: play / pause / resume / stop
/// plus segment-level progress for the waveform.
@MainActor
@Observable
public final class SpeechPlayer: NSObject {
    /// True while audio is actively speaking (false when paused or stopped).
    public private(set) var isPlaying = false
    /// Which chapter is loaded, if any.
    public private(set) var chapterNumber: Int?
    /// Segments spoken so far, and the total queued — drives `progress`.
    public private(set) var spokenCount = 0
    public private(set) var totalCount = 0

    /// Speed multiplier applied to the default speech rate (1.0 = normal).
    /// Settings drives this; clamped to a sane reading range.
    public var rateScale: Double = 1.0

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override public init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 0…1 across the chapter's segments.
    public var progress: Double {
        totalCount == 0 ? 0 : min(1, Double(spokenCount) / Double(totalCount))
    }

    public func isActive(chapter: Int) -> Bool { chapterNumber == chapter }

    /// Primary control: start this chapter, or pause/resume if it's already loaded.
    public func toggle(chapter: Int, lines: [String]) {
        if chapterNumber == chapter {
            if isPlaying { pause(); return }
            if synthesizer.isPaused { resume(); return }
        }
        start(chapter: chapter, lines: lines)
    }

    public func start(chapter: Int, lines: [String]) {
        stop()
        let segments = SpeechScript.segments(from: lines)
        guard !segments.isEmpty else { return }
        configureSession()
        chapterNumber = chapter
        totalCount = segments.count
        for segment in segments {
            let utterance = AVSpeechUtterance(string: segment)
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            let scale = Float(min(max(rateScale, 0.5), 1.5))
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92 * scale
            utterance.postUtteranceDelay = 0.15
            synthesizer.speak(utterance)
        }
        isPlaying = true
    }

    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
    }

    public func resume() {
        synthesizer.continueSpeaking()
        isPlaying = true
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        spokenCount = 0
        totalCount = 0
        chapterNumber = nil
    }

    fileprivate func advance() {
        spokenCount += 1
        if spokenCount >= totalCount, totalCount > 0 { isPlaying = false }
    }

    private func configureSession() {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)
        #endif
    }
}

extension SpeechPlayer: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didFinish _: AVSpeechUtterance
    ) {
        Task { @MainActor in self.advance() }
    }
}
