// CalendarPatternLearner.swift
// BioNaural
//
// Learns correlations between calendar events and biometric/session
// outcomes over time. Discovers patterns like "meetings with Client X
// cause HR spikes 15 min before" or "heavy meeting days degrade evening
// Focus performance." All processing is on-device.

import Foundation
import BioNauralShared
import OSLog
import SwiftData

// MARK: - CalendarPattern

/// A discovered correlation between a calendar condition and a biometric/session observation.
///
/// Patterns are learned over time by `CalendarPatternLearner` and stored
/// as JSON-encoded data in `CalendarPatternStore`. Each pattern carries a
/// strength score (0–1) that decays if not reinforced.
public struct CalendarPattern: Codable, Sendable, Identifiable {

    /// Composite identifier derived from the condition and observation.
    public var id: String { condition + "_" + observation }

    /// The calendar condition, e.g. "events_with_client".
    public let condition: String

    /// The biometric/session observation, e.g. "hr_spikes_15bpm_before".
    public let observation: String

    /// Correlation strength from 0 (no correlation) to 1 (very strong).
    public let strength: Double

    /// Number of event instances that contributed to this pattern.
    public let sampleCount: Int

    /// Recommended prep or recovery action, e.g. "relaxation_90min_before".
    public let suggestedAction: String

    /// When this pattern was last computed or reinforced.
    public let lastUpdated: Date

    public init(
        condition: String,
        observation: String,
        strength: Double,
        sampleCount: Int,
        suggestedAction: String,
        lastUpdated: Date
    ) {
        self.condition = condition
        self.observation = observation
        self.strength = strength
        self.sampleCount = sampleCount
        self.suggestedAction = suggestedAction
        self.lastUpdated = lastUpdated
    }
}

// MARK: - CalendarPatternStore (SwiftData)

/// SwiftData model that persists discovered `CalendarPattern` values as
/// a single JSON blob. This avoids complex relational schema for what is
/// essentially a cached analysis result.
@Model
public final class CalendarPatternStore {

    /// JSON-encoded `[CalendarPattern]`.
    public var patternsData: Data

    /// When the patterns were last recomputed.
    public var lastUpdated: Date

    public init(patternsData: Data = Data(), lastUpdated: Date = .distantPast) {
        self.patternsData = patternsData
        self.lastUpdated = lastUpdated
    }

    /// Replaces stored patterns with a new set.
    public func update(patterns: [CalendarPattern]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.patternsData = try encoder.encode(patterns)
        self.lastUpdated = Date()
    }

