import Audio
import DesignSystem
import SwiftUI

/// Compact playback bar for 聆听: a waveform, play/pause, and a close control.
/// Shown while a chapter is loaded in the shared `SpeechPlayer`.
struct ListenBar: View {
    let chapter: Int
    let lines: [String]

    @Environment(SpeechPlayer.self) private var speech

    private var playingThis: Bool { speech.isActive(chapter: chapter) && speech.isPlaying }

    var body: some View {
        HStack(spacing: 14) {
            Button { speech.toggle(chapter: chapter, lines: lines) } label: {
                Image(systemName: playingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DSColor.background)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DSColor.accent))
            }
            .accessibilityIdentifier("listen-toggle")

            VStack(alignment: .leading, spacing: 5) {
                Text(playingThis ? "朗读中 · 系统人声" : "已暂停")
                    .font(DSFont.sans(11.5)).foregroundStyle(DSColor.textTertiary)
                Waveform(isPlaying: playingThis, progress: speech.progress)
            }

            Button { speech.stop() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.textFaint)
            }
            .accessibilityIdentifier("listen-stop")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).fill(DSColor.card))
        .overlay(RoundedRectangle(cornerRadius: DSMetrics.radiusCard).strokeBorder(DSColor.border, lineWidth: 1))
        .padding(.horizontal, DSMetrics.screenPadding)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
