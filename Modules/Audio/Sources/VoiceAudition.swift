import AVFoundation
import Observation

/// Plays a short one-shot sample of a voice so the reader can pick by ear in
/// Settings. Synthesizes `TTSVoice.sampleText` through the same cached
/// MeloTTS synthesizer the reader uses, into its own small player — fully
/// independent of `SpeechPlayer`'s chapter playback.
@MainActor
@Observable
public final class VoiceAudition {
    /// The voice currently being synthesized or played, if any (drives the UI).
    public private(set) var playingVoiceID: String?

    #if os(iOS)
        @ObservationIgnored private let audioEngine = AVAudioEngine()
        @ObservationIgnored private let playerNode = AVAudioPlayerNode()
        @ObservationIgnored private let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false
        )!
        /// Invalidates in-flight synthesis/completion when a newer audition starts.
        @ObservationIgnored private var epoch = 0

        public init() {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        }

        /// Synthesize and play `voice` reading the language's sample line.
        /// Tapping the voice that's already playing stops it instead.
        public func toggle(_ voice: TTSVoice, language: TTSLanguage) {
            if playingVoiceID == voice.id {
                stop()
                return
            }
            stop()
            epoch += 1
            let epoch = epoch
            playingVoiceID = voice.id
            // The audition needs the synthesizer now — pause background fill.
            Task { await SynthesisScheduler.shared.auditionStarted() }

            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)

            let synthesizer = MeloSynthesizerCache.synthesizer(
                for: BundledTTSModels.directory(for: language)
            )
            let text = TTSVoice.sampleText(for: language)
            Task { [weak self] in
                guard let audio = try? await synthesizer.generate(
                    text: text, speakerID: voice.sid, speed: 1.0
                ) else {
                    await MainActor.run { self?.finished(epoch: epoch) }
                    return
                }
                await MainActor.run { self?.play(audio, epoch: epoch) }
            }
        }

        public func stop() {
            epoch += 1
            playerNode.stop()
            audioEngine.stop()
            playingVoiceID = nil
        }

        private func play(_ audio: SpeechAudio, epoch: Int) {
            guard epoch == self.epoch,
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)
                  )
            else { return }
            buffer.frameLength = AVAudioFrameCount(audio.samples.count)
            audio.samples.withUnsafeBufferPointer { source in
                buffer.floatChannelData![0].update(from: source.baseAddress!, count: source.count)
            }
            audioEngine.prepare()
            guard (try? audioEngine.start()) != nil else {
                finished(epoch: epoch)
                return
            }
            playerNode.play()
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in self?.finished(epoch: epoch) }
            }
        }

        private func finished(epoch: Int) {
            guard epoch == self.epoch else { return }
            playerNode.stop()
            audioEngine.stop()
            playingVoiceID = nil
            // Audition done — the filler may resume completing queued tasks.
            Task { await SynthesisScheduler.shared.auditionEnded() }
        }
    #else
        public init() {}
        public func toggle(_: TTSVoice, language _: TTSLanguage) {}
        public func stop() {}
    #endif
}