    /// Decodes the stored patterns from JSON.
    public func toPatterns() -> [CalendarPattern] {
        guard !patternsData.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([CalendarPattern].self, from: patternsData)
        } catch {
            Logger(subsystem: "com.bionaural", category: "CalendarPatternStore")
                .error("Failed to decode stored patterns: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - PatternConfig

/// All tuning constants for pattern learning. No hardcoded values at computation sites.
public enum PatternConfig {

    /// Minimum number of events sharing a keyword before a pattern is considered.
    static let minimumEventsForPattern: Int = 5

    /// Minimum correlation strength (0–1) for a pattern to be reported.
    static let minimumCorrelationStrength: Double = 0.3

    /// How many days of history to analyze.
    static let patternLookbackDays: Int = 60

    /// BPM above resting heart rate to qualify as a "spike."
    static let hrSpikeThreshold: Double = 10.0

    /// Sleep hours below this threshold count as poor sleep.
    static let poorSleepBeforeEventThreshold: Double = 6.0

    /// Events per day above this count as a "meeting-heavy" day.
    static let meetingDensityHighThreshold: Int = 5

    /// Minimum gap in minutes recommended between a prep session and the event.
    static let recoveryGapMinimumMinutes: Int = 90

    /// Percentage by which unreinforced pattern strength decays per cycle.
    static let decayFraction: Double = 0.10

    /// Days without reinforcement before decay is applied.
    static let decayGraceDays: Int = 30

    /// Minimum session score (0–1) to count as a "successful" session.
    static let successfulSessionThreshold: Double = 0.6

    /// Hours before an event within which a session is considered "pre-event."
    static let preEventWindowHours: Int = 3

    /// Hours after an event within which a session is considered "post-event."
    static let postEventWindowHours: Int = 3

    /// Default prep duration recommendation in minutes.
    static let defaultPrepDurationMinutes: Int = 20

    /// Default recovery duration recommendation in minutes.
    static let defaultRecoveryDurationMinutes: Int = 15

    /// Multiplier to scale a raw deficit (0-0.5 range) into a 0-1 strength score.
    static let deficitToStrengthMultiplier: Double = 2.0
}

// MARK: - Protocol

/// Pattern-learning interface for discovering correlations between
/// calendar events and biometric/session outcomes over time.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
public protocol CalendarPatternLearnerProtocol: AnyObject, Sendable {

    /// Runs the full pattern-discovery pipeline over the lookback window.
    func analyzePatterns() async -> [CalendarPattern]

    /// Returns the best preparation recommendation for an upcoming event
    /// based on known patterns.
    func bestPrepAction(
        for eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) async -> (mode: FocusMode, minutesBefore: Int, durationMinutes: Int)?

    /// Returns a recovery recommendation after a stressful event based on
    /// known patterns.
    func suggestedRecoveryAfter(
        eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) async -> (mode: FocusMode, durationMinutes: Int)?
}

// MARK: - CalendarPatternLearner

/// Analyzes historical calendar events alongside session outcomes and
/// biometric context to discover actionable patterns.
///
/// Thread safety is guaranteed by Swift's actor model — all mutable state
/// and analysis pipelines are serialized automatically.
public actor CalendarPatternLearner: CalendarPatternLearnerProtocol {

    // MARK: - Dependencies

    private let sessionStore: SessionStoreProtocol
    private let calendarService: CalendarServiceProtocol
    private let healthKitService: HealthKitServiceProtocol

    // MARK: - Initialization

    /// Creates a pattern learner with its required dependencies.
    ///
    /// - Parameters:
    ///   - sessionStore: Provides historical session outcomes.
    ///   - calendarService: Provides historical calendar events.
    ///   - healthKitService: Provides biometric context (resting HR, sleep).
    public init(
        sessionStore: SessionStoreProtocol,
        calendarService: CalendarServiceProtocol,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.sessionStore = sessionStore
        self.calendarService = calendarService
        self.healthKitService = healthKitService
    }

    // MARK: - Core Analysis Pipeline

    /// Runs the full pattern-discovery pipeline over the lookback window.
    ///
    /// 1. Fetches calendar events and session outcomes for the lookback period.
    /// 2. Extracts keywords from event titles and groups events by keyword.
    /// 3. For each keyword appearing in enough events, checks biometric and
    ///    session correlations (HR spikes, recovery speed, mode success rates,
    ///    sleep quality impact).
    /// 4. Checks day-level density patterns.
    /// 5. Returns patterns meeting `minimumCorrelationStrength`.
    ///
    /// Old patterns that are not reinforced within `decayGraceDays` have their
    /// strength reduced by `decayFraction`.
    public func analyzePatterns() async -> [CalendarPattern] {
        let calendar = Calendar.current
        let now = Date()

        guard let lookbackStart = calendar.date(
            byAdding: .day,
            value: -PatternConfig.patternLookbackDays,
            to: now
        ) else {
            return []
        }

        // Step 1: Fetch data
        let events = await calendarService.events(from: lookbackStart, to: now)
        let outcomes: [SessionOutcome]
        do {
            outcomes = try await sessionStore.outcomes(from: lookbackStart, to: now)
        } catch {
            return []
        }

        let restingHR = await healthKitService.latestRestingHR()
        let sleepData = await healthKitService.lastNightSleep()

        guard !events.isEmpty, !outcomes.isEmpty else { return [] }

        // Step 2: Group events by keyword
        let keywordGroups = groupEventsByKeyword(events)

        var patterns: [CalendarPattern] = []

        // Step 3: Per-keyword analysis
        for (keyword, keywordEvents) in keywordGroups {
            guard keywordEvents.count >= PatternConfig.minimumEventsForPattern else { continue }

            // 3a: HR spikes before events with this keyword
            if let hrPattern = analyzeHRSpikesBeforeEvents(
                keyword: keyword,
                events: keywordEvents,
                outcomes: outcomes,
                restingHR: restingHR,
                now: now
            ) {
                patterns.append(hrPattern)
            }

            // 3b: Recovery speed after events with this keyword
            if let recoveryPattern = analyzeRecoveryAfterEvents(
                keyword: keyword,
                events: keywordEvents,
                outcomes: outcomes,
                now: now
            ) {
                patterns.append(recoveryPattern)
            }

            // 3c: Best mode near events with this keyword
            if let modePattern = analyzeBestModeNearEvents(
                keyword: keyword,
                events: keywordEvents,
                outcomes: outcomes,
                now: now
            ) {
                patterns.append(modePattern)
            }

            // 3d: Sleep quality drop 1-2 days before events
            if let sleepPattern = analyzeSleepBeforeEvents(
                keyword: keyword,
                events: keywordEvents,
                sleepData: sleepData,
                now: now
            ) {
                patterns.append(sleepPattern)
            }
        }

        // Step 4: Day-level density patterns
        let densityPatterns = analyzeMeetingDensityPatterns(
            events: events,
            outcomes: outcomes,
            calendar: calendar,
            now: now
        )
        patterns.append(contentsOf: densityPatterns)

        // Step 5: Filter by minimum strength
        let qualifying = patterns.filter {
            $0.strength >= PatternConfig.minimumCorrelationStrength
        }

        return qualifying
    }

    // MARK: - Prep Recommendation

    /// Matches event title keywords against known patterns and returns
    /// the best preparation recommendation.
    ///
    /// - Parameters:
    ///   - eventTitle: The upcoming event's title.
    ///   - existingPatterns: Previously discovered patterns to match against.
    /// - Returns: A tuple of recommended mode, minutes before the event to start,
    ///   and session duration; or `nil` if no matching pattern exists.
    public func bestPrepAction(
        for eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) -> (mode: FocusMode, minutesBefore: Int, durationMinutes: Int)? {
        let titleKeywords = extractKeywords(from: eventTitle)

        // Find the strongest matching pattern that suggests a pre-event action.
        let matchingPatterns = existingPatterns.filter { pattern in
            let conditionKeywords = extractKeywords(from: pattern.condition)
            return !conditionKeywords.isDisjoint(with: titleKeywords)
                && pattern.suggestedAction.contains("before")
        }

        guard let strongest = matchingPatterns.max(by: { $0.strength < $1.strength }) else {
            return nil
        }

        let mode = parseModeFromAction(strongest.suggestedAction) ?? .relaxation
        let minutesBefore = parseMinutesFromAction(strongest.suggestedAction)
            ?? PatternConfig.recoveryGapMinimumMinutes
        let duration = PatternConfig.defaultPrepDurationMinutes

        return (mode: mode, minutesBefore: minutesBefore, durationMinutes: duration)
    }

    // MARK: - Recovery Recommendation

    /// Returns a recovery recommendation after a stressful event based on
    /// known patterns.
    ///
    /// - Parameters:
    ///   - eventTitle: The event that just ended.
    ///   - existingPatterns: Previously discovered patterns to match against.
    /// - Returns: A tuple of recommended mode and duration; or `nil` if no
    ///   matching pattern exists.
    public func suggestedRecoveryAfter(
        eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) -> (mode: FocusMode, durationMinutes: Int)? {
        let titleKeywords = extractKeywords(from: eventTitle)

        let matchingPatterns = existingPatterns.filter { pattern in
            let conditionKeywords = extractKeywords(from: pattern.condition)
            return !conditionKeywords.isDisjoint(with: titleKeywords)
                && pattern.suggestedAction.contains("after")
        }

        guard let strongest = matchingPatterns.max(by: { $0.strength < $1.strength }) else {
            return nil
        }

        let mode = parseModeFromAction(strongest.suggestedAction) ?? .relaxation
        let duration = PatternConfig.defaultRecoveryDurationMinutes

        return (mode: mode, durationMinutes: duration)
    }

    // MARK: - Keyword Extraction

    /// Extracts meaningful lowercase keywords from an event title,
    /// filtering out common stop words.
    private func extractKeywords(from text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to",
            "for", "of", "with", "by", "is", "are", "was", "be", "has",
            "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "shall", "can", "this", "that", "these", "those",
            "it", "its", "my", "your", "our", "their", "his", "her",
            "from", "into", "about", "up", "out", "no", "not", "so",
            "re", "vs", "meeting", "call", "sync"
        ]

        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopWords.contains($0) }

        return Set(words)
    }

    /// Groups calendar events by their extracted keywords. Each keyword maps
    /// to all events whose title contains that keyword.
    private func groupEventsByKeyword(_ events: [CalendarEvent]) -> [String: [CalendarEvent]] {
        var groups: [String: [CalendarEvent]] = [:]

        for event in events where !event.isBioNauralSession && !event.isAllDay {
            let keywords = extractKeywords(from: event.title)
            for keyword in keywords {
                groups[keyword, default: []].append(event)
            }
        }

        return groups
    }

    // MARK: - Per-Keyword Analyses

    /// Checks whether sessions before events containing `keyword` show
    /// elevated heart rate relative to resting.
    private func analyzeHRSpikesBeforeEvents(
        keyword: String,
        events: [CalendarEvent],
        outcomes: [SessionOutcome],
        restingHR: Double?,
        now: Date
    ) -> CalendarPattern? {
        guard let resting = restingHR else { return nil }

        let preEventWindow = TimeInterval(PatternConfig.preEventWindowHours * 3600)
        var spikeCount = 0
        var checkedCount = 0

        for event in events {
            let windowStart = event.startDate.addingTimeInterval(-preEventWindow)

            let nearbyOutcomes = outcomes.filter {
                $0.startDate >= windowStart && $0.startDate < event.startDate
            }

            for outcome in nearbyOutcomes {
                checkedCount += 1
                if let startHR = outcome.startingHR,
                   startHR - resting >= PatternConfig.hrSpikeThreshold {
                    spikeCount += 1
                }
            }
        }

        guard checkedCount >= PatternConfig.minimumEventsForPattern else { return nil }

        let strength = Double(spikeCount) / Double(checkedCount)

        return CalendarPattern(
            condition: "events_with_\(keyword)",
            observation: "hr_spikes_\(Int(PatternConfig.hrSpikeThreshold))bpm_before",
            strength: strength,
            sampleCount: checkedCount,
            suggestedAction: "relaxation_\(PatternConfig.recoveryGapMinimumMinutes)min_before",
            lastUpdated: now
        )
    }

    /// Checks whether sessions after events with `keyword` show faster
    /// biometric recovery (higher overall scores).
    private func analyzeRecoveryAfterEvents(
        keyword: String,
        events: [CalendarEvent],
        outcomes: [SessionOutcome],
        now: Date
    ) -> CalendarPattern? {
        let postEventWindow = TimeInterval(PatternConfig.postEventWindowHours * 3600)
        var postEventScores: [Double] = []
        var baselineScores: [Double] = []

        let eventIntervals = events.map {
            $0.endDate...$0.endDate.addingTimeInterval(postEventWindow)
        }

        for outcome in outcomes {
            let isPostEvent = eventIntervals.contains { $0.contains(outcome.startDate) }
            if isPostEvent {
                postEventScores.append(outcome.overallScore)
            } else {
                baselineScores.append(outcome.overallScore)
            }
        }

        guard postEventScores.count >= PatternConfig.minimumEventsForPattern,
              !baselineScores.isEmpty else {
            return nil
        }

        let postAvg = postEventScores.reduce(0, +) / Double(postEventScores.count)
        let baseAvg = baselineScores.reduce(0, +) / Double(baselineScores.count)

        // If post-event scores are noticeably lower, recovery sessions help.
        let deficit = max(0, baseAvg - postAvg)
        let strength = min(deficit * PatternConfig.deficitToStrengthMultiplier, 1.0)

        return CalendarPattern(
            condition: "events_with_\(keyword)",
            observation: "lower_session_scores_after",
            strength: strength,
            sampleCount: postEventScores.count,
            suggestedAction: "relaxation_session_after",
            lastUpdated: now
        )
    }

    /// Identifies which `FocusMode` has the highest success rate for sessions
    /// near events containing `keyword`.
    private func analyzeBestModeNearEvents(
        keyword: String,
        events: [CalendarEvent],
        outcomes: [SessionOutcome],
        now: Date
    ) -> CalendarPattern? {
        let windowSeconds = TimeInterval(PatternConfig.preEventWindowHours * 3600)

        var modeScores: [FocusMode: [Double]] = [:]

        for event in events {
            let windowStart = event.startDate.addingTimeInterval(-windowSeconds)
            let windowEnd = event.endDate.addingTimeInterval(windowSeconds)

            let nearbyOutcomes = outcomes.filter {
                $0.startDate >= windowStart && $0.endDate <= windowEnd
            }

            for outcome in nearbyOutcomes {
                modeScores[outcome.mode, default: []].append(outcome.overallScore)
            }
        }

        // Find the mode with the highest average score and enough samples.
        var bestMode: FocusMode?
        var bestAvg: Double = 0

        for (mode, scores) in modeScores {
            guard scores.count >= PatternConfig.minimumEventsForPattern else { continue }
            let avg = scores.reduce(0, +) / Double(scores.count)
            if avg > bestAvg {
                bestAvg = avg
                bestMode = mode
            }
        }

        guard let mode = bestMode else { return nil }

        return CalendarPattern(
            condition: "events_with_\(keyword)",
            observation: "best_mode_\(mode.rawValue)",
            strength: bestAvg,
            sampleCount: modeScores[mode]?.count ?? 0,
            suggestedAction: "\(mode.rawValue)_\(PatternConfig.recoveryGapMinimumMinutes)min_before",
            lastUpdated: now
        )
    }

    /// Checks whether sleep quality tends to drop 1–2 days before events
    /// containing `keyword`.
    ///
    /// Uses the HealthKit sleep data as a proxy. In a production system this
    /// would iterate over nightly sleep records; here we flag the pattern if
    /// current sleep is below threshold and such events are upcoming.
    private func analyzeSleepBeforeEvents(
        keyword: String,
        events: [CalendarEvent],
        sleepData: (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])?,
        now: Date
    ) -> CalendarPattern? {
        guard let sleep = sleepData else { return nil }

        // Count upcoming events (next 48 hours) with this keyword.
        let lookAhead: TimeInterval = 48 * 3600
        let upcomingCount = events.filter {
            $0.startDate > now && $0.startDate <= now.addingTimeInterval(lookAhead)
        }.count

        guard upcomingCount > 0,
              sleep.hours < PatternConfig.poorSleepBeforeEventThreshold else {
            return nil
        }

        // Strength scales with how far below threshold sleep was.
        let deficit = PatternConfig.poorSleepBeforeEventThreshold - sleep.hours
        let maxDeficit = PatternConfig.poorSleepBeforeEventThreshold
        let strength = min(deficit / maxDeficit, 1.0)

        return CalendarPattern(
            condition: "events_with_\(keyword)",
            observation: "poor_sleep_before",
            strength: strength,
            sampleCount: upcomingCount,
            suggestedAction: "sleep_session_evening_before",
            lastUpdated: now
        )
    }

