import DaodejingContent
import DesignSystem
import SwiftUI

/// The four primary destinations from the design: 今日 · 经文 · 笔记 · 我的.
enum ReaderTab: String, CaseIterable, Identifiable {
    case today, contents, notes, profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "今日"
        case .contents: "经文"
        case .notes: "笔记"
        case .profile: "我的"
        }
    }

    var symbol: String {
        switch self {
        case .today: "circle.dashed"
        case .contents: "book"
        case .notes: "bookmark"
        case .profile: "person"
        }
    }
}

struct RootTabView: View {
    let repository: any ContentRepository
    @State private var tab: ReaderTab = .today
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                DSColor.background.ignoresSafeArea()

                Group {
                    switch tab {
                    case .today: TodayView(repository: repository)
                    case .contents: ContentsView(repository: repository)
                    case .notes: NotesView()
                    case .profile: ProfileView(repository: repository)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Int.self) { number in
                ReaderView(repository: repository, startNumber: number)
            }
        }
        .accessibilityIdentifier("reader-root")
    }

    private var tabBar: some View {
        HStack {
            ForEach(ReaderTab.allCases) { item in
                let isOn = item == tab
                VStack(spacing: 4) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .regular))
                    Text(item.label)
                        .font(DSFont.sans(9.5, weight: .regular))
                        .tracking(1)
                }
                .foregroundStyle(isOn ? DSColor.accent : DSColor.textFaint)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { tab = item }
                }
                .accessibilityLabel(item.label)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.separator).frame(height: 1) }
    }
}
