// ClassLibrary.swift
// BioNaural — v3 Composing Core
//
// Hand-crafted MusicalClass presets per (FocusMode, TrackRole, BiometricState).
// CompositionPlanner picks a Class from this library when configuring each
// track. The Class becomes input to PatternBuilder which turns it into a VP.
//
// Biometric state matters for energize (positive feedback: higher arousal
// → more density / more atom types) and focus (subtle shifts). For sleep
// and relaxation the Class is biometric-invariant — we always aim to calm.
//
// NWL spec 3.6.2 (Class concept).

import BioNauralShared
import Foundation

// MARK: - ClassLibrary

public enum ClassLibrary {

    /// Returns the MusicalClass for the given (mode, role, biometric state).
    /// Returns `nil` if the role doesn't apply to the mode (e.g. drums in sleep).
    public static func musicalClass(
        mode: FocusMode,
        role: TrackRole,
        biometricState: BiometricState
    ) -> MusicalClass? {
        switch (mode, role) {
        case (.sleep, .melody): return sleepMelody()
        case (.sleep, .bass):   return sleepBass()
        case (.sleep, .chords): return sleepChords()
        case (.sleep, .drums):  return nil  // sleep has no drums
        case (.sleep, _):       return nil

        case (.relaxation, .melody): return relaxMelody()
        case (.relaxation, .bass):   return relaxBass()
        case (.relaxation, .chords): return relaxChords()
        case (.relaxation, .drums):  return nil  // relaxation has no drums
        case (.relaxation, _):       return nil

        case (.focus, .melody): return focusMelody(biometricState)
        case (.focus, .bass):   return focusBass()
        case (.focus, .chords): return focusChords()
        case (.focus, .drums):  return focusDrums(biometricState)
        case (.focus, _):       return nil

        case (.energize, .melody): return energizeMelody(biometricState)
        case (.energize, .bass):   return energizeBass(biometricState)
        case (.energize, .chords): return energizeChords()
        case (.energize, .drums):  return energizeDrums(biometricState)
        case (.energize, _):       return nil
        }
    }

    /// All roles supported for a given mode.
    public static func roles(for mode: FocusMode) -> [TrackRole] {
        switch mode {
        case .sleep:       return [.melody, .bass, .chords]
        case .relaxation:  return [.melody, .bass, .chords]
        case .focus:       return [.melody, .bass, .chords, .drums]
        case .energize:    return [.melody, .bass, .chords, .drums]
        }
    }

    // MARK: - SLEEP (biometric-invariant)

    private static func sleepMelody() -> MusicalClass {
        MusicalClass(
            name: "sleep_melody",
            role: .melody,
            allowedAtomTypes: [.alpha, .empty],   // no syncopation
            atomicRepetitiveness: .same,           // looping for habituation
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.20,
            allowedEventTypes: [.note],            // single notes only
            octaveRange: 3...4,
            velocityRange: 35...60,
            allowedAtomSizes: [4]                  // long phrases
        )
    }

