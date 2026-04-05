// LifeEventHaloView.swift
// BioNaural
//
// Multi-day stress arc around major life events. Big events don't just spike
// on the day -- they create a "stress halo": anticipation builds days before,
// recovery takes days after. This view captures that full arc with a hero
// AreaMark chart, day-detail pills, and a recovery indicator.
// All values from Theme tokens. Native SwiftUI + Swift Charts.

import SwiftUI
import Charts
import BioNauralShared

// MARK: - Constants

private extension Constants {
    enum LifeEventHalo {
        static let iconSize: CGFloat = 40
        static let chartHeight: CGFloat = 192
        static let pointSymbolSize: CGFloat = 80
        static let haloLineWidth: CGFloat = 2.5
        static let defaultDayRange: Int = 3
        static let secondsPerDay: TimeInterval = 86_400
        static let pillStaggerOffset: Int = 4
        /// Offset added to baseline stress to determine recovery threshold.
        static let recoveryThresholdOffset: Double = 0.1
    }
}

// MARK: - LifeEventCategory

enum LifeEventCategory: String, Sendable, CaseIterable {
    case deadline
    case performance  // presentation, interview, exam
    case social       // wedding, party, travel
    case health       // surgery, appointment
    case transition   // move, new job

    var icon: String {
        switch self {
        case .deadline:    return "clock.badge.exclamationmark"
        case .performance: return "person.wave.2"
        case .social:      return "party.popper"
        case .health:      return "heart.text.square"
        case .transition:  return "arrow.triangle.swap"
        }
    }

    var color: Color {
        switch self {
        case .deadline:    return Theme.Colors.stressWarning
        case .performance: return Theme.Colors.focus
        case .social:      return Theme.Colors.accent
        case .health:      return Theme.Colors.signalCalm
        case .transition:  return Theme.Colors.energize
        }
    }
}

// MARK: - HaloDayData

struct HaloDayData: Identifiable, Sendable {
    let id: String
    let dayOffset: Int // -3, -2, -1, 0, +1, +2, +3 (0 = event day)
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    let stressLevel: Double // 0-1 normalized
}

// MARK: - LifeEvent

struct LifeEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let eventDate: Date
    let category: LifeEventCategory
    let haloData: [HaloDayData]

    /// The day offset where stress returns at or below baseline, or nil if still elevated.
    var recoveryDay: Int? {
        let baseline = haloData.first(where: { $0.dayOffset == haloData.map(\.dayOffset).min() })?.stressLevel ?? 0
        let threshold = baseline + Constants.LifeEventHalo.recoveryThresholdOffset
        let afterEvent = haloData
            .filter { $0.dayOffset > 0 }
            .sorted { $0.dayOffset < $1.dayOffset }
        return afterEvent.first(where: { $0.stressLevel <= threshold })?.dayOffset
    }
}

// MARK: - LifeEventHaloView

struct LifeEventHaloView: View {

    let event: LifeEvent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

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

