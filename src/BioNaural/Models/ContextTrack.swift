// ContextTrack.swift
// BioNaural
//
// SwiftData model for purpose-built audio tracks tied to life events.
// A ContextTrack locks specific audio parameters (ambient bed, carrier,
// beat range, melodic palette) so the user gets a consistent sonic
// experience for recurring situations like exam prep or pre-performance
// routines. Tracks can auto-archive after an event date passes.

import Foundation
import BioNauralShared
import SwiftData

// MARK: - Track Purpose

/// The purpose category for a context-specific audio track.
///
/// Stored as a `String` raw value in the SwiftData model. Determines
/// default parameter ranges and UI presentation.
public enum TrackPurpose: String, Codable, CaseIterable, Identifiable, Sendable {

    case study
    case prePerformance
    case recovery
    case sleepPrep
    case custom

    public var id: String { rawValue }

    /// Human-readable label for display in the UI.
    public var displayName: String {
        switch self {
        case .study:          return "Study"
        case .prePerformance: return "Pre-Performance"
        case .recovery:       return "Recovery"
        case .sleepPrep:      return "Sleep Prep"
        case .custom:         return "Custom"
        }
    }

    /// SF Symbol name representing the track purpose.
    public var systemImageName: String {
        switch self {
        case .study:          return "book.fill"
        case .prePerformance: return "figure.run"
        case .recovery:       return "heart.fill"
        case .sleepPrep:      return "moon.fill"
        case .custom:         return "slider.horizontal.3"
        }
    }
}

// MARK: - ContextTrack Model

/// Persistent record of a purpose-built audio track tied to a life event.
///
/// Context tracks let users lock specific audio parameters for recurring
/// situations. Calendar event keywords can trigger automatic track selection.
/// Tracks accumulate session data and can auto-archive after an event passes.
@Model
public final class ContextTrack {

    // MARK: - Identity

    /// Unique track identifier.
    @Attribute(.unique)
    public var id: UUID

    // MARK: - User Configuration

    /// User-given name for the track (e.g., "Organic Chemistry Study Track").
    public var name: String

    /// The track's purpose category, stored as a `TrackPurpose` raw value string.
    public var purpose: String

    /// Calendar event keywords that trigger automatic selection of this track
    /// (e.g., ["exam", "final", "organic chemistry"]). Stored as a
    /// JSON-encoded `[String]`.
    public var linkedEventKeywords: [String]

    // MARK: - Locked Audio Parameters

    /// Locked ambient sound bed identifier for session consistency.
    /// `nil` if the ambient layer should adapt freely.
    public var lockedAmbientBedID: String?

    /// Locked carrier frequency (Hz) for session consistency.
    /// `nil` if the carrier should adapt freely.
    public var lockedCarrierFrequency: Double?

    /// Locked beat frequency range as `[min, max]` (Hz).
    /// `nil` if the beat frequency should adapt freely.
    /// Stored as a JSON-encoded `[Double]`.
    public var lockedBeatFrequencyRange: [Double]?

    /// Locked melodic palette tags for consistent sound character
    /// (e.g., ["piano", "ambient pad"]). Stored as a JSON-encoded `[String]`.
    public var lockedMelodicTags: [String]

    // MARK: - Relationships

    /// UUID of the `SonicMemory` used to create this track, if any.
    /// `nil` if the track was configured manually.
    public var sonicMemoryID: UUID?

    /// The focus mode for this track, stored as a `FocusMode` raw value string.
    public var mode: String

    // MARK: - Session History

    /// UUIDs of sessions that used this track, stored as string representations.
    /// Stored as a JSON-encoded `[String]`.
    public var sessionIDs: [String]

    /// Total number of sessions that have used this track.
    public var totalSessionCount: Int

    /// Running average of biometric success scores across sessions.
    /// `nil` until at least one scored session exists.
    public var averageSuccessScore: Double?

    // MARK: - Lifecycle

    /// When the track was created.
    public var dateCreated: Date

    /// Auto-archive date. `nil` means the track is permanent.
    /// When set, the track auto-archives after this date passes.
    public var activeUntil: Date?

    /// Whether the track has been manually archived by the user.
    public var isArchived: Bool

    // MARK: - Initialization

    /// Creates a new context track record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - name: User-given track name.
    ///   - purpose: Track purpose as `TrackPurpose` raw value.
    ///   - linkedEventKeywords: Calendar keywords for auto-selection.
    ///   - lockedAmbientBedID: Locked ambient bed identifier, or `nil`.
    ///   - lockedCarrierFrequency: Locked carrier frequency (Hz), or `nil`.
    ///   - lockedBeatFrequencyRange: Locked beat range `[min, max]`, or `nil`.
    ///   - lockedMelodicTags: Locked melodic palette tags.
    ///   - sonicMemoryID: Linked `SonicMemory` UUID, or `nil`.
    ///   - mode: Focus mode as `FocusMode` raw value.
    ///   - sessionIDs: Session UUID strings. Defaults to empty.
    ///   - totalSessionCount: Total sessions using this track. Defaults to `0`.
    ///   - averageSuccessScore: Running success average, or `nil`.
    ///   - dateCreated: Creation date. Defaults to now.
    ///   - activeUntil: Auto-archive date, or `nil` for permanent.
    ///   - isArchived: Whether archived. Defaults to `false`.
    public init(
        id: UUID = UUID(),
        name: String,
        purpose: String = TrackPurpose.custom.rawValue,
        linkedEventKeywords: [String] = [],
        lockedAmbientBedID: String? = nil,
        lockedCarrierFrequency: Double? = nil,
        lockedBeatFrequencyRange: [Double]? = nil,
        lockedMelodicTags: [String] = [],
        sonicMemoryID: UUID? = nil,
        mode: String = FocusMode.focus.rawValue,
        sessionIDs: [String] = [],
        totalSessionCount: Int = 0,
        averageSuccessScore: Double? = nil,
        dateCreated: Date = Date(),
        activeUntil: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.linkedEventKeywords = linkedEventKeywords
        self.lockedAmbientBedID = lockedAmbientBedID
        self.lockedCarrierFrequency = lockedCarrierFrequency
        self.lockedBeatFrequencyRange = lockedBeatFrequencyRange
        self.lockedMelodicTags = lockedMelodicTags
        self.sonicMemoryID = sonicMemoryID
        self.mode = mode
        self.sessionIDs = sessionIDs
        self.totalSessionCount = totalSessionCount
        self.averageSuccessScore = averageSuccessScore
        self.dateCreated = dateCreated
        self.activeUntil = activeUntil
        self.isArchived = isArchived
    }

    // MARK: - Convenience Computed Properties

    /// The track's focus mode as a typed `FocusMode` enum value.
    /// Returns `nil` if the stored string does not match any known case.
    public var focusMode: FocusMode? {
        FocusMode(rawValue: mode)
    }

    /// The track's purpose as a typed `TrackPurpose` enum value.
    /// Returns `nil` if the stored string does not match any known case.
    public var trackPurpose: TrackPurpose? {
        TrackPurpose(rawValue: purpose)
    }

    /// Whether the track is currently active (not archived and not past
    /// its `activeUntil` date).
    public var isActive: Bool {
        guard !isArchived else { return false }
        guard let expiry = activeUntil else { return true }
        return expiry > Date()
    }
}