    private static func sleepBass() -> MusicalClass {
        MusicalClass(
            name: "sleep_bass",
            role: .bass,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero), // chord root only
            density: 0.10,
            allowedEventTypes: [.note],
            octaveRange: 1...2,
            velocityRange: 30...50,
            allowedAtomSizes: [4]
        )
    }

    private static func sleepChords() -> MusicalClass {
        MusicalClass(
            name: "sleep_chords",
            role: .chords,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.15,
            allowedEventTypes: [.chord],
            octaveRange: 2...3,
            velocityRange: 35...55,
            allowedAtomSizes: [4]
        )
    }

    // MARK: - RELAXATION (biometric-invariant)

    private static func relaxMelody() -> MusicalClass {
        MusicalClass(
            name: "relax_melody",
            role: .melody,
            allowedAtomTypes: [.alpha, .beta, .empty],
            atomicRepetitiveness: .none,            // varied phrases
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: 0.40,
            allowedEventTypes: [.note, .arpeggio],
            octaveRange: 3...5,
            velocityRange: 50...75,
            allowedAtomSizes: [2]
        )
    }

    private static func relaxBass() -> MusicalClass {
        MusicalClass(
            name: "relax_bass",
            role: .bass,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero),
            density: 0.20,
            allowedEventTypes: [.note],
            octaveRange: 2...3,
            velocityRange: 40...60,
            allowedAtomSizes: [4]
        )
    }

    private static func relaxChords() -> MusicalClass {
        MusicalClass(
            name: "relax_chords",
            role: .chords,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.30,
            allowedEventTypes: [.chord],
            octaveRange: 3...4,
            velocityRange: 45...65,
            allowedAtomSizes: [4]
        )
    }

    // MARK: - FOCUS (subtle biometric shift)

    /// Focus melody: lo-fi piano feel. Density stays moderate across
    /// biometric states to maintain habituation. At higher arousal we
    /// don't add complexity — we keep the steady predictability.
    private static func focusMelody(_ state: BiometricState) -> MusicalClass {
        let density: Double
        let types: Set<AtomType>
        switch state {
        case .calm:     density = 0.55; types = [.alpha, .empty]
        case .focused:  density = 0.60; types = [.alpha, .beta, .empty]
        case .elevated: density = 0.50; types = [.alpha, .empty]   // calm them
        case .peak:     density = 0.45; types = [.alpha]            // calm further
        }
        return MusicalClass(
            name: "focus_melody_\(state)",
            role: .melody,
            allowedAtomTypes: types,
            atomicRepetitiveness: .same,            // loop for habituation
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: density,
            allowedEventTypes: [.note],
            octaveRange: 4...5,                     // C4-C5 mid range
            velocityRange: 50...75,
            allowedAtomSizes: [2]
        )
    }

    private static func focusBass() -> MusicalClass {
        MusicalClass(
            name: "focus_bass",
            role: .bass,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero),
            density: 0.25,
            allowedEventTypes: [.note],
            octaveRange: 2...3,
            velocityRange: 50...70,
            allowedAtomSizes: [4]
        )
    }

    private static func focusChords() -> MusicalClass {
        MusicalClass(
            name: "focus_chords",
            role: .chords,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.safe, .mild),
            density: 0.35,
            allowedEventTypes: [.chord],
            octaveRange: 3...4,
            velocityRange: 45...65,
            allowedAtomSizes: [4]
        )
    }

    /// Focus drums: nearly silent shaker/sidestick. Slight increase in
    /// presence at .focused; pulled back at .elevated/.peak.
    private static func focusDrums(_ state: BiometricState) -> MusicalClass {
        let density: Double
        switch state {
        case .calm:     density = 0.20
        case .focused:  density = 0.30
        case .elevated: density = 0.20  // calm them
        case .peak:     density = 0.15  // calm further
        }
        return MusicalClass(
            name: "focus_drums_\(state)",
            role: .drums,
            allowedAtomTypes: [.alpha, .empty],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),  // unused for drums
            density: density,
            allowedEventTypes: [.note],
            octaveRange: 0...0,                              // unused for drums
            velocityRange: 55...80,
            allowedAtomSizes: [2]
        )
    }

    // MARK: - ENERGIZE (positive feedback — arousal scales density)

    /// Energize melody: density and atom variety scale with biometric
    /// state. Calm = sparse hooks; peak = dense runs.
    private static func energizeMelody(_ state: BiometricState) -> MusicalClass {
        let density: Double
        let types: Set<AtomType>
        switch state {
        case .calm:     density = 0.45; types = [.alpha, .empty]
        case .focused:  density = 0.60; types = [.alpha, .beta, .empty]
        case .elevated: density = 0.75; types = [.alpha, .beta]
        case .peak:     density = 0.85; types = [.alpha, .beta, .gamma]
        }
        return MusicalClass(
            name: "energize_melody_\(state)",
            role: .melody,
            allowedAtomTypes: types,
            atomicRepetitiveness: .none,            // varied for energy
            weirdnessRange: WeirdnessRange(.zero, .adventurous),
            density: density,
            allowedEventTypes: [.note, .chord],
            octaveRange: 4...5,
            velocityRange: 70...100,
            allowedAtomSizes: [2]
        )
    }

    /// Energize bass: locked to kick. Pattern density increases at peak.
    private static func energizeBass(_ state: BiometricState) -> MusicalClass {
        let types: Set<AtomType>
        switch state {
        case .calm, .focused: types = [.alpha]          // quarter notes
        case .elevated, .peak: types = [.alpha, .beta]  // 8th notes allowed
        }
        return MusicalClass(
            name: "energize_bass_\(state)",
            role: .bass,
            allowedAtomTypes: types,
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.70,
            allowedEventTypes: [.note],
            octaveRange: 1...2,
            velocityRange: 70...95,
            allowedAtomSizes: [4]
        )
    }

    private static func energizeChords() -> MusicalClass {
        MusicalClass(
            name: "energize_chords",
            role: .chords,
            allowedAtomTypes: [.alpha, .beta],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: 0.50,
            allowedEventTypes: [.chord],
            octaveRange: 3...4,
            velocityRange: 55...75,
            allowedAtomSizes: [4]
        )
    }

    /// Energize drums: four-on-the-floor at all states. Atom variety
    /// scales with biometric state — calm = basic, peak = busy 16ths.
    private static func energizeDrums(_ state: BiometricState) -> MusicalClass {
        let types: Set<AtomType>
        let density: Double
        switch state {
        case .calm:     types = [.alpha];                  density = 0.70
        case .focused:  types = [.alpha];                  density = 0.75
        case .elevated: types = [.alpha, .beta];           density = 0.85
        case .peak:     types = [.alpha, .beta, .gamma];   density = 0.95
        }
        return MusicalClass(
            name: "energize_drums_\(state)",
            role: .drums,
            allowedAtomTypes: types,
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),  // unused for drums
            density: density,
            allowedEventTypes: [.note],
            octaveRange: 0...0,                              // unused for drums
            velocityRange: 60...100,
            allowedAtomSizes: [4]
        )
    }
}
