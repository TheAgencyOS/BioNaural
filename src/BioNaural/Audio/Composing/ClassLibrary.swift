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
        case (.sleep, .melody):  return sleepMelody()
        case (.sleep, .bass):    return sleepBass()
        case (.sleep, .chords):  return sleepChords()
        case (.sleep, .texture): return sleepTexture()
        case (.sleep, .drums):   return nil  // sleep has no drums
        case (.sleep, _):        return nil

        case (.relaxation, .melody):  return relaxMelody()
        case (.relaxation, .bass):    return relaxBass()
        case (.relaxation, .chords):  return relaxChords()
        case (.relaxation, .texture): return relaxTexture()
        case (.relaxation, .drums):   return nil  // relaxation has no drums
        case (.relaxation, _):        return nil

        case (.focus, .melody):  return focusMelody(biometricState)
        case (.focus, .bass):    return focusBass()
        case (.focus, .chords):  return focusChords()
        case (.focus, .texture): return focusTexture()
        case (.focus, .drums):   return focusDrums(biometricState)
        case (.focus, _):        return nil

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
        case .sleep:       return [.melody, .bass, .chords, .texture]
        case .relaxation:  return [.melody, .bass, .chords, .texture]
        // Focus (trip-hop / lo-fi): single Rhodes melody line over
        // bass + drums. No chord layer or texture — both route
        // through the melody sampler and create "multiple melodic
        // parts playing at once" on the same instrument. Real
        // lo-fi beats are melody + bass + drums; chord harmony
        // still drives pitch selection via the HarmonicContext
        // progression, just without a simultaneous comping voice.
        case .focus:       return [.melody, .bass, .drums]
        case .energize:    return [.melody, .bass, .chords, .drums]
        }
    }

    // MARK: - Texture classes

    /// Sleep texture — very sparse high sustains that hover above the
    /// main pad. Adds subliminal movement without filling the mix.
    /// Routed to the melody sampler for now; a dedicated texture voice
    /// would make this more distinct sonically.
    private static func sleepTexture() -> MusicalClass {
        MusicalClass(
            name: "sleep_texture",
            role: .texture,
            allowedAtomTypes: [.alpha, .empty],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.12,
            allowedEventTypes: [.note],
            octaveRange: 4...5,              // sits above main pad
            velocityRange: 25...45,          // very quiet
            allowedAtomSizes: [4],
            contour: .archDownUp
        )
    }

    /// Relaxation texture — gentle high drones / color notes.
    private static func relaxTexture() -> MusicalClass {
        MusicalClass(
            name: "relax_texture",
            role: .texture,
            allowedAtomTypes: [.alpha, .empty],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: 0.20,
            allowedEventTypes: [.note],
            octaveRange: 4...5,
            velocityRange: 30...55,
            allowedAtomSizes: [2],
            contour: .archUpDown
        )
    }

    /// Focus texture — sparse high harmonic overlay for the ambient
    /// focus reframe. Almost subliminal — just enough to give the
    /// phrase a shimmer above the main pad.
    private static func focusTexture() -> MusicalClass {
        MusicalClass(
            name: "focus_texture",
            role: .texture,
            allowedAtomTypes: [.alpha, .empty],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: 0.15,
            allowedEventTypes: [.note],
            octaveRange: 4...5,
            velocityRange: 28...48,
            allowedAtomSizes: [2, 4],
            contour: .archUpDown
        )
    }

    // MARK: - SLEEP (biometric-invariant)

    private static func sleepMelody() -> MusicalClass {
        // Sleep music research (Harmat et al. 2008, Lai & Good 2005,
        // Dickson & Schubert 2019) converges on: minimal melodic
        // events, long sustains, slow tempo, no surprise dynamics.
        // Density pushed to 0.12 so atom selection overwhelmingly
        // favors rest/drone atoms over any with multiple markers.
        //
        // Octave range raised from 2...3 to 3...4 — the old range
        // (C2-C3, 65-130 Hz) put sleep melodies in bass territory.
        // Research supports a mid-low register (C3-C4, 130-260 Hz)
        // for sleep induction; the descending contour still pulls
        // phrases toward the bottom of the range.
        MusicalClass(
            name: "sleep_melody",
            role: .melody,
            allowedAtomTypes: [.alpha, .empty],    // no beta/gamma
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.12,                         // research-sparse
            allowedEventTypes: [.note],
            octaveRange: 3...4,
            velocityRange: 30...55,
            allowedAtomSizes: [4],
            contour: .descending
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
        // Relaxation research (Pelletier 2004 meta-analysis, Linnemann
        // et al. 2015) supports slow tempo, sparse melodic density,
        // and predictable rhythms for parasympathetic response.
        // Density dropped from 0.40 to 0.25 so phrases have more
        // breath between events.
        MusicalClass(
            name: "relax_melody",
            role: .melody,
            allowedAtomTypes: [.alpha, .empty],     // dropped .beta — no syncopation
            atomicRepetitiveness: .same,            // more looping, fewer surprises
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.25,
            allowedEventTypes: [.note],             // dropped .arpeggio — too busy
            octaveRange: 3...4,
            velocityRange: 45...68,
            allowedAtomSizes: [2, 4],
            contour: .archUpDown
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

    // MARK: - FOCUS (slow trip-hop / lo-fi hip-hop)

    /// Focus melody: sparse and unobtrusive. Long rests between
    /// notes, low density across all biometric states. Real lo-fi
    /// beats put most of the melodic weight in the chord comping
    /// and leave the melody as occasional punctuation.
    private static func focusMelody(_ state: BiometricState) -> MusicalClass {
        let density: Double
        switch state {
        case .calm:     density = 0.22
        case .focused:  density = 0.26
        case .elevated: density = 0.20   // calm them via sparser melody
        case .peak:     density = 0.16
        }
        return MusicalClass(
            name: "focus_melody_\(state)",
            role: .melody,
            allowedAtomTypes: [.alpha, .empty],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .mild),
            density: density,
            allowedEventTypes: [.note],
            octaveRange: 3...4,
            // Velocity lowered so melody sits in the BACKGROUND.
            // Research: focus music should be low-saliency, not
            // demanding conscious parsing. The Rhodes should float
            // under awareness, not draw attention.
            velocityRange: 35...55,
            allowedAtomSizes: [4],
            contour: .neutral                       // no contour motion — predictability
        )
    }

    /// Focus bass: trip-hop upright — sits on the root at beat 1
    /// with occasional passing tones. The atom order in AtomLibrary
    /// puts focus_bass_boombap_4q first so .same repetitiveness
    /// picks the groove-with-kick pattern. Octave bumped from 1..2
    /// (too subby) to 2..3 for note definition.
    private static func focusBass() -> MusicalClass {
        // Bass pool now includes synth bass (GM 38/39) which is
        // fatter than acoustic/fretless. Velocity bumped for more
        // presence in the mix. Octave 1...2 for sub-weight.
        MusicalClass(
            name: "focus_bass",
            role: .bass,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero),
            density: 0.40,
            allowedEventTypes: [.note],
            octaveRange: 1...2,
            velocityRange: 75...100,
            allowedAtomSizes: [4]
        )
    }

    /// Focus chords: sparse rhodes comping. One or two chord hits
    /// per bar — enough to state the harmony without filling the
    /// mix. Most lo-fi tracks don't sustain pads, they comp.
    private static func focusChords() -> MusicalClass {
        MusicalClass(
            name: "focus_chords",
            role: .chords,
            allowedAtomTypes: [.alpha],
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),
            density: 0.30,
            allowedEventTypes: [.chord],
            octaveRange: 3...4,
            velocityRange: 45...68,
            allowedAtomSizes: [4]
        )
    }

    /// Focus drums: minimal rhythmic spine. The drum kit (tabla /
    /// congas / sparse kit) is chosen by CompositionSeed.drumKit —
    /// the atoms themselves are kit-neutral; the resolver maps
    /// marker intensities to kit-appropriate percussion notes.
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
            allowedAtomTypes: [.alpha],                      // no .empty — drums must be constant
            atomicRepetitiveness: .same,
            weirdnessRange: WeirdnessRange(.zero, .safe),  // unused for drums
            density: 0.85,
            allowedEventTypes: [.note],
            octaveRange: 0...0,                              // unused for drums
            // CRITICAL: the full 20..127 range is required so atom
            // intensity tiers (hat 0.55, snare 0.72, kick 0.95) map
            // to velocities that land in the resolver's drum tiers.
            // Previously 70..95 clamped every hit into the snare
            // tier — kicks weren't actually firing kick notes.
            velocityRange: 20...127,
            allowedAtomSizes: [4]
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
            octaveRange: 4...6,
            velocityRange: 70...100,
            allowedAtomSizes: [2],
            contour: .ascending                     // lift the listener
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
