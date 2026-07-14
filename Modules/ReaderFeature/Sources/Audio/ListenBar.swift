import Audio
import DesignSystem
import SwiftUI

/// Compact playback bar for 聆听: a waveform, play/pause, and a close control.
/// Shown while a chapter is loaded in the shared `SpeechPlayer`; it only
/// pauses/resumes the loaded reading — starting one is the screens' job.
struct ListenBar: View {
    let chapter: Int

    @Environment(SpeechPlayer.self) private var speech
    @Environment(\.appLanguage) private var lang

    private var playingThis: Bool { speech.isActive(chapter: chapter) && speech.isPlaying }

    private var statusText: String {
        let base = playingThis ? lang.pick("朗读中", "Playing") : lang.pick("已暂停", "Paused")
        guard let mode = speech.mode else { return base }
        let what: String = switch mode {
        case .original: lang.pick("原文", "Text")
        case .vernacular: lang.pick("白话", "Plain")
        case .interpretation: lang.pick("解读", "Reflection")
        }
        return "\(base) · \(what)"
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                if speech.isPlaying { speech.pause() } else { speech.resume() }
            } label: {
                Image(systemName: playingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DSColor.background)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(DSColor.accent))
            }
            .accessibilityIdentifier("listen-toggle")

            VStack(alignment: .leading, spacing: 5) {
                Text(statusText)
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
