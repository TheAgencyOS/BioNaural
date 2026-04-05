// HealthView.swift
// BioNaural
//
// "How well does this app know me?" — a personal health intelligence page.
// Atmospheric background, glass cards with colored accent glows, and
// meaningful data that proves BioNaural understands your body.
// All values from Theme tokens. Native SwiftUI + Swift Charts.

import SwiftUI
import SwiftData
import Charts
import BioNauralShared

// MARK: - HealthView

struct HealthView: View {

    @Environment(AppDependencies.self) private var dependencies

    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startDate,
        order: .reverse
    )
    private var recentSessions: [FocusSession]

    // MARK: - Health State

    @State private var dateRange: HealthDateRange = .week
    @State private var restingHR: Double?
    @State private var hrv: Double?
    @State private var avgRestingHR: Double?
    @State private var avgHRV: Double?
    @State private var sleepData: (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])?
    @State private var steps: Int?
    @State private var activeEnergy: Double?
    @State private var spo2: Double?
    @State private var todaysEvents: [CalendarEvent] = []
    @State private var nextFreeWindow: DateInterval?
    @State private var calendarAuthorized = false

    // MARK: - Correlation State

    @State private var recentImpacts: [EventImpact] = []
    @State private var activeForecast: HealthForecast?
    @State private var weeklyDigest: WeeklyDigest?
    @State private var activeLifeEvent: LifeEvent?
    @State private var journalCorrelations: [JournalCorrelation] = []
    @State private var weatherInsight: WeatherInsight?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                impactSection

                // Event-Health Timeline (HR + calendar overlay)
                if calendarAuthorized {
                    eventHealthTimelineSection
                }

                scheduleSection

                // Predictive forecast for upcoming stressors
                if let forecast = activeForecast {
                    forecastSection(forecast)
                }

                trendCards

                // Weather-health context
                if let weather = weatherInsight {
                    weatherSection(weather)
                }

                // Post-event impact cards
                if !recentImpacts.isEmpty {
                    postEventSection
                }

                sleepSection

                // Life event halo (multi-day arc)
                if let lifeEvent = activeLifeEvent {
                    lifeEventSection(lifeEvent)
                }

                // Weekly correlation digest
                if let digest = weeklyDigest {
                    weeklyDigestSection(digest)
                }

                // Journal-based life context correlations
                if !journalCorrelations.isEmpty {
                    journalSection
                }

                vitalsSection
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background { NebulaBokehBackground() }
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                dateRangeMenu
            }
        }
        .task(id: dateRange) { await refreshLoop() }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= Theme.Health.scoreThresholdGood {
            return Theme.Colors.signalCalm
        } else if score >= Theme.Health.scoreThresholdFair {
            return Theme.Colors.accent
        } else {
            return Theme.Colors.signalElevated
        }
    }

    // MARK: - Computed Data

    private var scoredSessions: [FocusSession] {
        recentSessions.filter { $0.biometricSuccessScore != nil }
    }

    /// Returns the average biometric success score across recent sessions.
    /// Falls back to a seed value before enough data exists.
    private var impactScore: Double? {
        let scored = scoredSessions
        guard !scored.isEmpty else { return Theme.Health.Seed.impactScore }
        let total = scored.compactMap(\.biometricSuccessScore).reduce(0, +)
        return total / Double(scored.count)
    }

    /// Generates a human-readable insight from session biometric data.
    /// Falls back to a seed insight before enough data exists.
    private var impactInsight: String? {
        let sessionsWithHR = recentSessions.filter { ($0.averageHeartRate ?? 0) > 0 }
        guard sessionsWithHR.count >= Theme.Health.minimumScoredSessions else {
            return "Your heart rate drops an average of \(Theme.Health.Seed.hrDeltaBPM) BPM during Focus sessions"
        }

        let avgSessionHR = sessionsWithHR.compactMap(\.averageHeartRate).reduce(0, +) / Double(sessionsWithHR.count)
        let baseline = restingHR ?? Theme.Health.Defaults.restingHR

        let delta = Int(baseline - avgSessionHR)
        if Double(delta) > Theme.Health.trendDeltaThreshold {
            return "Your heart rate drops an average of \(delta) BPM during sessions"
        }
        return nil
    }
}

// MARK: - Subview Sections

extension HealthView {

