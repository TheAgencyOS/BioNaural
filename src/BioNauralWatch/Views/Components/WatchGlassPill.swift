// WatchGlassPill.swift
// BioNauralWatch
//
// Transport controls pill for the session screen. Glass capsule
// containing play/pause, elapsed timer, and stop button. All
// visual values from WatchDesign tokens.

import SwiftUI
import BioNauralShared

// MARK: - WatchGlassPill

struct WatchGlassPill: View {

    // MARK: - Inputs

    /// Whether audio is currently playing.
    let isPlaying: Bool

    /// Elapsed session time in seconds.
    let elapsedSeconds: TimeInterval

    /// Current session mode (energize uses mode color for stop button).
    let sessionMode: FocusMode

    /// Toggle play/pause callback.
    let onTogglePlayPause: () -> Void

    /// Stop session callback.
    let onStop: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: WatchDesign.Layout.glassPillControlSpacing) {
            playPauseButton
            timerLabel
            stopButton
        }
        .padding(.vertical, WatchDesign.Layout.glassPillVerticalPadding)
        .padding(.horizontal, WatchDesign.Layout.glassPillHorizontalPadding)
        .background(glassBackground)
    }

    // MARK: - Play / Pause Button

    private var playPauseButton: some View {
        Button(action: onTogglePlayPause) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .foregroundStyle(WatchDesign.Colors.textSecondary)
                .frame(
                    width: WatchDesign.Layout.controlButtonSize,
                    height: WatchDesign.Layout.controlButtonSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
        .accessibilityHint(isPlaying ? "Pauses the session" : "Resumes the session")
    }

    // MARK: - Timer Label

    private var timerLabel: some View {
        Text(formattedTime)
            .font(.system(size: WatchDesign.Typography.timerSize, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(WatchDesign.Colors.textSecondary)
            .contentTransition(.numericText())
            .accessibilityLabel("Elapsed time: \(formattedTime)")
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .foregroundStyle(WatchDesign.Colors.textPrimary)
                .frame(
                    width: WatchDesign.Layout.controlButtonSize,
                    height: WatchDesign.Layout.controlButtonSize
                )
                .background(
                    Circle()
                        .fill(stopButtonColor.opacity(WatchDesign.Opacity.glassFill))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop session")
        .accessibilityHint("Ends the current session")
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        Capsule()
            .fill(WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.glassFill))
            .overlay(
                Capsule()
                    .stroke(
                        WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.glassStroke),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Stop Button Color

    /// Energize mode uses the energize color; all other modes use destructive red.
    private var stopButtonColor: Color {
        sessionMode == .energize
            ? WatchDesign.Colors.energize
            : WatchDesign.Colors.destructive
    }

    // MARK: - Time Formatting

    /// Formats elapsed seconds as "M:SS" (< 1 hour) or "H:MM:SS" (>= 1 hour).
    private var formattedTime: String {
        let totalSeconds = Int(elapsedSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preview

#Preview("Glass Pill - Playing") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        WatchGlassPill(
            isPlaying: true,
            elapsedSeconds: 754,
            sessionMode: .focus,
            onTogglePlayPause: {},
            onStop: {}
        )
    }
}

#Preview("Glass Pill - Paused Energize") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        WatchGlassPill(
            isPlaying: false,
            elapsedSeconds: 3661,
            sessionMode: .energize,
            onTogglePlayPause: {},
            onStop: {}
        )
    }
}
