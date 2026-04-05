// SonicMemory.swift
// BioNaural
//
// SwiftData model for user-described sound memories. Each SonicMemory
// captures an emotional sound anchor the user describes in their own words
// (e.g., "rain on a tin roof at my cabin") along with extracted sonic
// dimensions that the audio engine uses to shape sessions.

import Foundation
import BioNauralShared
import SwiftData

// MARK: - Emotional Association

/// The emotional quality a user associates with a sound memory.
///
/// Stored as a `String` raw value in the SwiftData model. The adaptive
/// audio engine uses this to weight melodic and ambient layer selection.
public enum EmotionalAssociation: String, Codable, CaseIterable, Identifiable, Sendable {

    case calm
    case focused
    case energized
    case nostalgic
    case safe
    case joyful

    public var id: String { rawValue }

    /// Human-readable label for display in the UI.
    public var displayName: String {
        switch self {
        case .calm:      return "Calm"
        case .focused:   return "Focused"
        case .energized: return "Energized"
        case .nostalgic: return "Nostalgic"
        case .safe:      return "Safe"
        case .joyful:    return "Joyful"
        }
    }

    /// SF Symbol name for the association.
    public var systemImageName: String {
        switch self {
        case .calm:      return "leaf.fill"
        case .focused:   return "scope"
        case .energized: return "bolt.fill"
        case .nostalgic: return "clock.arrow.circlepath"
        case .safe:      return "house.fill"
        case .joyful:    return "sun.max.fill"
        }
    }
}

// MARK: - SonicMemory Model

/// Persistent record of a user-described sound memory.
///
/// Sound memories are emotional anchors the user provides in natural language.
/// The system extracts sonic dimensions (warmth, rhythm, density, brightness,
/// tempo) and uses them to personalize ambient and melodic layer selection.
/// Over time, biometric correlations reveal which memories predict the best
/// session outcomes for this user.
@Model
public final class SonicMemory {

    // MARK: - Identity

    /// Unique memory identifier.
    @Attribute(.unique)
    public var id: UUID

    // MARK: - User Input

    /// The user's original description of the sound memory.
    /// Preserved verbatim for display and re-analysis.
    public var userDescription: String

    // MARK: - Extracted Sonic Dimensions

    /// Warmth dimension (0 = cool/clinical, 1 = warm/organic).
    /// Extracted from the user's description via NLP analysis.
    public var extractedWarmth: Double

    /// Rhythm dimension (0 = static/ambient, 1 = highly rhythmic).
    /// Extracted from the user's description via NLP analysis.
    public var extractedRhythm: Double

    /// Density dimension (0 = sparse/minimal, 1 = dense/layered).
    /// Extracted from the user's description via NLP analysis.
    public var extractedDensity: Double

    /// Brightness dimension (0 = dark/muffled, 1 = bright/crisp).
    /// Extracted from the user's description via NLP analysis.
    public var extractedBrightness: Double

    /// Estimated tempo in BPM if rhythm is relevant. `nil` for
    /// purely ambient or non-rhythmic memories.
    public var extractedTempo: Double?

    // MARK: - Derived Sound Tags

    /// Instrument tags derived from the description (e.g., "piano", "strings").
    /// Used to filter the melodic layer library. Stored as a JSON-encoded `[String]`.
    public var preferredInstruments: [String]

    /// Ambient sound tags derived from the description (e.g., "rain", "wind", "fire").
    /// Used to select ambient bed candidates. Stored as a JSON-encoded `[String]`.
    public var preferredAmbientTags: [String]

    // MARK: - Emotional & Mode Context

    /// The emotional quality the user associates with this memory,
    /// stored as an `EmotionalAssociation` raw value string.
    public var emotionalAssociation: String

    /// The focus mode this memory is specifically tied to, stored as a
    /// `FocusMode` raw value string. `nil` if the memory is mode-agnostic.
    public var associatedMode: String?

    // MARK: - Learning Metrics

    /// How strongly this sound memory predicts positive biometric outcomes
    /// (0 = no correlation, 1 = strong positive correlation). Updated by the
    /// learning system after each session that references this memory. `nil`
    /// until sufficient data is collected.
    public var biometricCorrelation: Double?

    /// Total number of sessions that have referenced this sound memory.
    public var sessionCount: Int

    /// Running average of biometric success scores for sessions that used
    /// this memory. `nil` until at least one scored session exists.
    public var averageSuccessScore: Double?

    // MARK: - Timestamps

    /// When the memory was created.
    public var dateCreated: Date

    /// When this memory was last used in a session. `nil` if never used.
    public var lastUsed: Date?

    // MARK: - Initialization

    /// Creates a new sound memory record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - userDescription: The user's original description of the sound.
    ///   - extractedWarmth: Warmth dimension (0-1).
    ///   - extractedRhythm: Rhythm dimension (0-1).
    ///   - extractedDensity: Density dimension (0-1).
    ///   - extractedBrightness: Brightness dimension (0-1).
    ///   - extractedTempo: Estimated BPM, or `nil`.
    ///   - preferredInstruments: Instrument tags derived from description.
    ///   - preferredAmbientTags: Ambient sound tags derived from description.
    ///   - emotionalAssociation: Emotional quality as `EmotionalAssociation` raw value.
    ///   - associatedMode: Linked `FocusMode` raw value, or `nil`.
    ///   - biometricCorrelation: Outcome correlation score (0-1), or `nil`.
    ///   - sessionCount: Number of sessions using this memory. Defaults to `0`.
    ///   - averageSuccessScore: Running success average, or `nil`.
    ///   - dateCreated: Creation date. Defaults to now.
    ///   - lastUsed: Date last used in a session, or `nil`.
    public init(
        id: UUID = UUID(),
        userDescription: String,
        extractedWarmth: Double,
        extractedRhythm: Double,
        extractedDensity: Double,
        extractedBrightness: Double,
        extractedTempo: Double? = nil,
        preferredInstruments: [String] = [],
        preferredAmbientTags: [String] = [],
        emotionalAssociation: String = EmotionalAssociation.calm.rawValue,
        associatedMode: String? = nil,
        biometricCorrelation: Double? = nil,
        sessionCount: Int = 0,
        averageSuccessScore: Double? = nil,
        dateCreated: Date = Date(),
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.userDescription = userDescription
        self.extractedWarmth = extractedWarmth
        self.extractedRhythm = extractedRhythm
        self.extractedDensity = extractedDensity
        self.extractedBrightness = extractedBrightness
        self.extractedTempo = extractedTempo
        self.preferredInstruments = preferredInstruments
        self.preferredAmbientTags = preferredAmbientTags
        self.emotionalAssociation = emotionalAssociation
        self.associatedMode = associatedMode
        self.biometricCorrelation = biometricCorrelation
        self.sessionCount = sessionCount
        self.averageSuccessScore = averageSuccessScore
        self.dateCreated = dateCreated
        self.lastUsed = lastUsed
    }

    // MARK: - Convenience Computed Properties

    /// The emotional association as a typed `EmotionalAssociation` enum value.
    /// Returns `nil` if the stored string does not match any known case.
    public var emotion: EmotionalAssociation? {
        EmotionalAssociation(rawValue: emotionalAssociation)
    }

    /// The associated focus mode as a typed `FocusMode` enum value.
    /// Returns `nil` if no mode is set or the stored string is unrecognized.
    public var focusMode: FocusMode? {
        guard let raw = associatedMode else { return nil }
        return FocusMode(rawValue: raw)
    }
}
