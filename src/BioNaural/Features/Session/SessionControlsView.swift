// SessionControlsView.swift
// BioNaural
//
// Minimal, recessive session controls overlay. Sits at the bottom of the
// session screen and provides stop and pause/resume actions. Designed to
// be nearly invisible during the session — never competing with the Orb
// or the user's focus.
//
// Controls float inside a glass pill container over the void. No decorative
// borders or heavy backgrounds. A subtle scale animation on press provides
// haptic-like visual feedback without distraction.

import SwiftUI

// MARK: - SessionControlsView

struct SessionControlsView: View {

    // MARK: - Inputs

    /// Whether audio is currently playing (determines pause vs resume icon).
    let isPlaying: Bool

    /// Action to end the session and navigate to PostSessionView.
    let onStop: () -> Void

    /// Action to toggle pause/resume.
    let onTogglePlayPause: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.xxl) {
            // Pause / Resume toggle (secondary action — smaller, lighter).
            Button(action: onTogglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(
                        width: pauseButtonSize,
                        height: pauseButtonSize
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(PremiumSessionButtonStyle())
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isPlaying)
            .accessibilityLabel(isPlaying ? "Pause" : "Resume")
            .accessibilityHint(isPlaying ? "Pauses the current session" : "Resumes the paused session")

            // Stop button (primary action — centered, recessive).
            Button(action: onStop) {
                Image(systemName: "square.fill")
                    .font(.system(size: Theme.Typography.Size.small, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(
                        width: stopButtonSize,
                        height: stopButtonSize
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(PremiumSessionButtonStyle())
            .accessibilityLabel("Stop")
            .accessibilityHint("Ends the current session")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .background(glassPillBackground)
    }

    // MARK: - Glass Pill Background

    private var glassPillBackground: some View {
        Group {
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(
                            Theme.Colors.surface.opacity(Theme.Opacity.glassFill)
                        ),
                        in: .capsule
                    )
            } else {
                Capsule()
                    .fill(Theme.Colors.surface.opacity(Theme.Opacity.glassFill))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )
            }
        }
    }

    // MARK: - Layout Constants

    /// Stop button diameter — small and recessive, yet comfortable tap target.
    private var stopButtonSize: CGFloat {
        Theme.Spacing.xxxl + Theme.Spacing.sm
    }

    /// Pause/resume button diameter — slightly smaller secondary control.
    private var pauseButtonSize: CGFloat {
        Theme.Spacing.xxxl
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Session Controls - Playing") {
    ZStack {
        Theme.Colors.canvas
            .ignoresSafeArea()

        VStack {
            Spacer()
            SessionControlsView(
                isPlaying: true,
                onStop: {},
                onTogglePlayPause: {}
            )
            .padding(.bottom, Theme.Spacing.jumbo)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Session Controls - Paused") {
    ZStack {
        Theme.Colors.canvas
            .ignoresSafeArea()

        VStack {
            Spacer()
            SessionControlsView(
                isPlaying: false,
                onStop: {},
                onTogglePlayPause: {}
            )
            .padding(.bottom, Theme.Spacing.jumbo)
        }
    }
    .preferredColorScheme(.dark)
}
#endif
