// WatchLearningProfile.swift
// BioNauralWatch
//
// Codable struct persisted in UserDefaults. Tracks the user's session history
// for smart suggestions on the Watch. The learning stage drives suggestion
// confidence and UI affordances (dot indicator, title phrasing).

import Foundation
import BioNauralShared

// MARK: - LearningStage

/// Describes how much the app has learned about the user's patterns.
///
/// Thresholds are sourced from `WatchDesign.Learning`:
/// - `.coldStart`: fewer than `learningThreshold` sessions
/// - `.learning`: at least `learningThreshold` but fewer than `confidentThreshold`
/// - `.confident`: `confidentThreshold` or more sessions
enum LearningStage: Sendable {
    case coldStart
    case learning
    case confident
}

// MARK: - WatchLearningProfile

struct WatchLearningProfile: Codable, Sendable {

    // MARK: - Stored Properties

    var totalSessions: Int = 0
    /// FocusMode.rawValue -> session count.
    var sessionsByMode: [String: Int] = [:]
    /// FocusMode.rawValue -> average duration in seconds.
    var averageDurationByMode: [String: TimeInterval] = [:]
    /// Hour of day (0-23) -> session count.
    var sessionsByHourOfDay: [Int: Int] = [:]
    /// Day of week (1 = Sunday ... 7 = Saturday) -> session count.
    var sessionsByDayOfWeek: [Int: Int] = [:]
    /// Rolling window of resting HR samples (last 14 values).
    var restingHRHistory: [Double] = []
    var lastSessionDate: Date?
    var streakDays: Int = 0
    var weeklyMinutes: TimeInterval = 0
    var weekStartDate: Date?

    // MARK: - Internal Tracking (for median calculation)

    /// FocusMode.rawValue -> list of all session durations in seconds.
    /// Kept private-ish but Codable so we can compute median accurately.
    var durationHistoryByMode: [String: [TimeInterval]] = [:]

    // MARK: - Persistence Key

    private static let userDefaultsKey = "com.bionaural.watch.learningProfile"

    // MARK: - Recording

    /// Records a completed session, updating all profile fields.
    ///
    /// - Parameters:
    ///   - mode: The focus mode used during the session.
    ///   - duration: The session duration in seconds.
    ///   - date: The date the session ended.
    mutating func recordSession(mode: FocusMode, duration: TimeInterval, date: Date) {
        let key = mode.rawValue

        // Total count
        totalSessions += 1

        // Per-mode count
        sessionsByMode[key, default: 0] += 1

        // Duration history (for median)
        durationHistoryByMode[key, default: []].append(duration)

        // Running average duration
        let count = Double(sessionsByMode[key] ?? 1)
        let previousAvg = averageDurationByMode[key] ?? 0
        averageDurationByMode[key] = previousAvg + (duration - previousAvg) / count

        // Time-of-day distribution
        let hour = Calendar.current.component(.hour, from: date)
        sessionsByHourOfDay[hour, default: 0] += 1

        // Day-of-week distribution
        let weekday = Calendar.current.component(.weekday, from: date)
        sessionsByDayOfWeek[weekday, default: 0] += 1

        // Weekly minutes tracking
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start
        if let startOfWeek, startOfWeek != weekStartDate {
            // New week — reset
            weeklyMinutes = duration / 60.0
            weekStartDate = startOfWeek
        } else {
            weeklyMinutes += duration / 60.0
        }

        // Streak tracking
        if let lastDate = lastSessionDate {
            let daysBetween = calendar.dateComponents([.day], from: lastDate, to: date).day ?? 0
            if daysBetween == 1 {
                streakDays += 1
            } else if daysBetween > 1 {
                streakDays = 1
            }
            // daysBetween == 0 means same day, streak unchanged
        } else {
            streakDays = 1
        }

        lastSessionDate = date
    }

    // MARK: - Queries

    /// Returns the median session duration for a given mode, or nil if no sessions exist.
    func medianDuration(for mode: FocusMode) -> TimeInterval? {
        guard let durations = durationHistoryByMode[mode.rawValue],
              !durations.isEmpty else {
            return nil
        }
        let sorted = durations.sorted()
        let count = sorted.count
        if count.isMultiple(of: 2) {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    /// Returns the most-used focus mode, or nil if no sessions have been recorded.
    func mostUsedMode() -> FocusMode? {
        guard let (key, _) = sessionsByMode.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return FocusMode(rawValue: key)
    }

    // MARK: - Computed Properties

    /// The current learning stage based on total session count and
    /// `WatchDesign.Learning` thresholds.
    var learningStage: LearningStage {
        if totalSessions < WatchDesign.Learning.learningThreshold {
            return .coldStart
        } else if totalSessions < WatchDesign.Learning.confidentThreshold {
            return .learning
        } else {
            return .confident
        }
    }

    /// How many of the learning dots (out of `WatchDesign.Learning.totalDots`)
    /// should be filled, based on `WatchDesign.Learning.sessionsPerDot` thresholds.
    var filledDots: Int {
        let thresholds = WatchDesign.Learning.sessionsPerDot
        var filled = 0
        for threshold in thresholds {
            if totalSessions >= threshold {
                filled += 1
            } else {
                break
            }
        }
        // If all thresholds passed, fill the last dot too
        if filled == thresholds.count {
            return WatchDesign.Learning.totalDots
        }
        return filled
    }

    // MARK: - Persistence

    /// Loads the profile from UserDefaults. Returns a fresh profile if none exists.
    static func load() -> WatchLearningProfile {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let profile = try? JSONDecoder().decode(WatchLearningProfile.self, from: data) else {
            return WatchLearningProfile()
        }
        return profile
    }

    /// Persists the profile to UserDefaults.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
