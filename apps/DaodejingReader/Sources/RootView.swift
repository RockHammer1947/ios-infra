import AppCore
import DesignSystem
import SwiftUI

/// Placeholder root view. Intentionally free of reader business logic — it
/// exists only so the app builds, launches, is reachable by UI tests, and can
/// be archived/uploaded by the release pipeline.
struct RootView: View {
    var body: some View {
        VStack(spacing: DesignSystem.spacing) {
            Text("道可道，非常道")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("名可名，非常名")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Infrastructure placeholder · v\(AppCore.version)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, DesignSystem.spacing)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .accessibilityIdentifier("root-view")
    }
}

#Preview {
    RootView()
}
