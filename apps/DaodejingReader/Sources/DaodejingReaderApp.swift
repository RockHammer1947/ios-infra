#if os(iOS) && DEBUG
    import Audio
#endif
import ReaderFeature
import SwiftUI

@main
struct DaodejingReaderApp: App {
    init() {
        #if os(iOS) && DEBUG
            // Headless on-device TTS benchmark: launch with `run-tts-bench` to
            // run every model and write results.json into the app container.
            if ProcessInfo.processInfo.arguments.contains("run-tts-bench") {
                Task { await TTSBenchmark.runAllToFile() }
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ReaderRoot()
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 820)
        #endif
    }
}
