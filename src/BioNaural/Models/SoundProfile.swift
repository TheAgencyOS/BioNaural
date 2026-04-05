// SoundProfile.swift
// BioNaural
//
// SwiftData model for learned sound preferences. The learning system
// updates this profile after every session based on biometric outcomes
// and user feedback. Complex data (instrument weights, energy prefs,
// success scores, disliked sounds) is stored as Codable dictionaries
// and arrays — no nested @Model relationships.

import Foundation
import BioNauralShared
import SwiftData
/// Persistent learned sound preferences that evolve with each session.
///
/// The melodic layer's `SoundSelector` reads this profile to rank
/// candidate sounds. After every session, `updateFromOutcome(_:)` adjusts
/// weights based on biometric success and user feedback. Over time the
/// profile converges on the sound palette that works best for this user.
@Model
public final class SoundProfile {
    // MARK: - Identity
    /// Unique profile identifier.
    @Attribute(.unique)
    public var id: UUID
    // MARK: - Instrument Preferences (Codable Dict)
    /// Per-instrument affinity weights. Keys are instrument names
    /// (e.g. "piano", "strings", "pads"), values range from `0.0`
    /// (never select) to `1.0` (strongly prefer).
    public var instrumentWeights: [String: Double]
    // MARK: - Mode-Specific Energy Preferences (Codable Dict)
    /// Preferred energy level per mode. Keys are `FocusMode` raw values,
    /// values range from `0.0` (very low energy) to `1.0` (high energy).
    public var energyPreference: [String: Double]
    // MARK: - Global Timbral Preferences
    /// Preferred spectral brightness. `0.0` = dark/warm, `1.0` = bright/airy.
    public var brightnessPreference: Double
    /// Preferred melodic density. `0.0` = sparse/minimal, `1.0` = dense/layered.
    public var densityPreference: Double
    // MARK: - Outcome Tracking (Codable Dict / Array)
    /// Cumulative success scores per sound. Keys are sound identifiers,
    /// values are running weighted sums of `biometricSuccessScore` from
    /// sessions where that sound was played. Higher = more effective.
    public var successfulSounds: [String: Double]
    /// Sound identifiers that received a thumbs-down rating. These are
    /// deprioritized (but not permanently excluded) by the `SoundSelector`.
    public var dislikedSounds: [String]
    // MARK: - Sound DNA Preferences

    /// Preferred tempo affinity from Sound DNA analysis (BPM).
    /// `nil` if no Sound DNA samples have been analyzed. Used by
    /// the melodic layer to select tempo-compatible content.
    public var tempoAffinity: Double?

    /// Preferred spectral warmth from Sound DNA analysis [0.0 - 1.0].
    /// `nil` if no Sound DNA samples have been analyzed.
    public var warmthPreference: Double?

    /// Preferred musical key from Sound DNA analysis (e.g., "A", "C#").
    /// `nil` if no Sound DNA samples have been analyzed or no clear
    /// key preference emerged.
    public var keyPreference: String?

    /// Number of Sound DNA samples that have been integrated into
    /// this profile. Used for weighting confidence.
    public var soundDNASampleCount: Int

