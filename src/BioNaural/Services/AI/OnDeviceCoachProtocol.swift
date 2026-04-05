// OnDeviceCoachProtocol.swift
// BioNaural
//
// Protocol contract for on-device AI coaching powered by Apple Foundation
// Models (iOS 26+). Separated from the implementation so callers can depend
// on the protocol without importing FoundationModels, and so a mock can be
// injected for testing.

import Foundation

// MARK: - Input Types

/// Summarized session history fed into the on-device model for
/// recommendation generation. All fields are pre-computed aggregates —
/// no raw HealthKit samples cross this boundary.
public struct OnDeviceSessionSummary: Sendable {

    /// Session mode raw value (e.g. "focus", "sleep").
    public let mode: String

    /// Session duration in minutes.
    public let durationMinutes: Int

    /// Hour of day the session started (0-23).
    public let hourOfDay: Int

    /// Biometric success score (0.0-1.0), or `nil` if unavailable.
    public let biometricSuccessScore: Double?

    /// Ambient bed identifier used, or `nil`.
    public let ambientBedID: String?

    /// Melodic layer identifiers played during the session.
    public let melodicLayerIDs: [String]

    public init(
        mode: String,
        durationMinutes: Int,
        hourOfDay: Int,
        biometricSuccessScore: Double?,
        ambientBedID: String?,
        melodicLayerIDs: [String]
    ) {
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.hourOfDay = hourOfDay
        self.biometricSuccessScore = biometricSuccessScore
        self.ambientBedID = ambientBedID
        self.melodicLayerIDs = melodicLayerIDs
    }
}

/// Current context used alongside session history to generate a
/// recommendation. Captures the user's present state without raw samples.
public struct OnDeviceCurrentContext: Sendable {

    /// Current hour of day (0-23).
    public let currentHour: Int

    /// Last night's sleep quality as a normalized score (0.0-1.0),
    /// or `nil` if unavailable from HealthKit.
    public let lastNightSleepQuality: Double?

    /// Current resting heart rate (BPM), or `nil` if unavailable.
    public let currentRestingHR: Double?

    public init(
        currentHour: Int,
        lastNightSleepQuality: Double?,
        currentRestingHR: Double?
    ) {
        self.currentHour = currentHour
        self.lastNightSleepQuality = lastNightSleepQuality
        self.currentRestingHR = currentRestingHR
    }
}

/// Biometric deltas from a just-completed session, used for post-session
/// insight generation.
public struct OnDevicePostSessionInput: Sendable {

    /// Session mode raw value.
    public let mode: String

    /// Session duration in minutes.
    public let durationMinutes: Int

    /// Heart rate change from start to end (BPM). Negative = HR decreased.
    public let heartRateDelta: Double?

    /// HRV change from start to end (ms). Positive = HRV increased.
    public let hrvDelta: Double?

    /// Ambient bed identifier used, or `nil`.
    public let ambientBedID: String?

    /// Melodic layer identifiers played.
    public let melodicLayerIDs: [String]

    /// Biometric success score (0.0-1.0), or `nil`.
    public let biometricSuccessScore: Double?

    public init(
        mode: String,
        durationMinutes: Int,
        heartRateDelta: Double?,
        hrvDelta: Double?,
        ambientBedID: String?,
        melodicLayerIDs: [String],
        biometricSuccessScore: Double?
    ) {
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.heartRateDelta = heartRateDelta
        self.hrvDelta = hrvDelta
        self.ambientBedID = ambientBedID
        self.melodicLayerIDs = melodicLayerIDs
        self.biometricSuccessScore = biometricSuccessScore
    }
}

// MARK: - Output Types

/// A session recommendation produced by the on-device model.
public struct OnDeviceRecommendation: Sendable, Equatable {

    /// Recommended session mode raw value (e.g. "focus").
    public let mode: String

    /// Recommended duration in minutes.
    public let durationMinutes: Int

    /// Recommended ambient bed identifier, or `nil` for no preference.
    public let ambientBedID: String?

    /// A 1-2 sentence explanation of why this session is recommended.
    /// Written in scientific-confidence tone, no exclamation marks.
    public let explanation: String

    public init(
        mode: String,
        durationMinutes: Int,
        ambientBedID: String?,
        explanation: String
    ) {
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.ambientBedID = ambientBedID
        self.explanation = explanation
    }
}

/// A post-session insight produced by the on-device model.
public struct OnDevicePostSessionInsight: Sendable, Equatable {

    /// Brief scientific-tone insight about the session outcome (1-3 sentences).
    public let insight: String

    public init(insight: String) {
        self.insight = insight
    }
}

// MARK: - Protocol

/// Contract for on-device AI coaching using Apple Foundation Models.
///
/// Implementations must gracefully handle unavailability (device does not
/// support Apple Intelligence, user has it disabled, model not downloaded).
/// All methods return optional results — `nil` means the service could not
/// generate output and the caller should fall back to rule-based logic or
/// show nothing.
public protocol OnDeviceCoachProtocol: AnyObject, Sendable {

    /// Whether the on-device language model is available and ready.
    /// Returns `false` on devices without Apple Intelligence or when the
    /// model has not been downloaded.
    var isAvailable: Bool { get }

    /// Generates a personalized session recommendation from recent session
    /// history and current biometric context.
    ///
    /// - Parameters:
    ///   - sessions: The last 10 (or fewer) completed sessions, most recent first.
    ///   - context: Current time-of-day, sleep quality, and resting HR.
    /// - Returns: A recommendation, or `nil` if the model is unavailable.
    func generateRecommendation(
        from sessions: [OnDeviceSessionSummary],
        context: OnDeviceCurrentContext
    ) async -> OnDeviceRecommendation?

    /// Generates a brief post-session insight from the just-completed session.
    ///
    /// - Parameter input: Biometric deltas and session metadata.
    /// - Returns: A scientific-tone insight, or `nil` if the model is unavailable.
    func generatePostSessionInsight(
        from input: OnDevicePostSessionInput
    ) async -> OnDevicePostSessionInsight?
}
