#if canImport(UIKit)
    import AVFoundation
    import DesignSystem
    import SwiftUI
    import UIKit

    /// Full-screen launch splash: plays the bundled `LaunchAnimation.mp4` as a
    /// seamless, *infinite* loop with sound. It never auto-dismisses — the reader
    /// taps the "开启智慧" button to enter the app.
    ///
    /// The video is hardware-decoded through an `AVPlayerLayer`; an
    /// `AVPlayerLooper` gives a gap-free loop. A backdrop color identical to the
    /// system launch screen fills the width-fit letterbox so there is no flash.
    struct LaunchScreenView: View {
        /// Invoked when the reader taps the enter button.
        let onFinish: () -> Void

        /// Matches `LaunchBackground` (the video's first-frame color, #2C2820).
        private static let backdrop = Color(red: 44 / 255, green: 40 / 255, blue: 32 / 255)
        /// Luminous gold matched to the 太极 icon / calligraphy in the animation.
        private static let gold = Color(red: 0xE0 / 255, green: 0xC5 / 255, blue: 0x7C / 255)
        /// Bottom inset of the enter button — lifts it up over the video's ✦
        /// sparkle. Bump this to move the button higher.
        private static let buttonBottomInset: CGFloat = 95

        private let url = Bundle.main.url(forResource: "LaunchAnimation", withExtension: "mp4")
        @State private var showButton = false

        var body: some View {
            ZStack {
                Self.backdrop.ignoresSafeArea()
                if let url {
                    LoopingVideoPlayer(url: url).ignoresSafeArea()
                }
            }
            .overlay(alignment: .bottomTrailing) { enterButton }
            .onAppear {
                withAnimation(.easeIn(duration: 0.8).delay(1.0)) { showButton = true }
            }
            .onDisappear {
                // Let the user's paused audio (if any) resume when we leave.
                try? AVAudioSession.sharedInstance()
                    .setActive(false, options: .notifyOthersOnDeactivation)
            }
        }

        private var enterButton: some View {
            Button(action: onFinish) {
                Text("开启智慧")
                    .font(DSFont.serif(16.5, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(Self.gold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .overlay(Capsule().strokeBorder(Self.gold.opacity(0.6), lineWidth: 1))
            }
            .padding(.trailing, 26)
            .padding(.bottom, Self.buttonBottomInset)
            .opacity(showButton ? 1 : 0)
            .accessibilityIdentifier("launch-enter")
        }
    }

    /// UIKit-backed `AVPlayerLayer` host with gap-free looping and sound.
    private struct LoopingVideoPlayer: UIViewRepresentable {
        let url: URL

        func makeUIView(context _: Context) -> PlayerUIView { PlayerUIView(url: url) }
        func updateUIView(_: PlayerUIView, context _: Context) {}
    }

    private final class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper? // retained — drives the seamless loop

        init(url: URL) {
            super.init(frame: .zero)
            // Route audio so the launch sound plays even with the silent switch on.
            // Deactivated in LaunchScreenView.onDisappear so background audio resumes.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback)
            try? session.setActive(true)

            backgroundColor = UIColor(red: 44 / 255, green: 40 / 255, blue: 32 / 255, alpha: 1)
            player.isMuted = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            playerLayer.player = player
            // Width-fit: full video width, never crop the sides; the shorter-than-
            // screen height leaves top/bottom bands filled by the backdrop color.
            playerLayer.videoGravity = .resizeAspect
            player.play()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) { fatalError("init(coder:) is not used") }
    }
#endif
