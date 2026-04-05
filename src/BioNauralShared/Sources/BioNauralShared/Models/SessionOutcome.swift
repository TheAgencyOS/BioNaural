import Foundation

/// A type alias for sound asset identifiers, enabling future migration to a
/// richer identifier type without changing the `SessionOutcome` API.
public typealias SoundID = String

/// User's binary post-session feedback rating.
public enum ThumbsRating: String, Codable, Sendable {
    case up
    case down
}

/// A complete record of a single BioNaural session, capturing every signal
/// needed for the feedback and learning loop.
///
/// `SessionOutcome` is the primary training data structure. It records session
/// metadata, the exact sound configuration used, all biometric outcomes, the
/// user's pre-session check-in, and their post-session rating. Two computed
/// scores — `biometricSuccessScore` and `overallScore` — distill this into
/// actionable values for the learning system.
///
/// Stored in SwiftData after every session. See Tech-FeedbackLoop.md for the
/// full specification and scoring weights.
public struct SessionOutcome: Codable, Sendable, Identifiable {

    // MARK: - Session Metadata

    /// Unique identifier for this session.
    public let sessionID: UUID

    /// The focus mode used during this session.
    public let mode: FocusMode

    /// Total session duration in seconds.
    public let duration: TimeInterval

    /// The date and time the session started.
    public let timestamp: Date

    /// Hour of day (0-23) when the session started. Used for time-of-day
    /// pattern learning.
    public let timeOfDay: Int

    /// Day of week (1 = Sunday, 7 = Saturday) when the session started.
    /// Used for day-of-week pattern learning.
    public let dayOfWeek: Int

    // MARK: - Sound Selections

    /// The ambient bed sound asset used during the session.
    public let ambientBedID: SoundID

    /// Melodic layer asset IDs used, including crossfade transitions.
    public let melodicLayerIDs: [SoundID]

    /// The binaural beat frequency range traversed during the session (Hz).
    /// The lower bound is the starting frequency; the upper bound is the ending
    /// frequency (or vice versa, depending on mode direction).
    public let binauralBeatRange: ClosedRange<Double>

    /// The carrier frequency used during the session (Hz).
    public let carrierFrequency: Double

    // MARK: - Biometric Outcomes

    /// Heart rate at session start (BPM).
    public let hrStart: Double

    /// Heart rate at session end (BPM).
    public let hrEnd: Double

    /// Heart rate change (end - start). Negative values indicate calming.
    public let hrDelta: Double

    /// Heart rate variability (RMSSD) at session start, if available.
    public let hrvStart: Double?

    /// Heart rate variability (RMSSD) at session end, if available.
    public let hrvEnd: Double?

    /// HRV change (end - start). Positive values indicate parasympathetic
    /// improvement.
    public let hrvDelta: Double?

    /// Seconds until the user first reached the Calm biometric state. `nil` if
    /// Calm was never reached.
    public let timeToCalm: TimeInterval?

    /// Seconds until sleep onset was detected (Sleep mode only). `nil` if sleep
    /// was not detected or the mode was not Sleep.
    public let timeToSleep: TimeInterval?

    /// Number of biometric state transitions during the session. Fewer
    /// transitions indicate a more stable session.
    public let adaptationCount: Int

    /// Minutes spent in the deepest biometric zone (Calm). Longer durations
    /// indicate higher session quality.
    public let sustainedDeepStateMinutes: Double

    /// Whether the user completed the intended session duration. `false` if
    /// they stopped early.
    public let wasCompleted: Bool

    // MARK: - Pre-Session Check-In

    /// Self-reported mood on a 0.0 (wired/anxious) to 1.0 (calm/tired) scale.
    /// `nil` if the check-in was skipped.
    public let checkInMood: Double?

    /// The mode the user said they wanted (may differ from actual `mode` if
    /// the system suggested otherwise). `nil` if skipped.
    public let checkInGoal: FocusMode?

    /// Whether the user skipped the pre-session check-in entirely.
    public let checkInSkipped: Bool

    // MARK: - Post-Session Feedback

    /// The user's thumbs-up/thumbs-down rating. `nil` if no rating was given.
    public let thumbsRating: ThumbsRating?

    /// Optional feedback tags selected after a thumbs-down (e.g., "too busy",
    /// "not my style"). `nil` if no tags were provided.
    public let feedbackTags: [String]?

    // MARK: - Identifiable

    public var id: UUID { sessionID }

    // MARK: - Computed Scores