    // MARK: - Self-Awareness Calibration
    /// How accurately the user's pre-session check-in predicts their
    /// actual biometric state. `0.0` = poor self-awareness (biometrics
    /// should override check-in), `1.0` = excellent self-awareness
    /// (check-in is highly reliable). Updated after each session.
    public var selfAwarenessScore: Double
    // MARK: - Initialization
    /// Creates a new sound profile with neutral defaults.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - instrumentWeights: Per-instrument weights. Defaults to empty (all equal).
    ///   - energyPreference: Per-mode energy preferences. Defaults to empty.
    ///   - brightnessPreference: Spectral brightness (0-1). Defaults to `0.5`.
    ///   - densityPreference: Melodic density (0-1). Defaults to `0.3`.
    ///   - successfulSounds: Cumulative success scores. Defaults to empty.
    ///   - dislikedSounds: Disliked sound IDs. Defaults to empty.
    ///   - selfAwarenessScore: Self-awareness calibration (0-1). Defaults to `0.5`.
    public init(
        id: UUID = UUID(),
        instrumentWeights: [String: Double] = [:],
        energyPreference: [String: Double] = [:],
        brightnessPreference: Double = 0.5,
        densityPreference: Double = 0.3,
        successfulSounds: [String: Double] = [:],
        dislikedSounds: [String] = [],
        tempoAffinity: Double? = nil,
        warmthPreference: Double? = nil,
        keyPreference: String? = nil,
        soundDNASampleCount: Int = 0,
        selfAwarenessScore: Double = 0.5
    ) {
        self.id = id
        self.instrumentWeights = instrumentWeights
        self.energyPreference = energyPreference
        self.brightnessPreference = brightnessPreference
        self.densityPreference = densityPreference
        self.successfulSounds = successfulSounds
        self.dislikedSounds = dislikedSounds
        self.tempoAffinity = tempoAffinity
        self.warmthPreference = warmthPreference
        self.keyPreference = keyPreference
        self.soundDNASampleCount = soundDNASampleCount
        self.selfAwarenessScore = selfAwarenessScore
    }
    // MARK: - Learning
    /// Updates the sound profile based on a completed session's outcome.
    /// This method adjusts instrument weights, energy preferences, sound
    /// success scores, and the disliked list based on what was played and
    /// how the session went. It uses exponential weight adjustment (not ML)
    /// — the v1 learning approach described in the feedback loop spec.
    /// - Parameter outcome: The session outcome containing biometric scores,
    ///   sound selections, user feedback, and mode information.
    public func updateFromOutcome(_ outcome: BioNauralShared.SessionOutcome) {
        let score = outcome.biometricSuccessScore
        let modeKey = outcome.mode.rawValue
        let learningRate = 0.3

        // Update success scores for all melodic sounds played
        for soundID in outcome.melodicLayerIDs {
            let current = successfulSounds[soundID] ?? 0.0
            successfulSounds[soundID] = current * (1.0 - learningRate) + score * learningRate
        }

        // Handle thumbs-down: add to disliked
        if outcome.thumbsRating == .down {
            for soundID in outcome.melodicLayerIDs where !dislikedSounds.contains(soundID) {
                dislikedSounds.append(soundID)
            }
        }

        // Handle thumbs-up: rehabilitate
        if outcome.thumbsRating == .up {
            for soundID in outcome.melodicLayerIDs {
                dislikedSounds.removeAll { $0 == soundID }
            }
        }

        // Update energy preference for mode
        if score > 0.0 {
            let currentEnergy = energyPreference[modeKey] ?? 0.5
            let energyLearningRate = 0.2
            energyPreference[modeKey] = currentEnergy * (1.0 - energyLearningRate) + score * energyLearningRate
        }

        // Reinforce brightness/density on good sessions
        if score > 0.6 {
            let rate = 0.05
            brightnessPreference = min(max(brightnessPreference + (brightnessPreference - 0.5) * rate, 0.0), 1.0)
            densityPreference = min(max(densityPreference + (densityPreference - 0.5) * rate, 0.0), 1.0)
        }
    }

    // MARK: - Sound DNA Integration

    /// Integrates features from a Sound DNA analysis into this profile.
    /// Uses exponential moving average to blend new data with existing
    /// preferences. Learning rate comes from ``Theme.SoundDNA.profileLearningRate``.
    ///
    /// - Parameter result: The analysis result from a Sound DNA capture.
    public func integrateFromSoundDNA(_ result: SoundDNAAnalysisResult) {
        let lr = Theme.SoundDNA.profileLearningRate

        // Brightness: EMA blend
        brightnessPreference = brightnessPreference * (1.0 - lr) + result.brightness * lr

        // Density: EMA blend
        densityPreference = densityPreference * (1.0 - lr) + result.density * lr

        // Warmth: EMA blend (new field from Sound DNA)
        if let existing = warmthPreference {
            warmthPreference = existing * (1.0 - lr) + result.warmth * lr
        } else {
            warmthPreference = result.warmth
        }

        // Tempo affinity: EMA blend if BPM was detected
        if let bpm = result.bpm {
            if let existing = tempoAffinity {
                tempoAffinity = existing * (1.0 - lr) + bpm * lr
            } else {
                tempoAffinity = bpm
            }
        }

        // Key preference: most recent wins (no meaningful average for keys)
        if let key = result.key {
            keyPreference = key
        }

        // Energy: apply per-mode (use a generic "all modes" update)
        for mode in FocusMode.allCases {
            let modeKey = mode.rawValue
            let current = energyPreference[modeKey] ?? 0.5
            energyPreference[modeKey] = current * (1.0 - lr) + result.energy * lr
        }

        soundDNASampleCount += 1
    }

    /// Resets all learned preferences to neutral defaults.
    public func resetPreferences() {
        instrumentWeights = [:]
        energyPreference = [:]
        brightnessPreference = 0.5
        densityPreference = 0.3
        successfulSounds = [:]
        dislikedSounds = []
        tempoAffinity = nil
        warmthPreference = nil
        keyPreference = nil
        soundDNASampleCount = 0
        selfAwarenessScore = 0.5
    }
}

// MARK: - Session Outcome (Input to Learning)

