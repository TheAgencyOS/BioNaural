// MonthlySummaryGenerator.swift
// BioNaural
//
// Computes aggregated monthly statistics from SwiftData session history.
// Produces a MonthlySummary struct containing all data needed for the
// 4-card Monthly Neural Summary ("Wrapped") feature.
// All thresholds from configuration constants — no hardcoded values.

import Foundation
import SwiftData
import BioNauralShared

// MARK: - Configuration

/// Tuning constants for the monthly summary computation.
/// Centralized here so nothing is hardcoded at call sites.
enum MonthlySummaryConfig {
    /// Minimum sessions required to generate a full summary.
    static let minimumSessionsForFullSummary: Int = 3
    /// Number of top sounds to feature on the Sound Profile card.
    static let topSoundsCount: Int = 3
    /// Minimum biometric success score to qualify as a "best session."
    static let bestSessionThreshold: Double = 0.0
    /// Number of time-of-day buckets for circadian analysis.
    static let circadianBucketCount: Int = 4
    /// Hour boundaries for circadian buckets: morning, afternoon, evening, night.
    static let circadianBucketHours: [Int] = [6, 12, 17, 21]
    /// Labels for each circadian bucket.
    static let circadianBucketLabels: [String] = ["morning", "afternoon", "evening", "night"]
    /// Percentage threshold for declaring a circadian preference "surprising."
    static let circadianSignificanceThreshold: Double = 0.30
    /// Minimum HR/HRV data points to compute biometric trends.
    static let minimumBiometricDataPoints: Int = 3
}

// MARK: - MonthlySummary

/// All computed data needed by the 4 summary cards.
/// Pure value type — safe to pass between actors and views.
struct MonthlySummary: Sendable {

    // MARK: - Metadata

    let month: Date
    let monthDisplayName: String
    let hasEnoughData: Bool

    // MARK: - Card 1: Overview

    let totalSessions: Int
    let totalMinutes: Int
    let mostUsedMode: FocusMode?
    let mostUsedModeSessionCount: Int
    let sessionsPerWeekAverage: Double
    let modeDistribution: [ModeDistributionEntry]
    let completionRate: Double

    // MARK: - Card 2: Biometric Journey

    let weeklyHRTrend: [WeeklyBiometricPoint]
    let weeklyHRVTrend: [WeeklyBiometricPoint]
    let biometricHeadline: String?
    let bestSession: BestSessionHighlight?
    let averageBiometricScore: Double?

    // MARK: - Card 3: Sound Profile

    let topSounds: [TopSoundEntry]
    let instrumentBreakdown: [InstrumentBreakdownEntry]
    let soundInsight: String?

    // MARK: - Card 4: Insight

    let primaryInsight: InsightFinding?
    let compositeAdaptationEvents: [CompositeAdaptationEntry]
}

// MARK: - Supporting Types

struct ModeDistributionEntry: Identifiable, Sendable {
    var id: String { mode.rawValue }
    let mode: FocusMode
    let sessionCount: Int
    let fraction: Double
}

struct WeeklyBiometricPoint: Identifiable, Sendable {
    let id: Int
    let weekLabel: String
    let value: Double
}

struct BestSessionHighlight: Sendable {
    let sessionDate: Date
    let mode: FocusMode
    let durationMinutes: Int
    let biometricScore: Double
    let averageHR: Double?
}

struct TopSoundEntry: Identifiable, Sendable {
    var id: String { soundID }
    let soundID: String
    let averageBiometricScore: Double
    let sessionCount: Int
}

struct InstrumentBreakdownEntry: Identifiable, Sendable {
    var id: String { instrument }
    let instrument: String
    let fraction: Double
    let sessionCount: Int
}

struct InsightFinding: Sendable {
    let headline: String
    let detail: String
    let iconName: String
}

struct CompositeAdaptationEntry: Sendable {
    let sessionDate: Date
    let mode: FocusMode
    let events: [AdaptationEventRecord]
    let sessionDuration: TimeInterval
}

// MARK: - MonthlySummaryGenerator

@MainActor
struct MonthlySummaryGenerator {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    func generate(for month: Date) -> MonthlySummary {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return makeInsufficientDataSummary(month: month)
        }

