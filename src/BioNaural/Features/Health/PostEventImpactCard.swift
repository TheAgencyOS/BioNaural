// PostEventImpactCard.swift
// BioNaural
//
// Shows the physiological cost of a calendar event after it ends.
// "Board meeting (Tue 2pm): HR +11 bpm starting 45 min before,
// HRV dropped 8ms, took 2.5 hrs to return to baseline."
// Makes the invisible visible.
//
// All values from Theme tokens. Native SwiftUI + Swift Charts.

import SwiftUI
import Charts
import BioNauralShared

// MARK: - EventImpact

struct EventImpact: Identifiable, Sendable {
    let id: String
    let eventTitle: String
    let eventDate: Date
    let stressLevel: String // StressLevel rawValue
    let hrDeltaBPM: Int // +/- change from baseline
    let hrvDeltaMS: Int? // optional HRV change
    let recoveryMinutes: Int? // time to return to baseline
    let comparisonToAverage: String? // "better", "worse", "typical"
    let miniSparkline: [Double]? // 5-10 HR values around the event
}

// MARK: - PostEventImpactCard

struct PostEventImpactCard: View {

    let impact: EventImpact

    // MARK: - Constants

    private static let sectionCount = 4

    // MARK: - Animation State

    @State private var sectionsVisible: [Bool] = Array(repeating: false, count: sectionCount)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var stressColor: Color {
        switch impact.stressLevel {
        case StressLevel.critical.rawValue: return Theme.Colors.stressCritical
        case StressLevel.high.rawValue:     return Theme.Colors.signalElevated
        case StressLevel.moderate.rawValue: return Theme.Colors.stressWarning
        default:                            return Theme.Colors.textTertiary
        }
    }

    private var hrDeltaColor: Color {
        impact.hrDeltaBPM > 0 ? Theme.Colors.signalElevated : Theme.Colors.signalCalm
    }

    private var hrDeltaArrow: String {
        impact.hrDeltaBPM > 0 ? "\u{2191}" : "\u{2193}"
    }

    private var hrvDeltaArrow: String {
        guard let delta = impact.hrvDeltaMS else { return "\u{2014}" }
        return delta > 0 ? "\u{2191}" : "\u{2193}"
    }

    private var formattedRecovery: String {
        guard let minutes = impact.recoveryMinutes else { return "\u{2014}" }
        if minutes >= 60 {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1f hrs", hours)
        }
        return "\(minutes) min"
    }

    private var eventTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: impact.eventDate)
    }

    // MARK: - Accessibility

    private var cardAccessibilityLabel: String {
        var parts: [String] = []
        parts.append("\(impact.eventTitle), \(eventTimeLabel)")
        parts.append("Heart rate \(impact.hrDeltaBPM > 0 ? "increased" : "decreased") by \(abs(impact.hrDeltaBPM)) BPM")

        if let hrv = impact.hrvDeltaMS {
            parts.append("HRV \(hrv > 0 ? "increased" : "decreased") by \(abs(hrv)) milliseconds")
        }

        if impact.recoveryMinutes != nil {
            parts.append("Recovery took \(formattedRecovery)")
        }

        if let comparison = impact.comparisonToAverage {
            parts.append(comparisonLabel(for: comparison))
        }

        return parts.joined(separator: ". ")
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )

            // Accent glow
            RadialGradient(
                colors: [stressColor.opacity(Theme.Opacity.light), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // 1. Event title + time with stress dot
                eventHeader
                    .sectionFade(visible: sectionsVisible[0])

                // 2. Metric pills
                metricPills
                    .sectionFade(visible: sectionsVisible[1])

                // 3. Mini sparkline
                if let sparklineData = impact.miniSparkline, !sparklineData.isEmpty {
                    ImpactSparklineView(data: sparklineData, accentColor: stressColor)
                        .sectionFade(visible: sectionsVisible[2])
                }

                // 4. Comparison badge
                if let comparison = impact.comparisonToAverage {
                    ComparisonBadge(comparison: comparison)
                        .sectionFade(visible: sectionsVisible[3])
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

    // MARK: - Event Header

    private var eventHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Stress-colored dot
            Circle()
                .fill(stressColor)
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(impact.eventTitle)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(eventTimeLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Metric Pills

    private var metricPills: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ImpactMetricPill(
                value: "\(hrDeltaArrow)\(abs(impact.hrDeltaBPM)) BPM",
                label: "Heart Rate",
                valueColor: hrDeltaColor
            )

            if let hrv = impact.hrvDeltaMS {
                ImpactMetricPill(
                    value: "\(hrvDeltaArrow)\(abs(hrv)) ms",
                    label: "HRV",
                    valueColor: hrv < 0 ? Theme.Colors.signalElevated : Theme.Colors.signalCalm
                )
            }

            if impact.recoveryMinutes != nil {
                ImpactMetricPill(
                    value: formattedRecovery,
                    label: "Recovery",
                    valueColor: Theme.Colors.textPrimary
                )
            }
        }
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

    // MARK: - Helpers

    private func comparisonLabel(for comparison: String) -> String {
        switch comparison {
        case "better":  return "Better than usual"
        case "worse":   return "Harder than usual"
        case "typical": return "Typical for you"
        default:        return comparison.capitalized
        }
    }
}

// MARK: - Impact Metric Pill

private struct ImpactMetricPill: View {

    let value: String
    let label: String
    var valueColor: Color = Theme.Colors.textPrimary

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(valueColor)

            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - Sparkline

private struct ImpactSparklineView: View {

    let data: [Double]
    let accentColor: Color

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("HR", value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            accentColor.opacity(Theme.Opacity.accentLight),
                            accentColor.opacity(Theme.Opacity.minimal)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", index),
                    y: .value("HR", value)
                )
                .foregroundStyle(accentColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Theme.Radius.legendStroke))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: Theme.Spacing.jumbo)
        .accessibilityLabel("Heart rate sparkline around the event")
    }
}

