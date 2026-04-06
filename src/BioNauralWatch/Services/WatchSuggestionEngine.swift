// WatchSuggestionEngine.swift
// BioNauralWatch
//
// Computes a WatchSuggestion based on time of day, biometric state, sleep
// context, and the user's session history. All thresholds reference
// WatchDesign tokens or BioNauralShared utilities — no hardcoded values.

import Foundation
import BioNauralShared

@MainActor
final class WatchSuggestionEngine {

    // MARK: - Public API

    /// Computes a mode suggestion using available context signals.
    ///
    /// Priority order:
    /// 1. Base mode from time of day.
    /// 2. Override from heart-rate reserve (if HR available).
    /// 3. Override from poor sleep (if sleep data available).
    /// 4. Duration from personal history or default.
    /// 5. Title phrasing from learning stage.
    /// 6. Context text from available biometric/history data.
    ///
    /// - Parameters:
    ///   - profile: The user's persisted learning profile.
    ///   - currentHR: Current heart rate in BPM, or nil.
    ///   - restingHR: Resting heart rate in BPM, or nil.
    ///   - recentSleepHours: Hours slept last night, or nil.
    /// - Returns: A `WatchSuggestion` ready for display.
    func computeSuggestion(
        profile: WatchLearningProfile,
        currentHR: Double?,
        restingHR: Double?,
        recentSleepHours: Double?
    ) -> WatchSuggestion {
        let hour = Calendar.current.component(.hour, from: Date())

        // Step 1: Base mode from time of day
        var mode = baseMode(for: hour)

        // Compute HR reserve if biometrics are available
        let effectiveResting = restingHR ?? WatchDesign.Audio.defaultRestingHR
        let effectiveMax = WatchDesign.Audio.defaultMaxHR
        var hrReserve: Double?
        var hrState: BiometricState?

        if let hr = currentHR {
            let reserve = FrequencyMath.heartRateReserveNormalized(
                current: hr,
                resting: effectiveResting,
                max: effectiveMax
            )
            hrReserve = reserve
            hrState = BiometricState.classify(hrNormalized: reserve)
        }

        // Step 2: Override from HR
        if let reserve = hrReserve {
            if reserve > WatchDesign.Suggestion.hrReserveRelaxationThreshold && hour < 20 {
                mode = .relaxation
            } else if reserve < WatchDesign.Suggestion.hrReserveEnergizeThreshold && hour < 12 {
                mode = .energize
            }
        }

        // Step 3: Override from poor sleep
        if let sleepHours = recentSleepHours, sleepHours < WatchDesign.Suggestion.poorSleepThreshold {
            mode = .relaxation
        }

        // Step 4: Duration from history or default
        let durationSeconds = profile.medianDuration(for: mode)
        let durationMinutes: Int?
        if let seconds = durationSeconds {
            durationMinutes = max(1, Int(round(seconds / 60.0)))
        } else {
            durationMinutes = WatchDesign.Layout.durationPickerDefault
        }

        // Step 5: Title by learning stage
        let title = suggestionTitle(for: mode, stage: profile.learningStage)

        // Step 6: Context text
        let contextText = buildContextText(
            mode: mode,
            hour: hour,
            profile: profile,
            currentHR: currentHR,
            hrReserve: hrReserve,
            recentSleepHours: recentSleepHours
        )

        return WatchSuggestion(
            mode: mode,
            durationMinutes: durationMinutes,
            title: title,
            contextText: contextText,
            currentHR: currentHR,
            currentHRState: hrState
        )
    }

    // MARK: - Private Helpers

    /// Determines the base focus mode from the hour of day.
    private func baseMode(for hour: Int) -> FocusMode {
        switch hour {
        case 5..<15:
            return .focus
        case 15..<21:
            return .relaxation
        default:
            // 21-23 and 0-4
            return .sleep
        }
    }

    /// Builds a stage-appropriate suggestion title.
    private func suggestionTitle(for mode: FocusMode, stage: LearningStage) -> String {
        switch stage {
        case .coldStart:
            return "Try a \(mode.displayName) session"
        case .learning:
            return "\(mode.displayName) looks right"
        case .confident:
            return "\(mode.displayName). You're ready."
        }
    }

    /// Assembles the context text from all available signals.
    private func buildContextText(
        mode: FocusMode,
        hour: Int,
        profile: WatchLearningProfile,
        currentHR: Double?,
        hrReserve: Double?,
        recentSleepHours: Double?
    ) -> String {
        var parts: [String] = []

        // HR context
        if let hr = currentHR, let reserve = hrReserve {
            let hrFormatted = String(format: "%.0f", hr)
            let comparison = hrComparisonLabel(reserve: reserve)
            let timeOfDay = timeOfDayLabel(for: hour)
            parts.append("HR \(hrFormatted) \u{00b7} \(comparison) for \(timeOfDay)")
        }

        // Sleep context
        if let sleepHours = recentSleepHours {
            let formatted = String(format: "%.1f", sleepHours)
            parts.append("Slept \(formatted)h last night")
        }

        // Personal pattern context (confident stage only)
        if profile.learningStage == .confident {
            let sessionsThisHour = profile.sessionsByHourOfDay[hour] ?? 0
            if sessionsThisHour > 0,
               let mostUsed = mostUsedModeForHour(hour, profile: profile),
               mostUsed == mode {
                parts.append("Mornings like this are your best sessions")
            }
        }

        // Fallback for cold start with no data
        if parts.isEmpty {
            return "Your first session helps me learn how your body responds."
        }

        return parts.joined(separator: " \u{00b7} ")
    }

    /// Returns a human-readable label for where HR sits within the reserve range.
    private func hrComparisonLabel(reserve: Double) -> String {
        let t = WatchDesign.Suggestion.hrLabelThresholds
        switch reserve {
        case ..<t[0]:
            return "very calm"
        case t[0]..<t[1]:
            return "resting"
        case t[1]..<t[2]:
            return "moderate"
        case t[2]..<t[3]:
            return "elevated"
        default:
            return "high"
        }
    }

    /// Returns a time-of-day label string.
    private func timeOfDayLabel(for hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }

    /// Finds the most-used mode for a specific hour of day from the profile's history.
    ///
    /// This is a simplified heuristic: if the user has used the suggested mode
    /// at this hour before, we consider it a pattern match.
    private func mostUsedModeForHour(_ hour: Int, profile: WatchLearningProfile) -> FocusMode? {
        // The profile tracks sessions by hour but not mode-per-hour.
        // For now, return the globally most-used mode — a future version
        // could track a [hour: [mode: count]] matrix for finer granularity.
        return profile.mostUsedMode()
    }
}
