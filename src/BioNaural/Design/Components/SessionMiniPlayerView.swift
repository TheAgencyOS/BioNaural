// SessionMiniPlayerView.swift
// BioNaural
//
// Two-row mini player: info row (indicator + mode + time + controls)
// above a full-width waveform progress bar. The wave fill acts as a
// session timer while showing the live entrainment amplitude.
//
// All values from Theme tokens. No hardcoded values.

import BioNauralShared
import SwiftUI

// MARK: - SessionMiniPlayerView

struct SessionMiniPlayerView: View {

    // MARK: - Inputs

    /// The active session's focus mode.
    let mode: FocusMode

    /// Current binaural beat frequency (Hz) from the audio engine.
    let beatFrequency: Double

    /// Elapsed session time in seconds.
    let elapsed: TimeInterval

    /// Target session duration in seconds. Used for progress fill.
    /// When `nil`, the progress bar shows an indeterminate state.
    let targetDuration: TimeInterval?

    /// Whether biometric data is live (Watch connected).
    let isAdaptive: Bool

    /// Current heart rate (0 when unavailable).
    let heartRate: Double

    /// Tap on the mini player body (navigate to session).
    let onTap: () -> Void

    /// Tap the stop button.
    let onStop: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var modeColor: Color { Color.modeColor(for: mode) }

    private var progress: Double {
        guard let target = targetDuration, target > 0 else { return 0 }
        return min(elapsed / target, 1.0)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.sm) {
                infoRow
                waveformBar
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.MiniPlayer.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(Theme.Colors.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(mode.displayName) session active, \(formattedTime) elapsed. Tap to return."
        )
    }

    // MARK: - Info Row

    private var infoRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Pulsing indicator dot
            Circle()
                .fill(modeColor)
                .frame(
                    width: Theme.MiniPlayer.indicatorSize,
                    height: Theme.MiniPlayer.indicatorSize
                )
                .modifier(PulseModifier(isActive: !reduceMotion, color: modeColor))

            // Mode name
            Text(mode.displayName)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            // Live HR badge (when Watch connected and HR available)
            if isAdaptive && heartRate > 0 {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(Theme.Colors.signalCalm)
                    Text("\(Int(heartRate))")
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.signalCalm)
                        .monospacedDigit()
                }
            }

            // Elapsed time
            Text(formattedTime)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monospacedDigit()

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(
                        width: Theme.Spacing.xxl,
                        height: Theme.Spacing.xxl
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop session")
        }
    }

    // MARK: - Waveform Progress Bar

    private var waveformBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * progress

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: Theme.Radius.xs)
                    .fill(Theme.Colors.surfaceRaised)

                // Progress fill
                if progress > 0 {
                    RoundedRectangle(cornerRadius: Theme.Radius.xs)
                        .fill(
                            LinearGradient(
                                colors: [
                                    modeColor.opacity(Theme.Opacity.light),
                                    modeColor.opacity(Theme.Opacity.medium)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(fillWidth, Theme.Radius.xs * 2))
                }

                // Wavelength overlay (fills full width)
                WavelengthView(
                    biometricState: .calm,
                    sessionMode: mode,
                    beatFrequency: beatFrequency,
                    isPlaying: true,
                    layerColor: modeColor,
                    isCompact: true
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
        }
        .frame(height: Theme.MiniPlayer.waveformHeight)
    }

    // MARK: - Formatting

    private var formattedTime: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Pulse Modifier

/// Subtle opacity pulse on the indicator dot.
/// Gated by Reduce Motion.
private struct PulseModifier: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(isPulsing ? Theme.Opacity.medium : Theme.Opacity.light) : .clear,
                radius: isPulsing ? Theme.Radius.sm : Theme.Radius.xs
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: Theme.Animation.Duration.breathingGlowCycle)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Mini Player — Focus") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            Spacer()
            SessionMiniPlayerView(
                mode: .focus,
                beatFrequency: 14.0,
                elapsed: 765,
                targetDuration: 1500,
                isAdaptive: true,
                heartRate: 68,
                onTap: {},
                onStop: {}
            )
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.mega)
        }
    }
}

#Preview("Mini Player — Sleep") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            Spacer()
            SessionMiniPlayerView(
                mode: .sleep,
                beatFrequency: 4.0,
                elapsed: 1200,
                targetDuration: 1800,
                isAdaptive: false,
                heartRate: 0,
                onTap: {},
                onStop: {}
            )
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.mega)
        }
    }
}

#Preview("Mini Player — Energize") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            Spacer()
            SessionMiniPlayerView(
                mode: .energize,
                beatFrequency: 22.0,
                elapsed: 420,
                targetDuration: 1800,
                isAdaptive: true,
                heartRate: 82,
                onTap: {},
                onStop: {}
            )
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.mega)
        }
    }
}
#endif
