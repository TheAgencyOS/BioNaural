// PreEventSessionCardView.swift
// BioNaural
//
// Notification-driven "we made something for you" card, presented when the app
// detects an upcoming stressor (exam, meeting, performance) via calendar data.
// Shown as a sheet from: pre-event notification tap, morning brief, or home tab
// upcoming-stressor detection.

import SwiftUI
import BioNauralShared

// MARK: - PreEventSessionCardView

struct PreEventSessionCardView: View {

    // MARK: - Inputs

    let eventTitle: String
    let minutesUntilEvent: Int
    let suggestedMode: FocusMode
    let suggestedDurationMinutes: Int
    let suggestedAmbientTag: String?
    let suggestedCarrierFrequency: Double?
    let contextTrackName: String?
    let sessionCount: Int?

    // MARK: - Actions

    let onStartNow: () -> Void
    let onSaveForLater: () -> Void
    let onDismiss: () -> Void

    // MARK: - State

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    /// Derives a purpose-driven title from event context.
    /// Examples: "Your Exam Prep Session", "Your Flow State Session",
    /// "Your Pre-Meeting Session".
    private var sessionTitle: String {
        if let trackName = contextTrackName {
            return "Your \(trackName) Session"
        }

        let lowered = eventTitle.lowercased()

        if lowered.contains("exam") || lowered.contains("test") || lowered.contains("quiz") {
            return "Your Exam Prep Session"
        } else if lowered.contains("study") {
            return "Your Study Session"
        } else if lowered.contains("interview") {
            return "Your Pre-Interview Session"
        } else if lowered.contains("present") || lowered.contains("pitch") || lowered.contains("talk") {
            return "Your Pre-Presentation Session"
        } else if lowered.contains("perform") || lowered.contains("recital") || lowered.contains("audition") {
            return "Your Pre-Performance Session"
        } else if lowered.contains("meet") || lowered.contains("standup") || lowered.contains("sync") {
            return "Your Pre-Meeting Session"
        } else if lowered.contains("workout") || lowered.contains("gym") || lowered.contains("run") {
            return "Your Pre-Workout Session"
        } else {
            return "Your \(suggestedMode.displayName) Session"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            eventContext
            sessionCard
            Spacer()
            actionButtons
        }
        .padding(Theme.Spacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
        .opacity(isVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .scaleEffect(isVisible ? 1.0 : Theme.ModeCard.entranceScale)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(Theme.Animation.sheet) {
                    isVisible = true
                }
            }
        }
    }

    // MARK: - Subviews

    /// Event name and countdown.
    private var eventContext: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(eventTitle)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("in \(minutesUntilEvent) minutes")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.top, Theme.Spacing.xxxl)
    }

    /// The "gift" card — orb visualization, session details, context references.
    private var sessionCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            OrbView(
                biometricState: .calm,
                sessionMode: suggestedMode,
                beatFrequency: suggestedMode.defaultBeatFrequency,
                isPlaying: true
            )
            .frame(width: Theme.Spacing.mega, height: Theme.Spacing.mega)

            Text(sessionTitle)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            sessionDetails

            if let trackName = contextTrackName {
                contextTrackRow(trackName)
            }

            if let ambient = suggestedAmbientTag {
                Text("Ambient: \(ambient.capitalized)")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            if let count = sessionCount {
                Text("Built from your last \(count) sessions")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .premiumCard(glowColor: Color.modeColor(for: suggestedMode))
    }

    /// Duration and mode labels.
    private var sessionDetails: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Label("\(suggestedDurationMinutes) min", systemImage: "clock")
            Label(suggestedMode.displayName, systemImage: suggestedMode.systemImageName)
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    /// Context track reference row.
    private func contextTrackRow(_ trackName: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "waveform.badge.plus")
            Text(trackName)
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.accent)
    }

    /// Start Now and Save for Later buttons.
    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button(action: onStartNow) {
                Text("Start Now")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.modeColor(for: suggestedMode))
            .accessibilityLabel("Start \(suggestedMode.displayName) session now")

            Button(action: onSaveForLater) {
                Text("Save for Later")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .accessibilityLabel("Save session for later")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Pre-Event — Exam") {
    PreEventSessionCardView(
        eventTitle: "Organic Chemistry Final",
        minutesUntilEvent: 90,
        suggestedMode: .focus,
        suggestedDurationMinutes: 25,
        suggestedAmbientTag: "rain",
        suggestedCarrierFrequency: 375.0,
        contextTrackName: nil,
        sessionCount: 12,
        onStartNow: {},
        onSaveForLater: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Pre-Event — Meeting with Track") {
    PreEventSessionCardView(
        eventTitle: "Q2 Planning Sync",
        minutesUntilEvent: 30,
        suggestedMode: .focus,
        suggestedDurationMinutes: 15,
        suggestedAmbientTag: nil,
        suggestedCarrierFrequency: nil,
        contextTrackName: "Deep Work",
        sessionCount: 47,
        onStartNow: {},
        onSaveForLater: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Pre-Event — Performance") {
    PreEventSessionCardView(
        eventTitle: "Piano Recital",
        minutesUntilEvent: 60,
        suggestedMode: .relaxation,
        suggestedDurationMinutes: 20,
        suggestedAmbientTag: "forest",
        suggestedCarrierFrequency: 200.0,
        contextTrackName: nil,
        sessionCount: nil,
        onStartNow: {},
        onSaveForLater: {},
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
#endif
