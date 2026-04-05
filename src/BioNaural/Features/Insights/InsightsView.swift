// InsightsView.swift
// BioNaural
//
// Unified "Insights" page — merges the old History tab and Health tab into
// a single premium health intelligence dashboard. Five sections: body-now,
// session impact, trends, history, and sleep. Atmospheric dark-first design
// with glass cards, periwinkle accent, staggered entrance animations.
// All values from Theme tokens. No hardcoded numbers.

import SwiftUI
import SwiftData
import Charts
import BioNauralShared

// MARK: - InsightsView

struct InsightsView: View {

    // MARK: - Environment & Data

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startDate,
        order: .reverse
    )
    private var completedSessions: [FocusSession]

    @Query(sort: \FocusSession.startDate, order: .reverse)
    private var allSessions: [FocusSession]

    // MARK: - Health State

    @State private var dateRange: HealthDateRange = .week
    @State private var restingHR: Double?
    @State private var hrv: Double?
    @State private var avgRestingHR: Double?
    @State private var avgHRV: Double?
    @State private var sleepData: (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])?
    @State private var steps: Int?
    @State private var activeEnergy: Double?

    // MARK: - UI State

    @State private var selectedModeFilter: ModeFilter = .all
    @State private var showAllSessions = false
    @State private var sectionsVisible = false

    // MARK: - Defaults

    /// Convenience alias for population-average health defaults.
    private typealias HealthDefaults = Constants.HealthDefaults

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                streakSection
                    .staggeredFadeIn(index: 0, isVisible: sectionsVisible)

                bodyRightNowSection
                    .staggeredFadeIn(index: 1, isVisible: sectionsVisible)

                sessionImpactSection
                    .staggeredFadeIn(index: 2, isVisible: sectionsVisible)

                trendsSection
                    .staggeredFadeIn(index: 3, isVisible: sectionsVisible)

                historySection
                    .staggeredFadeIn(index: 4, isVisible: sectionsVisible)

                if sleepData != nil {
                    sleepSection
                        .staggeredFadeIn(index: 5, isVisible: sectionsVisible)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .background { NebulaBokehBackground() }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                dateRangeMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Settings")
            }
        }
        .task(id: dateRange) { await refreshLoop() }
        .onAppear {
            guard !reduceMotion else {
                sectionsVisible = true
                return
            }
            withAnimation(Theme.Animation.standard) {
                sectionsVisible = true
            }
        }
    }

    // MARK: - Toolbar: Date Range Menu

    private var dateRangeMenu: some View {
        Menu {
            ForEach(HealthDateRange.allCases, id: \.self) { range in
                Button {
                    dateRange = range
                } label: {
                    Label(range.label, systemImage: dateRange == range ? "checkmark" : range.icon)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: dateRange.icon)
                Text(dateRange.label)
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // =========================================================================
    // MARK: - Section 0: Streak & Activity
    // =========================================================================

    private var streakSection: some View {
        let streak = currentStreak
        let weekCount = sessionsThisWeek

        return HStack(spacing: Theme.Spacing.lg) {
            // Streak
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(streak > 0 ? Theme.Colors.energize : Theme.Colors.textTertiary)

                Text(streak > 0 ? "\(streak)-day streak" : "Start a streak")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(streak > 0 ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            }

            Spacer()

            // This week count
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(weekCount)")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.accent)

                Text("this week")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(streak > 0 ? "\(streak) day streak, \(weekCount) sessions this week" : "\(weekCount) sessions this week")
    }

    // MARK: Streak Calculation

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streakCount = 0
        var checkDate = calendar.startOfDay(for: Date())

        let hasToday = allSessions.contains { calendar.isDate($0.startDate, inSameDayAs: checkDate) }

        if !hasToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let dayHasSession = allSessions.contains {
                calendar.isDate($0.startDate, inSameDayAs: checkDate)
            }

            if dayHasSession {
                streakCount += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streakCount
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return allSessions.filter { $0.startDate >= startOfWeek }.count
    }

    // Sections 1-3 moved to extensions below

    // =========================================================================
    // MARK: - Section 4: History
    // =========================================================================

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("History")

            // Mode filter pills
            filterBar

            if filteredSessions.isEmpty {
                historyEmptyState
            } else {
                // Session list (max 5 unless "See All")
                let displayedSessions = showAllSessions
                    ? filteredSessions
                    : Array(filteredSessions.prefix(Constants.historyPreviewLimit))

                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(displayedSessions.enumerated()), id: \.element.id) { _, session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(InsightsGlassRowButtonStyle())
                    }
                }

                // "See All" button
                if !showAllSessions && filteredSessions.count > Constants.historyPreviewLimit {
                    Button {
                        withAnimation(Theme.Animation.standard) {
                            showAllSessions = true
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("See All")
                                .font(Theme.Typography.caption)

                            Image(systemName: "chevron.right")
                                .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                        }
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ModeFilter.allCases) { filter in
                    filterPill(for: filter)
                }
            }
        }
        .accessibilityLabel("Filter sessions by mode")
    }

    private func filterPill(for filter: ModeFilter) -> some View {
        let isSelected = selectedModeFilter == filter

        return Button {
            withAnimation(Theme.Animation.press) {
                selectedModeFilter = filter
                showAllSessions = false
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: filter.systemImageName)
                    .font(.system(size: Theme.Typography.Size.small))

                Text(filter.displayName)
                    .font(Theme.Typography.caption)
            }
            .foregroundStyle(isSelected ? Theme.Colors.textOnAccent : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : Theme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? Theme.Animation.OrbScale.breathingMax : Theme.Animation.OrbScale.breathingMin)
        .animation(Theme.Animation.press, value: isSelected)
        .accessibilityLabel("\(filter.displayName) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Session Filtering

    private var filteredSessions: [FocusSession] {
        guard let mode = selectedModeFilter.focusMode else {
            return allSessions
        }
        return allSessions.filter { $0.mode == mode.rawValue }
    }

    // MARK: History Empty State

    private var historyEmptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: selectedModeFilter.systemImageName)
                .font(.system(size: Theme.Typography.Size.headline, weight: .light))
                .foregroundStyle(selectedModeFilter.color.opacity(Theme.Opacity.medium))

            Text(selectedModeFilter == .all
                 ? "No sessions yet"
                 : "No \(selectedModeFilter.displayName) sessions")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // Section 5 (Sleep) moved to extension below

    // =========================================================================
    // MARK: - Shared Helpers
    // =========================================================================

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    private func refreshLoop() async {
        await loadHealthData()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Theme.Animation.Duration.healthRefreshInterval))
            await loadHealthData()
        }
    }

    private func loadHealthData() async {
        let hk = dependencies.healthKitService

        // Heart rate: live -> resting -> 7-day avg -> default
        if dependencies.isWatchConnected {
            restingHR = await hk.latestHeartRate()
        }
        if restingHR == nil { restingHR = await hk.latestRestingHR() }
        if restingHR == nil { restingHR = await hk.averageRestingHR(days: Constants.healthAverageDays) }
        if restingHR == nil { restingHR = HealthDefaults.restingHR }

        // HRV: latest -> 7-day avg -> default
        hrv = await hk.latestHRV()
        if hrv == nil { hrv = await hk.averageHRV(days: Constants.healthAverageDays) }
        if hrv == nil { hrv = HealthDefaults.hrv }

        // Averages for trend comparison
        avgRestingHR = await hk.averageRestingHR(days: dateRange.days)
        avgHRV = await hk.averageHRV(days: dateRange.days)

        // Sleep
        sleepData = await hk.lastNightSleep()

        // Activity
        steps = await hk.stepsToday()
        activeEnergy = await hk.activeEnergyToday()
    }
}

