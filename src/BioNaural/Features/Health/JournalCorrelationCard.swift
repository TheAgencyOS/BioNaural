// JournalCorrelationCard.swift
// BioNaural
//
// Shows correlations between journal activities and BioNaural session outcomes.
// "Sessions after workouts: +15% response" or "Focus after coffee shop visits: best scores."
// Makes the connection between daily life and session performance visible.
//
// All values from Theme tokens. Native SwiftUI only.

import SwiftUI
import BioNauralShared

// MARK: - JournalCorrelation

/// A single correlation between a life activity and session performance.
struct JournalCorrelation: Identifiable, Sendable {

    /// Unique identifier.
    let id: String

    /// The type of activity that preceded the session.
    let activityType: JournalActivityType

    /// Human-readable title of the activity (e.g. "Morning Run", "Blue Bottle Coffee").
    let activityTitle: String

    /// Descriptive correlation text (e.g. "Sessions after this: +15% response").
    let correlationText: String

    /// Number of session samples that inform this correlation.
    let sampleCount: Int

    /// Whether the correlation is positive (green) or negative (amber).
    let isPositive: Bool
}

// MARK: - JournalCorrelationCard

/// Card view displaying life-context correlations with session outcomes.
/// Shown in the Health view alongside other insight cards.
struct JournalCorrelationCard: View {

    // MARK: - Properties

    /// Correlations to display. The card shows up to 4.
    let correlations: [JournalCorrelation]

    /// Maximum rows shown in the card.
    private static let maxRows: Int = 4

    /// Total animated sections: header + up to maxRows.
    private static let sectionCount: Int = 5

    // MARK: - Animation State

    @State private var sectionsVisible: [Bool] = Array(repeating: false, count: sectionCount)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var displayCorrelations: [JournalCorrelation] {
        Array(correlations.prefix(Self.maxRows))
    }

    private var isEmpty: Bool {
        correlations.isEmpty
    }

    // MARK: - Accessibility

    private var cardAccessibilityLabel: String {
        guard !isEmpty else {
            return "Life Context. Allow Journal access to see how your day affects your sessions."
        }

        var parts: [String] = ["Life Context."]
        for correlation in displayCorrelations {
            parts.append("\(correlation.activityTitle). \(correlation.correlationText)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

            // Accent glow
            RadialGradient(
                colors: [
                    Theme.Colors.accent.opacity(Theme.Opacity.light),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Section label
                sectionHeader
                    .sectionFade(visible: sectionsVisible[0])

                if isEmpty {
                    emptyState
                        .sectionFade(visible: sectionsVisible[1])
                } else {
                    // Activity correlation rows
                    ForEach(Array(displayCorrelations.enumerated()), id: \.element.id) { index, correlation in
                        CorrelationRow(correlation: correlation)
                            .sectionFade(visible: sectionsVisible[index + 1])
                    }
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .onAppear {
            staggerEntrance()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Text("LIFE CONTEXT")
            .font(Theme.Typography.small)
            .foregroundStyle(Theme.Colors.textTertiary)
            .tracking(Theme.Typography.Tracking.uppercase)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: Theme.Typography.Size.body))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("Allow Journal access to see how your day affects your sessions")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Entrance Animation

    private func staggerEntrance() {
        if reduceMotion {
            for index in sectionsVisible.indices {
                sectionsVisible[index] = true
            }
        } else {
            for index in sectionsVisible.indices {
                withAnimation(Theme.Animation.staggeredFadeIn(index: index)) {
                    sectionsVisible[index] = true
                }
            }
        }
    }
}

// MARK: - Correlation Row

/// A single row showing an activity and its correlation with session outcomes.
private struct CorrelationRow: View {

    let correlation: JournalCorrelation

    // MARK: - Derived

    private var iconColor: Color {
        switch correlation.activityType {
        case .workout:  return Theme.Colors.energize
        case .music:    return Theme.Colors.focus
        case .location: return Theme.Colors.accent
        case .social:   return Theme.Colors.relaxation
        case .photo:    return Theme.Colors.signalCalm
        case .other:    return Theme.Colors.textTertiary
        }
    }

    private var correlationColor: Color {
        correlation.isPositive ? Theme.Colors.signalCalm : Theme.Colors.signalElevated
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Activity icon in colored circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(Theme.Opacity.accentLight))
                    .frame(
                        width: Theme.Spacing.xxxl,
                        height: Theme.Spacing.xxxl
                    )

                Image(systemName: correlation.activityType.icon)
                    .font(.system(size: Theme.Typography.Size.caption, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Title + correlation text
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(correlation.activityTitle)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(correlation.correlationText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(correlationColor)
                    .lineLimit(2)
            }

            Spacer(minLength: Theme.Spacing.xs)

            // Sample count badge
            if correlation.sampleCount > 1 {
                Text("\(correlation.sampleCount)x")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.surface)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Theme.Colors.divider.opacity(Theme.Opacity.half),
                                        lineWidth: Theme.Radius.glassStroke
                                    )
                            )
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(correlation.activityTitle). \(correlation.correlationText). Based on \(correlation.sampleCount) sessions.")
    }
}

// MARK: - Section Fade Modifier

private extension View {

    /// Applies fade entrance for staggered card content.
    func sectionFade(visible: Bool) -> some View {
        self
            .opacity(visible ? Theme.Opacity.full : Theme.Opacity.transparent)
            .offset(y: visible ? 0 : Theme.Spacing.xl)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Journal Correlations — With Data") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        JournalCorrelationCard(
            correlations: [
                JournalCorrelation(
                    id: "preview-1",
                    activityType: .workout,
                    activityTitle: "Morning Run",
                    correlationText: "Sessions after this: +15% response",
                    sampleCount: 8,
                    isPositive: true
                ),
                JournalCorrelation(
                    id: "preview-2",
                    activityType: .location,
                    activityTitle: "Blue Bottle Coffee",
                    correlationText: "Focus after visits: best scores",
                    sampleCount: 5,
                    isPositive: true
                ),
                JournalCorrelation(
                    id: "preview-3",
                    activityType: .music,
                    activityTitle: "Lo-fi Beats Playlist",
                    correlationText: "Sessions with music context: +8% calm",
                    sampleCount: 12,
                    isPositive: true
                ),
                JournalCorrelation(
                    id: "preview-4",
                    activityType: .social,
                    activityTitle: "Team Happy Hour",
                    correlationText: "Sessions after this: -10% focus",
                    sampleCount: 3,
                    isPositive: false
                )
            ]
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}

#Preview("Journal Correlations — Empty State") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        JournalCorrelationCard(correlations: [])
            .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}

#Preview("Journal Correlations — Single Item") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        JournalCorrelationCard(
            correlations: [
                JournalCorrelation(
                    id: "preview-single",
                    activityType: .workout,
                    activityTitle: "Yoga Flow",
                    correlationText: "Relaxation sessions after yoga: deepest HRV drops",
                    sampleCount: 6,
                    isPositive: true
                )
            ]
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}
#endif