            // Radial glow
            RadialGradient(
                colors: [
                    event.category.color.opacity(Theme.Opacity.light),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                eventHeader
                haloChart
                dayDetailPills
                recoveryIndicator
            }
            .padding(Theme.Spacing.xxl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(Theme.Animation.dataReveal) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Event Header

    private var eventHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Category icon in colored circle
            ZStack {
                Circle()
                    .fill(event.category.color.opacity(Theme.Opacity.accentLight))
                    .frame(
                        width: Constants.LifeEventHalo.iconSize,
                        height: Constants.LifeEventHalo.iconSize
                    )

                Image(systemName: event.category.icon)
                    .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                    .foregroundStyle(event.category.color)
            }
            .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
            .animation(reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: 0), value: appeared)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(event.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(event.eventDate.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
            .animation(reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: 1), value: appeared)

            Spacer()

            // Category badge
            Text(event.category.rawValue.capitalized)
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(event.category.color)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(event.category.color.opacity(Theme.Opacity.light))
                )
                .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
                .animation(reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: 2), value: appeared)
        }
    }

    // MARK: - Halo Chart

    private var sortedData: [HaloDayData] {
        event.haloData.sorted { $0.dayOffset < $1.dayOffset }
    }

    private var haloChart: some View {
        Chart {
            // Area fill -- the stress halo arc
            ForEach(sortedData) { day in
                AreaMark(
                    x: .value("Day", day.dayOffset),
                    y: .value("Stress", day.stressLevel)
                )
                .foregroundStyle(haloGradient)
                .interpolationMethod(.catmullRom)
            }

            // Crisp line overlay
            ForEach(sortedData) { day in
                LineMark(
                    x: .value("Day", day.dayOffset),
                    y: .value("Stress", day.stressLevel)
                )
                .foregroundStyle(stressLineColor(day.stressLevel))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Constants.LifeEventHalo.haloLineWidth))
            }

            // Event day vertical rule
            RuleMark(x: .value("Event", 0))
                .foregroundStyle(event.category.color.opacity(Theme.Opacity.medium))
                .lineStyle(StrokeStyle(lineWidth: Theme.Radius.glassStroke, dash: [Theme.Spacing.xs, Theme.Spacing.xxs]))
                .annotation(position: .top, alignment: .center) {
                    Text("Event Day")
                        .font(Theme.Typography.small)
                        .foregroundStyle(event.category.color)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(event.category.color.opacity(Theme.Opacity.light))
                        )
                }

            // Peak stress point
            if let peak = sortedData.max(by: { $0.stressLevel < $1.stressLevel }) {
                PointMark(
                    x: .value("Day", peak.dayOffset),
                    y: .value("Stress", peak.stressLevel)
                )
                .foregroundStyle(Theme.Colors.signalPeak)
                .symbolSize(Constants.LifeEventHalo.pointSymbolSize)
            }
        }
        .chartXScale(
            domain: (sortedData.first?.dayOffset ?? -Constants.LifeEventHalo.defaultDayRange)
                ...(sortedData.last?.dayOffset ?? Constants.LifeEventHalo.defaultDayRange)
        )
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: sortedData.map(\.dayOffset)) { value in
                AxisValueLabel {
                    if let offset = value.as(Int.self) {
                        Text(dayLabel(for: offset))
                            .font(Theme.Typography.small)
                            .foregroundStyle(
                                offset == 0
                                    ? event.category.color
                                    : Theme.Colors.textTertiary
                            )
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(Theme.Opacity.light))
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text(stressLabel(for: level))
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(Theme.Opacity.subtle))
            }
        }
        .frame(height: Constants.LifeEventHalo.chartHeight)
        .padding(.top, Theme.Spacing.md)
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: 3), value: appeared)
        .accessibilityLabel("Stress halo chart showing \(sortedData.count) days around event")
    }

    private var haloGradient: LinearGradient {
        LinearGradient(
            colors: [
                Theme.Colors.stressWarning.opacity(Theme.Opacity.medium),
                Theme.Colors.signalPeak.opacity(Theme.Opacity.accentLight),
                Theme.Colors.signalCalm.opacity(Theme.Opacity.subtle)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func stressLineColor(_ level: Double) -> Color {
        if level >= Theme.Health.scoreThresholdGood {
            return Theme.Colors.signalPeak
        } else if level >= Theme.Health.scoreThresholdFair {
            return Theme.Colors.stressWarning
        } else {
            return Theme.Colors.signalCalm
        }
    }

    // MARK: - Day Detail Pills

    private var dayDetailPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(sortedData.enumerated()), id: \.element.id) { index, day in
                    dayPill(day: day, index: index)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxs)
        }
        .accessibilityLabel("Day details for each day around the event")
    }

    private func dayPill(day: HaloDayData, index: Int) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Day label
            Text(relativeDayLabel(for: day.dayOffset))
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(
                    day.dayOffset == 0
                        ? event.category.color
                        : Theme.Colors.textTertiary
                )

            // Stress indicator dot
            Circle()
                .fill(stressDotColor(day.stressLevel))
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)

            // Key metric
            Text(keyMetric(for: day))
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(
                    day.dayOffset == 0
                        ? event.category.color.opacity(Theme.Opacity.light)
                        : Theme.Colors.surface
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: index + Constants.LifeEventHalo.pillStaggerOffset), value: appeared)
        .accessibilityLabel(pillAccessibilityLabel(for: day))
    }

    private func stressDotColor(_ level: Double) -> Color {
        if level >= Theme.Health.scoreThresholdGood {
            return Theme.Colors.signalPeak
        } else if level >= Theme.Health.scoreThresholdFair {
            return Theme.Colors.stressWarning
        } else {
            return Theme.Colors.signalCalm
        }
    }

    private func keyMetric(for day: HaloDayData) -> String {
        if let hr = day.restingHR {
            let baseline = Theme.Health.Defaults.restingHR
            let delta = Int(hr - baseline)
            let sign = delta >= 0 ? "+" : ""
            return "HR \(sign)\(delta)"
        } else if let sleep = day.sleepHours {
            return String(format: "%.1fh", sleep)
        } else if let hrv = day.hrv {
            return "HRV \(Int(hrv))"
        }
        return String(format: "%.0f%%", day.stressLevel * 100)
    }

    // MARK: - Recovery Indicator

    @ViewBuilder
    private var recoveryIndicator: some View {
        let recoveryInfo = recoveryStatus

        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: recoveryInfo.icon)
                .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                .foregroundStyle(recoveryInfo.color)

            Text(recoveryInfo.text)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule()
                .fill(recoveryInfo.color.opacity(Theme.Opacity.subtle))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            recoveryInfo.color.opacity(Theme.Opacity.light),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(
            reduceMotion ? nil : Theme.Animation.staggeredFadeIn(
                index: sortedData.count + Constants.LifeEventHalo.pillStaggerOffset
            ),
            value: appeared
        )
        .accessibilityLabel(recoveryInfo.text)
    }

    private var recoveryStatus: (text: String, icon: String, color: Color) {
        if let day = event.recoveryDay {
            let plural = day == 1 ? "day" : "days"
            return (
                text: "Returned to baseline: \(day) \(plural) after",
                icon: "checkmark.circle.fill",
                color: Theme.Colors.signalCalm
            )
        } else {
            // Check if we have any post-event data
            let hasPostData = event.haloData.contains { $0.dayOffset > 0 }
            if hasPostData {
                return (
                    text: "Still recovering",
                    icon: "arrow.trianglehead.counterclockwise.rotate.90",
                    color: Theme.Colors.stressWarning
                )
            } else {
                return (
                    text: "Recovery data pending",
                    icon: "clock",
                    color: Theme.Colors.textTertiary
                )
            }
        }
    }

    // MARK: - Helpers

    private func dayLabel(for offset: Int) -> String {
        switch offset {
        case let n where n < 0:  return "\(abs(n))d before"
        case 0:                  return "Event"
        case let n where n > 0:  return "\(n)d after"
        default:                 return ""
        }
    }

    private func relativeDayLabel(for offset: Int) -> String {
        let referenceDate = event.eventDate.addingTimeInterval(TimeInterval(offset) * Constants.LifeEventHalo.secondsPerDay)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: referenceDate)
    }

    private func stressLabel(for level: Double) -> String {
        switch level {
        case 0:    return "Low"
        case 0.5:  return "Mid"
        case 1.0:  return "High"
        default:   return ""
        }
    }

    private var accessibilityDescription: String {
        let peakDay = sortedData.max(by: { $0.stressLevel < $1.stressLevel })
        let peakLabel = peakDay.map { dayLabel(for: $0.dayOffset) } ?? "unknown"
        let peakLevel = peakDay.map { Int($0.stressLevel * 100) } ?? 0
        return "Stress halo for \(event.title) on \(event.eventDate.formatted(date: .abbreviated, time: .omitted)). Peak stress \(peakLevel) percent on \(peakLabel). \(recoveryStatus.text)."
    }

    private func pillAccessibilityLabel(for day: HaloDayData) -> String {
        let label = dayLabel(for: day.dayOffset)
        let stress = Int(day.stressLevel * 100)
        let metric = keyMetric(for: day)
        return "\(label), stress \(stress) percent, \(metric)"
    }
}