// MARK: - Section 1: Your Body Right Now

extension InsightsView {

    fileprivate var bodyRightNowSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Your Body Right Now")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.md),
                    GridItem(.flexible(), spacing: Theme.Spacing.md)
                ],
                spacing: Theme.Spacing.md
            ) {
                // Resting HR
                biometricCard(
                    icon: "heart.fill",
                    label: "RESTING HR",
                    value: "\(Int(restingHR ?? HealthDefaults.restingHR))",
                    unit: "BPM",
                    current: restingHR ?? HealthDefaults.restingHR,
                    average: avgRestingHR ?? HealthDefaults.restingHR,
                    lowerIsGood: true,
                    glowColor: Theme.Colors.signalCalm
                )

                // HRV
                biometricCard(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(hrv ?? HealthDefaults.hrv))",
                    unit: "ms",
                    current: hrv ?? HealthDefaults.hrv,
                    average: avgHRV ?? HealthDefaults.hrv,
                    lowerIsGood: false,
                    glowColor: Theme.Colors.accent
                )

                // Last Night Sleep
                biometricCard(
                    icon: "moon.fill",
                    label: "LAST NIGHT",
                    value: String(format: "%.1f", sleepData?.hours ?? HealthDefaults.sleepHours),
                    unit: "hrs",
                    current: nil,
                    average: nil,
                    lowerIsGood: false,
                    glowColor: Theme.Colors.sleep,
                    subtitle: sleepData.map { "\(Int($0.deepSleepMinutes)) min deep" }
                )

                // Today's Activity
                biometricCard(
                    icon: "figure.walk",
                    label: "TODAY",
                    value: steps.map { "\($0.formatted())" } ?? "0",
                    unit: "steps",
                    current: nil,
                    average: nil,
                    lowerIsGood: false,
                    glowColor: Theme.Colors.energize,
                    subtitle: activeEnergy.map { "\(Int($0)) kcal" }
                )
            }
        }
    }

    fileprivate func biometricCard(
        icon: String,
        label: String,
        value: String,
        unit: String,
        current: Double?,
        average: Double?,
        lowerIsGood: Bool,
        glowColor: Color,
        subtitle: String? = nil
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

            // Subtle radial glow at top-left
            RadialGradient(
                colors: [glowColor.opacity(Theme.Opacity.light), Color.clear],
                center: .topLeading,
                startRadius: .zero,
                endRadius: Theme.Spacing.mega * 2
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(glowColor.opacity(Theme.Opacity.half))

                // Label
                Text(label)
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .foregroundStyle(Theme.Colors.textTertiary)

                // Value + unit
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                    Text(value)
                        .font(Theme.Typography.data)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(unit)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // Trend arrow (if we have current vs average)
                if let current, let average {
                    let delta = current - average
                    let isPositive = lowerIsGood ? delta < 0 : delta > 0
                    if abs(delta) > Constants.trendDeltaThreshold {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: delta < 0 ? "arrow.down.right" : "arrow.up.right")
                                .font(.system(size: Theme.Typography.Size.small, weight: .semibold))

                            Text("\(Int(abs(delta))) vs avg")
                                .font(Theme.Typography.small)
                        }
                        .foregroundStyle(isPositive ? Theme.Colors.signalCalm : Theme.Colors.signalElevated)
                    }
                }

                // Subtitle (e.g. deep sleep minutes, kcal)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - Section 2: Session Impact

