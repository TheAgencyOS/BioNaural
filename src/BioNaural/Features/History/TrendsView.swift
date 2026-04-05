// TrendsView.swift
// BioNaural
//
// Charts showing biometric trends over time. Premium feature with
// blur gate for non-subscribers. Uses native Swift Charts framework.
// All colors from Theme.Colors, all typography from Theme.Typography.

import SwiftUI
import SwiftData
import Charts
import BioNauralShared

// MARK: - Time Range

/// Selectable time ranges for trend charts.
enum TrendTimeRange: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case threeMonths
    case allTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneWeek:      return "1 Week"
        case .oneMonth:     return "1 Month"
        case .threeMonths:  return "3 Months"
        case .allTime:      return "All Time"
        }
    }

    /// The start date for this range, relative to now.
    /// Returns `nil` for `.allTime`.
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .oneWeek:      return calendar.date(byAdding: .day, value: -7, to: now)
        case .oneMonth:     return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:  return calendar.date(byAdding: .month, value: -3, to: now)
        case .allTime:      return nil
        }
    }
}

// MARK: - Chart Mode Filter

/// Mode filter for the HR chart series. Allows viewing per-mode lines.
enum TrendModeFilter: String, CaseIterable, Identifiable {
    case all
    case focus
    case relaxation
    case sleep
    case energize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:         return "All"
        case .focus:       return "Focus"
        case .relaxation:  return "Relaxation"
        case .sleep:       return "Sleep"
        case .energize:    return "Energize"
        }
    }

    var focusMode: FocusMode? {
        switch self {
        case .all:         return nil
        case .focus:       return .focus
        case .relaxation:  return .relaxation
        case .sleep:       return .sleep
        case .energize:    return .energize
        }
    }
}

// MARK: - Chart Data Points

/// A single data point for time-series charts.
private struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let mode: String
}

/// A data point for the weekly frequency bar chart.
private struct WeeklyFrequencyPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let count: Int
}

// MARK: - TrendsView

struct TrendsView: View {

    // MARK: - State

    @State private var timeRange: TrendTimeRange = .oneMonth
    @State private var hrModeFilter: TrendModeFilter = .all
    @State private var showPaywall = false

    // MARK: - Query

    @Query(sort: \FocusSession.startDate, order: .reverse)
    private var allSessions: [FocusSession]

    // MARK: - Environment

    @State private var subscriptionManager = SubscriptionManager.shared

    // MARK: - Computed

    private var isPremium: Bool {
        subscriptionManager.isPremium
    }

    /// Sessions filtered by the selected time range.
    private var timeFilteredSessions: [FocusSession] {
        guard let start = timeRange.startDate else {
            return allSessions
        }
        return allSessions.filter { $0.startDate >= start }
    }