    // MARK: - Day-Level Density Analysis

    /// Analyzes meeting-density patterns at the day level.
    ///
    /// Checks two things:
    /// - Days with many meetings: which mode works best that evening?
    /// - Meeting-heavy mornings: does afternoon Focus performance suffer?
    private func analyzeMeetingDensityPatterns(
        events: [CalendarEvent],
        outcomes: [SessionOutcome],
        calendar: Calendar,
        now: Date
    ) -> [CalendarPattern] {
        var patterns: [CalendarPattern] = []

        // Group events by calendar day.
        var eventsByDay: [DateComponents: [CalendarEvent]] = [:]
        for event in events where !event.isBioNauralSession && !event.isAllDay {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: event.startDate)
            eventsByDay[dayComponents, default: []].append(event)
        }

        // Identify high-density days.
        let highDensityDays = eventsByDay.filter {
            $0.value.count >= PatternConfig.meetingDensityHighThreshold
        }

        guard highDensityDays.count >= PatternConfig.minimumEventsForPattern else {
            return patterns
        }

        // 4a: Best evening mode on high-density days
        var eveningModeScores: [FocusMode: [Double]] = [:]

        for (dayComponents, _) in highDensityDays {
            guard let dayDate = calendar.date(from: dayComponents) else { continue }

            // "Evening" = after 17:00 on that day.
            var eveningComponents = dayComponents
            eveningComponents.hour = 17
            guard let eveningStart = calendar.date(from: eveningComponents) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate

            let eveningOutcomes = outcomes.filter {
                $0.startDate >= eveningStart && $0.startDate < dayEnd
            }

            for outcome in eveningOutcomes {
                eveningModeScores[outcome.mode, default: []].append(outcome.overallScore)
            }
        }

