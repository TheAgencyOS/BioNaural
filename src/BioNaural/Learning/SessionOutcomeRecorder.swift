// SessionOutcomeRecorder.swift
// BioNaural
//
// Records everything about a session for the learning system.
// Collects data throughout the session lifecycle, computes outcome
// scores at session end, and persists the result via SessionStore.
//
// All computation is on-device. No network dependencies.

import Foundation
import BioNauralShared

// MARK: - Session Outcome

/// The complete learning-system record for a single session.
/// Built by `SessionOutcomeRecorder` at session end and persisted via `SessionStoreProtocol`.
public struct SessionOutcome: Sendable, Identifiable {

    public let id: UUID
    public let sessionID: UUID
    public let mode: FocusMode
    public let startDate: Date
    public let endDate: Date
    public let durationSeconds: TimeInterval
    public let completed: Bool

    // MARK: - Biometric Data

    /// All HR samples collected during the session.
    public let hrSamples: [BiometricSample]

    /// Adaptation events that occurred during the session.
    public let adaptationEvents: [AdaptationEventRecord]

    /// Sound tags that were active during this session.
    public let activeSoundTags: [String]

    // MARK: - Check-In Data

    /// Pre-session mood self-report (0.0 = wired, 1.0 = calm). Nil if skipped.
    public let checkInMood: Double?

    /// Pre-session intent (the mode the user chose, may differ from actual mode).
    public let checkInIntent: FocusMode?

    // MARK: - User Feedback

    /// Post-session thumbs rating. `true` = up, `false` = down, `nil` = skipped.
    public let thumbsUp: Bool?

    // MARK: - Computed Scores

    /// Mode-specific biometric success score (0.0 - 1.0).
    public let biometricSuccessScore: Double

    /// Overall session quality score combining biometric + thumbs (0.0 - 1.0).
    public let overallScore: Double

    /// Alignment between check-in self-report and biometric reality (0.0 - 1.0).
    /// Nil if either check-in or biometrics unavailable.
    public let checkInBiometricAlignment: Double?

    // MARK: - Derived Metrics

    /// Heart rate at session start (average of first 30s of samples).
    public let startingHR: Double?

    /// Heart rate at session end (average of last 30s of samples).
    public let endingHR: Double?

    /// Net HR change (endingHR - startingHR).
    public let hrDelta: Double?

    /// Time in seconds from session start to first sustained calm state.
    /// Nil if calm was never reached.
    public let timeToCalmSeconds: TimeInterval?

    /// Estimated sleep onset time in seconds from session start.
    /// Nil for non-sleep modes or if onset was not detected.
    public let sleepOnsetSeconds: TimeInterval?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        mode: FocusMode,
        startDate: Date,
        endDate: Date,
        durationSeconds: TimeInterval,
        completed: Bool,
        hrSamples: [BiometricSample],
        adaptationEvents: [AdaptationEventRecord],
        activeSoundTags: [String],
        checkInMood: Double?,
        checkInIntent: FocusMode?,
        thumbsUp: Bool?,
        biometricSuccessScore: Double,
        overallScore: Double,
        checkInBiometricAlignment: Double?,
        startingHR: Double?,
        endingHR: Double?,
        hrDelta: Double?,
        timeToCalmSeconds: TimeInterval?,
        sleepOnsetSeconds: TimeInterval?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.hrSamples = hrSamples
        self.adaptationEvents = adaptationEvents
        self.activeSoundTags = activeSoundTags
        self.checkInMood = checkInMood
        self.checkInIntent = checkInIntent
        self.thumbsUp = thumbsUp
        self.biometricSuccessScore = biometricSuccessScore
        self.overallScore = overallScore
        self.checkInBiometricAlignment = checkInBiometricAlignment
        self.startingHR = startingHR
        self.endingHR = endingHR
        self.hrDelta = hrDelta
        self.timeToCalmSeconds = timeToCalmSeconds
        self.sleepOnsetSeconds = sleepOnsetSeconds
    }
}

