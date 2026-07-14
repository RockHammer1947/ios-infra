import Foundation
import Testing
@testable import Audio

// MARK: - Fakes

/// Deterministic synthesizer: tiny sine per call, optional per-call delay,
/// honors cancellation, records every request.
private final class FakeSynthesizer: SegmentSynthesizing, @unchecked Sendable {
    struct Call: Sendable { let text: String; let cancelled: Bool }

    private let lock = NSLock()
    private var _calls: [Call] = []
    private let delayNanos: UInt64

    init(delayMillis: UInt64 = 0) {
        delayNanos = delayMillis * 1_000_000
    }

    var calls: [Call] { lock.withLock { _calls } }
    var callTexts: [String] { calls.map(\.text) }

    func synthesize(
        text: String, voice _: TTSVoice, language _: TTSLanguage,
        cancel: MeloSynthesizer.CancelToken?
    ) async throws -> SpeechAudio {
        if delayNanos > 0 {
            // Poll in slices so cancellation lands mid-"generation".
            let slices = 10
            for _ in 0 ..< slices {
                try? await Task.sleep(nanoseconds: delayNanos / UInt64(slices))
                if let cancel, cancel.isCancelled { break }
            }
        }
        let wasCancelled = cancel?.isCancelled ?? false
        lock.withLock { _calls.append(Call(text: text, cancelled: wasCancelled)) }
        if wasCancelled { throw MeloSynthesizer.MeloError.cancelled }
        return SpeechAudio(samples: [Float](repeating: 0.1, count: 441), sampleRate: 44100)
    }
}

/// Scripted engine for `SpeechPlayer` tests: records speak calls; the test
/// fires `onSegmentFinished` by hand.
@MainActor
private final class FakeEngine: NeuralTTSEngine {
    var onSegmentFinished: (@MainActor () -> Void)?
    var isPaused = false
    var spoken: [(chapter: Int, mode: ReadingMode, from: Int, rate: Double)] = []
    var stopCount = 0

    @discardableResult
    func speak(request: SpeechRequest, from startIndex: Int, rateScale: Double) -> Bool {
        spoken.append((request.chapter, request.mode, startIndex, rateScale))
        isPaused = false
        return true
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }
    func stop() { stopCount += 1; isPaused = false }

    func finishSegment() { onSegmentFinished?() }
}

// MARK: - Helpers

private func makeRequest(
    chapter: Int, mode: ReadingMode = .original, segments: [String]
) -> SpeechRequest {
    SpeechRequest(chapter: chapter, mode: mode, language: .zh, voice: .fallback(for: .zh), segments: segments)
}

private func tempCache(maxBytes: Int64 = 500 * 1024 * 1024) -> (TTSCache, URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("pipeline-\(UUID().uuidString)", isDirectory: true)
    return (TTSCache(root: root, maxBytes: maxBytes), root)
}

/// Poll until `condition` holds (or time out) — the filler runs on its own task.
private func eventually(
    timeout: Duration = .seconds(3), _ condition: () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(40))
    }
    return await condition()
}

// MARK: - Scheduler

@Suite("SynthesisScheduler")
struct SynthesisSchedulerTests {
    @Test("Player path synthesizes once, then serves every replay from cache")
    func playPathCaches() async throws {
        let (cache, root) = tempCache()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = FakeSynthesizer()
        let scheduler = SynthesisScheduler(cache: cache, synthesizer: fake)
        let request = makeRequest(chapter: 1, segments: ["一。", "二。", "三。"])

        _ = await scheduler.begin(request)
        for index in 0 ..< 3 {
            #expect(await scheduler.segment(of: request, at: index) != nil)
        }
        #expect(fake.callTexts == ["一。", "二。", "三。"])

        // Replay: all cache hits — the synthesizer is never asked again.
        for index in 0 ..< 3 {
            #expect(await scheduler.segment(of: request, at: index) != nil)
        }
        #expect(fake.calls.count == 3, "replay must not re-synthesize")
        #expect(await cache.missingIndices(for: request).isEmpty)
    }

