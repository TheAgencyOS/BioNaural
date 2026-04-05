// WeeklyCorrelationDigestView.swift
// BioNaural
//
// Weekly Correlation Digest — ranks which calendar events cost the most
// health this week. Teaches users about their own patterns by surfacing
// correlations between schedule and biometrics. Glass card design with
// staggered entrance, full accessibility, reduceMotion support.
// All values from Theme tokens. Native SwiftUI only.

import SwiftUI
import BioNauralShared

// MARK: - Constants

private enum WeeklyDigestConstants {
    static let maxDisplayedEvents: Int = 5
}

// MARK: - WeeklyDigest

struct WeeklyDigest: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let rankedEvents: [RankedEventImpact]
    let weekSummary: WeekSummary
}

// MARK: - RankedEventImpact

struct RankedEventImpact: Identifiable, Sendable {
    let id: String
    let rank: Int
    let eventTitle: String
    let eventDate: Date
    let impactScore: Double // 0-1, higher = more impact
    let primaryMetric: String // "HR +6 bpm all day", "Sleep 4.8 hrs"
    let secondaryMetric: String? // optional second insight
    let stressLevel: ImpactLevel

    enum ImpactLevel: String, Sendable {
        case low
        case moderate
        case high
        case critical

        var color: Color {
            switch self {
            case .low: return Theme.Colors.signalCalm
            case .moderate: return Theme.Colors.signalElevated
            case .high: return Theme.Colors.stressWarning
            case .critical: return Theme.Colors.stressCritical
            }
        }
    }
}

// MARK: - WeekSummary

struct WeekSummary: Sendable {
    let totalEvents: Int
    let highStressCount: Int
    let averageHRDelta: Double
    let bestDay: String // "Wednesday"
    let hardestDay: String // "Monday"
}

// MARK: - WeeklyCorrelationDigestView

struct WeeklyCorrelationDigestView: View {

    let digest: WeeklyDigest?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        if let digest {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxl) {
                weekHeader(digest: digest)

                rankedEventList(events: digest.rankedEvents)

                weekSummaryFooter(summary: digest.weekSummary)
            }
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(Theme.Animation.standard) {
                    appeared = true
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Week Header

    private func weekHeader(digest: WeeklyDigest) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

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

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Title
                Text(weekRangeLabel(start: digest.weekStartDate, end: digest.weekEndDate))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Summary line
                HStack(spacing: Theme.Spacing.xs) {
                    summaryChip(
                        text: "\(digest.weekSummary.totalEvents) events",
                        icon: "calendar"
                    )

                    Text("\u{00B7}")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    summaryChip(
                        text: "\(digest.weekSummary.highStressCount) high-stress",
                        icon: "exclamationmark.triangle"
                    )
                }

                // HR delta
                if digest.weekSummary.averageHRDelta > Theme.Health.trendDeltaThreshold {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                            .foregroundStyle(Theme.Colors.signalElevated)

                        Text("Avg HR +\(Int(digest.weekSummary.averageHRDelta)) bpm on event days")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weekHeaderAccessibilityLabel(digest: digest))
    }

