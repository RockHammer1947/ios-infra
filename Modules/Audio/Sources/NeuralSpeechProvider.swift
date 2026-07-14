import AVFoundation

/// Synthesis engine behind the speech provider. On iOS this is
/// `SherpaOnnxEngine`, pulling cached-or-synthesized MeloTTS segments through
/// the `SynthesisScheduler`. On macOS (no xcframework) and in tests,
/// `PlaceholderNeuralEngine` keeps the pipeline — playback control and
/// progress — exercisable.
@MainActor
public protocol NeuralTTSEngine: AnyObject {
    var onSegmentFinished: (@MainActor () -> Void)? { get set }
    var isPaused: Bool { get }
    /// False when playback could not start (e.g. the audio engine failed) —
    /// the caller must reset its state instead of showing a zombie "playing".
    @discardableResult
    func speak(request: SpeechRequest, from startIndex: Int, rateScale: Double) -> Bool
    func pause()
    func resume()
    func stop()
}

/// Fallback engine for destinations without the sherpa-onnx xcframework
/// (currently macOS) and for tests: Apple's synthesizer in the content
/// language, no caching. iOS always uses the real `SherpaOnnxEngine`.
@MainActor
public final class PlaceholderNeuralEngine: NSObject, NeuralTTSEngine {
    public var onSegmentFinished: (@MainActor () -> Void)?
    private let synthesizer = AVSpeechSynthesizer()

    override public init() {
        super.init()
        synthesizer.delegate = self
    }

    public var isPaused: Bool { synthesizer.isPaused }

    @discardableResult
    public func speak(request: SpeechRequest, from startIndex: Int, rateScale: Double) -> Bool {
        let scale = Float(min(max(rateScale, 0.5), 1.5))
        for segment in request.segments.dropFirst(startIndex) {
            let utterance = AVSpeechUtterance(string: segment)
            utterance.voice = AVSpeechSynthesisVoice(language: SpeechLanguage.current)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92 * scale
            utterance.postUtteranceDelay = 0.15
            synthesizer.speak(utterance)
        }
        return true
    }

    public func pause() { synthesizer.pauseSpeaking(at: .word) }
    public func resume() { synthesizer.continueSpeaking() }
    public func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

extension PlaceholderNeuralEngine: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didFinish _: AVSpeechUtterance
    ) {
        Task { @MainActor in self.onSegmentFinished?() }
    }
}

/// The app's one speech backend: the bundled MeloTTS model for the current
/// content language (no system-voice fallback). `SpeechPlayer` rebuilds it on
/// a language switch so `speak` always runs the right model and voice.
@MainActor
public final class NeuralSpeechProvider {
    public var onSegmentFinished: (@MainActor () -> Void)? {
        get { engine.onSegmentFinished }
        set { engine.onSegmentFinished = newValue }
    }

    private let engine: any NeuralTTSEngine

    public init(engine: (any NeuralTTSEngine)? = nil) {
        #if os(iOS)
            self.engine = engine ?? SherpaOnnxEngine(
                modelDirectory: BundledTTSModels.directory(for: .current)
            )
        #else
            self.engine = engine ?? PlaceholderNeuralEngine()
        #endif
    }

    public var isPaused: Bool { engine.isPaused }

    @discardableResult
    public func speak(request: SpeechRequest, from startIndex: Int, rateScale: Double) -> Bool {
        engine.speak(request: request, from: startIndex, rateScale: rateScale)
    }

    public func pause() { engine.pause() }
    public func resume() { engine.resume() }
    public func stop() { engine.stop() }
}