extension InsightsView {

    fileprivate var sessionImpactSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Session Impact")

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
                        Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: .zero,
                    endRadius: Theme.Spacing.mega * 3
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let score = impactScore {
                        // Score display
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                            Text("\(Int(score * 100))")
                                .font(Theme.Typography.timer)
                                .foregroundStyle(scoreColor(score))

                            Text("%")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(scoreColor(score).opacity(Theme.Opacity.half))
                        }

                        Text("SESSION RESPONSE")
                            .font(Theme.Typography.small)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .foregroundStyle(Theme.Colors.textTertiary)

                        // Insight text
                        if let insight = impactInsight {
                            Text(insight)
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                        }

                        // Sparkline chart
                        impactSparkline
                    } else {
                        // Empty state
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: Theme.Typography.Size.title, weight: .light))
                                .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.medium))

                            Text("Start a session and I'll learn\nhow your body responds")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                    }
                }
                .padding(Theme.Spacing.xxl)
            }
        }
    }

    // MARK: Impact Helpers

    fileprivate var scoredSessions: [FocusSession] {
        completedSessions.filter { $0.biometricSuccessScore != nil }
    }

    fileprivate var impactScore: Double? {
        let scored = scoredSessions
        guard !scored.isEmpty else { return nil }
        let total = scored.compactMap(\.biometricSuccessScore).reduce(0, +)
        return total / Double(scored.count)
    }

    fileprivate var impactInsight: String? {
        let sessionsWithHR = completedSessions.filter { ($0.averageHeartRate ?? 0) > 0 }
        guard sessionsWithHR.count >= Constants.impactInsightMinSessions else { return nil }

        let avgSessionHR = sessionsWithHR.compactMap(\.averageHeartRate).reduce(0, +) / Double(sessionsWithHR.count)
        let baseline = restingHR ?? HealthDefaults.restingHR

        let delta = Int(baseline - avgSessionHR)
        if delta > Constants.impactInsightMinDelta {
            return "Your heart rate drops an average of \(delta) BPM during sessions"
        }
        return nil
    }

    fileprivate var sparklineData: [Double] {
        scoredSessions.suffix(Constants.sparklineDataPointCount).compactMap(\.biometricSuccessScore)
    }

    fileprivate var impactSparkline: some View {
        Chart {
            ForEach(Array(sparklineData.enumerated()), id: \.offset) { index, score in
                AreaMark(
                    x: .value("Session", index),
                    y: .value("Score", score)
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

                LineMark(
                    x: .value("Session", index),
                    y: .value("Score", score)
                )
                .foregroundStyle(Theme.Colors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Theme.Radius.legendStroke))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .frame(height: Theme.Spacing.jumbo)
    }

    fileprivate func scoreColor(_ score: Double) -> Color {
        switch score {
        case Constants.ImpactScore.goodThreshold...: return Theme.Colors.signalCalm
        case Constants.ImpactScore.moderateThreshold..<Constants.ImpactScore.goodThreshold: return Theme.Colors.accent
        default: return Theme.Colors.signalElevated
        }
    }
}

// MARK: - Section 3: Trends

extension InsightsView {

    fileprivate var trendsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Trends")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    // HR trend
                    trendMiniCard(
                        title: "RESTING HR",
                        currentValue: "\(Int(restingHR ?? HealthDefaults.restingHR))",
                        unit: "BPM",
                        color: Theme.Colors.signalCalm,
                        dataPoints: hrTrendData
                    )

                    // HRV trend
                    trendMiniCard(
                        title: "HRV",
                        currentValue: "\(Int(hrv ?? HealthDefaults.hrv))",
                        unit: "ms",
                        color: Theme.Colors.accent,
                        dataPoints: hrvTrendData
                    )

                    // Sessions per week
                    sessionsPerWeekCard
                }
            }
        }
    }

    fileprivate func trendMiniCard(
        title: String,
        currentValue: String,
        unit: String,
        color: Color,
        dataPoints: [Double]
    ) -> some View {
        NavigationLink {
            TrendsView()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .strokeBorder(
                                Theme.Colors.divider.opacity(Theme.Opacity.half),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    // Mini chart
                    if !dataPoints.isEmpty {
                        Chart {
                            ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, value in
                                LineMark(
                                    x: .value("Index", index),
                                    y: .value("Value", value)
                                )
                                .foregroundStyle(color)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: Theme.Radius.legendStroke))
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: Theme.Spacing.xxxl)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                        Text(currentValue)
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(unit)
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .frame(width: Theme.Spacing.mega * 2 + Theme.Spacing.xxxl)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(currentValue) \(unit). Tap for trends.")
    }

    fileprivate var sessionsPerWeekCard: some View {
        NavigationLink {
            TrendsView()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .strokeBorder(
                                Theme.Colors.divider.opacity(Theme.Opacity.half),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("SESSIONS / WEEK")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    // Bar chart
                    if !weeklySessionCounts.isEmpty {
                        Chart {
                            ForEach(Array(weeklySessionCounts.enumerated()), id: \.offset) { index, count in
                                BarMark(
                                    x: .value("Week", index),
                                    y: .value("Count", count)
                                )
                                .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.accentStrong))
                                .cornerRadius(Theme.Radius.xs)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: Theme.Spacing.xxxl)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                        Text("\(currentWeekSessionCount)")
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("this week")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .frame(width: Theme.Spacing.mega * 2 + Theme.Spacing.xxxl)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sessions per week: \(currentWeekSessionCount) this week. Tap for trends.")
    }

    // MARK: Trend Data Helpers

    fileprivate var hrTrendData: [Double] {
        let recent = completedSessions.prefix(Constants.trendDataPointCount)
        return recent.reversed().compactMap(\.averageHeartRate)
    }

    fileprivate var hrvTrendData: [Double] {
        let recent = completedSessions.prefix(Constants.trendDataPointCount)
        return recent.reversed().compactMap(\.averageHRV)
    }

    fileprivate var weeklySessionCounts: [Int] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<Constants.trendWeekCount).reversed().map { weeksAgo in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else {
                return 0
            }
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
            return allSessions.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }.count
        }
    }

    fileprivate var currentWeekSessionCount: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return allSessions.filter { $0.startDate >= startOfWeek }.count
    }
}

