#if os(iOS)
    import Foundation
    import os

    /// Synthesizes one text segment. The production implementation wraps the
    /// MeloTTS synthesizer; tests inject a fake to exercise the scheduler
    /// without the 163MB model.
    protocol SegmentSynthesizing: Sendable {
        func synthesize(
            text: String,
            voice: TTSVoice,
            language: TTSLanguage,
            cancel: MeloSynthesizer.CancelToken?
        ) async throws -> SpeechAudio
    }

    /// Production synthesis: the cached MeloTTS session for the language's
    /// bundled model, always at speed 1.0 (playback applies the reader's 语速).
    struct MeloSegmentSynthesizer: SegmentSynthesizing {
        func synthesize(
            text: String,
            voice: TTSVoice,
            language: TTSLanguage,
            cancel: MeloSynthesizer.CancelToken?
        ) async throws -> SpeechAudio {
            let synthesizer = await MeloSynthesizerCache.synthesizer(
                for: BundledTTSModels.directory(for: language)
            )
            return try await synthesizer.generate(
                text: text, speakerID: voice.sid, speed: 1.0, cancel: cancel
            )
        }
    }

    /// The synthesis task queue behind all playback:
    ///
    /// - The **player path** (`segment(of:at:)`) is authoritative: cache hit →
    ///   load from disk; miss → synthesize now, persist, return. Whatever the
    ///   player produces is cached, so a fully-played chapter is a fully-cached
    ///   chapter for free.
    /// - The **filler path** completes what playback started: every request is
    ///   registered as a task, and whenever no playback is pulling (TTS idle),
    ///   the filler silently synthesizes the missing segments of the most
    ///   recently touched incomplete task, then older ones. Starting playback
    ///   anywhere cancels the in-flight filler segment within milliseconds
    ///   (cooperative C-callback cancellation), so the user never waits on
    ///   background work.
    /// - Tasks survive relaunches implicitly: segment files ARE the state.
    ///   Re-registering the same request resumes where the cache left off.
    actor SynthesisScheduler {
        static let shared = SynthesisScheduler()

        private let cache: TTSCache
        private let synthesizer: any SegmentSynthesizing
        private let log = Logger(subsystem: "com.rockhammerlabs.daodejing", category: "tts")

        /// Incomplete synthesis tasks, most recently touched last.
        private var tasks: [SpeechRequest] = []
        /// The request playback is currently pulling from, if any.
        private var activeKey: TTSCacheKey?
        /// Cancels the filler's in-flight generate call.
        private var fillerCancel: MeloSynthesizer.CancelToken?
        private var fillerRunning = false

        init(cache: TTSCache = .shared, synthesizer: any SegmentSynthesizing = MeloSegmentSynthesizer()) {
            self.cache = cache
            self.synthesizer = synthesizer
        }

        // MARK: - Player path (priority)

        /// Playback is starting on `request`: register it as a task, mark it
        /// active (pausing background fill), and report cached progress.
        /// `previous` is the reading this playback replaces — re-registered
        /// here atomically, so no fire-and-forget `playbackEnded` can race in
        /// after `begin` and clear the new active key.
        func begin(_ request: SpeechRequest, ending previous: SpeechRequest? = nil) async -> Set<Int> {
            if let previous { enqueue(previous) }
            activeKey = request.cacheKey
            fillerCancel?.cancel() // yield the synthesizer to the player now
            enqueue(request)
            return await cache.preparedIndices(for: request)
        }

        /// One segment for the active playback: cache hit or synthesize-now.
        /// `cancel` lets the engine abandon an in-flight synthesis when the
        /// user switches chapters mid-segment.
        func segment(
            of request: SpeechRequest, at index: Int, cancel: MeloSynthesizer.CancelToken? = nil
        ) async -> SpeechAudio? {
            if let cached = await cache.loadSegment(key: request.cacheKey, index: index) {
                return cached
            }
            guard index < request.segments.count else { return nil }
            guard let audio = try? await synthesizer.synthesize(
                text: request.segments[index],
                voice: request.voice,
                language: request.language,
                cancel: cancel
            ) else { return nil }
            await cache.storeSegment(key: request.cacheKey, index: index, audio: audio)
            return audio
        }

        /// Playback stopped/paused/finished: nothing is pulling — let the
        /// filler continue incomplete tasks (this one first; `enqueue` keeps
        /// it most-recent).
        func playbackEnded(_ request: SpeechRequest?) {
            if let request { enqueue(request) }
            activeKey = nil
            kickFiller()
        }

        /// The audition player briefly needs the synthesizer too.
        func auditionStarted() {
            fillerCancel?.cancel()
        }

        /// Audition finished: resume idle-time fill — but never touch
        /// `activeKey`; a chapter playback may be running concurrently.
        func auditionEnded() {
            guard activeKey == nil else { return }
            kickFiller()
        }

        // MARK: - Filler (idle-time completion)

        private func enqueue(_ request: SpeechRequest) {
            tasks.removeAll { $0.cacheKey == request.cacheKey }
            tasks.append(request)
        }

        private func kickFiller() {
            guard !fillerRunning else { return }
            fillerRunning = true
            Task { await self.fillLoop() }
        }

        private func fillLoop() async {
            defer { fillerRunning = false }
            while activeKey == nil {
                // Most recently touched incomplete task first.
                guard let request = await nextIncompleteTask() else { return }
                guard let index = await cache.missingIndices(for: request).first else { continue }

                let token = MeloSynthesizer.CancelToken()
                fillerCancel = token
                guard activeKey == nil, !token.isCancelled else { return }
                do {
                    let audio = try await synthesizer.synthesize(
                        text: request.segments[index],
                        voice: request.voice,
                        language: request.language,
                        cancel: token
                    )
                    // A playback may have started while this segment rendered;
                    // its output is still valid cache either way. A failed
                    // write (disk full, unwritable dir) must STOP the loop —
                    // the index would stay "missing" and spin the CPU forever.
                    guard await cache.storeSegment(key: request.cacheKey, index: index, audio: audio) else {
                        log.warning("🧵 filler store failed ch\(request.chapter) seg \(index) — parking")
                        return
                    }
                    log.info("🧵 filler cached ch\(request.chapter)/\(request.mode.rawValue) seg \(index)")
                } catch {
                    // Cancelled (playback started) or failed — stop; a later
                    // idle period retries.
                    return
                }
            }
        }

        /// Pop completed tasks off the registry; return the newest incomplete.
        private func nextIncompleteTask() async -> SpeechRequest? {
            while let candidate = tasks.last {
                let missing = await cache.missingIndices(for: candidate)
                if missing.isEmpty {
                    tasks.removeAll { $0.cacheKey == candidate.cacheKey }
                    log.info("✅ task complete ch\(candidate.chapter)/\(candidate.mode.rawValue)")
                } else {
                    return candidate
                }
            }
            return nil
        }
    }
#endif