    private let calendar = Calendar.current

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xxl) {
                    timeRangePicker
                    hrChart
                    hrvChart
                    frequencyChart
                    successScoreChart
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())

            if !isPremium {
                premiumGate
            }
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TrendTimeRange.allCases) { range in
                Text(range.displayName)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, Theme.Spacing.md)
        .accessibilityLabel("Time range filter")
        .accessibilityHint("Filters trend charts by time period")
    }

    // MARK: - Chart 1: Average HR Over Time

    private var hrChart: some View {
        chartContainer(title: "Average Heart Rate", icon: "heart.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Picker("Mode", selection: $hrModeFilter) {
                    ForEach(TrendModeFilter.allCases) { filter in
                        Text(filter.displayName)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Heart rate mode filter")

                Chart(hrDataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("BPM", point.value)
                    )
                    .foregroundStyle(by: .value("Mode", point.mode))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: chartLineWidth))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("BPM", point.value)
                    )
                    .foregroundStyle(by: .value("Mode", point.mode))
                    .symbolSize(chartPointSize)
                }
                .chartForegroundStyleScale(modeColorMapping)
                .chartYAxisLabel("BPM", position: .trailing)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                            .foregroundStyle(Theme.Colors.divider)
                        AxisValueLabel()
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(Theme.Colors.divider)
                        AxisValueLabel()
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .frame(height: chartHeight)
                .accessibilityLabel("Average heart rate chart showing \(hrDataPoints.count) data points")
            }
        }
    }

    private var hrDataPoints: [TrendDataPoint] {
        let sessions: [FocusSession]
        if let mode = hrModeFilter.focusMode {
            sessions = timeFilteredSessions.filter { $0.mode == mode.rawValue }
        } else {
            sessions = timeFilteredSessions
        }

        return sessions.compactMap { session in
            guard let hr = session.averageHeartRate else { return nil }
            return TrendDataPoint(
                date: session.startDate,
                value: hr,
                mode: session.focusMode?.displayName ?? session.mode.capitalized
            )
        }
    }

    // MARK: - Chart 2: HRV Improvement

    private var hrvChart: some View {
        chartContainer(title: "HRV Over Time", icon: "waveform.path.ecg") {
            Chart(hrvDataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("ms", point.value)
                )
                .foregroundStyle(Theme.Colors.signalCalm)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: chartLineWidth))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("ms", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            Theme.Colors.signalCalm.opacity(Theme.Opacity.dim),
                            Theme.Colors.signalCalm.opacity(Theme.Opacity.transparent)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYAxisLabel("ms", position: .trailing)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(height: chartHeight)
            .accessibilityLabel("Heart rate variability chart showing \(hrvDataPoints.count) data points")
        }
    }

    private var hrvDataPoints: [TrendDataPoint] {
        timeFilteredSessions.compactMap { session in
            guard let hrv = session.averageHRV else { return nil }
            return TrendDataPoint(
                date: session.startDate,
                value: hrv,
                mode: session.focusMode?.displayName ?? session.mode.capitalized
            )
        }
    }

    // MARK: - Chart 3: Session Frequency (Bar)

    private var frequencyChart: some View {
        chartContainer(title: "Sessions Per Week", icon: "calendar") {
            Chart(weeklyFrequencyPoints) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Sessions", point.count)
                )
                .foregroundStyle(Theme.Colors.accent)
                .cornerRadius(Theme.Radius.sm)
            }
            .chartYAxisLabel("Sessions", position: .trailing)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(height: chartHeight)
            .accessibilityLabel("Sessions per week bar chart showing \(weeklyFrequencyPoints.count) weeks")
        }
    }

    private var weeklyFrequencyPoints: [WeeklyFrequencyPoint] {
        var weekCounts: [Date: Int] = [:]
        for session in timeFilteredSessions {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.startDate)?.start else {
                continue
            }
            weekCounts[weekStart, default: 0] += 1
        }
        return weekCounts
            .map { WeeklyFrequencyPoint(weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Chart 4: Biometric Success Score Trend

    private var successScoreChart: some View {
        chartContainer(title: "Biometric Success Score", icon: "chart.line.uptrend.xyaxis") {
            Chart(successScoreDataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(by: .value("Mode", point.mode))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: chartLineWidth))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(by: .value("Mode", point.mode))
                .symbolSize(chartPointSize)
            }
            .chartForegroundStyleScale(modeColorMapping)
            .chartYScale(domain: 0...1)
            .chartYAxisLabel("Score", position: .trailing)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(height: chartHeight)
            .accessibilityLabel("Biometric success score chart showing \(successScoreDataPoints.count) data points")
        }
    }

    private var successScoreDataPoints: [TrendDataPoint] {
        timeFilteredSessions.compactMap { session in
            guard let score = session.biometricSuccessScore else { return nil }
            return TrendDataPoint(
                date: session.startDate,
                value: score,
                mode: session.focusMode?.displayName ?? session.mode.capitalized
            )
        }
    }

    // MARK: - Premium Gate

    private var premiumGate: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xxl) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: Theme.Typography.Size.display))
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityHidden(true)

                Text("Unlock Trends")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Track your progress with detailed charts, biometric trends, and personalized insights.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)

                Button {
                    showPaywall = true
                } label: {
                    Text("Go Premium")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(
                            Theme.Colors.accent,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        )
                }
                .padding(.horizontal, Theme.Spacing.jumbo)
                .accessibilityLabel("Go Premium")
                .accessibilityHint("Opens the subscription options to unlock trends")
            }
        }
    }

    // MARK: - Chart Container

    private func chartContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(Theme.Colors.accent)

                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            content()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }

    // MARK: - Constants

    private var chartHeight: CGFloat { Theme.Spacing.mega * 3 }
    private var chartLineWidth: CGFloat { Theme.Wavelength.Stroke.elevated }
    private var chartPointSize: CGFloat { Theme.Spacing.xxxl }

    // MARK: - Color Mapping

    private var modeColorMapping: KeyValuePairs<String, Color> {
        [
            FocusMode.focus.displayName: Theme.Colors.focus,
            FocusMode.relaxation.displayName: Theme.Colors.relaxation,
            FocusMode.sleep.displayName: Theme.Colors.sleep,
            FocusMode.energize.displayName: Theme.Colors.energize
        ]
    }
}

// MARK: - Preview

#Preview("Trends - Premium") {
    NavigationStack {
        TrendsView()
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: FocusSession.self, inMemory: true)
}