        // Find best evening mode.
        var bestEveningMode: FocusMode?
        var bestEveningAvg: Double = 0

        for (mode, scores) in eveningModeScores {
            guard scores.count >= PatternConfig.minimumEventsForPattern else { continue }
            let avg = scores.reduce(0, +) / Double(scores.count)
            if avg > bestEveningAvg {
                bestEveningAvg = avg
                bestEveningMode = mode
            }
        }

        if let mode = bestEveningMode {
            patterns.append(CalendarPattern(
                condition: "high_density_day_\(PatternConfig.meetingDensityHighThreshold)_plus",
                observation: "best_evening_mode_\(mode.rawValue)",
                strength: bestEveningAvg,
                sampleCount: eveningModeScores[mode]?.count ?? 0,
                suggestedAction: "\(mode.rawValue)_session_evening",
                lastUpdated: now
            ))
        }

        // 4b: Morning meeting density vs. afternoon Focus performance
        var heavyMorningFocusScores: [Double] = []
        var lightMorningFocusScores: [Double] = []

        for (dayComponents, dayEvents) in eventsByDay {
            guard let dayDate = calendar.date(from: dayComponents) else { continue }

            var noonComponents = dayComponents
            noonComponents.hour = 12
            guard let noon = calendar.date(from: noonComponents) else { continue }

            let morningEventCount = dayEvents.filter { $0.startDate < noon }.count

            // Afternoon Focus outcomes.
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate
            let afternoonFocus = outcomes.filter {
                $0.startDate >= noon && $0.startDate < dayEnd && $0.mode == .focus
            }

            let scores = afternoonFocus.map(\.overallScore)

            if morningEventCount >= PatternConfig.meetingDensityHighThreshold {
                heavyMorningFocusScores.append(contentsOf: scores)
            } else {
                lightMorningFocusScores.append(contentsOf: scores)
            }
        }

