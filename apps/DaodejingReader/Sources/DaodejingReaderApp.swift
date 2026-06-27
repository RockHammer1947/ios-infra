import ReaderFeature
import SwiftUI

@main
struct DaodejingReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ReaderRoot()
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 820)
        #endif
    }
}