// MARK: - Preview

#Preview("Life Event Halo - Exam Week") {
    let calendar = Calendar.current
    let examDate = calendar.date(
        from: DateComponents(year: 2026, month: 4, day: 3)
    ) ?? Date()

    let sampleData: [HaloDayData] = [
        HaloDayData(id: "d-3", dayOffset: -3, restingHR: 71, hrv: 38, sleepHours: 6.8, stressLevel: 0.35),
        HaloDayData(id: "d-2", dayOffset: -2, restingHR: 74, hrv: 34, sleepHours: 6.2, stressLevel: 0.52),
        HaloDayData(id: "d-1", dayOffset: -1, restingHR: 78, hrv: 28, sleepHours: 5.5, stressLevel: 0.74),
        HaloDayData(id: "d-0", dayOffset: 0, restingHR: 82, hrv: 24, sleepHours: 5.0, stressLevel: 0.91),
        HaloDayData(id: "d+1", dayOffset: 1, restingHR: 76, hrv: 30, sleepHours: 6.0, stressLevel: 0.63),
        HaloDayData(id: "d+2", dayOffset: 2, restingHR: 70, hrv: 36, sleepHours: 7.1, stressLevel: 0.38),
        HaloDayData(id: "d+3", dayOffset: 3, restingHR: 68, hrv: 41, sleepHours: 7.4, stressLevel: 0.25)
    ]

    let event = LifeEvent(
        id: "exam-finals",
        title: "Final Exam - Neuroscience",
        eventDate: examDate,
        category: .performance,
        haloData: sampleData
    )

    ScrollView {
        LifeEventHaloView(event: event)
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.xxl)
    }
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
