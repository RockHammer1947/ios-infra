import AVFoundation
import CryptoKit
import Foundation

/// Disk cache for synthesized speech, one directory per `TTSCacheKey`
/// (language / voice / chapter / mode):
///
///     TTSCache/zh/zh-standard/ch1-original/
///         manifest.json     — segment count + content hash + sample rate
///         seg-000.caf …     — one 16-bit mono file per synthesized segment
///
/// A segment file's existence is its "done" flag, so partially synthesized
/// chapters persist naturally and the filler can complete them later — even
/// across launches. A content hash invalidates a directory when the chapter
/// text changes in an app update. Total size is capped with LRU eviction at
/// completed-chapter granularity.
actor TTSCache {
    struct Manifest: Codable {
        let contentHash: String
        let total: Int
        let sampleRate: Double
    }

    static let shared = TTSCache()

    /// Soft cap on the cache's total size (16-bit mono 44.1kHz ≈ 5MB/min).
    private let maxBytes: Int64

    private let root: URL
    /// Running total of cached bytes; walked once lazily, then maintained
    /// incrementally so segment writes don't re-stat the whole cache.
    private var totalBytes: Int64 = -1

    init(root: URL? = nil, maxBytes: Int64 = 500 * 1024 * 1024) {
        self.root = root ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TTSCache", isDirectory: true)
        self.maxBytes = maxBytes
    }

    // MARK: - Lookup

    /// Prepare (and validate) the directory for `request`. Returns the set of
    /// segment indices already cached. Wipes the directory when the content
    /// hash doesn't match (text or voice changed).
    func preparedIndices(for request: SpeechRequest) -> Set<Int> {
        let dir = directory(for: request.cacheKey)
        let hash = Self.contentHash(of: request.segments)
        let manifestURL = dir.appendingPathComponent("manifest.json")

        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
           manifest.contentHash == hash {
            touch(dir)
            return cachedIndices(in: dir, total: manifest.total)
        }

        // Missing or stale → start fresh.
        if totalBytes >= 0, FileManager.default.fileExists(atPath: dir.path) {
            totalBytes -= directorySize(dir)
        }
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let manifest = Manifest(contentHash: hash, total: request.segments.count, sampleRate: 44100)
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL)
        }
        return []
    }

    func loadSegment(key: TTSCacheKey, index: Int) -> SpeechAudio? {
        let url = segmentURL(key: key, index: index)
        guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)
              ),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData
        else { return nil }
        let samples = [Float](UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
        return .init(samples: samples, sampleRate: file.processingFormat.sampleRate)
    }

    /// Returns false when the segment could not be persisted (disk full,
    /// unwritable directory) so callers can stop instead of spinning.
    @discardableResult
    func storeSegment(key: TTSCacheKey, index: Int, audio: SpeechAudio) -> Bool {
        let url = segmentURL(key: key, index: index)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: audio.sampleRate, channels: 1, interleaved: false
        )
        guard let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)),
              let channel = buffer.floatChannelData
        else { return false }
        buffer.frameLength = AVAudioFrameCount(audio.samples.count)
        audio.samples.withUnsafeBufferPointer { source in
            channel[0].update(from: source.baseAddress!, count: source.count)
        }
        // 16-bit on disk halves the footprint; AVAudioFile converts on write.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: audio.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        // Atomic: write beside, then rename — a crash mid-write can't leave a
        // truncated segment that would poison the cache forever.
        let temp = url.appendingPathExtension("tmp")
        try? FileManager.default.removeItem(at: temp)
        do {
            let file = try AVAudioFile(forWriting: temp, settings: settings)
            try file.write(from: buffer)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            return false
        }
        try? FileManager.default.removeItem(at: url)
        guard (try? FileManager.default.moveItem(at: temp, to: url)) != nil else { return false }
        if totalBytes >= 0 {
            totalBytes += fileSize(url)
        }
        enforceSizeCap(protecting: key)
        return true
    }

    /// Indices still missing for a prepared directory.
    func missingIndices(for request: SpeechRequest) -> [Int] {
        let done = preparedIndices(for: request)
        return (0 ..< request.segments.count).filter { !done.contains($0) }
    }

    // MARK: - Internals

    private func directory(for key: TTSCacheKey) -> URL {
        root.appendingPathComponent(key.relativePath, isDirectory: true)
    }

    private func segmentURL(key: TTSCacheKey, index: Int) -> URL {
        directory(for: key).appendingPathComponent(String(format: "seg-%03d.caf", index))
    }

    private func cachedIndices(in dir: URL, total: Int) -> Set<Int> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        var indices = Set<Int>()
        for name in names where name.hasPrefix("seg-") && name.hasSuffix(".caf") {
            if let index = Int(name.dropFirst(4).dropLast(4)), index < total {
                indices.insert(index)
            }
        }
        return indices
    }

    /// Bump the directory's content-modification clock for LRU ordering.
    private func touch(_ dir: URL) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()], ofItemAtPath: dir.appendingPathComponent("manifest.json").path
        )
    }

    private func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
    }

    private func directorySize(_ dir: URL) -> Int64 {
        ((try? FileManager.default.subpathsOfDirectory(atPath: dir.path)) ?? [])
            .map { fileSize(dir.appendingPathComponent($0)) }
            .reduce(0, +)
    }

    /// Evict least-recently-used chapter directories once over the cap,
    /// never touching the directory currently in use. The full walk happens
    /// once (lazy total); afterwards the running total keeps this O(1) until
    /// an eviction is actually needed.
    private func enforceSizeCap(protecting key: TTSCacheKey) {
        if totalBytes < 0 { totalBytes = directorySize(root) }
        guard totalBytes > maxBytes else { return }

        // Chapter dirs sorted by manifest mtime, oldest first.
        let fileManager = FileManager.default
        let protected = directory(for: key).path
        let all = (try? fileManager.subpathsOfDirectory(atPath: root.path)) ?? []
        var candidates: [(url: URL, date: Date)] = []
        for sub in all where sub.hasSuffix("manifest.json") {
            let dir = root.appendingPathComponent(sub).deletingLastPathComponent()
            guard dir.path != protected else { continue }
            let date = (try? fileManager.attributesOfItem(atPath: root.appendingPathComponent(sub).path))?[.modificationDate] as? Date ??
                .distantPast
            candidates.append((dir, date))
        }
        for candidate in candidates.sorted(by: { $0.date < $1.date }) {
            guard totalBytes > maxBytes else { break }
            let size = directorySize(candidate.url)
            try? fileManager.removeItem(at: candidate.url)
            totalBytes -= size
        }
    }

    static func contentHash(of segments: [String]) -> String {
        let joined = segments.joined(separator: "\u{1F}")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
