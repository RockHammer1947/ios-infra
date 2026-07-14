#if os(iOS)
    import Foundation

    // Implementation-only: the C shim stays an implementation detail, so
    // modules importing Audio don't need the modulemap paths.
    @_implementationOnly import SherpaOnnxC

    /// Owns a sherpa-onnx OfflineTts session running a MeloTTS (VITS) model.
    /// Actor isolation gives serial, off-main synthesis and keeps the non-Sendable
    /// session pointer from escaping. One instance per model directory; the first
    /// `generate`/`warmUp` pays the model load, so keep it cached.
    actor MeloSynthesizer {
        enum MeloError: Error { case modelMissing, sessionFailed, generationFailed, cancelled }

        /// Cooperative cancellation for an in-flight generate call: the C
        /// callback polls it between decoder chunks, so a background synthesis
        /// yields to the player within milliseconds.
        final class CancelToken: @unchecked Sendable {
            private let flag = NSLock()
            private var cancelled = false
            public init() {}
            func cancel() { flag.withLock { cancelled = true } }
            var isCancelled: Bool { flag.withLock { cancelled } }
        }

        /// Owns the C session; freeing rides on this holder's deinit so the actor
        /// needs no nonisolated deinit touching the pointer.
        private final class Session: @unchecked Sendable {
            let pointer: OpaquePointer
            init(_ pointer: OpaquePointer) { self.pointer = pointer }
            deinit { SherpaOnnxDestroyOfflineTts(pointer) }
        }

        private let layout: MeloModelLayout
        private var session: Session?

        init(modelDirectory: URL) {
            layout = MeloModelLayout(directory: modelDirectory)
        }

        /// Load the model now so the first playback doesn't pay the cost.
        func warmUp() { _ = try? ensureSession() }

        func generate(
            text: String, speakerID: Int32, speed: Float, cancel: CancelToken? = nil
        ) throws -> SpeechAudio {
            let session = try ensureSession().pointer

            var generation = SherpaOnnxGenerationConfig()
            generation.sid = speakerID
            generation.speed = speed

            // The C callback (below, file scope) returns 0 to abort generation
            // early; the token rides the `arg` pointer, unretained — it outlives
            // the call because we hold it right here.
            let arg = cancel.map { UnsafeMutableRawPointer(Unmanaged.passUnretained($0).toOpaque()) }
            // Flat call (no generic closure): the C string is copied up front.
            let cText = strdup(text)
            defer { free(cText) }
            let generated = SherpaOnnxOfflineTtsGenerateWithConfig(
                session, cText, &generation,
                { _, _, _, rawToken in // samples, count, progress, user arg
                    guard let rawToken else { return 1 }
                    let token = Unmanaged<CancelToken>.fromOpaque(rawToken).takeUnretainedValue()
                    return token.isCancelled ? 0 : 1
                },
                arg
            )
            guard let audio = generated else { throw MeloError.generationFailed }
            defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }

            if let cancel, cancel.isCancelled { throw MeloError.cancelled }
            let sampleTotal = Int(audio.pointee.n)
            guard sampleTotal >= 1, let samples = audio.pointee.samples else { throw MeloError.generationFailed }
            return SpeechAudio(
                samples: [Float](UnsafeBufferPointer(start: samples, count: sampleTotal)),
                sampleRate: Double(audio.pointee.sample_rate)
            )
        }

        private func ensureSession() throws -> Session {
            if let session { return session }
            guard layout.isComplete else { throw MeloError.modelMissing }

            let arena = CStringArena()
            var config = SherpaOnnxOfflineTtsConfig()
            config.model.num_threads = 2
            config.model.provider = arena.pointer("cpu")
            config.model.vits.model = arena.pointer(layout.model.path)
            config.model.vits.lexicon = arena.pointer(layout.lexicon.path)
            config.model.vits.tokens = arena.pointer(layout.tokens.path)
            if let dict = layout.dictDir { config.model.vits.dict_dir = arena.pointer(dict.path) }
            config.model.vits.noise_scale = 0.667
            config.model.vits.noise_scale_w = 0.8
            config.model.vits.length_scale = 1.0
            // Chinese text normalization FSTs (English model ships none).
            let fsts = layout.ruleFSTs.map(\.path).joined(separator: ",")
            if !fsts.isEmpty { config.rule_fsts = arena.pointer(fsts) }
            config.max_num_sentences = 1

            guard let created = SherpaOnnxCreateOfflineTts(&config) else { throw MeloError.sessionFailed }
            withExtendedLifetime(arena) {}
            let wrapped = Session(created)
            session = wrapped
            return wrapped
        }
    }

    /// Keeps loaded synthesizers alive across provider re-creation so the model
    /// load cost is paid once per app run, not per language/voice switch.
    @MainActor
    enum MeloSynthesizerCache {
        private static var cache: [URL: MeloSynthesizer] = [:]

        static func synthesizer(for directory: URL) -> MeloSynthesizer {
            if let cached = cache[directory] { return cached }
            let created = MeloSynthesizer(modelDirectory: directory)
            cache[directory] = created
            return created
        }
    }

    /// Holds strdup'd C strings for the lifetime of a config-building call.
    private final class CStringArena {
        private var pointers: [UnsafeMutablePointer<CChar>] = []
        func pointer(_ string: String) -> UnsafePointer<CChar> {
            let duplicated = strdup(string)!
            pointers.append(duplicated)
            return UnsafePointer(duplicated)
        }

        deinit { for pointer in pointers {
            free(pointer)
        } }
    }
#endif