    @Test("Filler silently completes a partially played chapter when idle")
    func fillerCompletesTask() async throws {
        let (cache, root) = tempCache()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = FakeSynthesizer()
        let scheduler = SynthesisScheduler(cache: cache, synthesizer: fake)
        let request = makeRequest(chapter: 2, segments: ["甲。", "乙。", "丙。", "丁。"])

        // Play only the first segment, then stop.
        _ = await scheduler.begin(request)
        _ = await scheduler.segment(of: request, at: 0)
        await scheduler.playbackEnded(request)

        // The filler finishes the remaining three on its own.
        let completed = await eventually {
            await cache.missingIndices(for: request).isEmpty
        }
        #expect(completed, "filler should complete the chapter while idle")
        #expect(Set(fake.callTexts) == ["甲。", "乙。", "丙。", "丁。"])
    }

    @Test("Filler yields to new playback within one in-flight segment")
    func fillerYieldsToPlayer() async throws {
        let (cache, root) = tempCache()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = FakeSynthesizer(delayMillis: 400) // slow enough to interrupt
        let scheduler = SynthesisScheduler(cache: cache, synthesizer: fake)
        let taskA = makeRequest(chapter: 3, segments: ["A一。", "A二。"])
        let taskB = makeRequest(chapter: 4, segments: ["B一。"])

        // Register A and let the filler start grinding on it.
        await scheduler.playbackEnded(taskA)
        try await Task.sleep(for: .milliseconds(100)) // filler is mid-segment now

        // User starts B: the filler's in-flight segment must cancel, and B
        // must be served.
        _ = await scheduler.begin(taskB)
        let audio = await scheduler.segment(of: taskB, at: 0)
        #expect(audio != nil)

        let aCancelled = fake.calls.contains { $0.text.hasPrefix("A") && $0.cancelled }
        #expect(aCancelled, "the filler's A-segment should have been cancelled")
        #expect(fake.calls.contains { $0.text == "B一。" && !$0.cancelled })

        // Idle again: the filler eventually completes A too.
        await scheduler.playbackEnded(taskB)
        let completed = await eventually {
            await cache.missingIndices(for: taskA).isEmpty
        }
        #expect(completed, "A should finish once the player goes idle")
    }

    @Test("A failed cache write parks the filler instead of spinning the CPU")
    func storeFailureParksFiller() async throws {
        // Root under a read-only location: every write fails, every index
        // stays "missing" — the old behavior would loop forever.
        let cache = TTSCache(root: URL(fileURLWithPath: "/System/tts-denied"))
        let fake = FakeSynthesizer()
        let scheduler = SynthesisScheduler(cache: cache, synthesizer: fake)
        let request = makeRequest(chapter: 6, segments: ["坏。", "盘。"])

        await scheduler.playbackEnded(request) // kick the filler
        try await Task.sleep(for: .milliseconds(400))
        #expect(fake.calls.count <= 1, "filler must park after a store failure, not respin")
    }

    @Test("Completed tasks drop out of the registry (no busy re-checking)")
    func completedTasksPopped() async throws {
        let (cache, root) = tempCache()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = FakeSynthesizer()
        let scheduler = SynthesisScheduler(cache: cache, synthesizer: fake)
        let request = makeRequest(chapter: 5, segments: ["完。"])

        _ = await scheduler.begin(request)
        _ = await scheduler.segment(of: request, at: 0)
        await scheduler.playbackEnded(request)

        _ = await eventually { await cache.missingIndices(for: request).isEmpty }
        let callsAfterComplete = fake.calls.count
        // Kick the filler again: nothing left to do, no new synth calls.
        await scheduler.playbackEnded(nil)
        try await Task.sleep(for: .milliseconds(150))
        #expect(fake.calls.count == callsAfterComplete)
    }
}

// MARK: - Cache eviction

@Suite("TTSCache eviction")
struct TTSCacheEvictionTests {
    @Test("LRU eviction removes the oldest chapter, never the active one")
    func evictsOldestFirst() async throws {
        // Cap small enough that two chapters can't coexist.
        let (cache, root) = tempCache(maxBytes: 300_000)
        defer { try? FileManager.default.removeItem(at: root) }

        let audio = SpeechAudio(samples: [Float](repeating: 0.2, count: 60000), sampleRate: 44100)
        let old = makeRequest(chapter: 1, segments: ["旧一。", "旧二。"])
        let fresh = makeRequest(chapter: 2, segments: ["新一。", "新二。"])

        _ = await cache.preparedIndices(for: old)
        await cache.storeSegment(key: old.cacheKey, index: 0, audio: audio)
        await cache.storeSegment(key: old.cacheKey, index: 1, audio: audio)
        try await Task.sleep(for: .seconds(1.1)) // mtime resolution

        _ = await cache.preparedIndices(for: fresh)
        await cache.storeSegment(key: fresh.cacheKey, index: 0, audio: audio)
        await cache.storeSegment(key: fresh.cacheKey, index: 1, audio: audio)

        // The old chapter was evicted; the active (protected) one survived.
        #expect(await cache.missingIndices(for: fresh).isEmpty)
        #expect(await cache.loadSegment(key: old.cacheKey, index: 0) == nil)
    }
}

