import AppCore
import DesignSystem
import SwiftUI

@main
struct DaodejingReaderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 800, height: 600)
        #endif
    }
}