    fileprivate var dateRangeMenu: some View {
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

    // MARK: - Section 1: Impact

    fileprivate var impactSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Your Impact")

            ZStack(alignment: .topLeading) {
                // Card background with accent glow
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                    )

                // Radial glow at top-left corner
                RadialGradient(
                    colors: [
                        Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusLarge
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let score = impactScore {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                            Text("\(Int(score * 100))")
                                .font(Theme.Typography.timer)
                                .foregroundStyle(scoreColor(score))

                            Text("%")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(scoreColor(score).opacity(Theme.Opacity.half))
                        }

                        Text("Session Response")
                            .font(Theme.Typography.small)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.Colors.textTertiary)

                        if let insight = impactInsight {
                            Text(insight)
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                        }

                        impactSparkline
                    } else {
                        // Empty state with icon
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

    fileprivate var sparklineData: [Double] {
        let real = scoredSessions.suffix(10).compactMap(\.biometricSuccessScore)
        return real.isEmpty ? Theme.Health.Seed.sparkline : real
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

    // MARK: - Section 2: Schedule

    fileprivate var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Your Day")

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                    )

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if !calendarAuthorized {
                        // Permission request
                        calendarPermissionPrompt
                    } else if todaysEvents.isEmpty {
                        // Free day
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                                .foregroundStyle(Theme.Colors.signalCalm)

                            Text("Your calendar is clear today")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    } else {
                        // Today's timeline
                        ForEach(todaysEvents) { event in
                            scheduleRow(event: event)

                            if event.id != todaysEvents.last?.id {
                                Rectangle()
                                    .fill(Theme.Colors.divider.opacity(Theme.Opacity.half))
                                    .frame(height: Theme.Radius.glassStroke)
                            }
                        }

                        // Next free window suggestion
                        if let window = nextFreeWindow {
                            freeWindowSuggestion(window: window)
                        }
                    }
                }
                .padding(Theme.Spacing.xxl)
            }
        }
    }

    fileprivate var calendarPermissionPrompt: some View {
        Button {
            Task {
                calendarAuthorized = await dependencies.calendarService.requestAccess()
                if calendarAuthorized {
                    await loadCalendarData()
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "calendar")
                    .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.accent)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Connect Calendar")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Find the best time for sessions")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    fileprivate func scheduleRow(event: CalendarEvent) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Time indicator
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(event.isBioNauralSession ? Theme.Colors.accent : Theme.Colors.textTertiary)
                .frame(width: Theme.Spacing.xxs, height: Theme.Spacing.xxxl)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(event.title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    if !event.isAllDay {
                        Text("\(event.durationMinutes) min")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if event.isBioNauralSession {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: Theme.Typography.Size.body))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    fileprivate func freeWindowSuggestion(window: DateInterval) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Free at \(window.start.formatted(date: .omitted, time: .shortened))")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Perfect for a session")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.half))
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Section 3: Trend Cards

    fileprivate var trendCards: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Trends")

            HStack(spacing: Theme.Spacing.md) {
                trendCard(
                    icon: "heart.fill",
                    label: "RESTING HR",
                    value: "\(Int(restingHR ?? Theme.Health.Defaults.restingHR))",
                    unit: "BPM",
                    current: restingHR ?? Theme.Health.Defaults.restingHR,
                    average: avgRestingHR ?? Theme.Health.Defaults.restingHR,
                    lowerIsGood: true,
                    color: Theme.Colors.signalCalm
                )

                trendCard(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(hrv ?? Theme.Health.Defaults.hrv))",
                    unit: "ms",
                    current: hrv ?? Theme.Health.Defaults.hrv,
                    average: avgHRV ?? Theme.Health.Defaults.hrv,
                    lowerIsGood: false,
                    color: Theme.Colors.accent
                )
            }
        }
    }

    fileprivate func trendCard(
        icon: String,
        label: String,
        value: String,
        unit: String,
        current: Double,
        average: Double,
        lowerIsGood: Bool,
        color: Color
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )

            // Subtle color glow
            RadialGradient(
                colors: [color.opacity(Theme.Opacity.light), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(color.opacity(Theme.Opacity.half))

                // Label
                Text(label)
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .foregroundStyle(Theme.Colors.textTertiary)

                // Value
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                    Text(value)
                        .font(Theme.Typography.data)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(unit)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // Trend arrow
                let delta = current - average
                let isPositive = lowerIsGood ? delta < 0 : delta > 0
                if abs(delta) > Theme.Health.trendDeltaThreshold {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: delta < 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: Theme.Typography.Size.small, weight: .semibold))

                        Text("\(Int(abs(delta))) vs avg")
                            .font(Theme.Typography.small)
                    }
                    .foregroundStyle(isPositive ? Theme.Colors.signalCalm : Theme.Colors.signalElevated)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 4: Sleep

    fileprivate var sleepSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Last Night")

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                    )

                RadialGradient(
                    colors: [Theme.Colors.sleep.opacity(Theme.Opacity.light), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Icon
                    Image(systemName: "moon.fill")
                        .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(Theme.Colors.sleep.opacity(Theme.Opacity.half))

                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text(String(format: "%.1f", sleepData?.hours ?? Theme.Health.Defaults.sleepHours))
                            .font(Theme.Typography.data)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("hrs")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Spacer()

                        if let deep = sleepData?.deepSleepMinutes, deep > 0 {
                            HStack(spacing: Theme.Spacing.xxs) {
                                Text("\(Int(deep / 60))h \(Int(deep.truncatingRemainder(dividingBy: 60)))m")
                                    .font(Theme.Typography.dataSmall)
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                Text("deep")
                                    .font(Theme.Typography.small)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }
                    }

                    // Sleep stage bar
                    if let stages = sleepData?.stages, !stages.isEmpty {
                        sleepStageBar(stages: stages)

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

    fileprivate func sleepStageBar(stages: [SleepStage]) -> some View {
        let total = stages.reduce(0) { $0 + $1.duration }
        return GeometryReader { geo in
            if total > 0 {
                HStack(spacing: Theme.Health.stageBarSpacing) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                        let fraction = stage.duration / total
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(stageColor(stage.stage))
                            .frame(width: max(geo.size.width * fraction - Theme.Health.stageBarSpacing, Theme.Health.stageBarMinSegmentWidth))
                    }
                }
            }
        }
        .frame(height: Theme.Spacing.md)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    fileprivate func stageColor(_ stage: SleepStage.Stage) -> Color {
        switch stage {
        case .deep:  return Theme.Colors.sleep
        case .core:  return Theme.Colors.accent
        case .rem:   return Theme.Colors.focus
        case .awake: return Theme.Colors.textTertiary
        }
    }

    // MARK: - Section 5: Today's Vitals

    fileprivate var vitalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Today")

            // Zero spacing: rows manage their own internal padding
            VStack(spacing: 0) {
                vitalRow(
                    icon: "figure.walk",
                    label: "Steps",
                    value: steps.map { "\($0.formatted())" } ?? "0",
                    color: Theme.Colors.accent
                )

                vitalDivider

                vitalRow(
                    icon: "flame.fill",
                    label: "Active Energy",
                    value: "\(Int(activeEnergy ?? 0)) kcal",
                    color: Theme.Colors.energize
                )

                if let spo2 = spo2 {
                    vitalDivider

                    vitalRow(
                        icon: "lungs.fill",
                        label: "Blood Oxygen",
                        value: "\(Int(spo2 * 100))%",
                        color: Theme.Colors.signalCalm
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                    )
            )
        }
    }

    fileprivate var vitalDivider: some View {
        Rectangle()
            .fill(Theme.Colors.divider.opacity(Theme.Opacity.half))
            .frame(height: Theme.Radius.glassStroke)
    }

    fileprivate func vitalRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                .foregroundStyle(color)
                .frame(width: Theme.Spacing.xxxl)

            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Section 6: Event-Health Timeline

    fileprivate var eventHealthTimelineSection: some View {
        EventHealthTimelineView()
    }

    // MARK: - Section 7: Predictive Forecast

    fileprivate func forecastSection(_ forecast: HealthForecast) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Upcoming")
            PredictiveHealthForecastCard(forecast: forecast)
        }
    }

    // MARK: - Section 8: Post-Event Impacts

    fileprivate var postEventSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Recent Events")

            ForEach(recentImpacts.prefix(Constants.Insights.maxImpactCards)) { impact in
                PostEventImpactCard(impact: impact)
            }
        }
    }

    // MARK: - Section 9: Life Event Halo

    fileprivate func lifeEventSection(_ lifeEvent: LifeEvent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Life Event")
            LifeEventHaloView(event: lifeEvent)
        }
    }

    // MARK: - Section 10: Weekly Digest

    fileprivate func weeklyDigestSection(_ digest: WeeklyDigest) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("This Week")
            WeeklyCorrelationDigestView(digest: digest)
        }
    }

    // MARK: - Section 11: Weather Context

    fileprivate func weatherSection(_ insight: WeatherInsight) -> some View {
        WeatherHealthCard(insight: insight)
    }

    // MARK: - Section 12: Journal Correlations

    fileprivate var journalSection: some View {
        JournalCorrelationCard(correlations: journalCorrelations)
    }
}

