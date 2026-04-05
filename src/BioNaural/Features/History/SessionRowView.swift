// SessionRowView.swift
// BioNaural
//
// A single session row in the history list. Shows mode icon with mode color,
// mode name, date, duration (SF Mono), average HR, and thumbs rating icon.
// Glass card styling applied by parent via GlassRowButtonStyle.
// All values from Theme tokens.

import SwiftUI
import BioNauralShared

// MARK: - SessionRowView

struct SessionRowView: View {

    // MARK: - Inputs

    let session: FocusSession

    // MARK: - Computed

    private var focusMode: FocusMode {
        session.focusMode ?? .focus
    }

    private var modeColor: Color {
        Color.modeColor(for: focusMode)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Mode icon in colored circle
            modeIcon

            // Mode name and date
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(focusMode.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(session.startDate.sessionDate)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration and metrics column
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(session.durationSeconds.formattedDuration)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let avgHR = session.averageHeartRate {
                    Text(avgHR.formattedBPM)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .accessibilityLabel(durationAccessibilityLabel)

            // Thumbs rating icon
            thumbsIcon
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    // MARK: - Mode Icon

    private var modeIcon: some View {
        ZStack {
            Circle()
                .fill(modeColor.opacity(Theme.Opacity.accentLight))
                .frame(
                    width: Theme.Spacing.xxxl + Theme.Spacing.xs,
                    height: Theme.Spacing.xxxl + Theme.Spacing.xs
                )

            Image(systemName: focusMode.systemImageName)
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(modeColor)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Thumbs Icon

    @ViewBuilder
    private var thumbsIcon: some View {
        if let rating = session.thumbsRating {
            Image(systemName: rating > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(rating > 0 ? Theme.Colors.signalCalm : Theme.Colors.signalPeak)
                .accessibilityLabel(rating > 0 ? "Thumbs up" : "Thumbs down")
        }
    }

    // MARK: - Accessibility

    private var durationAccessibilityLabel: String {
        var parts = ["Duration: \(session.durationSeconds.formattedDuration)"]
        if let avgHR = session.averageHeartRate {
            parts.append("Average heart rate: \(avgHR.formattedBPM)")
        }
        return parts.joined(separator: ", ")
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = [
            focusMode.displayName,
            "session on",
            session.startDate.sessionDate,
            "duration \(session.durationSeconds.formattedDuration)"
        ]

        if let avgHR = session.averageHeartRate {
            parts.append("average heart rate \(avgHR.formattedBPM)")
        }

        if let rating = session.thumbsRating {
            parts.append(rating > 0 ? "rated thumbs up" : "rated thumbs down")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("SessionRowView") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        VStack(spacing: Theme.Spacing.md) {
            SessionRowView(
                session: FocusSession(
                    startDate: Date(),
                    mode: FocusMode.focus.rawValue,
                    durationSeconds: 1500,
                    averageHeartRate: 72,
                    beatFrequencyStart: 14,
                    beatFrequencyEnd: 16,
                    carrierFrequency: 375,
                    wasCompleted: true,
                    thumbsRating: 1
                )
            )
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

            SessionRowView(
                session: FocusSession(
                    startDate: Date().addingTimeInterval(-86400),
                    mode: FocusMode.relaxation.rawValue,
                    durationSeconds: 900,
                    averageHeartRate: 65,
                    beatFrequencyStart: 10,
                    beatFrequencyEnd: 8,
                    carrierFrequency: 200,
                    wasCompleted: true,
                    thumbsRating: -1
                )
            )
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

            SessionRowView(
                session: FocusSession(
                    startDate: Date().addingTimeInterval(-172800),
                    mode: FocusMode.energize.rawValue,
                    durationSeconds: 1200,
                    beatFrequencyStart: 20,
                    beatFrequencyEnd: 25,
                    carrierFrequency: 500,
                    wasCompleted: false
                )
            )
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}
