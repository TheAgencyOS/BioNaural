// SoundDNASample.swift
// BioNaural
//
// SwiftData model for a song analyzed via Sound DNA capture. Each sample
// stores the raw musical features extracted from a real song — either via
// ShazamKit identification + Apple Music preview analysis, or via on-device
// microphone capture analysis. These features feed the Sonic Profile,
// informing ambient and melodic layer selection within the adaptive system.
//
// Sound DNA samples never touch the entrainment layer. They influence
// Layers 2 (ambient) and 3 (melodic) only. The biometric feedback loop
// and mode selection always have priority over Sound DNA preferences.

import Foundation
import BioNauralShared
import SwiftData

// MARK: - Sound DNA Source

/// How the audio sample was acquired for analysis.
public enum SoundDNASource: String, Codable, Sendable {

    /// Song identified via ShazamKit, features extracted from Apple Music preview.
    case shazamPreview

    /// Song identified via ShazamKit, features extracted from mic capture.
    case shazamMic

    /// Song not identified, features extracted from mic capture only.
    case micOnly
}

// MARK: - Musical Scale

/// Simplified major/minor classification from key detection.
public enum DetectedScale: String, Codable, Sendable {
    case major
    case minor
    case unknown
}

// MARK: - SoundDNASample Model

/// Persistent record of a song analyzed through the Sound DNA pipeline.
///
/// Each sample captures the musical fingerprint of a real song the user
/// sampled. The extracted features (tempo, key, brightness, warmth, energy)
/// are aggregated into the user's ``SoundProfile`` to personalize ambient
/// and melodic layer selection across all future sessions.
///
/// Sound DNA samples are distinct from ``SonicMemory`` records: SonicMemory
/// stores NLP-extracted parameters from text descriptions, while SoundDNA
/// stores DSP-extracted parameters from actual audio analysis.
@Model
public final class SoundDNASample {

    // MARK: - Identity

    /// Unique sample identifier.
    @Attribute(.unique)
    public var id: UUID

    // MARK: - Song Identification (ShazamKit)

    /// Song title from ShazamKit match. `nil` if unidentified.
    public var songTitle: String?

    /// Artist name from ShazamKit match. `nil` if unidentified.
    public var artistName: String?

    /// Shazam media item identifier. `nil` if unidentified.
    public var shazamID: String?

    /// Apple Music catalog identifier. `nil` if unidentified or unavailable.
    public var appleMusicID: String?

    /// Genre string from ShazamKit metadata. `nil` if unavailable.
    public var genre: String?

    // MARK: - Extracted Musical Features

    /// Detected tempo in beats per minute. `nil` if no clear beat detected.
    public var extractedBPM: Double?

    /// Detected musical key as a note name (e.g., "C", "F#", "Bb").
    /// `nil` if key detection failed or confidence was too low.
    public var extractedKey: String?

    /// Major/minor classification. Stored as ``DetectedScale`` raw value.
    public var extractedScale: String

    /// Spectral centroid mapped to brightness [0.0 = dark, 1.0 = bright].
    /// Normalized against ``SoundDNAConfig.spectralCentroidRange``.
    public var extractedBrightness: Double

    /// Perceived warmth [0.0 = cold/clinical, 1.0 = warm/organic].
    /// Derived from low-to-mid frequency energy ratio.
    public var extractedWarmth: Double

    /// Overall energy level [0.0 = very calm, 1.0 = very energetic].
    /// Composite of RMS loudness, spectral centroid, and onset density.
    public var extractedEnergy: Double

    /// Melodic density [0.0 = sparse/minimal, 1.0 = dense/layered].
    /// Derived from spectral flatness and harmonic-to-noise ratio.
    public var extractedDensity: Double

    /// Raw spectral centroid in Hz. Stored for potential future use.
    public var spectralCentroidHz: Double?

    // MARK: - Analysis Metadata

    /// How the sample was captured.
    /// Stored as ``SoundDNASource`` raw value.
    public var source: String

    /// Overall confidence in the extracted features [0.0 - 1.0].
    /// Higher when analyzing clean preview audio vs. noisy mic capture.
    public var analysisConfidence: Double

    /// Duration of the analyzed audio segment in seconds.
    public var analyzedDurationSeconds: Double

    // MARK: - Integration State

    /// Whether this sample has been incorporated into the user's SoundProfile.
    public var isIntegratedIntoProfile: Bool

    /// When this sample was created.
    public var dateCreated: Date

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        songTitle: String? = nil,
        artistName: String? = nil,
        shazamID: String? = nil,
        appleMusicID: String? = nil,
        genre: String? = nil,
        extractedBPM: Double? = nil,
        extractedKey: String? = nil,
        extractedScale: String = DetectedScale.unknown.rawValue,
        extractedBrightness: Double = 0.5,
        extractedWarmth: Double = 0.5,
        extractedEnergy: Double = 0.5,
        extractedDensity: Double = 0.5,
        spectralCentroidHz: Double? = nil,
        source: String = SoundDNASource.micOnly.rawValue,
        analysisConfidence: Double = 0.5,
        analyzedDurationSeconds: Double = 0,
        isIntegratedIntoProfile: Bool = false,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.songTitle = songTitle
        self.artistName = artistName
        self.shazamID = shazamID
        self.appleMusicID = appleMusicID
        self.genre = genre
        self.extractedBPM = extractedBPM
        self.extractedKey = extractedKey
        self.extractedScale = extractedScale
        self.extractedBrightness = extractedBrightness
        self.extractedWarmth = extractedWarmth
        self.extractedEnergy = extractedEnergy
        self.extractedDensity = extractedDensity
        self.spectralCentroidHz = spectralCentroidHz
        self.source = source
        self.analysisConfidence = analysisConfidence
        self.analyzedDurationSeconds = analyzedDurationSeconds
        self.isIntegratedIntoProfile = isIntegratedIntoProfile
        self.dateCreated = dateCreated
    }

    // MARK: - Convenience Computed Properties

    /// The capture source as a typed ``SoundDNASource`` enum value.
    public var dnaSource: SoundDNASource? {
        SoundDNASource(rawValue: source)
    }

    /// The detected scale as a typed ``DetectedScale`` enum value.
    public var detectedScale: DetectedScale? {
        DetectedScale(rawValue: extractedScale)
    }

    /// Display name combining title and artist, or a fallback.
    public var displayName: String {
        if let title = songTitle, let artist = artistName {
            return "\(title) — \(artist)"
        } else if let title = songTitle {
            return title
        } else {
            return "Unknown Song"
        }
    }

    /// Whether the song was identified by ShazamKit.
    public var isIdentified: Bool {
        shazamID != nil
    }
}