// MARK: - Data Loading

extension HealthView {

    /// Polls health data on a loop — live HR updates when Watch is streaming.
    fileprivate func refreshLoop() async {
        calendarAuthorized = dependencies.calendarService.isAuthorized
        await loadHealthData()
        if calendarAuthorized {
            await loadCalendarData()
            await loadCorrelationData()
        }
        // Spotlight indexing deferred — sessions are indexed at session end
        // via SessionOutcomeRecorder, not during HealthView refresh.
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Theme.Animation.Duration.healthRefreshInterval))
            await loadHealthData()
        }
    }

    fileprivate func loadCalendarData() async {
        todaysEvents = await dependencies.calendarService.todaysEvents()
        nextFreeWindow = await dependencies.calendarService.nextFreeWindow(
            minimumMinutes: Theme.SF2.NeutralBiometrics.defaultSessionMinutes
        )
    }

    /// Loads calendar-health correlation data: post-event impacts, forecasts,
    /// weekly digest, and life event halos. Runs once per session (not polled).
    fileprivate func loadCorrelationData() async {
        let patterns = await dependencies.calendarPatternLearner.analyzePatterns()
        let events = todaysEvents
        let now = Date()
        let baseline = restingHR ?? Theme.Health.Defaults.restingHR

        await loadPostEventImpacts(events: events, patterns: patterns, now: now, baseline: baseline)
        await loadForecasts(events: events, patterns: patterns, now: now)
        await buildWeeklyDigest(baseline: baseline)
        await detectLifeEvent(baseline: baseline)
        await loadWeatherInsight()
        await loadJournalCorrelations()
    }

    /// Builds post-event impact cards for today's completed events.
    fileprivate func loadPostEventImpacts(
        events: [CalendarEvent],
        patterns: [CalendarPattern],
        now: Date,
        baseline: Double
    ) async {
        var impacts: [EventImpact] = []

        for event in events where event.endDate < now && !event.isBioNauralSession && !event.isAllDay {
            let hrHistory = await dependencies.healthKitService.heartRateHistory(hours: Constants.Insights.hrHistoryLookbackHours)
            let sparkline = hrHistory?.suffix(Constants.Insights.sparklinePointCount).map(\.bpm)

            // Compute HR delta: average HR during event window vs baseline
            let eventSamples = hrHistory?.filter {
                $0.date >= event.startDate && $0.date <= event.endDate
            } ?? []
            let avgEventHR = eventSamples.isEmpty ? baseline : eventSamples.map(\.bpm).reduce(0, +) / Double(eventSamples.count)
            let delta = Int((avgEventHR - baseline).rounded())

            let matchingPattern = patterns.first { pattern in
                event.title.lowercased().contains(
                    pattern.condition.replacingOccurrences(of: "events_with_", with: "")
                )
            }

            impacts.append(EventImpact(
                id: event.id,
                eventTitle: event.title,
                eventDate: event.startDate,
                stressLevel: matchingPattern?.suggestedAction.contains("relaxation") == true ? "high" : "moderate",
                hrDeltaBPM: delta,
                hrvDeltaMS: nil,
                recoveryMinutes: nil,
                comparisonToAverage: nil,
                miniSparkline: sparkline
            ))
        }
        recentImpacts = impacts
    }

    /// Builds a predictive forecast for the next upcoming stressor.
    fileprivate func loadForecasts(
        events: [CalendarEvent],
        patterns: [CalendarPattern],
        now: Date
    ) async {
        let upcomingStressors = events.filter { $0.startDate > now && !$0.isAllDay }
        guard let nextStressor = upcomingStressors.first else { return }

        let prep = await dependencies.calendarPatternLearner.bestPrepAction(
            for: nextStressor.title,
            existingPatterns: patterns
        )

        let matchingPatterns = patterns.filter { pattern in
            nextStressor.title.lowercased().contains(
                pattern.condition.replacingOccurrences(of: "events_with_", with: "")
            )
        }

        guard !matchingPatterns.isEmpty else { return }

        var predictions: [ForecastPrediction] = []

        for pattern in matchingPatterns.prefix(Constants.Insights.maxForecastPatterns) {
            if pattern.observation.contains("hr_spike") {
                predictions.append(ForecastPrediction(
                    id: "hr_\(pattern.id)",
                    metric: "Resting HR",
                    icon: "heart.fill",
                    delta: "+\(Int(PatternConfig.hrSpikeThreshold)) bpm",
                    timing: "before event",
                    isNegative: true
                ))
            } else if pattern.observation.contains("poor_sleep") {
                predictions.append(ForecastPrediction(
                    id: "sleep_\(pattern.id)",
                    metric: "Sleep Quality",
                    icon: "moon.fill",
                    delta: "below avg",
                    timing: "night before",
                    isNegative: true
                ))
            }
        }

        guard !predictions.isEmpty else { return }

        activeForecast = HealthForecast(
            id: nextStressor.id,
            eventTitle: nextStressor.title,
            eventDate: nextStressor.startDate,
            stressLevel: "high",
            predictions: predictions,
            sampleCount: matchingPatterns.first?.sampleCount ?? 0,
            suggestedPrepMode: prep?.mode,
            suggestedPrepMinutes: prep?.durationMinutes,
            confidence: matchingPatterns.first?.strength ?? 0
        )
    }

    /// Loads weather context and builds insight text.
    fileprivate func loadWeatherInsight() async {
        guard let weather = await dependencies.weatherService.currentWeather() else { return }

        let pressureDelta = await dependencies.weatherService.pressureChangeFromYesterday()
        let insightText: String? = {
            guard let delta = pressureDelta else { return nil }
            if delta < -WeatherConfig.pressureChangeDeltaThreshold {
                return "Pressure dropping — your HRV may be lower today"
            } else if delta > WeatherConfig.pressureChangeDeltaThreshold {
                return "Rising pressure — good conditions for Focus"
            }
            return nil
        }()
        weatherInsight = WeatherInsight(
            current: weather,
            pressureDelta: pressureDelta,
            insightText: insightText,
            isPositiveForSession: pressureDelta.map { $0 > 0 }
        )
    }

    /// Loads journal activity correlations.
    fileprivate func loadJournalCorrelations() async {
        let activities = await dependencies.journalService.recentActivities()
        guard !activities.isEmpty else { return }

        // Group activities by type and build simple correlations
        let grouped = Dictionary(grouping: activities, by: \.activityType)
        var correlations: [JournalCorrelation] = []

        for (type, items) in grouped.prefix(Constants.Insights.maxImpactCards) {
            let mostRecent = items.sorted(by: { $0.date > $1.date }).first
            correlations.append(JournalCorrelation(
                id: type.rawValue,
                activityType: type,
                activityTitle: mostRecent?.title ?? type.rawValue.capitalized,
                correlationText: "\(items.count) this week",
                sampleCount: items.count,
                isPositive: true
            ))
        }
        journalCorrelations = correlations
    }

    /// Builds the weekly digest by scoring this week's calendar events against
    /// heart rate data and ranking them by physiological impact.
    fileprivate func buildWeeklyDigest(baseline: Double) async {
        let calendar = Calendar.current
        let now = Date()

        // Week start: most recent Monday (or Sunday depending on locale)
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) else { return }

        let weekEvents = await dependencies.calendarService.events(from: weekStart, to: now)

        // Filter to non-BioNaural, non-all-day, completed events
        let scorableEvents = weekEvents.filter {
            !$0.isBioNauralSession && !$0.isAllDay && $0.endDate < now
        }

        guard !scorableEvents.isEmpty else { return }

        // Fetch HR history covering the full week
        let weekHoursElapsed = max(1, Int(now.timeIntervalSince(weekStart) / 3600))
        let hrHistory = await dependencies.healthKitService.heartRateHistory(
            hours: min(weekHoursElapsed, Constants.Insights.lifeEventHRHistoryHours)
        )

        // Score each event by HR delta vs baseline
        struct ScoredEvent {
            let event: CalendarEvent
            let hrDelta: Double
            let impactScore: Double
        }

        var scored: [ScoredEvent] = []
        var dayDeltas: [String: [Double]] = [:] // weekday name -> deltas

        for event in scorableEvents {
            let eventSamples = hrHistory?.filter {
                $0.date >= event.startDate && $0.date <= event.endDate
            } ?? []

            let avgEventHR = eventSamples.isEmpty
                ? baseline
                : eventSamples.map(\.bpm).reduce(0, +) / Double(eventSamples.count)
            let delta = avgEventHR - baseline
            let normalizedScore = min(
                max(delta / Constants.Insights.impactScoreNormalizationCeiling, 0),
                1.0
            )

            scored.append(ScoredEvent(
                event: event,
                hrDelta: delta,
                impactScore: normalizedScore
            ))

            // Track deltas per weekday for best/hardest day
            let dayName = event.startDate.formatted(.dateTime.weekday(.wide))
            dayDeltas[dayName, default: []].append(delta)
        }

        // Rank by impact score descending, take top N
        let ranked = scored
            .sorted { $0.impactScore > $1.impactScore }
            .prefix(Constants.Insights.weeklyDigestMaxEvents)

        var rankedImpacts: [RankedEventImpact] = []
        for (index, item) in ranked.enumerated() {
            let level: RankedEventImpact.ImpactLevel = {
                if item.hrDelta >= Constants.Insights.criticalStressHRDelta { return .critical }
                if item.hrDelta >= Constants.Insights.highStressHRDelta { return .high }
                if item.hrDelta >= Constants.Insights.moderateStressHRDelta { return .moderate }
                return .low
            }()

            let sign = item.hrDelta >= 0 ? "+" : ""
            let primaryMetric = "HR \(sign)\(Int(item.hrDelta.rounded())) bpm during event"

            rankedImpacts.append(RankedEventImpact(
                id: item.event.id,
                rank: index + 1,
                eventTitle: item.event.title,
                eventDate: item.event.startDate,
                impactScore: item.impactScore,
                primaryMetric: primaryMetric,
                secondaryMetric: item.event.durationMinutes > 0
                    ? "\(item.event.durationMinutes) min event"
                    : nil,
                stressLevel: level
            ))
        }

        // Compute per-day averages for best/hardest
        let dayAverages = dayDeltas.mapValues { deltas in
            deltas.reduce(0, +) / Double(deltas.count)
        }
        let bestDay = dayAverages.min(by: { $0.value < $1.value })?.key ?? "N/A"
        let hardestDay = dayAverages.max(by: { $0.value < $1.value })?.key ?? "N/A"

        let highStressCount = scored.filter {
            $0.hrDelta >= Constants.Insights.highStressHRDelta
        }.count

        let avgDelta = scored.isEmpty
            ? 0
            : scored.map(\.hrDelta).reduce(0, +) / Double(scored.count)

        let summary = WeekSummary(
            totalEvents: scorableEvents.count,
            highStressCount: highStressCount,
            averageHRDelta: max(avgDelta, 0),
            bestDay: bestDay,
            hardestDay: hardestDay
        )

        weeklyDigest = WeeklyDigest(
            weekStartDate: weekStart,
            weekEndDate: now,
            rankedEvents: rankedImpacts,
            weekSummary: summary
        )
    }

    /// Detects life events from the calendar by looking for all-day events,
    /// multi-day events, or events with significant keywords in a 7-day
    /// window centered on today.
    fileprivate func detectLifeEvent(baseline: Double) async {
        let calendar = Calendar.current
        let now = Date()
        let radius = Constants.Insights.lifeEventScanDaysRadius

        guard let scanStart = calendar.date(byAdding: .day, value: -radius, to: now),
              let scanEnd = calendar.date(byAdding: .day, value: radius, to: now)
        else { return }

        let scanEvents = await dependencies.calendarService.events(from: scanStart, to: scanEnd)

        // Find candidate life events: all-day, multi-day, or keyword matches
        struct Candidate {
            let event: CalendarEvent
            let category: LifeEventCategory
        }

        var candidates: [Candidate] = []

        for event in scanEvents where !event.isBioNauralSession {
            // Check for all-day or multi-day events
            let isMultiDay = !calendar.isDate(event.startDate, inSameDayAs: event.endDate)

            if event.isAllDay || isMultiDay {
                // Try to detect category from title keywords
                let category = categoryFromTitle(event.title) ?? .transition
                candidates.append(Candidate(event: event, category: category))
                continue
            }

            // Check title for life event keywords
            if let category = categoryFromTitle(event.title) {
                candidates.append(Candidate(event: event, category: category))
            }
        }

        // Pick the most relevant candidate: prefer closest to today
        guard let best = candidates.min(by: {
            abs($0.event.startDate.timeIntervalSince(now)) <
            abs($1.event.startDate.timeIntervalSince(now))
        }) else { return }

        // Build halo data: 7 days centered on the event
        let eventDate = best.event.startDate
        let hrHistory = await dependencies.healthKitService.heartRateHistory(
            hours: Constants.Insights.lifeEventHRHistoryHours
        )

        var haloData: [HaloDayData] = []

        for offset in -radius...radius {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: eventDate)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else { continue }

            // Filter HR samples for this specific day
            let daySamples = hrHistory?.filter {
                $0.date >= dayStart && $0.date < dayEnd
            } ?? []

            let dayAvgHR: Double? = daySamples.isEmpty
                ? nil
                : daySamples.map(\.bpm).reduce(0, +) / Double(daySamples.count)

            // Query HRV and sleep via multi-day averages as approximation
            // (protocol only offers averageHRV/averageRestingHR for N days back)
            let dayHRV: Double? = await dependencies.healthKitService.latestHRV()
            let daySleep: Double? = await dependencies.healthKitService.lastNightSleep()?.hours

            // Compute stress level: normalized HR deviation from baseline (0-1)
            let stressLevel: Double = {
                guard let hr = dayAvgHR else { return 0 }
                let delta = hr - baseline
                return min(max(delta / Constants.Insights.impactScoreNormalizationCeiling, 0), 1.0)
            }()

            haloData.append(HaloDayData(
                id: "halo_\(best.event.id)_\(offset)",
                dayOffset: offset,
                restingHR: dayAvgHR,
                hrv: dayHRV,
                sleepHours: daySleep,
                stressLevel: stressLevel
            ))
        }

        activeLifeEvent = LifeEvent(
            id: best.event.id,
            title: best.event.title,
            eventDate: eventDate,
            category: best.category,
            haloData: haloData
        )
    }

    /// Matches a calendar event title against known life event keywords.
    fileprivate func categoryFromTitle(_ title: String) -> LifeEventCategory? {
        let lowered = title.lowercased()
        for (keyword, mapping) in Constants.Insights.lifeEventKeywords where lowered.contains(keyword) {
            return mapping.category
        }
        return nil
    }

    fileprivate func loadHealthData() async {
        let hk = dependencies.healthKitService

        if dependencies.isWatchConnected {
            restingHR = await hk.latestHeartRate()
        }
        if restingHR == nil { restingHR = await hk.latestRestingHR() }
        if restingHR == nil { restingHR = await hk.averageRestingHR(days: Theme.Health.fallbackLookbackDays) }
        if restingHR == nil { restingHR = Theme.Health.Defaults.restingHR }

        hrv = await hk.latestHRV()
        if hrv == nil { hrv = await hk.averageHRV(days: Theme.Health.fallbackLookbackDays) }
        if hrv == nil { hrv = Theme.Health.Defaults.hrv }

        avgRestingHR = await hk.averageRestingHR(days: dateRange.days)
        avgHRV = await hk.averageHRV(days: dateRange.days)

        sleepData = await hk.lastNightSleep()

        steps = await hk.stepsToday()
        activeEnergy = await hk.activeEnergyToday()
        spo2 = await hk.oxygenSaturation()
    }
}

// MARK: - Date Range

enum HealthDateRange: String, CaseIterable {
    case today
    case week
    case month

    var label: String {
        switch self {
        case .today: return "Today"
        case .week:  return "7 Days"
        case .month: return "30 Days"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar.day.timeline.left"
        case .week:  return "calendar"
        case .month: return "calendar.badge.clock"
        }
    }

    var days: Int {
        switch self {
        case .today: return 1
        case .week:  return 7
        case .month: return 30
        }
    }
}

// MARK: - Preview

#Preview("Health") {
    NavigationStack {
        HealthView()
    }
    .environment(AppDependencies())
    .preferredColorScheme(.dark)
}
