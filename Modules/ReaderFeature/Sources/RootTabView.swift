import DaodejingContent
import DesignSystem
import SwiftUI

/// The four primary destinations from the design: 今日 · 经文 · 笔记 · 我的.
enum ReaderTab: String, CaseIterable, Identifiable {
    case today, contents, notes, profile

    var id: String { rawValue }

    func label(_ lang: ContentLanguage) -> String {
        switch self {
        case .today: lang.pick("今日", "Today")
        case .contents: lang.pick("经文", "Text")
        case .notes: lang.pick("笔记", "Notes")
        case .profile: lang.pick("我的", "Me")
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
    @Environment(\.appLanguage) private var lang
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
                    case .notes: NotesView(repository: repository)
                    case .profile: ProfileView(repository: repository)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            .dsHideNavigationChrome()
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
                    Text(item.label(lang))
                        .font(DSFont.sans(9.5, weight: .regular))
                        .tracking(1)
                }
                .foregroundStyle(isOn ? DSColor.accent : DSColor.textFaint)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { tab = item }
                }
                .accessibilityLabel(item.label(lang))
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.separator).frame(height: 1) }
    }
}