    /// Biometric success score (0.0 = no improvement, 1.0 = strong improvement).
    ///
    /// Computed as a weighted combination of biometric deltas, normalized to the
    /// mode-specific success criteria from Tech-FeedbackLoop.md:
    ///
    /// **Focus:** HR stability (0.3) + low adaptation count (0.2) +
    ///   session completed (0.2) + sustained focused state (0.3).
    ///
    /// **Relaxation:** HR delta negative (0.3) + HRV delta positive (0.3) +
    ///   time to calm (0.2) + session completed (0.2).
    ///
    /// **Sleep:** Time to sleep onset (0.4) + HR delta negative (0.2) +
    ///   HRV delta positive (0.2) + session completed (0.2).
    ///
    /// **Energize:** HR delta positive (0.3) + adaptation count (0.2) +
    ///   completion (0.2) + sustained activated state (0.3).
    public var biometricSuccessScore: Double {
        switch mode {
        case .focus:
            return computeFocusScore()
        case .relaxation:
            return computeRelaxationScore()
        case .sleep:
            return computeSleepScore()
        case .energize:
            return computeEnergizeScore()
        }
    }

    /// Overall session quality score (0.0 = failure, 1.0 = ideal).
    ///
    /// Combines `biometricSuccessScore` (weight 0.7) and `thumbsRating`
    /// (weight 0.3). When no thumbs rating is provided, the biometric score
    /// is used alone.
    public var overallScore: Double {
        let biometricWeight = 0.7
        let thumbsWeight = 0.3

        let biometric = biometricSuccessScore

        guard let rating = thumbsRating else {
            return biometric
        }

        let thumbsValue: Double = (rating == .up) ? 1.0 : 0.0
        return biometric * biometricWeight + thumbsValue * thumbsWeight
    }

    // MARK: - Initialization

    public init(
        sessionID: UUID,
        mode: FocusMode,
        duration: TimeInterval,
        timestamp: Date,
        timeOfDay: Int,
        dayOfWeek: Int,
        ambientBedID: SoundID,
        melodicLayerIDs: [SoundID],
        binauralBeatRange: ClosedRange<Double>,
        carrierFrequency: Double,
        hrStart: Double,
        hrEnd: Double,
        hrDelta: Double,
        hrvStart: Double?,
        hrvEnd: Double?,
        hrvDelta: Double?,
        timeToCalm: TimeInterval?,
        timeToSleep: TimeInterval?,
        adaptationCount: Int,
        sustainedDeepStateMinutes: Double,
        wasCompleted: Bool,
        checkInMood: Double?,
        checkInGoal: FocusMode?,
        checkInSkipped: Bool,
        thumbsRating: ThumbsRating?,
        feedbackTags: [String]?
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.duration = duration
        self.timestamp = timestamp
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.ambientBedID = ambientBedID
        self.melodicLayerIDs = melodicLayerIDs
        self.binauralBeatRange = binauralBeatRange
        self.carrierFrequency = carrierFrequency
        self.hrStart = hrStart
        self.hrEnd = hrEnd
        self.hrDelta = hrDelta
        self.hrvStart = hrvStart
        self.hrvEnd = hrvEnd
        self.hrvDelta = hrvDelta
        self.timeToCalm = timeToCalm
        self.timeToSleep = timeToSleep
        self.adaptationCount = adaptationCount
        self.sustainedDeepStateMinutes = sustainedDeepStateMinutes
        self.wasCompleted = wasCompleted
        self.checkInMood = checkInMood
        self.checkInGoal = checkInGoal
        self.checkInSkipped = checkInSkipped
        self.thumbsRating = thumbsRating
        self.feedbackTags = feedbackTags
    }

    // MARK: - Private Scoring

    /// Focus mode scoring per Tech-FeedbackLoop.md.
    ///
    /// Weights: HR stability 0.3, adaptation count 0.2, completion 0.2,
    /// sustained focused state 0.3.
    private func computeFocusScore() -> Double {
        let hrStabilityWeight = 0.3
        let adaptationWeight = 0.2
        let completionWeight = 0.2
        let sustainedWeight = 0.3

        // HR stability: smaller absolute delta is better. Sigmoid-normalize
        // so that |delta| <= 2 BPM scores near 1.0 and |delta| >= 15 scores near 0.0.
        let hrStability = FrequencyMath.sigmoid(
            x: abs(hrDelta),
            midpoint: 8.0,
            steepness: -0.5
        )

        // Adaptation count: fewer is better. 0 transitions = 1.0, 10+ = ~0.0.
        let adaptationScore = FrequencyMath.sigmoid(
            x: Double(adaptationCount),
            midpoint: 5.0,
            steepness: -0.6
        )

        // Completion: binary.
        let completionScore: Double = wasCompleted ? 1.0 : 0.0

        // Sustained state: fraction of session duration spent in deep state.
        let sessionMinutes = duration / 60.0
        let sustainedScore: Double
        if sessionMinutes > 0 {
            sustainedScore = min(sustainedDeepStateMinutes / sessionMinutes, 1.0)
        } else {
            sustainedScore = 0.0
        }

        return hrStability * hrStabilityWeight
            + adaptationScore * adaptationWeight
            + completionScore * completionWeight
            + sustainedScore * sustainedWeight
    }