// MARK: - Comparison Badge

private struct ComparisonBadge: View {

    let comparison: String

    private var badgeLabel: String {
        switch comparison {
        case "better":  return "Better than usual"
        case "worse":   return "Harder than usual"
        case "typical": return "Typical for you"
        default:        return comparison.capitalized
        }
    }

    private var badgeColor: Color {
        switch comparison {
        case "better":  return Theme.Colors.confirmationGreen
        case "worse":   return Theme.Colors.signalElevated
        case "typical": return Theme.Colors.textTertiary
        default:        return Theme.Colors.textTertiary
        }
    }

    private var badgeIcon: String {
        switch comparison {
        case "better":  return "arrow.down.right"
        case "worse":   return "arrow.up.right"
        case "typical": return "equal"
        default:        return "minus"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: badgeIcon)
                .font(.system(size: Theme.Typography.Size.small, weight: .semibold))

            Text(badgeLabel)
                .font(Theme.Typography.caption)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            badgeColor.opacity(Theme.Opacity.light),
            in: Capsule()
        )
        .accessibilityLabel(badgeLabel)
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
#Preview("Post-Event Impact — High Stress") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        PostEventImpactCard(
            impact: EventImpact(
                id: "preview-1",
                eventTitle: "Board Meeting",
                eventDate: Calendar.current.date(
                    bySettingHour: 14,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date(),
                stressLevel: StressLevel.high.rawValue,
                hrDeltaBPM: 11,
                hrvDeltaMS: -8,
                recoveryMinutes: 150,
                comparisonToAverage: "worse",
                miniSparkline: [68, 72, 78, 82, 79, 75, 71, 69]
            )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}

#Preview("Post-Event Impact — Moderate") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        PostEventImpactCard(
            impact: EventImpact(
                id: "preview-2",
                eventTitle: "Weekly Team Standup",
                eventDate: Calendar.current.date(
                    bySettingHour: 10,
                    minute: 30,
                    second: 0,
                    of: Date()
                ) ?? Date(),
                stressLevel: StressLevel.moderate.rawValue,
                hrDeltaBPM: 4,
                hrvDeltaMS: -3,
                recoveryMinutes: 25,
                comparisonToAverage: "typical",
                miniSparkline: [65, 67, 69, 68, 66, 65]
            )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}

#Preview("Post-Event Impact — Better Than Usual") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        PostEventImpactCard(
            impact: EventImpact(
                id: "preview-3",
                eventTitle: "Final Exam",
                eventDate: Calendar.current.date(
                    bySettingHour: 9,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date(),
                stressLevel: StressLevel.critical.rawValue,
                hrDeltaBPM: 6,
                hrvDeltaMS: nil,
                recoveryMinutes: 45,
                comparisonToAverage: "better",
                miniSparkline: [70, 73, 76, 74, 72, 71, 70, 69, 68]
            )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}

#Preview("Post-Event Impact — Minimal Data") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        PostEventImpactCard(
            impact: EventImpact(
                id: "preview-4",
                eventTitle: "Lunch with Sarah",
                eventDate: Date(),
                stressLevel: StressLevel.low.rawValue,
                hrDeltaBPM: -2,
                hrvDeltaMS: nil,
                recoveryMinutes: nil,
                comparisonToAverage: nil,
                miniSparkline: nil
            )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}
#endif
