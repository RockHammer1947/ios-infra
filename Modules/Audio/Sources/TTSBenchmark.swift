#if os(iOS) && DEBUG
    import Foundation

    // Implementation-only: the C shim stays an implementation detail.
    @_implementationOnly import SherpaOnnxC

    /// One engine's measured cost on the current device.
    public struct TTSBenchmarkResult: Sendable, Identifiable {
        public let id = UUID()
        public let label: String
        public let sampleRate: Int
        public let loadSeconds: Double
        public let firstSegmentSeconds: Double
        public let synthSeconds: Double // mean, full passage
        public let audioSeconds: Double
        /// Real-time factor: synth time ÷ audio produced. <1 = faster than real time.
        public var rtf: Double { audioSeconds > 0 ? synthSeconds / audioSeconds : 0 }
    }

    /// The models we compare. Each loads from `TTSBenchmark.rootDir/<dirName>`,
    /// which is populated out-of-band (e.g. `devicectl device copy`) so the
    /// benchmark itself carries no download/extract code.
    public enum TTSBenchModel: String, CaseIterable, Sendable, Identifiable {
        case kokoro, melo
        public var id: String { rawValue }
        public var displayName: String { self == .kokoro ? "Kokoro int8 · 24kHz" : "MeloTTS · 44kHz" }
        var speaker: Int32 { self == .kokoro ? 3 : 0 } // a Chinese voice in each
        var dirName: String { self == .kokoro ? "kokoro-int8-multi-lang-v1_1" : "vits-melo-tts-zh_en" }
    }

    /// DEBUG-only on-device TTS benchmark. Loads a model through sherpa-onnx and
    /// times cold load, first-segment latency, and steady-state RTF, so Kokoro vs
    /// MeloTTS can be compared on real hardware (e.g. iPhone 12 Pro / A14) rather
    /// than extrapolated from a Mac.
    public actor TTSBenchmark {
        public enum BenchError: Error { case missingModel, loadFailed, generateFailed }

        public static let rootDir: URL = {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            return base.appendingPathComponent("TTSBench", isDirectory: true)
        }()

        /// True once a model's onnx is present on disk.
        public static func isReady(_ model: TTSBenchModel) -> Bool {
            let dir = rootDir.appendingPathComponent(model.dirName)
            return ["model.int8.onnx", "model.onnx"].contains {
                FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
            }
        }

        // A chapter-length passage (道德经·第八章) — enough to average RTF.
        private static let passage = "上善若水。水善利万物而不争，处众人之所恶，故几于道。"
            + "居善地，心善渊，与善仁，言善信，正善治，事善能，动善时。夫唯不争，故无尤。"
        private static let firstSegment = "上善若水。"

        public init() {}

        public func run(_ model: TTSBenchModel, runs: Int = 3) throws -> TTSBenchmarkResult {
            guard Self.isReady(model) else { throw BenchError.missingModel }
            let dir = Self.rootDir.appendingPathComponent(model.dirName)
            let arena = CBenchArena()
            var config = SherpaOnnxOfflineTtsConfig()
            config.model.num_threads = 2
            config.model.provider = arena.dup("cpu")

            func p(_ name: String) -> String { dir.appendingPathComponent(name).path }
            func fsts(_ names: [String]) -> String {
                names.map(p).filter { FileManager.default.fileExists(atPath: $0) }.joined(separator: ",")
            }

            switch model {
            case .kokoro:
                let modelFile = ["model.int8.onnx", "model.onnx"].map(p).first {
                    FileManager.default.fileExists(atPath: $0)
                } ?? p("model.int8.onnx")
                config.model.kokoro.model = arena.dup(modelFile)
                config.model.kokoro.voices = arena.dup(p("voices.bin"))
                config.model.kokoro.tokens = arena.dup(p("tokens.txt"))
                config.model.kokoro.data_dir = arena.dup(p("espeak-ng-data"))
                config.model.kokoro.dict_dir = arena.dup(p("dict"))
                config.model.kokoro.lexicon = arena.dup([p("lexicon-us-en.txt"), p("lexicon-zh.txt")].joined(separator: ","))
                config.rule_fsts = arena.dup(fsts(["phone-zh.fst", "date-zh.fst", "number-zh.fst"]))
            case .melo:
                config.model.vits.model = arena.dup(p("model.onnx"))
                config.model.vits.lexicon = arena.dup(p("lexicon.txt"))
                config.model.vits.tokens = arena.dup(p("tokens.txt"))
                config.model.vits.dict_dir = arena.dup(p("dict"))
                config.rule_fsts = arena.dup(fsts(["phone.fst", "date.fst", "number.fst", "new_heteronym.fst"]))
            }
            config.max_num_sentences = 2

            let loadStart = Date()
            guard let tts = SherpaOnnxCreateOfflineTts(&config) else { throw BenchError.loadFailed }
            defer { SherpaOnnxDestroyOfflineTts(tts) }
            withExtendedLifetime(arena) {}
            let loadSeconds = Date().timeIntervalSince(loadStart)

            // First-segment latency (proxy for first-audio after load).
            let firstStart = Date()
            _ = try synth(tts, Self.firstSegment, model.speaker)
            let firstSegmentSeconds = Date().timeIntervalSince(firstStart)

            // Steady-state: mean over `runs` of the full passage.
            var times: [Double] = []
            var count = 0, sampleRate = 0
            for _ in 0 ..< runs {
                let s = Date()
                (count, sampleRate) = try synth(tts, Self.passage, model.speaker)
                times.append(Date().timeIntervalSince(s))
            }
            let synthSeconds = times.reduce(0, +) / Double(times.count)
            let audioSeconds = Double(count) / Double(max(sampleRate, 1))
            return TTSBenchmarkResult(
                label: model.displayName, sampleRate: sampleRate,
                loadSeconds: loadSeconds, firstSegmentSeconds: firstSegmentSeconds,
                synthSeconds: synthSeconds, audioSeconds: audioSeconds
            )
        }

        // MARK: - Headless runner (launch-argument driven, writes JSON)

        public struct Output: Codable, Sendable {
            public struct Row: Codable, Sendable {
                public let model: String, label: String
                public let sampleRate: Int
                public let load, firstSegment, synth, audio, rtf: Double
                public let error: String?
            }

            public let device: String
            public let rows: [Row]
        }

        /// Runs every model and writes `rootDir/results.json`. Invoked from the
        /// app entry when launched with the `run-tts-bench` argument, so the
        /// benchmark runs headless on the device and the file is pulled back.
        public static func runAllToFile() async {
            let bench = TTSBenchmark()
            var rows: [Output.Row] = []
            for model in TTSBenchModel.allCases {
                do {
                    let r = try await bench.run(model)
                    rows.append(.init(
                        model: model.rawValue,
                        label: r.label,
                        sampleRate: r.sampleRate,
                        load: r.loadSeconds,
                        firstSegment: r.firstSegmentSeconds,
                        synth: r.synthSeconds,
                        audio: r.audioSeconds,
                        rtf: r.rtf,
                        error: nil
                    ))
                } catch {
                    rows.append(.init(
                        model: model.rawValue,
                        label: model.displayName,
                        sampleRate: 0,
                        load: 0,
                        firstSegment: 0,
                        synth: 0,
                        audio: 0,
                        rtf: 0,
                        error: "\(error)"
                    ))
                }
            }
            let output = Output(device: machineIdentifier(), rows: rows)
            try? FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(output) {
                try? data.write(to: rootDir.appendingPathComponent("results.json"))
            }
        }

        public static func machineIdentifier() -> String {
            var sys = utsname()
            uname(&sys)
            return withUnsafeBytes(of: &sys.machine) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
        }

        private func synth(_ tts: OpaquePointer, _ text: String, _ sid: Int32) throws -> (count: Int, sampleRate: Int) {
            var gen = SherpaOnnxGenerationConfig()
            gen.sid = sid
            gen.speed = 1.0
            gen.silence_scale = 0.2
            guard let audio = text.withCString({ SherpaOnnxOfflineTtsGenerateWithConfig(tts, $0, &gen, nil, nil) })
            else { throw BenchError.generateFailed }
            defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }
            return (Int(audio.pointee.n), Int(audio.pointee.sample_rate))
        }
    }

    /// Holds strdup'd C strings for the lifetime of a config-building call.
    private final class CBenchArena {
        private var pointers: [UnsafeMutablePointer<CChar>] = []
        func dup(_ string: String) -> UnsafePointer<CChar> {
            let duplicated = strdup(string)!
            pointers.append(duplicated)
            return UnsafePointer(duplicated)
        }

        deinit { for pointer in pointers {
            free(pointer)
        } }
    }
#endif