// MARK: - Session Store Protocol

/// Persistence contract for session outcomes. Backed by SwiftData in production,
/// replaceable with an in-memory implementation for tests.
public protocol SessionStoreProtocol: AnyObject, Sendable {

    /// Saves a session outcome to persistent storage.
    func save(outcome: SessionOutcome) async throws

    /// Retrieves all session outcomes, optionally filtered by mode.
    func outcomes(mode: FocusMode?) async throws -> [SessionOutcome]

    /// Retrieves outcomes within a date range.
    func outcomes(from start: Date, to end: Date) async throws -> [SessionOutcome]

    /// Total number of recorded outcomes.
    func outcomeCount() async throws -> Int
}

// MARK: - Date Provider Protocol

/// Abstracts the system clock for deterministic testing.
public protocol DateProviding: Sendable {
    func now() -> Date
}

/// Production date provider that returns the real system time.
public struct SystemDateProvider: DateProviding, Sendable {
    public init() {}
    public func now() -> Date { Date() }
}

// MARK: - Score Configuration

/// All tuning constants for outcome scoring. No hardcoded values at computation sites.
public enum OutcomeScoring {

    // MARK: - Component Weights by Mode

    enum Focus {
        static let hrStabilityWeight: Double = 0.3
        static let lowAdaptationWeight: Double = 0.2
        static let completionWeight: Double = 0.2
        static let sustainedFocusWeight: Double = 0.3
    }

    enum Relaxation {
        static let hrDeltaNegativeWeight: Double = 0.3
        static let hrvDeltaPositiveWeight: Double = 0.3
        static let timeToCalmWeight: Double = 0.2
        static let completionWeight: Double = 0.2
    }

    enum Sleep {
        static let timeToSleepOnsetWeight: Double = 0.4
        static let hrDeltaWeight: Double = 0.2
        static let hrvDeltaWeight: Double = 0.2
        static let completionWeight: Double = 0.2
    }

    enum Energize {
        /// HR elevation: positive delta indicates arousal activation.
        static let hrElevationWeight: Double = 0.3
        /// Sustained elevated/peak state fraction.
        static let sustainedActivationWeight: Double = 0.3
        /// Completed the session including cool-down.
        static let completionWeight: Double = 0.2
        /// Successful cool-down: HR decreased during cool-down phase.
        static let coolDownRecoveryWeight: Double = 0.2
    }

    // MARK: - Overall Score Blend

    /// Weight of biometric score in the overall blend.
    static let biometricWeight: Double = 0.7

    /// Weight of thumbs feedback in the overall blend.
    static let thumbsWeight: Double = 0.3

    /// Score assigned when thumbs feedback is absent.
    static let thumbsNeutral: Double = 0.5

    // MARK: - Threshold Constants

    /// Number of seconds to average at session start/end for HR measurement.
    static let hrWindowSeconds: TimeInterval = 30.0

    /// Maximum adaptation count considered "low" for focus scoring.
    static let lowAdaptationThreshold: Int = 5

    /// Maximum time-to-calm (seconds) that scores 1.0 in relaxation mode.
    static let idealTimeToCalmSeconds: TimeInterval = 120.0

    /// Maximum sleep onset time (seconds) that scores 1.0.
    static let idealSleepOnsetSeconds: TimeInterval = 900.0

    /// HR standard deviation threshold for "stable" classification.
    static let stableHRStdDev: Double = 5.0

    /// Minimum fraction of session spent in focused state for full score.
    static let sustainedFocusThreshold: Double = 0.6

    /// Minimum number of HR samples required to compute biometric scores.
    static let minimumHRSamples: Int = 5

    /// Duration (seconds) of sustained calm state required to count as "calm reached".
    static let calmDwellSeconds: TimeInterval = 30.0

    /// HR drop rate (BPM/min) threshold used to estimate sleep onset.
    static let sleepOnsetHRDropRate: Double = 2.0

    /// Window size (seconds) for rolling HR analysis in sleep onset detection.
    static let sleepOnsetWindowSeconds: TimeInterval = 60.0