// MARK: - SpeechPlayer

@Suite("SpeechPlayer")
@MainActor
struct SpeechPlayerTests {
    private func makePlayer() -> (SpeechPlayer, FakeEngine) {
        let engine = FakeEngine()
        let player = SpeechPlayer(engine: engine)
        return (player, engine)
    }

    @Test("Start sets identity; finished segments persist then clear progress")
    func progressLifecycle() {
        let chapter = 971
        defer { PlaybackProgress.clear(chapter: chapter, mode: .original) }
        let (player, engine) = makePlayer()

        player.start(chapter: chapter, mode: .original, lines: ["一。二。三。"])
        #expect(player.isActive(chapter: chapter, mode: .original))
        #expect(player.totalCount == 3)
        #expect(player.isPlaying)
        #expect(engine.spoken.last?.from == 0)

        engine.finishSegment()
        #expect(player.spokenCount == 1)
        let saved = player.savedProgress(chapter: chapter, mode: .original)
        #expect(saved?.spoken == 1)
        #expect(saved?.total == 3)

        engine.finishSegment()
        engine.finishSegment()
        #expect(!player.isPlaying, "completing all segments ends playback")
        #expect(
            player.savedProgress(chapter: chapter, mode: .original) == nil,
            "completion must clear the resume point"
        )
        // Natural completion fully stops: engine halted (battery, and the
        // scheduler's active slot freed for the filler), identity cleared.
        #expect(engine.stopCount >= 1, "completion must stop the engine")
        #expect(player.chapterNumber == nil)
    }

    @Test("Resume from a saved index: progress starts there, engine told to skip")
    func resumeFromIndex() {
        let chapter = 972
        defer { PlaybackProgress.clear(chapter: chapter, mode: .interpretation) }
        let (player, engine) = makePlayer()

        player.start(chapter: chapter, mode: .interpretation, lines: ["一。二。三。四。"], startIndex: 2)
        #expect(player.spokenCount == 2)
        #expect(engine.spoken.last?.from == 2)
        #expect(engine.spoken.last?.mode == .interpretation)

        engine.finishSegment()
        engine.finishSegment()
        #expect(!player.isPlaying)
        #expect(player.savedProgress(chapter: chapter, mode: .interpretation) == nil)
        #expect(engine.stopCount >= 1, "completion must stop the engine")
    }

    @Test("Toggle: same reading pauses/resumes; different mode restarts")
    func toggleSemantics() {
        let chapter = 973
        defer {
            PlaybackProgress.clear(chapter: chapter, mode: .original)
            PlaybackProgress.clear(chapter: chapter, mode: .interpretation)
        }
        let (player, engine) = makePlayer()

        player.toggle(chapter: chapter, mode: .original, lines: ["一。二。"])
        #expect(engine.spoken.count == 1)

        player.toggle(chapter: chapter, mode: .original, lines: ["一。二。"])
        #expect(!player.isPlaying, "second toggle pauses")
        #expect(engine.isPaused)

        player.toggle(chapter: chapter, mode: .original, lines: ["一。二。"])
        #expect(player.isPlaying, "third toggle resumes")
        #expect(engine.spoken.count == 1, "pause/resume must not restart")

        // Same chapter, different mode → a fresh start, separate progress.
        player.toggle(chapter: chapter, mode: .interpretation, lines: ["解。读。"])
        #expect(engine.spoken.count == 2)
        #expect(engine.spoken.last?.mode == .interpretation)
    }

    @Test("Stop mid-way keeps the resume point")
    func stopKeepsResumePoint() {
        let chapter = 974
        defer { PlaybackProgress.clear(chapter: chapter, mode: .original) }
        let (player, engine) = makePlayer()

        player.start(chapter: chapter, mode: .original, lines: ["一。二。三。"])
        engine.finishSegment()
        player.stop()

        #expect(player.chapterNumber == nil)
        let saved = player.savedProgress(chapter: chapter, mode: .original)
        #expect(saved?.spoken == 1)
        #expect(saved?.total == 3)
    }
}
