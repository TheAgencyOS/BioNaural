// SoundSelector.swift
// BioNaural
//
// Protocol-based sound selection system. v1 ships with rule-based selection;
// v1.5 swaps in an ML contextual bandit — same protocol, no refactoring.
// SoundSelector does NOT play audio. It returns ranked SoundIDs that
// MelodicLayer then plays. Separation of selection from playback.

import Foundation
import BioNauralShared

// MARK: - Supporting Types

/// Snapshot of the user's current biometric state, used as input
/// to sound selection logic.
public struct SoundSelectionBiometricState: Sendable {

    /// Smoothed heart rate (BPM).
    public let heartRate: Double

    /// Heart rate variability (ms, RMSSD or SDNN).
    public let hrv: Double

    /// Classified arousal state.
    public let classification: SoundSelectionClassification

    /// HR trend direction.
    public let trend: SoundSelectionTrend

    public init(
        heartRate: Double,
        hrv: Double,
        classification: SoundSelectionClassification,
        trend: SoundSelectionTrend
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.classification = classification
        self.trend = trend
    }
}

/// Arousal classification from the biometric processor.
public enum SoundSelectionClassification: String, Sendable {
    case calm
    case focused
    case elevated
    case peak
}

/// Heart rate trend direction.
public enum SoundSelectionTrend: String, Sendable {
    case falling
    case stable
    case rising
}

/// Per-user sound preference profile used by the selector.
/// Stored in SwiftData, updated after every session by the feedback loop.
public struct SoundSelectionProfile: Sendable {

    /// Weight per instrument family [0...1]. Higher = more preferred.
    public let preferredInstruments: [Instrument: Double]

    /// Preferred energy level per mode [0...1].
    public let energyPreference: [FocusMode: Double]

    /// Global brightness preference [0...1].
    public let brightnessPreference: Double

    /// Global density preference [0...1].
    public let densityPreference: Double

    /// Sounds that produced good biometric outcomes, with success count.
    public let successfulSounds: [SoundID: Int]

    /// Sounds the user has explicitly thumbs-downed.
    public let dislikedSounds: Set<SoundID>

    public init(
        preferredInstruments: [Instrument: Double] = [:],
        energyPreference: [FocusMode: Double] = [:],
        brightnessPreference: Double = 0.5,
        densityPreference: Double = 0.5,
        successfulSounds: [SoundID: Int] = [:],
        dislikedSounds: Set<SoundID> = []
    ) {
        self.preferredInstruments = preferredInstruments
        self.energyPreference = energyPreference
        self.brightnessPreference = brightnessPreference
        self.densityPreference = densityPreference
        self.successfulSounds = successfulSounds
        self.dislikedSounds = dislikedSounds
    }
}

// MARK: - Protocol

/// Contract for sound selection. Implementations receive context
/// (mode, biometrics, mood, user preferences) and return ranked
/// candidate SoundIDs. v1 = rules, v1.5 = ML.
public protocol SoundSelectorProtocol {

    /// Select the best melodic sounds for the current state.
    ///
    /// - Parameters:
    ///   - mode: The active focus mode.
    ///   - biometricState: Current biometric snapshot (may be a default
    ///     if no Watch is connected).
    ///   - mood: Pre-session mood check-in value [0...1] where 0 = wired,
    ///     1 = calm. `nil` if the user skipped the check-in.
    ///   - preferences: The user's learned + explicit sound profile.
    /// - Returns: Ordered list of 2-3 `SoundID` candidates, best first.
    func selectSounds(
        mode: FocusMode,
        biometricState: SoundSelectionBiometricState,
        mood: Double?,
        preferences: SoundSelectionProfile
    ) -> [SoundID]
}

// MARK: - Mode Selection Ranges

/// Per-mode energy/brightness/density ranges from Theme tokens.
/// Stored as a value type so the selector can reference them without
/// hardcoding numbers inline.
private struct ModeSelectionRanges {
    let energy: ClosedRange<Double>
    let brightness: ClosedRange<Double>
    let density: ClosedRange<Double>
}

// MARK: - Rule-Based Selector (v1)

/// Deterministic sound selector that ships at v1 launch.
///
/// 1. Filters the library by mode affinity and tag ranges.
/// 2. Removes disliked sounds.
/// 3. Ranks by user preference weights.
/// 4. Ensures key compatibility among the top candidates.
/// 5. Returns the top 2-3 sounds.
///
/// All range thresholds come from `Theme.Audio` tokens, not from
/// hardcoded constants.
public final class RuleBasedSoundSelector: SoundSelectorProtocol {

    private let library: SoundLibrary