// MARK: - Section 5: Sleep

extension InsightsView {

    @ViewBuilder
    fileprivate var sleepSection: some View {
        if let sleep = sleepData {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionLabel("Last Night")

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

                    // Sleep-colored glow
                    RadialGradient(
                        colors: [Theme.Colors.sleep.opacity(Theme.Opacity.light), Color.clear],
                        center: .topLeading,
                        startRadius: .zero,
                        endRadius: Theme.Spacing.mega * 2
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Icon
                        Image(systemName: "moon.fill")
                            .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                            .foregroundStyle(Theme.Colors.sleep.opacity(Theme.Opacity.half))

                        // Total hours + deep
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                            Text(String(format: "%.1f", sleep.hours))
                                .font(Theme.Typography.data)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Text("hrs")
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.Colors.textTertiary)

                            Spacer()

                            if sleep.deepSleepMinutes > 0 {
                                HStack(spacing: Theme.Spacing.xxs) {
                                    Text("\(Int(sleep.deepSleepMinutes)) min")
                                        .font(Theme.Typography.dataSmall)
                                        .foregroundStyle(Theme.Colors.textSecondary)

                                    Text("deep")
                                        .font(Theme.Typography.small)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                            }
                        }

                        // Sleep stage bar
                        if !sleep.stages.isEmpty {
                            sleepStageBar(stages: sleep.stages)

                            // Stage legend
                            HStack(spacing: Theme.Spacing.lg) {
                                stageLegend(label: "Deep", color: Theme.Colors.sleep)
                                stageLegend(label: "Core", color: Theme.Colors.accent)
                                stageLegend(label: "REM", color: Theme.Colors.focus)
                                stageLegend(label: "Awake", color: Theme.Colors.textTertiary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.xxl)
                }
            }
        }
    }