        if heavyMorningFocusScores.count >= PatternConfig.minimumEventsForPattern,
           !lightMorningFocusScores.isEmpty {
            let heavyAvg = heavyMorningFocusScores.reduce(0, +) / Double(heavyMorningFocusScores.count)
            let lightAvg = lightMorningFocusScores.reduce(0, +) / Double(lightMorningFocusScores.count)
            let deficit = max(0, lightAvg - heavyAvg)
            let strength = min(deficit * PatternConfig.deficitToStrengthMultiplier, 1.0)

            patterns.append(CalendarPattern(
                condition: "heavy_morning_meetings",
                observation: "afternoon_focus_degraded",
                strength: strength,
                sampleCount: heavyMorningFocusScores.count,
                suggestedAction: "relaxation_\(PatternConfig.recoveryGapMinimumMinutes)min_before_afternoon_focus",
                lastUpdated: now
            ))
        }

        return patterns
    }

    // MARK: - Pattern Decay

    /// Applies decay to patterns that have not been reinforced within
    /// `decayGraceDays`. Returns a new array with updated strengths;
    /// patterns that decay below `minimumCorrelationStrength` are removed.
    public func applyDecay(
        to existingPatterns: [CalendarPattern],
        reinforcedIDs: Set<String>,
        now: Date
    ) -> [CalendarPattern] {
        let calendar = Calendar.current
        let gracePeriod = calendar.date(
            byAdding: .day,
            value: -PatternConfig.decayGraceDays,
            to: now
        ) ?? now

        return existingPatterns.compactMap { pattern in
            // If this pattern was reinforced in the latest analysis, keep it.
            if reinforcedIDs.contains(pattern.id) {
                return pattern
            }

            // If last updated is within the grace period, keep unchanged.
            if pattern.lastUpdated >= gracePeriod {
                return pattern
            }

            // Apply decay.
            let decayedStrength = pattern.strength * (1.0 - PatternConfig.decayFraction)

            guard decayedStrength >= PatternConfig.minimumCorrelationStrength else {
                return nil // Pattern has decayed below threshold — remove it.
            }

            return CalendarPattern(
                condition: pattern.condition,
                observation: pattern.observation,
                strength: decayedStrength,
                sampleCount: pattern.sampleCount,
                suggestedAction: pattern.suggestedAction,
                lastUpdated: pattern.lastUpdated
            )
        }
    }

    // MARK: - Action String Parsing

    /// Parses a `FocusMode` from an action string like "relaxation_90min_before".
    private func parseModeFromAction(_ action: String) -> FocusMode? {
        let lowered = action.lowercased()
        for mode in FocusMode.allCases where lowered.contains(mode.rawValue) {
            return mode
        }
        return nil
    }

    /// Parses a minutes value from an action string like "relaxation_90min_before".
    /// Returns `nil` if no numeric + "min" pattern is found.
    private func parseMinutesFromAction(_ action: String) -> Int? {
        let pattern = #/(\d+)min/#
        guard let match = action.firstMatch(of: pattern) else { return nil }
        return Int(match.1)
    }
}