    /// Fallback biometric score when data is insufficient and session completed.
    static let insufficientDataCompletedScore: Double = 0.6

    /// Fallback biometric score when data is insufficient and session not completed.
    static let insufficientDataIncompleteScore: Double = 0.3

    /// BPM range used to normalize HR delta into a 0-1 score.
    /// A delta of +/- this value maps to the score extremes.
    static let hrDeltaNormalizationRange: Double = 20.0

    /// Midpoint for HR delta normalization (no change = this score).
    static let hrDeltaMidpoint: Double = 0.5

    /// Minimum samples required in a sleep-onset detection window.
    static let sleepOnsetMinWindowSamples: Int = 3

    // MARK: - Biometric State Mood Mapping

    /// Mapping from BiometricState to a 0-1 mood scale for alignment computation.
    /// calm=1.0, focused=0.7, elevated=0.3, peak=0.0.
    enum StateMoodMapping {
        static let calm: Double = 1.0
        static let focused: Double = 0.7
        static let elevated: Double = 0.3
        static let peak: Double = 0.0
    }

    /// Fraction of session duration used for "early" state analysis in alignment.
    static let earlySessionFraction: Double = 3.0
}

// MARK: - Session Outcome Recorder

/// Collects session data in real time and computes learning outcomes at session end.
///
/// Usage:
/// 1. Create a recorder at session start via `beginSession(...)`.
/// 2. Feed data as it arrives: `recordHRSample(...)`, `recordAdaptationEvent(...)`, etc.
/// 3. Call `finalizeSession(...)` at session end to compute scores and persist.
///
/// Thread safety: This actor serializes all mutations. Callers may invoke methods
/// from any concurrency context.
public actor SessionOutcomeRecorder {

    // MARK: - Dependencies

    private let sessionStore: SessionStoreProtocol
    private let healthKit: HealthKitServiceProtocol
    private let dateProvider: DateProviding

    // MARK: - Session State

    private var sessionID: UUID?
    private var mode: FocusMode?
    private var startDate: Date?
    private var checkInMood: Double?
    private var checkInIntent: FocusMode?

    private var hrSamples: [BiometricSample] = []
    private var adaptationEvents: [AdaptationEventRecord] = []
    private var activeSoundTags: Set<String> = []
    private var biometricStateHistory: [(timestamp: TimeInterval, state: BiometricState)] = []

    // MARK: - Initialization

    /// Creates a session outcome recorder.
    ///
    /// - Parameters:
    ///   - sessionStore: Persistence backend for saving outcomes.
    ///   - healthKit: HealthKit service for writing mindful sessions, state of mind, and workouts.
    ///   - dateProvider: Clock abstraction for testability.
    public init(
        sessionStore: SessionStoreProtocol,
        healthKit: HealthKitServiceProtocol,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.sessionStore = sessionStore
        self.healthKit = healthKit
        self.dateProvider = dateProvider
    }

    // MARK: - Session Lifecycle

    /// Begins recording a new session. Resets all accumulated data.
    ///
    /// - Parameters:
    ///   - sessionID: Unique identifier for this session.
    ///   - mode: The focus mode being used.
    ///   - checkInMood: Pre-session mood (0.0 wired to 1.0 calm), nil if skipped.
    ///   - checkInIntent: The mode the user selected at check-in.
    public func beginSession(
        sessionID: UUID,
        mode: FocusMode,
        checkInMood: Double?,
        checkInIntent: FocusMode?
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.startDate = dateProvider.now()
        self.checkInMood = checkInMood
        self.checkInIntent = checkInIntent

        hrSamples = []
        adaptationEvents = []
        activeSoundTags = []
        biometricStateHistory = []
    }

    /// Records a heart rate sample received during the session.
    public func recordHRSample(_ sample: BiometricSample) {
        hrSamples.append(sample)
    }

    /// Records a batch of HR samples (e.g., when replaying buffered Watch data).
    public func recordHRSamples(_ samples: [BiometricSample]) {
        hrSamples.append(contentsOf: samples)
    }

    /// Records an adaptation event from the adaptive algorithm.
    public func recordAdaptationEvent(_ event: AdaptationEventRecord) {
        adaptationEvents.append(event)
    }

    /// Records that a sound with the given tags was selected during the session.
    public func recordSoundSelection(tags: [String]) {
        for tag in tags {
            activeSoundTags.insert(tag)
        }
    }

    /// Records a biometric state transition observed during the session.
    ///
    /// - Parameters:
    ///   - state: The new biometric state.
    ///   - elapsedSeconds: Seconds since session start when this state was entered.
    public func recordBiometricState(_ state: BiometricState, at elapsedSeconds: TimeInterval) {
        biometricStateHistory.append((timestamp: elapsedSeconds, state: state))
    }

    /// Finalizes the session, computes all scores, and persists the outcome.
    ///
    /// - Parameters:
    ///   - completed: Whether the session ran to its full planned duration.
    ///   - thumbsUp: Post-session feedback. `true` = thumbs up, `false` = down, `nil` = skipped.
    /// - Returns: The computed `SessionOutcome`, or `nil` if no session was active.
    @discardableResult
    public func finalizeSession(
        completed: Bool,
        thumbsUp: Bool?
    ) async throws -> SessionOutcome? {
        guard let sessionID, let mode, let startDate else { return nil }

        let endDate = dateProvider.now()
        let duration = endDate.timeIntervalSince(startDate)

        // Sort samples by timestamp for reliable windowed computations.
        let sortedSamples = hrSamples.sorted { $0.timestamp < $1.timestamp }

        let startingHR = computeWindowedHR(
            samples: sortedSamples,
            referenceTimestamp: sortedSamples.first?.timestamp ?? startDate.timeIntervalSince1970,
            windowSeconds: OutcomeScoring.hrWindowSeconds,
            fromEnd: false
        )
        let endingHR = computeWindowedHR(
            samples: sortedSamples,
            referenceTimestamp: sortedSamples.last?.timestamp ?? endDate.timeIntervalSince1970,
            windowSeconds: OutcomeScoring.hrWindowSeconds,
            fromEnd: true
        )
        let hrDelta: Double? = {
            guard let s = startingHR, let e = endingHR else { return nil }
            return e - s
        }()

        let timeToCalmSeconds = computeTimeToCalmState()
        let sleepOnsetSeconds = mode == .sleep ? estimateSleepOnset(samples: sortedSamples) : nil

        let biometricScore = computeBiometricSuccessScore(
            mode: mode,
            completed: completed,
            sortedSamples: sortedSamples,
            hrDelta: hrDelta,
            timeToCalmSeconds: timeToCalmSeconds,
            sleepOnsetSeconds: sleepOnsetSeconds,
            duration: duration
        )

        let thumbsScore: Double = {
            switch thumbsUp {
            case .some(true): return 1.0
            case .some(false): return 0.0
            case .none: return OutcomeScoring.thumbsNeutral
            }
        }()

        let overallScore = biometricScore * OutcomeScoring.biometricWeight
            + thumbsScore * OutcomeScoring.thumbsWeight

        let alignment = computeCheckInBiometricAlignment()

        let outcome = SessionOutcome(
            sessionID: sessionID,
            mode: mode,
            startDate: startDate,
            endDate: endDate,
            durationSeconds: duration,
            completed: completed,
            hrSamples: sortedSamples,
            adaptationEvents: adaptationEvents,
            activeSoundTags: Array(activeSoundTags),
            checkInMood: checkInMood,
            checkInIntent: checkInIntent,
            thumbsUp: thumbsUp,
            biometricSuccessScore: biometricScore,
            overallScore: overallScore,
            checkInBiometricAlignment: alignment,
            startingHR: startingHR,
            endingHR: endingHR,
            hrDelta: hrDelta,
            timeToCalmSeconds: timeToCalmSeconds,
            sleepOnsetSeconds: sleepOnsetSeconds
        )

        try await sessionStore.save(outcome: outcome)

        // Write mindful session to HealthKit for ALL modes.
        await healthKit.saveMindfulSession(start: startDate, end: endDate)

        // Write State of Mind to HealthKit.
        let (valence, stateLabel) = stateOfMindMapping(for: mode)
        await healthKit.saveStateOfMind(
            valence: valence,
            label: stateLabel,
            association: "selfCare"
        )

        // Write workout to HealthKit for Energize mode only.
        if mode == .energize {
            // HKWorkoutActivityType.mindAndBody.rawValue == 52
            let mindAndBodyRawValue: UInt = 52
            await healthKit.saveWorkout(
                activityType: mindAndBodyRawValue,
                start: startDate,
                end: endDate,
                energyBurned: nil
            )
        }

        // Reset state for potential reuse.
        self.sessionID = nil
        self.mode = nil
        self.startDate = nil

        return outcome
    }

    // MARK: - State of Mind Mapping

    /// Maps a focus mode to its State of Mind valence and label.
    ///
    /// Valence is on a -1.0 to 1.0 scale. Labels correspond to
    /// `HKStateOfMind.Label` cases available in iOS 18+.
    private func stateOfMindMapping(for mode: FocusMode) -> (valence: Double, label: String) {
        switch mode {
        case .focus:       return (valence: 0.5, label: "focused")
        case .relaxation:  return (valence: 0.7, label: "calm")
        case .sleep:       return (valence: 0.6, label: "peaceful")
        case .energize:    return (valence: 0.6, label: "energized")
        }
    }

    // MARK: - Biometric Success Score

    /// Computes the mode-specific biometric success score (0.0 - 1.0).
    private func computeBiometricSuccessScore(
        mode: FocusMode,
        completed: Bool,
        sortedSamples: [BiometricSample],
        hrDelta: Double?,
        timeToCalmSeconds: TimeInterval?,
        sleepOnsetSeconds: TimeInterval?,
        duration: TimeInterval
    ) -> Double {
        guard sortedSamples.count >= OutcomeScoring.minimumHRSamples else {
            // Insufficient biometric data — return neutral score weighted toward completion.
            return completed
                ? OutcomeScoring.insufficientDataCompletedScore
                : OutcomeScoring.insufficientDataIncompleteScore
        }

        let completionScore: Double = completed ? 1.0 : 0.0

        switch mode {
        case .focus:
            return computeFocusScore(
                sortedSamples: sortedSamples,
                completionScore: completionScore,
                duration: duration
            )
        case .relaxation:
            return computeRelaxationScore(
                hrDelta: hrDelta,
                timeToCalmSeconds: timeToCalmSeconds,
                completionScore: completionScore
            )
        case .sleep:
            return computeSleepScore(
                hrDelta: hrDelta,
                sleepOnsetSeconds: sleepOnsetSeconds,
                completionScore: completionScore
            )
        case .energize:
            return computeEnergizeScore(
                sortedSamples: sortedSamples,
                hrDelta: hrDelta,
                completionScore: completionScore,
                duration: duration
            )
        }
    }

    /// Focus: HR stability (0.3) + low adaptation count (0.2) + completed (0.2) + sustained focused state (0.3).
    private func computeFocusScore(
        sortedSamples: [BiometricSample],
        completionScore: Double,
        duration: TimeInterval
    ) -> Double {
        // HR stability: lower standard deviation = better.
        let hrValues = sortedSamples.map(\.bpm)
        let stdDev = standardDeviation(hrValues)
        let stabilityScore = max(0, 1.0 - (stdDev / OutcomeScoring.stableHRStdDev)).clamped01()

        // Low adaptation count: fewer adaptations = more stable session.
        let adaptCount = Double(adaptationEvents.count)
        let adaptThreshold = Double(OutcomeScoring.lowAdaptationThreshold)
        let adaptScore = max(0, 1.0 - (adaptCount / adaptThreshold)).clamped01()

        // Sustained focused state: fraction of time in .focused biometric state.
        let focusedFraction = fractionInState(.focused, totalDuration: duration)
        let focusScore = min(focusedFraction / OutcomeScoring.sustainedFocusThreshold, 1.0).clamped01()

        return stabilityScore * OutcomeScoring.Focus.hrStabilityWeight
            + adaptScore * OutcomeScoring.Focus.lowAdaptationWeight
            + completionScore * OutcomeScoring.Focus.completionWeight
            + focusScore * OutcomeScoring.Focus.sustainedFocusWeight
    }

    /// Relaxation: HR delta negative (0.3) + HRV delta positive (0.3) + time to calm (0.2) + completed (0.2).
    private func computeRelaxationScore(
        hrDelta: Double?,
        timeToCalmSeconds: TimeInterval?,
        completionScore: Double
    ) -> Double {
        // HR delta: negative is good (HR went down).
        let hrDeltaScore: Double = {
            guard let delta = hrDelta else { return OutcomeScoring.hrDeltaMidpoint }
            return (OutcomeScoring.hrDeltaMidpoint - delta / OutcomeScoring.hrDeltaNormalizationRange).clamped01()
        }()

        // HRV delta: not available from HR samples alone in v1.
        // Score based on reaching calm state as a proxy.
        let hrvProxy: Double = {
            let calmFraction = fractionInState(.calm, totalDuration: nil)
            return calmFraction.clamped01()
        }()

        // Time to calm: faster = better.
        let calmScore: Double = {
            guard let t = timeToCalmSeconds else { return 0.0 }
            return max(0, 1.0 - t / OutcomeScoring.idealTimeToCalmSeconds).clamped01()
        }()

        return hrDeltaScore * OutcomeScoring.Relaxation.hrDeltaNegativeWeight
            + hrvProxy * OutcomeScoring.Relaxation.hrvDeltaPositiveWeight
            + calmScore * OutcomeScoring.Relaxation.timeToCalmWeight
            + completionScore * OutcomeScoring.Relaxation.completionWeight
    }

    /// Sleep: time to sleep onset (0.4) + HR delta (0.2) + HRV delta (0.2) + completed (0.2).
    private func computeSleepScore(
        hrDelta: Double?,
        sleepOnsetSeconds: TimeInterval?,
        completionScore: Double
    ) -> Double {
        // Sleep onset: faster = better.
        let onsetScore: Double = {
            guard let t = sleepOnsetSeconds else { return 0.0 }
            return max(0, 1.0 - t / OutcomeScoring.idealSleepOnsetSeconds).clamped01()
        }()

        // HR delta: should decrease during sleep prep.
        let hrDeltaScore: Double = {
            guard let delta = hrDelta else { return 0.5 }
            return (0.5 - delta / 20.0).clamped01()
        }()

        // HRV proxy via calm-state fraction.
        let hrvProxy: Double = fractionInState(.calm, totalDuration: nil).clamped01()

        return onsetScore * OutcomeScoring.Sleep.timeToSleepOnsetWeight
            + hrDeltaScore * OutcomeScoring.Sleep.hrDeltaWeight
            + hrvProxy * OutcomeScoring.Sleep.hrvDeltaWeight
            + completionScore * OutcomeScoring.Sleep.completionWeight
    }

    /// Energize: HR elevation (0.3) + sustained activation (0.3) + completed (0.2) + cool-down recovery (0.2).
    private func computeEnergizeScore(
        sortedSamples: [BiometricSample],
        hrDelta: Double?,
        completionScore: Double,
        duration: TimeInterval
    ) -> Double {
        // HR elevation: positive delta indicates successful arousal activation.
        let hrElevationScore: Double = {
            guard let delta = hrDelta else { return OutcomeScoring.hrDeltaMidpoint }
            // For energize, a positive HR delta is good (opposite of relaxation).
            return (OutcomeScoring.hrDeltaMidpoint + delta / OutcomeScoring.hrDeltaNormalizationRange).clamped01()
        }()

        // Sustained activation: fraction of time in elevated or peak biometric state.
        let elevatedFraction = fractionInState(.elevated, totalDuration: duration)
        let peakFraction = fractionInState(.peak, totalDuration: duration)
        let activationFraction = min(elevatedFraction + peakFraction, 1.0)
        let activationScore = activationFraction.clamped01()

        // Cool-down recovery: proxy via calm-state fraction in last portion of session.
        // If the session completed, assume cool-down was successful.
        let coolDownScore: Double = completionScore > 0 ? 0.8 : 0.2

        return hrElevationScore * OutcomeScoring.Energize.hrElevationWeight
            + activationScore * OutcomeScoring.Energize.sustainedActivationWeight
            + completionScore * OutcomeScoring.Energize.completionWeight
            + coolDownScore * OutcomeScoring.Energize.coolDownRecoveryWeight
    }

    // MARK: - Derived Metrics

    /// Computes the average HR from samples within a time window.
    private func computeWindowedHR(
        samples: [BiometricSample],
        referenceTimestamp: TimeInterval,
        windowSeconds: TimeInterval,
        fromEnd: Bool
    ) -> Double? {
        guard !samples.isEmpty else { return nil }

        let windowSamples: [BiometricSample]
        if fromEnd {
            windowSamples = samples.filter {
                $0.timestamp >= referenceTimestamp - windowSeconds
                && $0.timestamp <= referenceTimestamp
            }
        } else {
            windowSamples = samples.filter {
                $0.timestamp >= referenceTimestamp
                && $0.timestamp <= referenceTimestamp + windowSeconds
            }
        }

        guard !windowSamples.isEmpty else { return samples.last?.bpm }

        let sum = windowSamples.reduce(0.0) { $0 + $1.bpm }
        return sum / Double(windowSamples.count)
    }

    /// Finds the earliest time at which the user sustained the calm state
    /// for at least `calmDwellSeconds`.
    private func computeTimeToCalmState() -> TimeInterval? {
        guard biometricStateHistory.count >= 2 else { return nil }

        var calmStart: TimeInterval?

        for i in 0..<biometricStateHistory.count {
            let entry = biometricStateHistory[i]
            if entry.state == .calm {
                if calmStart == nil {
                    calmStart = entry.timestamp
                }
                // Check if next state change is far enough away.
                let nextTimestamp: TimeInterval
                if i + 1 < biometricStateHistory.count {
                    nextTimestamp = biometricStateHistory[i + 1].timestamp
                } else {
                    // Session ended in calm — use a large duration.
                    nextTimestamp = entry.timestamp + OutcomeScoring.calmDwellSeconds
                }
                let calmDuration = nextTimestamp - (calmStart ?? entry.timestamp)
                if calmDuration >= OutcomeScoring.calmDwellSeconds {
                    return calmStart
                }
            } else {
                calmStart = nil
            }
        }

        return nil
    }

    /// Estimates sleep onset from HR samples by detecting a sustained decline.
    ///
    /// Looks for a window where the rolling average HR drops at a rate
    /// consistent with sleep onset (> `sleepOnsetHRDropRate` BPM/min).
    private func estimateSleepOnset(samples: [BiometricSample]) -> TimeInterval? {
        guard samples.count >= OutcomeScoring.minimumHRSamples,
              let firstTimestamp = samples.first?.timestamp else { return nil }

        let windowSize = OutcomeScoring.sleepOnsetWindowSeconds

        // Slide a window across the session looking for sustained HR decline.
        var windowStart = firstTimestamp
        let sessionEnd = samples.last?.timestamp ?? firstTimestamp

        while windowStart + windowSize <= sessionEnd {
            let windowEnd = windowStart + windowSize
            let windowSamples = samples.filter {
                $0.timestamp >= windowStart && $0.timestamp <= windowEnd
            }

            guard windowSamples.count >= OutcomeScoring.sleepOnsetMinWindowSamples else {
                windowStart += windowSize / 2.0
                continue
            }

            let firstHalf = windowSamples.prefix(windowSamples.count / 2)
            let secondHalf = windowSamples.suffix(windowSamples.count / 2)

            let avgFirst = firstHalf.reduce(0.0) { $0 + $1.bpm } / Double(firstHalf.count)
            let avgSecond = secondHalf.reduce(0.0) { $0 + $1.bpm } / Double(secondHalf.count)

            let dropBPM = avgFirst - avgSecond
            let durationMinutes = windowSize / 60.0
            let dropRate = dropBPM / durationMinutes

            if dropRate >= OutcomeScoring.sleepOnsetHRDropRate {
                return windowStart - firstTimestamp
            }

            windowStart += windowSize / 2.0
        }

        return nil
    }

    /// Computes the fraction of session time spent in a given biometric state.
    ///
    /// - Parameters:
    ///   - state: The target biometric state.
    ///   - totalDuration: Total session duration. If nil, uses time span from history.
    private func fractionInState(_ state: BiometricState, totalDuration: TimeInterval?) -> Double {
        guard biometricStateHistory.count >= 2 else { return 0.0 }

        guard let lastEntry = biometricStateHistory.last,
              let firstEntry = biometricStateHistory.first else { return 0.0 }
        let total = totalDuration ?? (lastEntry.timestamp - firstEntry.timestamp)
        guard total > 0 else { return 0.0 }

        var timeInState: TimeInterval = 0

        for i in 0..<(biometricStateHistory.count - 1) where biometricStateHistory[i].state == state {
            let segmentDuration = biometricStateHistory[i + 1].timestamp - biometricStateHistory[i].timestamp
            timeInState += segmentDuration
        }

        // Account for the last segment if it matches.
        if let last = biometricStateHistory.last, last.state == state {
            let remaining = total - (last.timestamp - (biometricStateHistory.first?.timestamp ?? 0))
            if remaining > 0 {
                timeInState += remaining
            }
        }

        return (timeInState / total).clamped01()
    }

    /// Computes alignment between check-in mood and actual biometric state.
    ///
    /// Check-in mood is on a 0-1 scale (wired to calm).
    /// Biometric state is mapped: calm=1.0, focused=0.7, elevated=0.3, peak=0.0.
    /// Alignment = 1.0 - |mood - biometricMapping|.
    private func computeCheckInBiometricAlignment() -> Double? {
        guard let mood = checkInMood,
              !biometricStateHistory.isEmpty else { return nil }

        // Use the dominant state from the first third of the session.
        let firstThirdEnd = biometricStateHistory.last.map {
            $0.timestamp / OutcomeScoring.earlySessionFraction
        } ?? 0

        let earlyStates = biometricStateHistory.filter { $0.timestamp <= firstThirdEnd }
        guard !earlyStates.isEmpty else { return nil }

        // Count occurrences of each state in the early period.
        var stateCounts: [BiometricState: Int] = [:]
        for entry in earlyStates {
            stateCounts[entry.state, default: 0] += 1
        }

        let dominantState = stateCounts.max(by: { $0.value < $1.value })?.key ?? .focused

        let biometricMapping: Double
        switch dominantState {
        case .calm: biometricMapping = OutcomeScoring.StateMoodMapping.calm
        case .focused: biometricMapping = OutcomeScoring.StateMoodMapping.focused
        case .elevated: biometricMapping = OutcomeScoring.StateMoodMapping.elevated
        case .peak: biometricMapping = OutcomeScoring.StateMoodMapping.peak
        }

        return 1.0 - abs(mood - biometricMapping)
    }

    // MARK: - Statistics Helpers

    /// Computes the standard deviation of an array of Doubles.
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let count = Double(values.count)
        let mean = values.reduce(0.0, +) / count
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / count
        return variance.squareRoot()
    }
}

// MARK: - Clamping Helpers

private extension Double {

    /// Clamps a value to 0.0...1.0.
    func clamped01() -> Double {
        min(max(self, 0.0), 1.0)
    }
}