    public init(library: SoundLibrary) {
        self.library = library
    }

    public func selectSounds(
        mode: FocusMode,
        biometricState: SoundSelectionBiometricState,
        mood: Double?,
        preferences: SoundSelectionProfile
    ) -> [SoundID] {
        let ranges = selectionRanges(for: mode)

        // Step 1: Filter by mode affinity + tag ranges.
        // Energize mode additionally filters by preferred rhythmic instruments.
        let instrumentFilter: Set<Instrument>? = (mode == .energize)
            ? Theme.Audio.energizePreferredInstruments
            : nil

        var candidates = library.filter(
            mode: mode,
            energyRange: ranges.energy,
            brightnessRange: ranges.brightness,
            densityRange: ranges.density,
            instruments: instrumentFilter
        )

        // If Energize instrument filter was too restrictive, fall back to
        // unfiltered so the user always hears something.
        if candidates.isEmpty && mode == .energize {
            candidates = library.filter(
                mode: mode,
                energyRange: ranges.energy,
                brightnessRange: ranges.brightness,
                densityRange: ranges.density
            )
        }

        // Step 2: Remove disliked sounds.
        candidates.removeAll { preferences.dislikedSounds.contains($0.id) }

        guard !candidates.isEmpty else { return [] }

        // Step 3: Score and rank by user preferences.
        let scored = candidates.map { sound -> (SoundMetadata, Double) in
            let score = preferenceScore(
                sound: sound,
                mode: mode,
                preferences: preferences,
                biometricState: biometricState,
                mood: mood
            )
            return (sound, score)
        }
        .sorted { $0.1 > $1.1 }

        // Step 4: Pick top candidates ensuring key compatibility.
        let maxCandidates = Theme.Audio.melodicMaxConcurrentSounds
        let selected = selectKeyCompatible(from: scored, maxCount: maxCandidates)

        return selected.map(\.id)
    }

    // MARK: - Mode Ranges

    /// Returns the tag ranges for a given mode from Theme tokens.
    private func selectionRanges(for mode: FocusMode) -> ModeSelectionRanges {
        switch mode {
        case .focus:
            return ModeSelectionRanges(
                energy: Theme.Audio.focusEnergyRange,
                brightness: Theme.Audio.focusBrightnessRange,
                density: Theme.Audio.focusDensityRange
            )
        case .relaxation:
            return ModeSelectionRanges(
                energy: Theme.Audio.relaxEnergyRange,
                brightness: Theme.Audio.relaxBrightnessRange,
                density: Theme.Audio.relaxDensityRange
            )
        case .sleep:
            return ModeSelectionRanges(
                energy: Theme.Audio.sleepEnergyRange,
                brightness: Theme.Audio.sleepBrightnessRange,
                density: Theme.Audio.sleepDensityRange
            )
        case .energize:
            return ModeSelectionRanges(
                energy: Theme.Audio.energizeEnergyRange,
                brightness: Theme.Audio.energizeBrightnessRange,
                density: Theme.Audio.energizeDensityRange
            )
        }
    }

    // MARK: - Preference Scoring

    /// Computes a composite score for a candidate sound based on how well
    /// it matches the user's preferences and current state.
    /// Higher score = better match. All weights come from Theme tokens.
    private func preferenceScore(
        sound: SoundMetadata,
        mode: FocusMode,
        preferences: SoundSelectionProfile,
        biometricState: SoundSelectionBiometricState,
        mood: Double?
    ) -> Double {
        var score: Double = 0.0

        // Instrument preference weight.
        let instrumentWeight = preferences.preferredInstruments[sound.instrument]
            ?? Theme.Audio.defaultInstrumentWeight
        score += instrumentWeight * Theme.Audio.instrumentScoreWeight

        // Energy proximity to user's preferred energy for this mode.
        let preferredEnergy = preferences.energyPreference[mode]
            ?? Theme.Audio.defaultEnergyPreference
        let energyDelta = abs(sound.energy - preferredEnergy)
        score += (1.0 - energyDelta) * Theme.Audio.energyScoreWeight

        // Brightness proximity.
        let brightnessDelta = abs(sound.brightness - preferences.brightnessPreference)
        score += (1.0 - brightnessDelta) * Theme.Audio.brightnessScoreWeight

        // Density proximity.
        let densityDelta = abs(sound.density - preferences.densityPreference)
        score += (1.0 - densityDelta) * Theme.Audio.densityScoreWeight

        // Bonus for historically successful sounds.
        if let successCount = preferences.successfulSounds[sound.id] {
            let successBonus = min(
                Double(successCount) * Theme.Audio.successBonusPerSession,
                Theme.Audio.successBonusCap
            )
            score += successBonus
        }

        // Mode-specific biometric adaptation.
        if mode == .energize {
            score += energizeBiometricScore(
                sound: sound,
                biometricState: biometricState
            )
        } else {
            // Non-Energize modes: in elevated states, prefer lower-energy sounds
            // (negative feedback — calm the user down).
            if biometricState.classification == .elevated || biometricState.classification == .peak {
                score += (1.0 - sound.energy) * Theme.Audio.biometricAlignmentWeight
            }
        }

        // Mood alignment: if the user reported feeling wired (mood near 0),
        // prefer calmer sounds. (Skipped for Energize — the whole point is activation.)
        if let mood, mode != .energize {
            let calmBias = 1.0 - mood // Higher when user is more wired
            score += (1.0 - sound.energy) * calmBias * Theme.Audio.moodAlignmentWeight
        }

        return score
    }