    private func summaryChip(text: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Ranked Event List

    private func rankedEventList(events: [RankedEventImpact]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Top Health Costs")

            VStack(spacing: 0) {
                ForEach(Array(events.prefix(WeeklyDigestConstants.maxDisplayedEvents).enumerated()), id: \.element.id) { index, event in
                    rankedEventRow(event: event, index: index)

                    if index < min(events.count, WeeklyDigestConstants.maxDisplayedEvents) - 1 {
                        Rectangle()
                            .fill(Theme.Colors.divider.opacity(Theme.Opacity.half))
                            .frame(height: Theme.Radius.glassStroke)
                            .padding(.leading, Theme.Spacing.jumbo)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(
                                Theme.Colors.divider.opacity(Theme.Opacity.half),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )
            )
        }
    }

    // MARK: - Ranked Event Row

    private func rankedEventRow(event: RankedEventImpact, index: Int) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Rank circle
            ZStack {
                Circle()
                    .fill(event.stressLevel.color.opacity(Theme.Opacity.accentLight))
                    .frame(
                        width: Theme.Spacing.xxxl,
                        height: Theme.Spacing.xxxl
                    )

                Text("\(event.rank)")
                    .font(Theme.Typography.data)
                    .foregroundStyle(event.stressLevel.color)
            }

            // Event details
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Title
                Text(event.eventTitle)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                // Primary metric
                Text(event.primaryMetric)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(event.stressLevel.color)

                // Secondary metric
                if let secondary = event.secondaryMetric {
                    Text(secondary)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // Impact bar
                impactBar(score: event.impactScore)

                // Day label
                Text(event.eventDate.formatted(.dateTime.weekday(.wide)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.md)
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(
            reduceMotion
                ? .identity
                : Theme.Animation.staggeredFadeIn(index: index),
            value: appeared
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(eventRowAccessibilityLabel(event: event))
    }

    // MARK: - Impact Bar

    private func impactBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: Theme.Radius.xs)
                    .fill(Theme.Colors.divider.opacity(Theme.Opacity.light))

                // Fill
                RoundedRectangle(cornerRadius: Theme.Radius.xs)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.signalCalm,
                                Theme.Colors.signalElevated,
                                Theme.Colors.signalPeak
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * max(score, Theme.Health.stageBarMinSegmentWidth / geo.size.width))
            }
        }
        .frame(height: Theme.Spacing.xs)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
        .accessibilityHidden(true)
    }

    // MARK: - Week Summary Footer

    private func weekSummaryFooter(summary: WeekSummary) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

            RadialGradient(
                colors: [
                    Theme.Colors.signalCalm.opacity(Theme.Opacity.light),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                sectionLabel("Week at a Glance")

                HStack(spacing: Theme.Spacing.xl) {
                    // Best day
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: Theme.Typography.Size.small, weight: .semibold))
                                .foregroundStyle(Theme.Colors.signalCalm)

                            Text("Best day")
                                .font(Theme.Typography.small)
                                .tracking(Theme.Typography.Tracking.uppercase)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }

                        Text(summary.bestDay)
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.signalCalm)
                    }

                    // Divider
                    Rectangle()
                        .fill(Theme.Colors.divider.opacity(Theme.Opacity.half))
                        .frame(width: Theme.Radius.glassStroke, height: Theme.Spacing.xxxl)

                    // Hardest day
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: Theme.Typography.Size.small, weight: .semibold))
                                .foregroundStyle(Theme.Colors.signalElevated)

                            Text("Hardest")
                                .font(Theme.Typography.small)
                                .tracking(Theme.Typography.Tracking.uppercase)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }

                        Text(summary.hardestDay)
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.signalElevated)
                    }

                    Spacer()
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(
            reduceMotion
                ? .identity
                : Theme.Animation.staggeredFadeIn(index: WeeklyDigestConstants.maxDisplayedEvents + 1),
            value: appeared
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best day: \(summary.bestDay). Hardest day: \(summary.hardestDay).")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: Theme.Typography.Size.title, weight: .light))
                    .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.medium))

                Text("Complete a few sessions this\nweek to see your digest")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxxl)
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly digest unavailable. Complete a few sessions this week to see your digest.")
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    private func weekRangeLabel(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(start, equalTo: Date.now, toGranularity: .weekOfYear) {
            return "This Week"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) \u{2013} \(formatter.string(from: end))"
    }

    // MARK: Accessibility Labels

    private func weekHeaderAccessibilityLabel(digest: WeeklyDigest) -> String {
        let range = weekRangeLabel(start: digest.weekStartDate, end: digest.weekEndDate)
        let summary = digest.weekSummary
        return "\(range). \(summary.totalEvents) events, \(summary.highStressCount) high-stress."
    }

    private func eventRowAccessibilityLabel(event: RankedEventImpact) -> String {
        let day = event.eventDate.formatted(.dateTime.weekday(.wide))
        var label = "Rank \(event.rank): \(event.eventTitle) on \(day). \(event.primaryMetric)."
        if let secondary = event.secondaryMetric {
            label += " \(secondary)."
        }
        label += " Impact: \(Int(event.impactScore * 100)) percent."
        return label
    }
}

// MARK: - Preview

#Preview("Weekly Correlation Digest") {
    let calendar = Calendar.current
    let now = Date.now
    let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? Date()
    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? Date()

    let sampleEvents: [RankedEventImpact] = [
        RankedEventImpact(
            id: "1",
            rank: 1,
            eventTitle: "Monday standup marathon",
            eventDate: calendar.date(byAdding: .day, value: 0, to: weekStart) ?? Date(),
            impactScore: 0.92,
            primaryMetric: "HR baseline +6 bpm all day",
            secondaryMetric: "5 back-to-back meetings",
            stressLevel: .critical
        ),
        RankedEventImpact(
            id: "2",
            rank: 2,
            eventTitle: "Thursday deadline",
            eventDate: calendar.date(byAdding: .day, value: 3, to: weekStart) ?? Date(),
            impactScore: 0.78,
            primaryMetric: "Sleep 4.8 hrs night before",
            secondaryMetric: "HRV dropped 12 ms",
            stressLevel: .high
        ),
        RankedEventImpact(
            id: "3",
            rank: 3,
            eventTitle: "Quarterly review prep",
            eventDate: calendar.date(byAdding: .day, value: 1, to: weekStart) ?? Date(),
            impactScore: 0.61,
            primaryMetric: "HR +4 bpm during block",
            secondaryMetric: nil,
            stressLevel: .moderate
        ),
        RankedEventImpact(
            id: "4",
            rank: 4,
            eventTitle: "Client presentation",
            eventDate: calendar.date(byAdding: .day, value: 2, to: weekStart) ?? Date(),
            impactScore: 0.45,
            primaryMetric: "HR +3 bpm, recovered quickly",
            secondaryMetric: "Good sleep the night before",
            stressLevel: .moderate
        ),
        RankedEventImpact(
            id: "5",
            rank: 5,
            eventTitle: "Friday team sync",
            eventDate: calendar.date(byAdding: .day, value: 4, to: weekStart) ?? Date(),
            impactScore: 0.22,
            primaryMetric: "Minimal impact",
            secondaryMetric: nil,
            stressLevel: .low
        )
    ]

    let sampleSummary = WeekSummary(
        totalEvents: 12,
        highStressCount: 3,
        averageHRDelta: 4.2,
        bestDay: "Wednesday",
        hardestDay: "Monday"
    )

    let sampleDigest = WeeklyDigest(
        weekStartDate: weekStart,
        weekEndDate: weekEnd,
        rankedEvents: sampleEvents,
        weekSummary: sampleSummary
    )

    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: Theme.Spacing.xxxl) {
            WeeklyCorrelationDigestView(digest: sampleDigest)

            // Empty state preview
            WeeklyCorrelationDigestView(digest: nil)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, Theme.Spacing.xxl)
    }
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