        let sessions = fetchSessions(from: monthStart, to: monthEnd)
        guard sessions.count >= MonthlySummaryConfig.minimumSessionsForFullSummary else {
            return makeInsufficientDataSummary(
                month: month,
                sessionCount: sessions.count,
                totalMinutes: sessions.reduce(0) { $0 + $1.durationSeconds } / 60
            )
        }

        let monthDisplayName = monthStart.formatted(.dateTime.month(.wide).year())

        // Card 1: Overview
        let totalSessions = sessions.count
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        let modeDistribution = computeModeDistribution(sessions: sessions)
        let mostUsedEntry = modeDistribution.max(by: { $0.sessionCount < $1.sessionCount })
        let weeksInMonth = Double(calendar.range(of: .weekOfMonth, in: .month, for: monthStart)?.count ?? 4)
        let sessionsPerWeek = Double(totalSessions) / max(weeksInMonth, 1.0)
        let completedCount = sessions.filter(\.wasCompleted).count
        let completionRate = Double(completedCount) / Double(max(totalSessions, 1))

        // Card 2: Biometric Journey
        let weeklyHR = computeWeeklyBiometricTrend(
            sessions: sessions,
            monthStart: monthStart,
            keyPath: \.averageHeartRate
        )
        let weeklyHRV = computeWeeklyBiometricTrend(
            sessions: sessions,
            monthStart: monthStart,
            keyPath: \.averageHRV
        )
        let biometricHeadline = computeBiometricHeadline(
            sessions: sessions,
            weeklyHR: weeklyHR,
            weeklyHRV: weeklyHRV
        )
        let bestSession = computeBestSession(sessions: sessions)
        let scores = sessions.compactMap(\.biometricSuccessScore)
        let avgScore: Double? = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)

        // Card 3: Sound Profile
        let topSounds = computeTopSounds(sessions: sessions)
        let instrumentBreakdown = computeInstrumentBreakdown(sessions: sessions)
        let soundInsight = computeSoundInsight(
            sessions: sessions,
            instrumentBreakdown: instrumentBreakdown
        )

        // Card 4: Insight
        let primaryInsight = computePrimaryInsight(sessions: sessions)
        let compositeEvents = sessions.compactMap { session -> CompositeAdaptationEntry? in
            guard let mode = session.focusMode,
                  !session.adaptationEvents.isEmpty else { return nil }
            return CompositeAdaptationEntry(
                sessionDate: session.startDate,
                mode: mode,
                events: session.adaptationEvents,
                sessionDuration: session.duration
            )
        }

        return MonthlySummary(
            month: monthStart,
            monthDisplayName: monthDisplayName,
            hasEnoughData: true,
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            mostUsedMode: mostUsedEntry?.mode,
            mostUsedModeSessionCount: mostUsedEntry?.sessionCount ?? 0,
            sessionsPerWeekAverage: sessionsPerWeek,
            modeDistribution: modeDistribution,
            completionRate: completionRate,
            weeklyHRTrend: weeklyHR,
            weeklyHRVTrend: weeklyHRV,
            biometricHeadline: biometricHeadline,
            bestSession: bestSession,
            averageBiometricScore: avgScore,
            topSounds: topSounds,
            instrumentBreakdown: instrumentBreakdown,
            soundInsight: soundInsight,
            primaryInsight: primaryInsight,
            compositeAdaptationEvents: compositeEvents
        )
    }

    // MARK: - Data Fetching

    private func fetchSessions(from start: Date, to end: Date) -> [FocusSession] {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.startDate >= start && session.startDate < end
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        descriptor.fetchLimit = nil
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Card 1: Overview Computation

    private func computeModeDistribution(sessions: [FocusSession]) -> [ModeDistributionEntry] {
        var counts: [FocusMode: Int] = [:]
        for session in sessions {
            guard let mode = session.focusMode else { continue }
            counts[mode, default: 0] += 1
        }
        let total = max(sessions.count, 1)
        return counts.map { mode, count in
            ModeDistributionEntry(
                mode: mode,
                sessionCount: count,
                fraction: Double(count) / Double(total)
            )
        }
        .sorted { $0.sessionCount > $1.sessionCount }
    }

    // MARK: - Card 2: Biometric Journey Computation

    private func computeWeeklyBiometricTrend(
        sessions: [FocusSession],
        monthStart: Date,
        keyPath: KeyPath<FocusSession, Double?>
    ) -> [WeeklyBiometricPoint] {
        var weekBuckets: [Int: [Double]] = [:]
        for session in sessions {
            guard let value = session[keyPath: keyPath] else { continue }
            let weekOfMonth = calendar.component(.weekOfMonth, from: session.startDate)
            weekBuckets[weekOfMonth, default: []].append(value)
        }
        return weekBuckets
            .filter { !$0.value.isEmpty }
            .map { week, values in
                let avg = values.reduce(0, +) / Double(values.count)
                return WeeklyBiometricPoint(
                    id: week,
                    weekLabel: "W\(week)",
                    value: avg
                )
            }
            .sorted { $0.id < $1.id }
    }

    private func computeBiometricHeadline(
        sessions: [FocusSession],
        weeklyHR: [WeeklyBiometricPoint],
        weeklyHRV: [WeeklyBiometricPoint]
    ) -> String? {
        if weeklyHR.count >= MonthlySummaryConfig.minimumBiometricDataPoints,
           let first = weeklyHR.first,
           let last = weeklyHR.last {
            let delta = last.value - first.value
            let absDelta = abs(Int(delta))
            if absDelta > 0 {
                let direction = delta < 0 ? "dropped" : "rose"
                let mostUsedMode = sessions.compactMap(\.focusMode)
                    .reduce(into: [:]) { counts, mode in counts[mode, default: 0] += 1 }
                    .max(by: { $0.value < $1.value })?.key
                let modeLabel = mostUsedMode?.displayName ?? "Session"
                return "Your \(modeLabel) HR \(direction) \(absDelta) BPM"
            }
        }

        if weeklyHRV.count >= MonthlySummaryConfig.minimumBiometricDataPoints,
           let first = weeklyHRV.first,
           let last = weeklyHRV.last,
           first.value > 0 {
            let percentChange = ((last.value - first.value) / first.value) * 100
            let absPercent = abs(Int(percentChange))
            if absPercent > 0 {
                let direction = percentChange > 0 ? "improved" : "declined"
                return "Your Relaxation HRV \(direction) \(absPercent)%"
            }
        }

        return nil
    }

    private func computeBestSession(sessions: [FocusSession]) -> BestSessionHighlight? {
        let scored = sessions.filter {
            ($0.biometricSuccessScore ?? 0) > MonthlySummaryConfig.bestSessionThreshold
        }
        guard let best = scored.max(by: {
            ($0.biometricSuccessScore ?? 0) < ($1.biometricSuccessScore ?? 0)
        }) else { return nil }

        return BestSessionHighlight(
            sessionDate: best.startDate,
            mode: best.focusMode ?? .focus,
            durationMinutes: best.durationSeconds / 60,
            biometricScore: best.biometricSuccessScore ?? 0,
            averageHR: best.averageHeartRate
        )
    }

    // MARK: - Card 3: Sound Profile Computation

    private func computeTopSounds(sessions: [FocusSession]) -> [TopSoundEntry] {
        var soundScores: [String: (totalScore: Double, count: Int)] = [:]
        for session in sessions {
            let score = session.biometricSuccessScore ?? 0
            for soundID in session.melodicLayerIDs {
                let existing = soundScores[soundID, default: (totalScore: 0, count: 0)]
                soundScores[soundID] = (
                    totalScore: existing.totalScore + score,
                    count: existing.count + 1
                )
            }
        }
        return soundScores
            .map { soundID, data in
                TopSoundEntry(
                    soundID: soundID,
                    averageBiometricScore: data.totalScore / Double(max(data.count, 1)),
                    sessionCount: data.count
                )
            }
            .sorted { $0.averageBiometricScore > $1.averageBiometricScore }
            .prefix(MonthlySummaryConfig.topSoundsCount)
            .map { $0 }
    }

    private func computeInstrumentBreakdown(sessions: [FocusSession]) -> [InstrumentBreakdownEntry] {
        var instrumentCounts: [String: Int] = [:]
        var totalSounds = 0

        for session in sessions {
            for soundID in session.melodicLayerIDs {
                let instrument = extractInstrumentFromSoundID(soundID)
                instrumentCounts[instrument, default: 0] += 1
                totalSounds += 1
            }
        }

        guard totalSounds > 0 else { return [] }

        return instrumentCounts
            .map { instrument, count in
                InstrumentBreakdownEntry(
                    instrument: instrument,
                    fraction: Double(count) / Double(totalSounds),
                    sessionCount: count
                )
            }
            .sorted { $0.fraction > $1.fraction }
    }

    private func extractInstrumentFromSoundID(_ soundID: String) -> String {
        let components = soundID.split(separator: "-")
        guard let first = components.first else { return soundID }
        return String(first).capitalized
    }

    private func computeSoundInsight(
        sessions: [FocusSession],
        instrumentBreakdown: [InstrumentBreakdownEntry]
    ) -> String? {
        var modeInstrumentScores: [FocusMode: [String: (totalScore: Double, count: Int)]] = [:]

        for session in sessions {
            guard let mode = session.focusMode else { continue }
            let score = session.biometricSuccessScore ?? 0
            for soundID in session.melodicLayerIDs {
                let instrument = extractInstrumentFromSoundID(soundID)
                var modeScores = modeInstrumentScores[mode, default: [:]]
                let existing = modeScores[instrument, default: (totalScore: 0, count: 0)]
                modeScores[instrument] = (
                    totalScore: existing.totalScore + score,
                    count: existing.count + 1
                )
                modeInstrumentScores[mode] = modeScores
            }
        }

        var bestMode: FocusMode?
        var bestInstrument: String?
        var bestAvg: Double = 0

        for (mode, instruments) in modeInstrumentScores {
            for (instrument, data) in instruments {
                let avg = data.totalScore / Double(max(data.count, 1))
                if avg > bestAvg {
                    bestAvg = avg
                    bestMode = mode
                    bestInstrument = instrument
                }
            }
        }

        guard let mode = bestMode, let instrument = bestInstrument else { return nil }
        return "You respond best to \(instrument.lowercased()) during \(mode.displayName)"
    }

    // MARK: - Card 4: Insight Computation

    private func computePrimaryInsight(sessions: [FocusSession]) -> InsightFinding? {
        if let circadianInsight = analyzeCircadianPattern(sessions: sessions) {
            return circadianInsight
        }
        if let dayInsight = analyzeDayOfWeekPattern(sessions: sessions) {
            return dayInsight
        }
        if let ambientInsight = analyzeAmbientPreference(sessions: sessions) {
            return ambientInsight
        }
        return nil
    }

    private func analyzeCircadianPattern(sessions: [FocusSession]) -> InsightFinding? {
        let bucketHours = MonthlySummaryConfig.circadianBucketHours
        let bucketLabels = MonthlySummaryConfig.circadianBucketLabels

        var bucketScores: [Int: [Double]] = [:]
        for session in sessions {
            guard let score = session.biometricSuccessScore else { continue }
            let hour = calendar.component(.hour, from: session.startDate)
            let bucketIndex = circadianBucket(for: hour)
            bucketScores[bucketIndex, default: []].append(score)
        }

        guard bucketScores.count >= 2 else { return nil }

        let bucketAverages = bucketScores.mapValues { scores in
            scores.reduce(0, +) / Double(max(scores.count, 1))
        }

        guard let bestBucket = bucketAverages.max(by: { $0.value < $1.value }),
              let worstBucket = bucketAverages.min(by: { $0.value < $1.value }) else { return nil }

        let delta = bestBucket.value - worstBucket.value
        guard delta >= MonthlySummaryConfig.circadianSignificanceThreshold else { return nil }

        let percentBetter = Int(delta * 100)
        let timeLabel = bucketLabels[bestBucket.key]

        let bestModeAtTime = sessions
            .filter { session in
                let hour = calendar.component(.hour, from: session.startDate)
                return circadianBucket(for: hour) == bestBucket.key
            }
            .compactMap(\.focusMode)
            .reduce(into: [:]) { counts, mode in counts[mode, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key

        let modeLabel = bestModeAtTime?.displayName.lowercased() ?? "focus"

        return InsightFinding(
            headline: "You \(modeLabel) \(percentBetter)% better in the \(timeLabel)",
            detail: "Sessions started in the \(timeLabel) consistently produced stronger biometric outcomes than other times of day.",
            iconName: "sun.and.horizon.fill"
        )
    }

    private func circadianBucket(for hour: Int) -> Int {
        let bucketHours = MonthlySummaryConfig.circadianBucketHours
        if hour < bucketHours[0] {
            return MonthlySummaryConfig.circadianBucketLabels.count - 1
        } else if hour < bucketHours[1] {
            return 0
        } else if hour < bucketHours[2] {
            return 1
        } else if hour < bucketHours[3] {
            return 2
        } else {
            return MonthlySummaryConfig.circadianBucketLabels.count - 1
        }
    }

    private func analyzeDayOfWeekPattern(sessions: [FocusSession]) -> InsightFinding? {
        var dayScores: [Int: [Double]] = [:]
        for session in sessions {
            guard let score = session.biometricSuccessScore else { continue }
            let weekday = calendar.component(.weekday, from: session.startDate)
            dayScores[weekday, default: []].append(score)
        }

        guard dayScores.count >= 3 else { return nil }

        let dayAverages = dayScores.mapValues { scores in
            scores.reduce(0, +) / Double(max(scores.count, 1))
        }

        guard let bestDay = dayAverages.max(by: { $0.value < $1.value }),
              let worstDay = dayAverages.min(by: { $0.value < $1.value }) else { return nil }

        let delta = bestDay.value - worstDay.value
        guard delta >= MonthlySummaryConfig.circadianSignificanceThreshold else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let dayName = formatter.weekdaySymbols[bestDay.key - 1]

        return InsightFinding(
            headline: "\(dayName)s are your power day",
            detail: "Your biometric scores on \(dayName)s were consistently higher than other days of the week.",
            iconName: "calendar.badge.checkmark"
        )
    }

    private func analyzeAmbientPreference(sessions: [FocusSession]) -> InsightFinding? {
        var ambientScores: [String: (totalScore: Double, count: Int)] = [:]

        for session in sessions {
            guard let bedID = session.ambientBedID,
                  let score = session.biometricSuccessScore else { continue }
            let existing = ambientScores[bedID, default: (totalScore: 0, count: 0)]
            ambientScores[bedID] = (
                totalScore: existing.totalScore + score,
                count: existing.count + 1
            )
        }

        guard let best = ambientScores.max(by: {
            $0.value.totalScore / Double(max($0.value.count, 1))
            < $1.value.totalScore / Double(max($1.value.count, 1))
        }) else { return nil }

        guard best.value.count >= 2 else { return nil }

        let bestMode = sessions
            .filter { $0.ambientBedID == best.key }
            .compactMap(\.focusMode)
            .reduce(into: [:]) { counts, mode in counts[mode, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key

        let ambientName = best.key
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let modeLabel = bestMode?.displayName.lowercased() ?? "session"

        return InsightFinding(
            headline: "\(ambientName) is your \(modeLabel) sound",
            detail: "When paired with \(ambientName.lowercased()), your sessions scored higher on average.",
            iconName: "ear.fill"
        )
    }

    // MARK: - Insufficient Data Fallback

    private func makeInsufficientDataSummary(
        month: Date,
        sessionCount: Int = 0,
        totalMinutes: Int = 0
    ) -> MonthlySummary {
        let components = calendar.dateComponents([.year, .month], from: month)
        let monthStart = calendar.date(from: components) ?? month
        let monthDisplayName = monthStart.formatted(.dateTime.month(.wide).year())

        return MonthlySummary(
            month: monthStart,
            monthDisplayName: monthDisplayName,
            hasEnoughData: false,
            totalSessions: sessionCount,
            totalMinutes: totalMinutes,
            mostUsedMode: nil,
            mostUsedModeSessionCount: 0,
            sessionsPerWeekAverage: 0,
            modeDistribution: [],
            completionRate: 0,
            weeklyHRTrend: [],
            weeklyHRVTrend: [],
            biometricHeadline: nil,
            bestSession: nil,
            averageBiometricScore: nil,
            topSounds: [],
            instrumentBreakdown: [],
            soundInsight: nil,
            primaryInsight: nil,
            compositeAdaptationEvents: []
        )
    }
}