    // MARK: - Energize Biometric Adaptation

    /// Computes the biometric-driven score adjustment for Energize mode.
    /// Energize uses POSITIVE feedback — the opposite of Focus/Relax:
    /// - HR rising (user is activating): MAINTAIN current energy level (it's working).
    /// - HR falling (user is flagging): shift to HIGHER energy sounds to counteract.
    /// - Cool-down phase (calm classification): shift to lower energy.
    /// Also applies bonuses for preferred scales, tempo, and instruments
    /// from Theme.Audio tokens.
    private func energizeBiometricScore(
        sound: SoundMetadata,
        biometricState: SoundSelectionBiometricState
    ) -> Double {
        var score: Double = 0.0

        // Biometric-driven melodic adaptation for Energize.
        switch biometricState.trend {
        case .rising:
            // User is activating — reward sounds near current energy level
            // (maintain what's working). Proximity to mid-high energy = good.
            let midEnergy = (Theme.Audio.energizeEnergyRange.lowerBound
                           + Theme.Audio.energizeEnergyRange.upperBound) / 2.0
            let proximity = 1.0 - abs(sound.energy - midEnergy)
            score += proximity * Theme.Audio.energizeRisingHRMaintainWeight
        case .falling:
            // User is flagging — boost HIGHER energy sounds to counteract.
            score += sound.energy * Theme.Audio.energizeFallingHRBoostWeight
        case .stable:
            // Stable — no special adjustment; let preference scoring dominate.
            break
        }

        // Cool-down override: if the session is in cool-down (calm classification
        // winding down), prefer lower-energy sounds approaching relaxation levels.
        if biometricState.classification == .calm {
            let coolDownTarget = Theme.Audio.energizeCoolDownEnergyTarget
            let coolDownProximity = 1.0 - abs(sound.energy - coolDownTarget)
            score += coolDownProximity * Theme.Audio.energizeFallingHRBoostWeight
        }

        // Preferred scale bonus (major, Lydian).
        let normalizedScale = (sound.scale ?? "").lowercased()
        if Theme.Audio.energizePreferredScales.contains(normalizedScale) {
            score += Theme.Audio.energizeScaleBonus
        }

        // Preferred tempo bonus — only for sounds that have a tempo
        // (arrhythmic/free-time sounds get no bonus — tempo matters for energy).
        if let tempo = sound.tempo,
           Theme.Audio.energizeTempoRange.contains(tempo) {
            score += Theme.Audio.energizeTempoBonus
        }

        // Preferred instrument bonus (already filtered, but adds scoring
        // gradient when fallback candidates are included).
        if Theme.Audio.energizePreferredInstruments.contains(sound.instrument) {
            score += Theme.Audio.energizeInstrumentBonus
        }

        return score
    }

    // MARK: - Key Compatibility (Tonic-Powered)

    /// Selects up to `maxCount` sounds from the ranked list, ensuring
    /// key compatibility between all selected sounds.
    /// Walks down the ranked list. For each candidate, checks if its key
    /// is compatible with all previously selected sounds. If not, skips it.
    /// Uses ScaleMapper (Tonic) for music-theory-based compatibility checks.
    private func selectKeyCompatible(
        from ranked: [(SoundMetadata, Double)],
        maxCount: Int
    ) -> [SoundMetadata] {
        var selected: [SoundMetadata] = []
        for (sound, _) in ranked {
            guard selected.count < maxCount else { break }
            let isCompatible = selected.allSatisfy { existing in
                ScaleMapper.areKeysCompatible(existing.key, sound.key)
            }
            if isCompatible {
                selected.append(sound)
            }
        }
        return selected
    }
}
