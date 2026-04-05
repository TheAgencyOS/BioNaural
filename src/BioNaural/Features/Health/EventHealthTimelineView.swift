// EventHealthTimelineView.swift
// BioNaural
//
// Event-Health Timeline — overlays heart rate data with calendar events
// on a shared Swift Charts timeline. Users see their HR spike before
// a meeting, dip after lunch, and elevate during finals week.
// All values from Theme tokens. Native SwiftUI + Swift Charts.

import SwiftUI
import Charts
import BioNauralShared

// MARK: - TimelineRange

/// Selectable time windows for the HR + events overlay chart.
enum TimelineRange: String, CaseIterable, Identifiable {
    case sixHours
    case twelveHours
    case twentyFourHours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sixHours:         return "6h"
        case .twelveHours:      return "12h"
        case .twentyFourHours:  return "24h"
        }
    }

    var hours: Int {
        switch self {
        case .sixHours:         return 6
        case .twelveHours:      return 12
        case .twentyFourHours:  return 24
        }
    }

    /// The start date for this range, relative to now.
    var startDate: Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
    }
}

// MARK: - EventHealthTimelineView

struct EventHealthTimelineView: View {

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var selectedRange: TimelineRange = .twelveHours
    @State private var heartRateData: [(date: Date, bpm: Double)] = []
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var restingHR: Double?
    @State private var isLoaded = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            rangeSelector
            timelineCard
        }
        .task(id: selectedRange) { await loadData() }
    }

    // MARK: - Range Selector

    private var rangeSelector: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(TimelineRange.allCases) { range in
                Button {
                    withAnimation(Theme.Animation.standard) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.label)
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(
                            selectedRange == range
                                ? Theme.Colors.textOnAccent
                                : Theme.Colors.textTertiary
                        )
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(Theme.Colors.accent)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.label) time range")
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(Theme.Spacing.xxs)
        .background {
            Capsule()
                .fill(Theme.Colors.surface)
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )
        }
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )

            // Radial glow
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
                chartHeader
                timelineChart
                eventLegend
            }
            .padding(Theme.Spacing.xxl)
        }
        .opacity(isLoaded ? Theme.Opacity.full : Theme.Opacity.transparent)
        .animation(
            reduceMotion ? .none : Theme.Animation.dataReveal,
            value: isLoaded
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: "heart.text.square")
                .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.half))

            Text("Heart Rate Timeline")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            if let currentHR = heartRateData.last?.bpm {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                    Text("\(Int(currentHR))")
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(signalColor(for: currentHR))

                    Text("BPM")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Chart Content

    private var timelineChart: some View {
        Chart {
            // Area fill under the HR line
            ForEach(Array(heartRateData.enumerated()), id: \.offset) { _, sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                            Theme.Colors.accent.opacity(Theme.Opacity.minimal)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // HR line
            ForEach(Array(heartRateData.enumerated()), id: \.offset) { _, sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(Theme.Colors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Theme.Radius.legendStroke))
            }

            // Resting HR baseline
            if let baseline = restingHR {
                RuleMark(y: .value("Resting HR", baseline))
                    .foregroundStyle(Theme.Colors.signalCalm.opacity(Theme.Opacity.medium))
                    .lineStyle(StrokeStyle(lineWidth: Theme.Radius.glassStroke, dash: [Theme.Spacing.xs, Theme.Spacing.xxs]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text("Rest \(Int(baseline))")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.signalCalm.opacity(Theme.Opacity.half))
                    }
            }

            // Calendar event annotations
            ForEach(visibleEvents) { event in
                RuleMark(x: .value("Event", event.startDate))
                    .foregroundStyle(eventStressColor(event: event).opacity(Theme.Opacity.medium))
                    .lineStyle(StrokeStyle(lineWidth: Theme.Radius.glassStroke, dash: [Theme.Spacing.sm, Theme.Spacing.xxs]))
                    .annotation(position: .top, alignment: .leading) {
                        eventAnnotationLabel(event: event)
                    }
            }
        }
        .chartXScale(domain: selectedRange.startDate...Date())
        .chartYScale(domain: chartYDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(Theme.Opacity.light))
                AxisValueLabel(format: xAxisDateFormat)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.Colors.divider.opacity(Theme.Opacity.light))
                AxisValueLabel()
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(height: Constants.EventHealthTimeline.chartHeight)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    // MARK: - Event Annotation

    private func eventAnnotationLabel(event: CalendarEvent) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(eventStressColor(event: event))
                .frame(width: Theme.Spacing.xxs, height: Theme.Spacing.md)

            Text(event.title)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.Colors.surface.opacity(Theme.Opacity.translucent))
        }
        .accessibilityLabel("\(event.title) at \(event.startDate.formatted(date: .omitted, time: .shortened))")
    }

    // MARK: - Event Legend

    private var eventLegend: some View {
        Group {
            if !visibleEvents.isEmpty {
                HStack(spacing: Theme.Spacing.lg) {
                    legendItem(color: Theme.Colors.signalPeak, label: "High stress")
                    legendItem(color: Theme.Colors.signalElevated, label: "Moderate")
                    legendItem(color: Theme.Colors.textTertiary, label: "Low")
                    legendItem(color: Theme.Colors.signalCalm, label: "Resting HR")
                }
                .opacity(isLoaded ? Theme.Opacity.full : Theme.Opacity.transparent)
                .animation(
                    reduceMotion
                        ? .none
                        : Theme.Animation.staggeredFadeIn(index: 1),
                    value: isLoaded
                )
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(color)
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.xxs)

            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Data Loading

    private func loadData() async {
        let hk = dependencies.healthKitService
        let cal = dependencies.calendarService

        let rangeStart = selectedRange.startDate
        let now = Date()

        async let hrTask = hk.heartRateHistory(hours: selectedRange.hours)
        async let restingTask = hk.latestRestingHR()
        async let eventsTask = cal.events(from: rangeStart, to: now)

        let hrResult = await hrTask
        let restingResult = await restingTask
        let eventsResult = await eventsTask

        heartRateData = hrResult ?? []
        restingHR = restingResult ?? Theme.Health.Defaults.restingHR
        calendarEvents = eventsResult

        if !isLoaded {
            withAnimation(reduceMotion ? .none : Theme.Animation.dataReveal) {
                isLoaded = true
            }
        }
    }

    // MARK: - Helpers

    /// Events that are not all-day and fall within the selected time range.
    private var visibleEvents: [CalendarEvent] {
        let rangeStart = selectedRange.startDate
        return calendarEvents.filter { event in
            !event.isAllDay && event.startDate >= rangeStart
        }
    }

    /// Determines stress color for an event based on average HR near the event start.
    private func eventStressColor(event: CalendarEvent) -> Color {
        guard let avgHR = averageHRNearEvent(event) else {
            return Theme.Colors.textTertiary
        }

        let baseline = restingHR ?? Theme.Health.Defaults.restingHR
        let delta = avgHR - baseline

        if delta > Constants.EventHealthTimeline.hrDeltaHighThreshold {
            return Theme.Colors.signalPeak
        } else if delta > Constants.EventHealthTimeline.hrDeltaModerateThreshold {
            return Theme.Colors.signalElevated
        } else {
            return Theme.Colors.textTertiary
        }
    }

    /// Returns the average HR within a window around the event start time.
    private func averageHRNearEvent(_ event: CalendarEvent) -> Double? {
        let windowStart = event.startDate.addingTimeInterval(-Constants.EventHealthTimeline.hrWindowSeconds)
        let windowEnd = event.startDate.addingTimeInterval(Constants.EventHealthTimeline.hrWindowSeconds)

        let nearbyReadings = heartRateData.filter { sample in
            sample.date >= windowStart && sample.date <= windowEnd
        }

        guard !nearbyReadings.isEmpty else { return nil }
        let total = nearbyReadings.reduce(0.0) { $0 + $1.bpm }
        return total / Double(nearbyReadings.count)
    }

    /// Y-axis domain computed from actual data with padding.
    private var chartYDomain: ClosedRange<Double> {
        let bpmValues = heartRateData.map(\.bpm)
        let baseline = restingHR ?? Theme.Health.Defaults.restingHR

        let allValues = bpmValues + [baseline]
        let minBPM = (allValues.min() ?? Constants.EventHealthTimeline.chartMinBPM) - Constants.EventHealthTimeline.chartBPMPadding
        let maxBPM = (allValues.max() ?? (baseline + Constants.EventHealthTimeline.chartMinBPM)) + Constants.EventHealthTimeline.chartBPMPadding

        return max(minBPM, 0)...maxBPM
    }

    /// X-axis stride component for the selected range.
    private var xAxisStride: Calendar.Component {
        switch selectedRange {
        case .sixHours:         return .hour
        case .twelveHours:      return .hour
        case .twentyFourHours:  return .hour
        }
    }

    /// X-axis stride count for the selected range.
    private var xAxisStrideCount: Int {
        switch selectedRange {
        case .sixHours:         return 1
        case .twelveHours:      return 2
        case .twentyFourHours:  return 4
        }
    }

    /// X-axis date format for the selected range.
    private var xAxisDateFormat: Date.FormatStyle {
        .dateTime.hour(.defaultDigits(amPM: .abbreviated))
    }

    /// Determines signal color based on HR value relative to resting baseline.
    private func signalColor(for bpm: Double) -> Color {
        let baseline = restingHR ?? Theme.Health.Defaults.restingHR
        let delta = bpm - baseline

        if delta > Constants.EventHealthTimeline.hrDeltaHighThreshold {
            return Theme.Colors.signalPeak
        } else if delta > Constants.EventHealthTimeline.hrDeltaModerateThreshold {
            return Theme.Colors.signalElevated
        } else if delta > Constants.EventHealthTimeline.hrDeltaLowThreshold {
            return Theme.Colors.signalFocus
        } else {
            return Theme.Colors.signalCalm
        }
    }

    /// Accessibility label summarizing the chart content.
    private var chartAccessibilityLabel: String {
        let rangeLabel = selectedRange.label
        let eventCount = visibleEvents.count
        let hrCount = heartRateData.count

        var label = "Heart rate timeline for the past \(rangeLabel)"

        if hrCount > 0, let minHR = heartRateData.map(\.bpm).min(), let maxHR = heartRateData.map(\.bpm).max() {
            label += ". Heart rate ranged from \(Int(minHR)) to \(Int(maxHR)) BPM"
        }

        if let baseline = restingHR {
            label += ". Resting heart rate baseline at \(Int(baseline)) BPM"
        }

        if eventCount > 0 {
            label += ". \(eventCount) calendar event\(eventCount == 1 ? "" : "s") shown"
        }

        return label
    }
}

// MARK: - Preview

#Preview("Event-Health Timeline") {
    ScrollView {
        EventHealthTimelineView()
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxl)
    }
    .background { Theme.Colors.canvas }
    .environment(AppDependencies())
    .preferredColorScheme(.dark)
}

// MARK: - Constants

private extension Constants {
    enum EventHealthTimeline {
        static let hrDeltaHighThreshold: Double = 20   // BPM above baseline = high stress
        static let hrDeltaModerateThreshold: Double = 10 // BPM above baseline = moderate
        static let hrDeltaLowThreshold: Double = 4      // BPM above baseline = low
        static let hrWindowSeconds: TimeInterval = 300   // 5 min window around event
        static let chartMinBPM: Double = 50              // minimum Y axis value
        static let chartBPMPadding: Double = 8           // padding above/below HR range
        static let chartHeight: CGFloat = 192            // chart frame height
    }
}
