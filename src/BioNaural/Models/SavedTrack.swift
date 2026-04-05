// SavedTrack.swift
// BioNaural
//
// SwiftData model for Body Music — saved session audio parameters that
// can be replayed. When a user has a great session, they can save its
// audio fingerprint (frequencies, layers, adaptation timeline) for
// consistent replay in future sessions.

import Foundation
import BioNauralShared
import SwiftData

// MARK: - Adaptation Snapshot

/// A point-in-time snapshot of the adaptive audio state during a session.
///
/// An array of these snapshots forms the adaptation timeline, which enables
/// faithful replay of a saved session's audio evolution. Compressed and
/// stored as `Data` on the `SavedTrack` model.
public struct AdaptationSnapshot: Codable, Sendable, Equatable {

    /// Seconds elapsed since the session's start.
    public let timestamp: TimeInterval

    /// Binaural beat frequency at this moment (Hz).
    public let beatFrequency: Double

    /// Carrier (base) frequency at this moment (Hz).
    public let carrierFrequency: Double

    /// Overall audio amplitude at this moment (0-1).
    public let amplitude: Double

    /// Heart rate at this moment (BPM). `nil` if biometric data was
    /// unavailable at this point in the session.
    public let heartRate: Double?

    /// Creates a new adaptation snapshot.
    ///
    /// - Parameters:
    ///   - timestamp: Seconds since session start.
    ///   - beatFrequency: Beat frequency at this moment (Hz).
    ///   - carrierFrequency: Carrier frequency at this moment (Hz).
    ///   - amplitude: Audio amplitude at this moment (0-1).
    ///   - heartRate: Heart rate at this moment (BPM), or `nil`.
    public init(
        timestamp: TimeInterval,
        beatFrequency: Double,
        carrierFrequency: Double,
        amplitude: Double,
        heartRate: Double? = nil
    ) {
        self.timestamp = timestamp
        self.beatFrequency = beatFrequency
        self.carrierFrequency = carrierFrequency
        self.amplitude = amplitude
        self.heartRate = heartRate
    }
}

// MARK: - SavedTrack Model

/// Persistent record of a saved session's audio parameters for replay.
///
/// When a user completes a session they loved, they can save it as a
/// "Body Music" track. The saved track captures all audio parameters
/// and the full adaptation timeline so the experience can be faithfully
/// reproduced in future sessions.
@Model
public final class SavedTrack {

    // MARK: - Identity

    /// Unique saved track identifier.
    @Attribute(.unique)
    public var id: UUID

    /// UUID of the original `FocusSession` this track was saved from.
    public var sessionID: UUID

    // MARK: - Display

    /// Track name — auto-generated from session parameters or user-edited.
    public var name: String

    /// The session mode, stored as a `FocusMode` raw value string.
    public var mode: String

    /// Total session duration in seconds.
    public var durationSeconds: Int

    // MARK: - Biometric Context

    /// Average heart rate during the original session (BPM).
    /// `nil` if no biometric data was available.
    public var averageHeartRate: Double?

    // MARK: - Audio Parameters

    /// Binaural beat frequency at session start (Hz).
    public var beatFrequencyStart: Double

    /// Binaural beat frequency at session end (Hz).
    public var beatFrequencyEnd: Double

    /// Carrier (base) frequency used for the session (Hz).
    public var carrierFrequency: Double

    /// Identifier of the ambient sound bed used. `nil` if none.
    public var ambientBedID: String?

    /// Identifiers of melodic layers played during the session.
    /// Stored as a JSON-encoded `[String]`.
    public var melodicLayerIDs: [String]

    // MARK: - Adaptation Timeline

    /// Compressed biometric adaptation timeline for faithful replay.
    /// Encoded as a `[AdaptationSnapshot]` via `JSONEncoder`. `nil` if
    /// the session had no adaptive events (e.g., manual mode).
    public var adaptationTimeline: Data?

    // MARK: - Usage & Preference

    /// When this track was saved.
    public var dateSaved: Date

    /// Number of times this saved track has been replayed.
    public var playCount: Int

    /// Whether the user has marked this track as a favorite.
    public var isFavorite: Bool

    // MARK: - Initialization

    /// Creates a new saved track record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - sessionID: UUID of the original session.
    ///   - name: Track name (auto-generated or user-edited).
    ///   - mode: Session mode as `FocusMode` raw value.
    ///   - durationSeconds: Total duration in seconds.
    ///   - averageHeartRate: Mean HR during the session (BPM), or `nil`.
    ///   - beatFrequencyStart: Starting beat frequency (Hz).
    ///   - beatFrequencyEnd: Ending beat frequency (Hz).
    ///   - carrierFrequency: Carrier frequency (Hz).
    ///   - ambientBedID: Ambient sound bed identifier, or `nil`.
    ///   - melodicLayerIDs: Melodic layer identifiers.
    ///   - adaptationTimeline: Encoded adaptation snapshots, or `nil`.
    ///   - dateSaved: Save date. Defaults to now.
    ///   - playCount: Replay count. Defaults to `0`.
    ///   - isFavorite: Favorite flag. Defaults to `false`.
    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        name: String,
        mode: String,
        durationSeconds: Int,
        averageHeartRate: Double? = nil,
        beatFrequencyStart: Double,
        beatFrequencyEnd: Double,
        carrierFrequency: Double,
        ambientBedID: String? = nil,
        melodicLayerIDs: [String] = [],
        adaptationTimeline: Data? = nil,
        dateSaved: Date = Date(),
        playCount: Int = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.sessionID = sessionID
        self.name = name
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.averageHeartRate = averageHeartRate
        self.beatFrequencyStart = beatFrequencyStart
        self.beatFrequencyEnd = beatFrequencyEnd
        self.carrierFrequency = carrierFrequency
        self.ambientBedID = ambientBedID
        self.melodicLayerIDs = melodicLayerIDs
        self.adaptationTimeline = adaptationTimeline
        self.dateSaved = dateSaved
        self.playCount = playCount
        self.isFavorite = isFavorite
    }

    // MARK: - Convenience Computed Properties

    /// The session mode as a typed `FocusMode` enum value.
    /// Returns `nil` if the stored string does not match any known case.
    public var focusMode: FocusMode? {
        FocusMode(rawValue: mode)
    }

    /// Session duration as a `TimeInterval` for use with date arithmetic
    /// and formatting APIs.
    public var duration: TimeInterval {
        TimeInterval(durationSeconds)
    }

    /// Human-readable duration string (e.g., "25:00" or "1:05:30").
    public var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
