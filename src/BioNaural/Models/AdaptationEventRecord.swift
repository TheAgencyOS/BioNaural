// AdaptationEventRecord.swift
// BioNaural
//
// Codable record of a single adaptive frequency change during a session.
// Stored as a JSON array inside FocusSession (flat schema — no nested @Model).

import Foundation

/// A single adaptation event that occurred during a biometric-driven session.
///
/// When the adaptive algorithm adjusts the binaural beat frequency in response
/// to a heart-rate change, one of these records is appended to the session's
/// `adaptationEvents` array. The full history enables post-session analytics
/// and feeds the learning system.
public struct AdaptationEventRecord: Codable, Sendable, Equatable {

    // MARK: - Properties

    /// Seconds elapsed since the session's `startDate`.
    public let timestamp: TimeInterval

    /// Human-readable reason for the adaptation (e.g. "HR elevated", "trend rising").
    public let reason: String

    /// Beat frequency (Hz) before this adaptation was applied.
    public let oldBeatFrequency: Double

    /// Beat frequency (Hz) after this adaptation was applied.
    public let newBeatFrequency: Double

    /// Heart rate (BPM) at the moment the adaptation was triggered.
    public let heartRateAtTime: Double

    // MARK: - Initialization

    /// Creates a new adaptation event record.
    ///
    /// - Parameters:
    ///   - timestamp: Seconds since session start.
    ///   - reason: Description of what triggered the adaptation.
    ///   - oldBeatFrequency: Beat frequency before adaptation (Hz).
    ///   - newBeatFrequency: Beat frequency after adaptation (Hz).
    ///   - heartRateAtTime: Heart rate at the moment of adaptation (BPM).
    public init(
        timestamp: TimeInterval,
        reason: String,
        oldBeatFrequency: Double,
        newBeatFrequency: Double,
        heartRateAtTime: Double
    ) {
        self.timestamp = timestamp
        self.reason = reason
        self.oldBeatFrequency = oldBeatFrequency
        self.newBeatFrequency = newBeatFrequency
        self.heartRateAtTime = heartRateAtTime
    }
}
