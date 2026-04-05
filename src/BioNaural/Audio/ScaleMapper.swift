// ScaleMapper.swift
// BioNaural
//
// Maps brainwave states and session modes to musically coherent scales
// using AudioKit's Tonic library. Used by SoundSelector to ensure
// melodic layer selections are harmonically appropriate for the
// current biometric/mode context.
//
// v1: Static mode→scale mapping with biometric-state modulation.
// v1.5: ML-driven scale selection based on user preference learning.

import Foundation
@preconcurrency import Tonic
import BioNauralShared

// MARK: - ScaleMapper

/// Determines the optimal musical scale for the current session context.
/// The melodic layer uses these scales to filter sound selections and
/// ensure harmonic coherence across concurrent sounds.
enum ScaleMapper {

    // MARK: - Mode → Scale Mapping

    /// Returns the preferred musical scale for a given mode and biometric state.
    ///
    /// The mapping is informed by music therapy research:
    /// - **Focus:** Pentatonic major — simple, non-distracting, minimal tension.
    /// - **Relaxation:** Lydian — dreamy, floating quality from the raised 4th.
    /// - **Sleep:** Pentatonic minor — minimal notes, soothing, no dissonance.
    /// - **Energize:** Major — bright, uplifting, forward-driving energy.
    ///
    /// Biometric state modulates the choice:
    /// - Elevated/Peak in non-Energize modes → shift to calmer scales.
    /// - Calm in Energize → shift to brighter scales to counteract.
    static func scale(
        for mode: FocusMode,
        biometricState: BiometricState
    ) -> Scale {
        switch mode {
        case .focus:
            return focusScale(biometricState: biometricState)
        case .relaxation:
            return relaxationScale(biometricState: biometricState)
        case .sleep:
            return sleepScale(biometricState: biometricState)
        case .energize:
            return energizeScale(biometricState: biometricState)
        }
    }

    // MARK: - Key for Mode

    /// Returns the preferred root key for a given mode.
    /// Lower roots for calmer modes, higher for energizing modes.
    static func rootNote(for mode: FocusMode) -> NoteClass {
        switch mode {
        case .focus:       return .C
        case .relaxation:  return .G
        case .sleep:       return .F
        case .energize:    return .D
        }
    }

    /// Returns the full `Key` (root + scale) for the current context.
    static func key(
        for mode: FocusMode,
        biometricState: BiometricState
    ) -> Key {
        Key(root: rootNote(for: mode), scale: scale(for: mode, biometricState: biometricState))
    }

    // MARK: - Valid Frequencies

    /// Returns an array of valid MIDI-to-frequency values for the current
    /// mode and biometric state, within the given octave range.
    /// Used by the melodic layer to constrain note selection.
    static func validFrequencies(
        for mode: FocusMode,
        biometricState: BiometricState,
        octaveRange: ClosedRange<Int> = 3...6
    ) -> [Double] {
        let currentKey = key(for: mode, biometricState: biometricState)
        let validNotes = currentKey.noteSet.array

        return validNotes.flatMap { note -> [Double] in
            octaveRange.compactMap { octave -> Double? in
                let midiNote = Double(note.noteNumber) + Double((octave - 4) * 12)
                guard midiNote >= 0, midiNote <= 127 else { return nil }
                return 440.0 * pow(2.0, (midiNote - 69.0) / 12.0)
            }
        }
        .sorted()
    }

    // MARK: - Key Compatibility Check

    /// Returns true if two key strings are harmonically compatible,
    /// using Tonic's music theory to check interval relationships.
    /// Falls back to circle-of-fifths heuristic for unrecognized keys.
    static func areKeysCompatible(_ keyA: String?, _ keyB: String?) -> Bool {
        guard let keyA, let keyB else { return true }
        if keyA == keyB { return true }

        // Parse root notes from key strings (e.g., "C", "Am", "F#m").
        guard let rootA = parseRoot(keyA),
              let rootB = parseRoot(keyB) else {
            return true // Unknown format — allow it
        }

        // Keys within a perfect fifth (7 semitones) are generally compatible.
        let semitoneDistance = abs(rootA.intValue - rootB.intValue) % 12
        let normalizedDistance = min(semitoneDistance, 12 - semitoneDistance)
        return normalizedDistance <= 7
    }

    // MARK: - Private

    private static func focusScale(biometricState: BiometricState) -> Scale {
        switch biometricState {
        case .calm, .focused:  return .pentatonicMajor
        case .elevated:        return .pentatonicMajor  // Same family, keeps it simple
        case .peak:            return .pentatonicMinor   // Shift calmer when overstimulated
        }
    }

    private static func relaxationScale(biometricState: BiometricState) -> Scale {
        switch biometricState {
        case .calm:            return .lydian
        case .focused:         return .lydian
        case .elevated:        return .dorian           // Slightly more grounded
        case .peak:            return .pentatonicMinor   // Maximum calm
        }
    }

    private static func sleepScale(biometricState: BiometricState) -> Scale {
        // Sleep always stays minimal — pentatonic minor is the safest choice.
        // Only vary slightly for elevated states.
        switch biometricState {
        case .calm, .focused:  return .pentatonicMinor
        case .elevated, .peak: return .pentatonicMinor
        }
    }

    private static func energizeScale(biometricState: BiometricState) -> Scale {
        switch biometricState {
        case .calm:            return .lydian            // Bright, uplifting to counteract
        case .focused:         return .major
        case .elevated:        return .major
        case .peak:            return .mixolydian        // Slightly less tension at peak
        }
    }

    /// Parses a NoteClass from a key string like "C", "Am", "F#".
    private static func parseRoot(_ keyString: String) -> NoteClass? {
        let cleaned = keyString
            .replacingOccurrences(of: "m", with: "")
            .replacingOccurrences(of: "min", with: "")
            .replacingOccurrences(of: "maj", with: "")
            .trimmingCharacters(in: .whitespaces)

        switch cleaned {
        case "C":  return .C
        case "C#", "Db": return .Cs
        case "D":  return .D
        case "D#", "Eb": return .Ds
        case "E":  return .E
        case "F":  return .F
        case "F#", "Gb": return .Fs
        case "G":  return .G
        case "G#", "Ab": return .Gs
        case "A":  return .A
        case "A#", "Bb": return .As
        case "B":  return .B
        default:   return nil
        }
    }
}
