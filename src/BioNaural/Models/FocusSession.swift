// FocusSession.swift
// BioNaural
//
// SwiftData model for session history. Each completed (or abandoned) session
// produces one FocusSession record. Complex data (adaptation events, melodic
// layer IDs, feedback tags) is stored as Codable arrays — no nested @Model
// relationships.

import Foundation
import BioNauralShared
import SwiftData
/// Persistent record of a single BioNaural session.
///
/// Captures everything needed for the learning system: audio parameters,
/// biometric outcomes, user feedback, and adaptation history. Stored in
/// SwiftData as a flat schema — complex data uses Codable JSON columns.
@Model
public final class FocusSession {
    // MARK: - Identity
    /// Unique session identifier.
    @Attribute(.unique)
    public var id: UUID
    // MARK: - Timing
    /// When the session began.
    public var startDate: Date
    /// When the session ended. `nil` if the session is still in progress.
    public var endDate: Date?
    /// Total session duration in seconds (wall clock, not audio time).
    public var durationSeconds: Int
    // MARK: - Mode
    /// The session mode stored as a raw `FocusMode` string value.
    /// SwiftData does not reliably persist Swift enums, so we store the
    /// `rawValue` and provide a computed accessor.
    public var mode: String
    // MARK: - Biometric Outcomes
    /// Average heart rate across the session (BPM). `nil` if no HR data.
    public var averageHeartRate: Double?
    /// Average heart-rate variability across the session (ms). `nil` if unavailable.
    public var averageHRV: Double?
    /// Minimum heart rate observed during the session (BPM).
    public var minHeartRate: Double?
    /// Maximum heart rate observed during the session (BPM).
    public var maxHeartRate: Double?
    // MARK: - Audio Parameters
    /// Binaural beat frequency at session start (Hz).
    public var beatFrequencyStart: Double
    /// Binaural beat frequency at session end (Hz). May differ from start
    /// if adaptation occurred.
    public var beatFrequencyEnd: Double
    /// Carrier (base) frequency used for the session (Hz).
    public var carrierFrequency: Double
    // MARK: - Adaptation History (Codable JSON)
    /// Ordered list of every adaptive frequency change during the session.
    /// Stored as a JSON-encoded `[AdaptationEventRecord]`.
    public var adaptationEvents: [AdaptationEventRecord]
    // MARK: - Sound Selections
    /// Identifier of the ambient sound bed used. `nil` if none.
    public var ambientBedID: String?
    /// Identifiers of melodic layers played during the session (may include
    /// multiple due to crossfades). Stored as a JSON-encoded `[String]`.
    public var melodicLayerIDs: [String]
    // MARK: - Session Outcome
    /// Whether the user completed the session (vs. abandoning early).
    public var wasCompleted: Bool
    /// Post-session thumbs rating: `1` = thumbs up, `-1` = thumbs down,
    /// `nil` = no rating given.
    public var thumbsRating: Int?
    /// Optional post-session feedback tags (e.g. "too busy", "loved it").
    /// Stored as a JSON-encoded `[String]`.
    public var feedbackTags: [String]?
    // MARK: - Pre-Session Check-In
    /// Self-reported mood from the pre-session check-in. Ranges from
    /// `0.0` (wired/anxious) to `1.0` (calm/tired). `nil` if skipped.
    public var checkInMood: Double?
    /// The focus mode the user said they wanted, stored as a `FocusMode`
    /// raw value. `nil` if the check-in was skipped.
    public var checkInGoal: String?
    // MARK: - Computed Scores
    /// Biometric success score computed at session end. Ranges from `0.0`
    /// (no improvement) to `1.0` (strong improvement). `nil` if insufficient
    /// biometric data.
    public var biometricSuccessScore: Double?
    // MARK: - Initialization
    /// Creates a new session record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - startDate: When the session began.
    ///   - endDate: When the session ended (`nil` if still active).
    ///   - mode: Session mode as a `FocusMode` raw value string.
    ///   - durationSeconds: Total duration in seconds.
    ///   - averageHeartRate: Mean HR across the session (BPM), or `nil`.
    ///   - averageHRV: Mean HRV across the session (ms), or `nil`.
    ///   - minHeartRate: Lowest HR observed (BPM), or `nil`.
    ///   - maxHeartRate: Highest HR observed (BPM), or `nil`.
    ///   - beatFrequencyStart: Starting beat frequency (Hz).
    ///   - beatFrequencyEnd: Ending beat frequency (Hz).
    ///   - carrierFrequency: Carrier frequency (Hz).
    ///   - adaptationEvents: Array of adaptation records.
    ///   - ambientBedID: Ambient sound bed identifier, or `nil`.
    ///   - melodicLayerIDs: Melodic layer identifiers.
    ///   - wasCompleted: Whether the session was completed.
    ///   - thumbsRating: Post-session rating (1, -1, or `nil`).
    ///   - feedbackTags: Optional feedback tag strings.
    ///   - checkInMood: Pre-session mood (0-1), or `nil`.
    ///   - checkInGoal: Pre-session goal as `FocusMode` raw value, or `nil`.
    ///   - biometricSuccessScore: Computed success score (0-1), or `nil`.
    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        mode: String,
        durationSeconds: Int,
        averageHeartRate: Double? = nil,
        averageHRV: Double? = nil,
        minHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        beatFrequencyStart: Double,
        beatFrequencyEnd: Double,
        carrierFrequency: Double,
        adaptationEvents: [AdaptationEventRecord] = [],
        ambientBedID: String? = nil,
        melodicLayerIDs: [String] = [],
        wasCompleted: Bool,
        thumbsRating: Int? = nil,
        feedbackTags: [String]? = nil,
        checkInMood: Double? = nil,
        checkInGoal: String? = nil,
        biometricSuccessScore: Double? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.averageHeartRate = averageHeartRate
        self.averageHRV = averageHRV
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.beatFrequencyStart = beatFrequencyStart
        self.beatFrequencyEnd = beatFrequencyEnd
        self.carrierFrequency = carrierFrequency
        self.adaptationEvents = adaptationEvents
        self.ambientBedID = ambientBedID
        self.melodicLayerIDs = melodicLayerIDs
        self.wasCompleted = wasCompleted
        self.thumbsRating = thumbsRating
        self.feedbackTags = feedbackTags
        self.checkInMood = checkInMood
        self.checkInGoal = checkInGoal
        self.biometricSuccessScore = biometricSuccessScore
    }
    // MARK: - Convenience Computed Properties
    /// The session mode as a typed `FocusMode` enum value.
    /// Returns `nil` if the stored string does not match any known case
    /// (defensive against future mode additions).
    public var focusMode: FocusMode? {
        FocusMode(rawValue: mode)
    }

    /// Session duration as a `TimeInterval` for use with date arithmetic
    /// and formatting APIs.
    public var duration: TimeInterval {
        TimeInterval(durationSeconds)
    }
}