    /// Relaxation mode scoring per Tech-FeedbackLoop.md.
    ///
    /// Weights: HR delta 0.3, HRV delta 0.3, time to calm 0.2, completion 0.2.
    private func computeRelaxationScore() -> Double {
        let hrDeltaWeight = 0.3
        let hrvDeltaWeight = 0.3
        let timeToCalmWeight = 0.2
        let completionWeight = 0.2

        // HR delta: more negative is better. -10 BPM = great, +5 = bad.
        let hrScore = FrequencyMath.sigmoid(
            x: hrDelta,
            midpoint: 0.0,
            steepness: -0.3
        )

        // HRV delta: more positive is better. +10ms = great, -5ms = bad.
        let hrvScore: Double
        if let delta = hrvDelta {
            hrvScore = FrequencyMath.sigmoid(
                x: delta,
                midpoint: 0.0,
                steepness: 0.3
            )
        } else {
            hrvScore = 0.5 // Neutral when no HRV data available.
        }

        // Time to calm: faster is better. Under 3 min = great, over 15 min = poor.
        let calmScore: Double
        if let ttc = timeToCalm {
            let minutes = ttc / 60.0
            calmScore = FrequencyMath.sigmoid(
                x: minutes,
                midpoint: 8.0,
                steepness: -0.4
            )
        } else {
            calmScore = 0.0 // Never reached calm.
        }

        let completionScore: Double = wasCompleted ? 1.0 : 0.0

        return hrScore * hrDeltaWeight
            + hrvScore * hrvDeltaWeight
            + calmScore * timeToCalmWeight
            + completionScore * completionWeight
    }

    /// Sleep mode scoring per Tech-FeedbackLoop.md.
    ///
    /// Weights: time to sleep 0.4, HR delta 0.2, HRV delta 0.2, completion 0.2.
    private func computeSleepScore() -> Double {
        let sleepOnsetWeight = 0.4
        let hrDeltaWeight = 0.2
        let hrvDeltaWeight = 0.2
        let completionWeight = 0.2

        // Time to sleep: faster is better. Under 10 min = great, over 30 = poor.
        let sleepScore: Double
        if let tts = timeToSleep {
            let minutes = tts / 60.0
            sleepScore = FrequencyMath.sigmoid(
                x: minutes,
                midpoint: 20.0,
                steepness: -0.2
            )
        } else {
            sleepScore = 0.0 // Sleep not detected.
        }

        // HR delta: more negative is better.
        let hrScore = FrequencyMath.sigmoid(
            x: hrDelta,
            midpoint: 0.0,
            steepness: -0.3
        )

        // HRV delta: more positive is better.
        let hrvScore: Double
        if let delta = hrvDelta {
            hrvScore = FrequencyMath.sigmoid(
                x: delta,
                midpoint: 0.0,
                steepness: 0.3
            )
        } else {
            hrvScore = 0.5
        }

        // Completion: sleep detected counts as completion.
        let completionScore: Double = (wasCompleted || timeToSleep != nil) ? 1.0 : 0.0

        return sleepScore * sleepOnsetWeight
            + hrScore * hrDeltaWeight
            + hrvScore * hrvDeltaWeight
            + completionScore * completionWeight
    }

    /// Energize mode scoring.
    ///
    /// Weights: HR elevation 0.3, adaptation count 0.2, completion 0.2,
    /// sustained activated state 0.3.
    /// Unlike Focus, a moderate positive HR delta indicates successful activation.
    private func computeEnergizeScore() -> Double {
        let hrElevationWeight = 0.3
        let adaptationWeight = 0.2
        let completionWeight = 0.2
        let sustainedWeight = 0.3

        // HR elevation: a moderate positive delta is desirable for activation.
        // +5 BPM = good, +15 = peak. Negative delta = not activated.
        let hrElevation = FrequencyMath.sigmoid(
            x: hrDelta,
            midpoint: 5.0,
            steepness: 0.3
        )

        // Adaptation count: fewer large swings is better. Stable activation preferred.
        let adaptationScore = FrequencyMath.sigmoid(
            x: Double(adaptationCount),
            midpoint: 5.0,
            steepness: -0.6
        )

        // Completion: binary.
        let completionScore: Double = wasCompleted ? 1.0 : 0.0

        // Sustained state: fraction of session duration spent in activated state.
        let sessionMinutes = duration / 60.0
        let sustainedScore: Double
        if sessionMinutes > 0 {
            sustainedScore = min(sustainedDeepStateMinutes / sessionMinutes, 1.0)
        } else {
            sustainedScore = 0.0
        }

        return hrElevation * hrElevationWeight
            + adaptationScore * adaptationWeight
            + completionScore * completionWeight
            + sustainedScore * sustainedWeight
    }
}
