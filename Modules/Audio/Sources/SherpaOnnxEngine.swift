#if os(iOS)
    import AVFoundation
    import os

    /// The real neural engine: pulls each segment from the `SynthesisScheduler`
    /// (disk cache hit, or synthesize-now with priority) and plays the PCM
    /// through an `AVAudioEngine`. Pulling runs ahead of playback with a small
    /// lookahead so audio never starves, without synthesizing a whole chapter
    /// up front.
    ///
    /// Synthesis is always 1.0× (cache-stable); the reader's 语速 is applied at
    /// playback time through an `AVAudioUnitTimePitch`, so cached audio serves
    /// every speed.
    @MainActor
    public final class SherpaOnnxEngine: NeuralTTSEngine {
        public var onSegmentFinished: (@MainActor () -> Void)?
        public private(set) var isPaused = false

        /// Segments allowed to be scheduled-but-unfinished at once.
        private static let lookahead = 2

        private let audioEngine = AVAudioEngine()
        private let playerNode = AVAudioPlayerNode()
        private let timePitch = AVAudioUnitTimePitch()
        // MeloTTS outputs 44.1kHz mono float PCM (both zh and en models).
        private let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false
        )!

        /// Bumped on every stop/speak; stale playback callbacks compare against
        /// it so a stopped chapter can't advance the next one's progress.
        private var epoch = 0
        private var speakTask: Task<Void, Never>?
        private var inFlight = 0
        private var gate: CheckedContinuation<Void, Never>?
        private var currentRequest: SpeechRequest?
        /// Cancels the in-flight player-path synthesis when the user switches
        /// chapters mid-segment, so the new chapter isn't queued behind it.
        private var pullCancel: MeloSynthesizer.CancelToken?

        public init(modelDirectory: URL) {
            audioEngine.attach(playerNode)
            audioEngine.attach(timePitch)
            audioEngine.connect(playerNode, to: timePitch, format: format)
            audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: format)
            // Pay the model load off the critical path of the first tap.
            let synthesizer = MeloSynthesizerCache.synthesizer(for: modelDirectory)
            Task { await synthesizer.warmUp() }
        }

        @discardableResult
        public func speak(request: SpeechRequest, from startIndex: Int, rateScale: Double) -> Bool {
            // The old reading is handed to `begin(_:ending:)` below in ONE
            // atomic scheduler call — a separate playbackEnded task could race
            // in after begin and clear the new active key.
            let previous = currentRequest
            haltPlayback(notifyScheduler: false)
            epoch += 1
            let epoch = epoch
            currentRequest = request
            timePitch.rate = Float(min(max(rateScale, 0.5), 1.5))
            Logger(subsystem: "com.rockhammerlabs.daodejing", category: "tts")
                .info("🧠 speaking ch\(request.chapter)/\(request.mode.rawValue) from seg \(startIndex) (voice \(request.voice.id))")

            guard startEngineWithRetry() else {
                Logger(subsystem: "com.rockhammerlabs.daodejing", category: "tts")
                    .fault("audio engine failed to start — playback aborted")
                return false
            }
            playerNode.play()
            isPaused = false

            let pullToken = MeloSynthesizer.CancelToken()
            pullCancel = pullToken
            speakTask = Task { [weak self] in
                _ = await SynthesisScheduler.shared.begin(request, ending: previous)
                for index in startIndex ..< request.segments.count {
                    guard let self, !Task.isCancelled else { return }
                    await self.waitForLookaheadSlot()
                    guard !Task.isCancelled else { return }
                    guard let audio = await SynthesisScheduler.shared.segment(
                        of: request, at: index, cancel: pullToken
                    ) else {
                        // Failed segment: still advance progress so the
                        // player's segment count stays in step.
                        await self.segmentDone(epoch: epoch)
                        continue
                    }
                    await self.schedule(audio, epoch: epoch)
                }
            }
            return true
        }

        /// One retry after re-activating the audio session: recovers from a
        /// deactivated session (interruption teardown) without user action.
        private func startEngineWithRetry() -> Bool {
            if startEngine() { return true }
            try? AVAudioSession.sharedInstance().setActive(true)
            return startEngine()
        }

        public func pause() {
            playerNode.pause()
            isPaused = true
            // Nothing is consuming audio — let the filler use the idle time.
            let request = currentRequest
            Task { await SynthesisScheduler.shared.playbackEnded(request) }
        }

        public func resume() {
            guard startEngine() else { return }
            if let request = currentRequest {
                Task { _ = await SynthesisScheduler.shared.begin(request) }
            }
            playerNode.play()
            isPaused = false
        }

        public func stop() {
            haltPlayback(notifyScheduler: true)
        }

        // MARK: - Playback plumbing

        private func schedule(_ audio: SpeechAudio, epoch: Int) {
            guard epoch == self.epoch,
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)
                  ),
                  let channel = buffer.floatChannelData
            else { return }
            buffer.frameLength = AVAudioFrameCount(audio.samples.count)
            audio.samples.withUnsafeBufferPointer { source in
                channel[0].update(from: source.baseAddress!, count: source.count)
            }

            inFlight += 1
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in self?.segmentDone(epoch: epoch) }
            }
        }

        /// A segment finished playing (or was skipped): advance progress and
        /// free a lookahead slot — unless a stop() invalidated this epoch.
        private func segmentDone(epoch: Int) {
            guard epoch == self.epoch else { return }
            inFlight = max(0, inFlight - 1)
            gate?.resume()
            gate = nil
            onSegmentFinished?()
        }

        private func waitForLookaheadSlot() async {
            guard inFlight >= Self.lookahead else { return }
            await withCheckedContinuation { gate = $0 }
        }

        private func startEngine() -> Bool {
            guard !audioEngine.isRunning else { return true }
            audioEngine.prepare()
            do {
                try audioEngine.start()
                return true
            } catch {
                Logger(subsystem: "com.rockhammerlabs.daodejing", category: "tts")
                    .fault("engine start error: \(error)")
                return false
            }
        }

        private func haltPlayback(notifyScheduler: Bool) {
            epoch += 1
            pullCancel?.cancel()
            pullCancel = nil
            speakTask?.cancel()
            speakTask = nil
            gate?.resume()
            gate = nil
            inFlight = 0
            playerNode.stop()
            audioEngine.stop()
            isPaused = false
            if notifyScheduler {
                let request = currentRequest
                Task { await SynthesisScheduler.shared.playbackEnded(request) }
            }
            currentRequest = nil
        }
    }
#endif