    fileprivate func sleepStageBar(stages: [SleepStage]) -> some View {
        let total = stages.reduce(0) { $0 + $1.duration }
        return GeometryReader { geo in
            if total > 0 {
                HStack(spacing: Theme.Radius.xs) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                        let fraction = stage.duration / total
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(stageColor(stage.stage))
                            .frame(width: max(geo.size.width * fraction - Theme.Radius.xs, Theme.Radius.segmentHeight))
                    }
                }
            }
        }
        .frame(height: Theme.Spacing.md)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .accessibilityLabel(sleepStageAccessibilityLabel(stages: stages))
    }

    fileprivate func sleepStageAccessibilityLabel(stages: [SleepStage]) -> String {
        let breakdown = stages.map { stage in
            let minutes = Int(stage.duration / 60)
            return "\(stage.stage.rawValue) \(minutes) minutes"
        }
        return "Sleep stages: \(breakdown.joined(separator: ", "))"
    }

    fileprivate func stageColor(_ stage: SleepStage.Stage) -> Color {
        switch stage {
        case .deep:  return Theme.Colors.sleep
        case .core:  return Theme.Colors.accent
        case .rem:   return Theme.Colors.focus
        case .awake: return Theme.Colors.textTertiary
        }
    }

    fileprivate func stageLegend(label: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(color)
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.xxs)
            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Mode Filter

private enum ModeFilter: String, CaseIterable, Identifiable {
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

    var systemImageName: String {
        switch self {
        case .all:         return "waveform.path"
        case .focus:       return "brain.head.profile"
        case .relaxation:  return "leaf.fill"
        case .sleep:       return "moon.fill"
        case .energize:    return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .all:         return Theme.Colors.accent
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        }
    }
}

// MARK: - Glass Row Button Style (Insights)

private struct InsightsGlassRowButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .strokeBorder(
                        Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
            .scaleEffect(configuration.isPressed ? Theme.Interaction.pressScale : 1.0)
            .opacity(configuration.isPressed ? Theme.Opacity.translucent : Theme.Opacity.full)
            .animation(
                reduceMotion ? .identity : Theme.Animation.press,
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#Preview("Insights") {
    NavigationStack {
        InsightsView()
    }
    .environment(AppDependencies())
    .preferredColorScheme(.dark)
}
