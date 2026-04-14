// AtomLibrary.swift
// BioNaural — v3 Composing Core
//
// Hand-crafted Atom presets per (FocusMode, TrackRole, AtomType).
// PatternBuilder picks Atoms from this library when assembling Molecules.
//
// Each Atom is a small rhythmic chunk (1, 2, or 4 quarters) containing
// Markers at musically sensible positions. Atoms know nothing about
// pitches — they only encode RHYTHM, INTENSITY, and MOVEABILITY.
//
// Drums use the same Atom type as melodic tracks: the resolver picks
// drum elements by interpreting Marker intensity (kick > snare > hat).
// This means drum atoms can have multiple markers at the same tick
// (e.g., kick + closed hat on beat 1).
//
// AtomTypes:
//   ALPHA — simple, on-the-beat, baseline rhythm
//   BETA  — syncopated, off-beat, more rhythmic interest
//   GAMMA — busy, dense, fills and accents

import BioNauralShared
import Foundation

// MARK: - AtomLibrary

public enum AtomLibrary {

    // MARK: - Tick Helpers (480 PPQN)

    private static let q: Int = Composing.ticksPerQuarter           // 480 = 1 quarter
    private static let e: Int = Composing.ticksPerQuarter / 2       // 240 = 1 eighth
    private static let s: Int = Composing.ticksPerQuarter / 4       // 120 = 1 sixteenth
    private static let de: Int = Composing.ticksPerQuarter * 3 / 4  // 360 = dotted eighth

    // MARK: - Public Lookup

    /// Returns all atoms matching the given (mode, role, type) combo.
    /// Returns an empty array if no atoms match.
    public static func atoms(
        mode: FocusMode,
        role: TrackRole,
        type: AtomType
    ) -> [Atom] {
        let pool: [Atom]
        switch (mode, role) {
        case (.sleep,      .melody): pool = sleepMelody
        case (.sleep,      .bass):   pool = sleepBass
        case (.sleep,      .chords): pool = sleepChords
        case (.sleep,      .pad):    pool = sleepMelody
        case (.sleep,      .drums):  pool = []  // sleep has no drums
        case (.sleep,      .texture):pool = sleepMelody

        case (.relaxation, .melody): pool = relaxMelody
        case (.relaxation, .bass):   pool = relaxBass
        case (.relaxation, .chords): pool = relaxChords
        case (.relaxation, .pad):    pool = relaxMelody
        case (.relaxation, .drums):  pool = []  // relaxation has no drums
        case (.relaxation, .texture):pool = relaxMelody

        case (.focus,      .melody): pool = focusMelody
        case (.focus,      .bass):   pool = focusBass
        case (.focus,      .chords): pool = focusChords
        case (.focus,      .drums):  pool = focusDrums
        case (.focus,      .pad):    pool = focusMelody
        case (.focus,      .texture):pool = focusMelody

        case (.energize,   .melody): pool = energizeMelody
        case (.energize,   .bass):   pool = energizeBass
        case (.energize,   .chords): pool = energizeChords
        case (.energize,   .drums):  pool = energizeDrums
        case (.energize,   .pad):    pool = energizeMelody
        case (.energize,   .texture):pool = energizeMelody
        }

        return pool.filter { $0.type == type }
    }

    /// All atoms for (mode, role) regardless of type.
    public static func allAtoms(mode: FocusMode, role: TrackRole) -> [Atom] {
        AtomType.allCases.flatMap { atoms(mode: mode, role: role, type: $0) }
    }

    // MARK: - SLEEP — Melody (very sparse, long sustains)

    /// Sleep is sparse and meditative: 1-2 notes per 4-quarter atom,
    /// long durations, gentle intensity, lots of moveability for rubato.
    private static let sleepMelody: [Atom] = [
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: 4 * q, intensity: 0.55, moveAbility: 0.6)
            ],
            name: "sleep_alpha_drone_4q"
        ),
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: 2 * q, intensity: 0.55, moveAbility: 0.5),
                Marker(startTick: 2 * q,    stopTick: 4 * q, intensity: 0.45, moveAbility: 0.7)
            ],
            name: "sleep_alpha_pair_descend_4q"
        ),
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: 3 * q, intensity: 0.50, moveAbility: 0.5),
                Marker(startTick: 3 * q,    stopTick: 4 * q, intensity: 0.40, moveAbility: 0.7)
            ],
            name: "sleep_alpha_long_short_4q"
        ),
        // ALPHA: single late note (huge space then whisper)
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 2 * q + e, stopTick: 4 * q, intensity: 0.45, moveAbility: 0.8)
            ],
            name: "sleep_alpha_whisper_late_4q"
        ),
        // ALPHA: three descending points
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: q + e,     intensity: 0.55, moveAbility: 0.4),
                Marker(startTick: q + e,     stopTick: 2 * q + e, intensity: 0.50, moveAbility: 0.5),
                Marker(startTick: 2 * q + e, stopTick: 4 * q,     intensity: 0.40, moveAbility: 0.7)
            ],
            name: "sleep_alpha_three_descend_4q"
        ),
        Atom(
            sizeQuarters: 4,
            type: .empty,
            markers: [],
            name: "sleep_empty_4q"
        ),
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: e,        stopTick: 4 * q, intensity: 0.50, moveAbility: 0.6)
            ],
            name: "sleep_beta_offbeat_4q"
        ),
    ]

    // MARK: - SLEEP — Bass / Chords (drones)

    private static let sleepBass: [Atom] = [
        // Long drone on the root — the default sleep bass.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.45, moveAbility: 0.0)
            ],
            name: "sleep_bass_drone_4q"
        ),
        // Two halves — a gentle root-to-5th breath.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.45, moveAbility: 0.1),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.40, moveAbility: 0.1),
            ],
            name: "sleep_bass_halves_4q"
        ),
        // Late entry — silence for two beats, then a single long note.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.42, moveAbility: 0.2)
            ],
            name: "sleep_bass_late_4q"
        ),
        // Fill variant for section transitions — half note pulse.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: q,         intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: 2 * q,     intensity: 0.45, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 3 * q,     intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 4 * q,     intensity: 0.45, moveAbility: 0.0),
            ],
            name: "sleep_bass_fill_walkin_4q"
        ),
    ]

    private static let sleepChords: [Atom] = [
        // Long pad — the default sleep chord voice.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.40, moveAbility: 0.2)
            ],
            name: "sleep_chord_pad_4q"
        ),
        // Two-chord breath — late entry on beat 3.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.42, moveAbility: 0.2),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.38, moveAbility: 0.3),
            ],
            name: "sleep_chord_breath_4q"
        ),
        // Chord swell into beat 1 — long crescendo.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: e, stopTick: 4 * q, intensity: 0.35, moveAbility: 0.3)
            ],
            name: "sleep_chord_swell_4q"
        ),
        // Fill — arpeggiated pad into next section.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: 4 * q,     intensity: 0.42, moveAbility: 0.0),
                Marker(startTick: q + e,     stopTick: 4 * q,     intensity: 0.38, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 4 * q,     intensity: 0.35, moveAbility: 0.0),
            ],
            name: "sleep_chord_fill_arp_4q"
        ),
    ]

    // MARK: - RELAXATION — Melody (gentle, breathing)

    /// Relaxation is gentle: 2-4 notes per 2-quarter atom, arch-like
    /// rhythms, moderate intensity. Some breathing room.
    private static let relaxMelody: [Atom] = [
        // ALPHA: 2 notes — beat 1 and "and" of 2 (breathing)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: q,         intensity: 0.65, moveAbility: 0.3),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.55, moveAbility: 0.4)
            ],
            name: "relax_alpha_breath_2q"
        ),
        // ALPHA: 3 notes — arch (rise then fall)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.60, moveAbility: 0.3),
                Marker(startTick: e,        stopTick: q,         intensity: 0.70, moveAbility: 0.3),
                Marker(startTick: q,        stopTick: 2 * q,     intensity: 0.55, moveAbility: 0.4)
            ],
            name: "relax_alpha_arch_2q"
        ),
        // ALPHA: single sustained note
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: 2 * q,     intensity: 0.60, moveAbility: 0.4)
            ],
            name: "relax_alpha_sustained_2q"
        ),
        // BETA: syncopated 3-note (off-beat emphasis)
        Atom(
            sizeQuarters: 2,
            type: .beta,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.55, moveAbility: 0.3),
                Marker(startTick: e,        stopTick: 3 * e,     intensity: 0.65, moveAbility: 0.3),
                Marker(startTick: 3 * e,    stopTick: 2 * q,     intensity: 0.50, moveAbility: 0.4)
            ],
            name: "relax_beta_syncopated_2q"
        ),
        // EMPTY (rest)
        Atom(
            sizeQuarters: 2,
            type: .empty,
            markers: [],
            name: "relax_empty_2q"
        ),
    ]

    // MARK: - RELAXATION — Bass / Chords

    private static let relaxBass: [Atom] = [
        // Whole-note root.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.50, moveAbility: 0.0)
            ],
            name: "relax_bass_root_4q"
        ),
        // Dotted half + quarter (soft push into beat 4).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 3 * q, intensity: 0.52, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 4 * q, intensity: 0.46, moveAbility: 0.0),
            ],
            name: "relax_bass_dotted_half_4q"
        ),
        // Root + 5th halves.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.52, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.48, moveAbility: 0.0),
            ],
            name: "relax_bass_halves_4q"
        ),
        // Fill — walking quarter notes into next phrase.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: q,     intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: q,     stopTick: 2 * q, intensity: 0.52, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 3 * q, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 4 * q, intensity: 0.60, moveAbility: 0.0),
            ],
            name: "relax_bass_fill_walking_4q"
        ),
    ]

    private static let relaxChords: [Atom] = [
        // Sustained whole.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.50, moveAbility: 0.1)
            ],
            name: "relax_chord_sustained_4q"
        ),
        // Gentle two-chord (change on beat 3).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.50, moveAbility: 0.1),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.48, moveAbility: 0.1),
            ],
            name: "relax_chord_change_3_4q"
        ),
        // Soft swell — late start.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: q, stopTick: 4 * q, intensity: 0.44, moveAbility: 0.2)
            ],
            name: "relax_chord_swell_4q"
        ),
        // Fill — arpeggiated pad across the last bar.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 4 * q, intensity: 0.48, moveAbility: 0.0),
                Marker(startTick: q,     stopTick: 4 * q, intensity: 0.45, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.42, moveAbility: 0.0),
            ],
            name: "relax_chord_fill_roll_4q"
        ),
    ]

    // MARK: - FOCUS — Melody (lo-fi piano feel)

    /// Focus is steady and predictable: 4-6 notes per 2-quarter atom,
    /// 8th-note grid, lo-fi piano feel. Tight to the grid.
    private static let focusMelody: [Atom] = [
        // ALPHA: steady 8ths (4 notes in 2 quarters)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.65, moveAbility: 0.1),
                Marker(startTick: e,        stopTick: q,         intensity: 0.50, moveAbility: 0.1),
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.60, moveAbility: 0.1),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.50, moveAbility: 0.1)
            ],
            name: "focus_alpha_8ths_2q"
        ),
        // ALPHA: dotted (note + rest + note pattern)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: de,        intensity: 0.65, moveAbility: 0.15),
                Marker(startTick: de,       stopTick: q,         intensity: 0.55, moveAbility: 0.15),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.55, moveAbility: 0.15)
            ],
            name: "focus_alpha_dotted_2q"
        ),
        // ALPHA: lo-fi gap (1 note + space + 2 notes)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: q,         intensity: 0.60, moveAbility: 0.15),
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.55, moveAbility: 0.15),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.50, moveAbility: 0.15)
            ],
            name: "focus_alpha_gap_2q"
        ),
        // BETA: syncopated (off-beat emphasis)
        Atom(
            sizeQuarters: 2,
            type: .beta,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.55, moveAbility: 0.1),
                Marker(startTick: e,        stopTick: 3 * e,     intensity: 0.65, moveAbility: 0.1),
                Marker(startTick: 3 * e,    stopTick: q + e,     intensity: 0.55, moveAbility: 0.1),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.60, moveAbility: 0.1)
            ],
            name: "focus_beta_syncopated_2q"
        ),
        // GAMMA: busy 16ths
        Atom(
            sizeQuarters: 2,
            type: .gamma,
            markers: [
                Marker(startTick: 0,        stopTick: s,         intensity: 0.60, moveAbility: 0.1),
                Marker(startTick: s,        stopTick: 2 * s,     intensity: 0.45, moveAbility: 0.1),
                Marker(startTick: 2 * s,    stopTick: 3 * s,     intensity: 0.55, moveAbility: 0.1),
                Marker(startTick: e + s,    stopTick: q,         intensity: 0.45, moveAbility: 0.1),
                Marker(startTick: q,        stopTick: q + s,     intensity: 0.60, moveAbility: 0.1),
                Marker(startTick: q + 2*s,  stopTick: q + 3*s,   intensity: 0.50, moveAbility: 0.1),
                Marker(startTick: q + e + s,stopTick: 2 * q,     intensity: 0.50, moveAbility: 0.1)
            ],
            name: "focus_gamma_16ths_2q"
        ),
        // EMPTY
        Atom(
            sizeQuarters: 2,
            type: .empty,
            markers: [],
            name: "focus_empty_2q"
        ),
    ]

    // MARK: - FOCUS — Bass (warm whole notes)

    private static let focusBass: [Atom] = [
        // Whole note root — the simplest focus bass.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.55, moveAbility: 0.0)
            ],
            name: "focus_bass_whole_4q"
        ),
        // Root + 5th halves.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.50, moveAbility: 0.0)
            ],
            name: "focus_bass_halves_4q"
        ),
        // Boom-bap: root on 1, root on 3-and (classic lo-fi hip-hop).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,             stopTick: q,     intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: 2 * q + e,     stopTick: 4 * q, intensity: 0.58, moveAbility: 0.0),
            ],
            name: "focus_bass_boombap_4q"
        ),
        // Walking quarters — upright feel.
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: 0,     stopTick: q,     intensity: 0.58, moveAbility: 0.0),
                Marker(startTick: q,     stopTick: 2 * q, intensity: 0.52, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 3 * q, intensity: 0.56, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 4 * q, intensity: 0.52, moveAbility: 0.0),
            ],
            name: "focus_bass_walking_4q"
        ),
        // Fill — chromatic walk-up into next phrase.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 3 * q, intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 4 * q, intensity: 0.65, moveAbility: 0.0),
            ],
            name: "focus_bass_fill_walkup_4q"
        ),
    ]

    // MARK: - FOCUS — Chords (sustained pads + Rhodes comping)

    private static let focusChords: [Atom] = [
        // Sustained whole — the default focus chord voice.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.45, moveAbility: 0.0)
            ],
            name: "focus_chord_sustained_4q"
        ),
        // Rhodes comp on beat 1 and 3-and (lo-fi comping).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: q,         intensity: 0.48, moveAbility: 0.0),
                Marker(startTick: 2 * q + e, stopTick: 4 * q,     intensity: 0.44, moveAbility: 0.0),
            ],
            name: "focus_chord_comp_lofi_4q"
        ),
        // Chord change halfway — two colours per bar.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: 2 * q, intensity: 0.46, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 4 * q, intensity: 0.44, moveAbility: 0.0),
            ],
            name: "focus_chord_halves_4q"
        ),
        // Fill — short stab on every beat (turnaround).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: e,         intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: q + e,     intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 2 * q + e, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 3 * q + e, intensity: 0.60, moveAbility: 0.0),
            ],
            name: "focus_chord_fill_stabs_4q"
        ),
    ]

    // MARK: - FOCUS — Drums (very minimal, side stick on 2 & 4)

    // MARK: - FOCUS — Drums (kit-neutral trance patterns)
    //
    // Focus drum atoms are kit-neutral: they encode the RHYTHM and
    // general intensity tier (low / mid / high-accent). The
    // WeirdnessResolver translates each intensity tier into the
    // correct percussion note for the seed's selected DrumKit —
    // sparse rock kit, congas, or tabla. That lets a single pattern
    // sound like a sidestick loop, a conga pattern, or a tabla cycle
    // without maintaining three parallel atom libraries.
    //
    // Intensity tiers used throughout:
    //   0.92+  → low-tier hit (kick / low conga / bayan)
    //   0.72-  → mid-tier hit (snare / mid conga / tabla slap)
    //   0.55-  → high-tier hit (closed hat / high conga / tabla tin)
    private static let focusDrums: [Atom] = [
        // Hypnotic downbeat pulse: low hit on beat 1, high hit on
        // every 8th after. Trance four-on-the-floor without snares.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: s,         intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: e,         stopTick: e + s,     intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: q + s,     intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: q + e,     stopTick: q + e + s, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s, intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 2 * q + e, stopTick: 2 * q + e + s, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s, intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 3 * q + e, stopTick: 3 * q + e + s, intensity: 0.55, moveAbility: 0.0),
            ],
            name: "focus_drum_pulse_4q"
        ),
        // Downbeat + backbeat spine — low on 1+3, mid on 2+4,
        // high on the "ands". The most song-like focus drum.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: s,         intensity: 0.95),
                Marker(startTick: e,         stopTick: e + s,     intensity: 0.55),
                Marker(startTick: q,         stopTick: q + s,     intensity: 0.72),
                Marker(startTick: q + e,     stopTick: q + e + s, intensity: 0.55),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s, intensity: 0.95),
                Marker(startTick: 2 * q + e, stopTick: 2 * q + e + s, intensity: 0.55),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s, intensity: 0.72),
                Marker(startTick: 3 * q + e, stopTick: 3 * q + e + s, intensity: 0.55),
            ],
            name: "focus_drum_backbeat_4q"
        ),
        // Syncopated trance pattern — low on 1 + 2-and, mid on 3,
        // scattered high hits.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,         stopTick: s,         intensity: 0.95),
                Marker(startTick: e,         stopTick: e + s,     intensity: 0.55),
                Marker(startTick: q + e,     stopTick: q + e + s, intensity: 0.92),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s, intensity: 0.72),
                Marker(startTick: 2 * q + e, stopTick: 2 * q + e + s, intensity: 0.55),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s, intensity: 0.55),
                Marker(startTick: 3 * q + e, stopTick: 3 * q + e + s, intensity: 0.55),
            ],
            name: "focus_drum_synco_4q"
        ),
        // Sparse groove — every beat a high hit, low on 1 only.
        // The minimum-viable focus drum atom.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: s,         intensity: 0.95),
                Marker(startTick: q,     stopTick: q + s,     intensity: 0.55),
                Marker(startTick: 2 * q, stopTick: 2 * q + s, intensity: 0.55),
                Marker(startTick: 3 * q, stopTick: 3 * q + s, intensity: 0.55),
            ],
            name: "focus_drum_sparse_4q"
        ),
        // EMPTY bar for breath.
        Atom(
            sizeQuarters: 4,
            type: .empty,
            markers: [],
            name: "focus_drum_empty_4q"
        ),
    ]

    // MARK: - ENERGIZE — Melody (driving riffs with rests)

    /// Energize melody: hooks and stabs with strong downbeats.
    /// Bass and drums carry the groove — melody is sparse and emphatic.
    private static let energizeMelody: [Atom] = [
        // ALPHA: stab on beat 1 + stab on beat 2 (sparse hook)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.75, moveAbility: 0.0)
            ],
            name: "energize_alpha_stabs_2q"
        ),
        // ALPHA: 4 8th notes (driving)
        Atom(
            sizeQuarters: 2,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: e,        stopTick: q,         intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.65, moveAbility: 0.0)
            ],
            name: "energize_alpha_8ths_2q"
        ),
        // BETA: syncopated hook (rest + 2 notes + rest + note)
        Atom(
            sizeQuarters: 2,
            type: .beta,
            markers: [
                Marker(startTick: e,        stopTick: 3 * e,     intensity: 0.80, moveAbility: 0.0),
                Marker(startTick: 3 * e,    stopTick: q + e,     intensity: 0.70, moveAbility: 0.0),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.85, moveAbility: 0.0)
            ],
            name: "energize_beta_hook_2q"
        ),
        // GAMMA: dense run
        Atom(
            sizeQuarters: 2,
            type: .gamma,
            markers: [
                Marker(startTick: 0,        stopTick: s,         intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: s,        stopTick: 2 * s,     intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: 2 * s,    stopTick: 3 * s,     intensity: 0.70, moveAbility: 0.0),
                Marker(startTick: 3 * s,    stopTick: q,         intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: q,        stopTick: q + s,     intensity: 0.80, moveAbility: 0.0),
                Marker(startTick: q + s,    stopTick: q + 2 * s, intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: q + 2 * s,stopTick: q + 3 * s, intensity: 0.70, moveAbility: 0.0),
                Marker(startTick: q + 3 * s,stopTick: 2 * q,     intensity: 0.65, moveAbility: 0.0)
            ],
            name: "energize_gamma_run_2q"
        ),
        // EMPTY (let the rhythm section breathe)
        Atom(
            sizeQuarters: 2,
            type: .empty,
            markers: [],
            name: "energize_empty_2q"
        ),
    ]

    // MARK: - ENERGIZE — Bass (locked to kick)

    private static let energizeBass: [Atom] = [
        // Quarter notes — default four-on-the-floor lock.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,        stopTick: e + s,     intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: q,        stopTick: q + e + s, intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 2 * q,    stopTick: 2*q + e + s, intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: 3 * q,    stopTick: 3*q + e + s, intensity: 0.75, moveAbility: 0.0)
            ],
            name: "energize_bass_quarters_4q"
        ),
        // 8th note pattern (root, root, fifth, root, ...).
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: 0,        stopTick: e,         intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: e,        stopTick: q,         intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: q + e,    stopTick: 2 * q,     intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 2 * q,    stopTick: 2*q + e,   intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: 2*q + e,  stopTick: 3 * q,     intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 3 * q,    stopTick: 3*q + e,   intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 3*q + e,  stopTick: 4 * q,     intensity: 0.55, moveAbility: 0.0)
            ],
            name: "energize_bass_8ths_4q"
        ),
        // Syncopated house bass — root on 1, root on 2-and, root on 4.
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: 0,             stopTick: e,         intensity: 0.88, moveAbility: 0.0),
                Marker(startTick: q + e,         stopTick: 2 * q,     intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 2 * q + e,     stopTick: 3 * q,     intensity: 0.78, moveAbility: 0.0),
                Marker(startTick: 3 * q,         stopTick: 3 * q + e, intensity: 0.85, moveAbility: 0.0),
            ],
            name: "energize_bass_house_synco_4q"
        ),
        // 16th pulse — aggressive driving pattern.
        Atom(
            sizeQuarters: 4,
            type: .gamma,
            markers: (0..<16).map { i in
                Marker(
                    startTick: i * s,
                    stopTick: i * s + s,
                    intensity: i % 4 == 0 ? 0.88 : 0.62,
                    moveAbility: 0.0
                )
            },
            name: "energize_bass_16ths_4q"
        ),
        // Fill — octave walk-up into the next section.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: q,     intensity: 0.80, moveAbility: 0.0),
                Marker(startTick: q,     stopTick: 2 * q, intensity: 0.82, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 3 * q, intensity: 0.85, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 4 * q, intensity: 0.92, moveAbility: 0.0),
            ],
            name: "energize_bass_fill_walkup_4q"
        ),
    ]

    // MARK: - ENERGIZE — Chords (stabs on backbeats)

    private static let energizeChords: [Atom] = [
        // BETA: chord stabs on beats 2 and 4.
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: q,        stopTick: q + e,     intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: 3 * q,    stopTick: 3 * q + e, intensity: 0.65, moveAbility: 0.0)
            ],
            name: "energize_chord_stabs_4q"
        ),
        // ALPHA: sustained pad.
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0, stopTick: 4 * q, intensity: 0.55, moveAbility: 0.0)
            ],
            name: "energize_chord_pad_4q"
        ),
        // ALPHA: 8th-note comping (uplifting push).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,             stopTick: s,         intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: e,             stopTick: e + s,     intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: q,             stopTick: q + s,     intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: q + e,         stopTick: q + e + s, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 2 * q,         stopTick: 2 * q + s, intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: 2 * q + e,     stopTick: 2 * q + e + s, intensity: 0.55, moveAbility: 0.0),
                Marker(startTick: 3 * q,         stopTick: 3 * q + s, intensity: 0.60, moveAbility: 0.0),
                Marker(startTick: 3 * q + e,     stopTick: 3 * q + e + s, intensity: 0.55, moveAbility: 0.0),
            ],
            name: "energize_chord_pumping_4q"
        ),
        // BETA: syncopated stab pattern (house / synthwave feel).
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                Marker(startTick: e,             stopTick: q,         intensity: 0.62, moveAbility: 0.0),
                Marker(startTick: q + e,         stopTick: 2 * q,     intensity: 0.65, moveAbility: 0.0),
                Marker(startTick: 2 * q + e,     stopTick: 3 * q,     intensity: 0.62, moveAbility: 0.0),
                Marker(startTick: 3 * q + e,     stopTick: 4 * q,     intensity: 0.68, moveAbility: 0.0),
            ],
            name: "energize_chord_synco_4q"
        ),
        // Fill — chord stab on every quarter (turnaround).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(startTick: 0,     stopTick: e,         intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: q,     stopTick: q + e,     intensity: 0.72, moveAbility: 0.0),
                Marker(startTick: 2 * q, stopTick: 2 * q + e, intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 3 * q, stopTick: 3 * q + e, intensity: 0.85, moveAbility: 0.0),
            ],
            name: "energize_chord_fill_punches_4q"
        ),
    ]

    // MARK: - ENERGIZE — Drums (four-on-the-floor)

    /// Drum atoms encode multi-element patterns via Marker intensity:
    ///   intensity ~0.95 → kick
    ///   intensity ~0.75 → snare
    ///   intensity ~0.50 → closed hi-hat
    ///   intensity ~0.35 → open hi-hat
    private static let energizeDrums: [Atom] = [
        // ALPHA: classic four-on-the-floor (1 bar)
        // Beat 1: kick + closed hat
        // Beat 1.5 (and): closed hat
        // Beat 2: snare + closed hat
        // Beat 2.5 (and): closed hat
        // Beat 3: kick + closed hat
        // Beat 3.5 (and): closed hat
        // Beat 4: snare + open hat
        // Beat 4.5 (and): closed hat
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                // Beat 1: kick + hat
                Marker(startTick: 0,         stopTick: s,             intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 0,         stopTick: s,             intensity: 0.50, moveAbility: 0.0),
                // Beat 1.5: hat
                Marker(startTick: e,         stopTick: e + s,         intensity: 0.50, moveAbility: 0.0),
                // Beat 2: snare + hat
                Marker(startTick: q,         stopTick: q + s,         intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: q + s,         intensity: 0.50, moveAbility: 0.0),
                // Beat 2.5: hat
                Marker(startTick: q + e,     stopTick: q + e + s,     intensity: 0.50, moveAbility: 0.0),
                // Beat 3: kick + hat
                Marker(startTick: 2 * q,     stopTick: 2 * q + s,     intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s,     intensity: 0.50, moveAbility: 0.0),
                // Beat 3.5: hat
                Marker(startTick: 2 * q + e, stopTick: 2 * q + e + s, intensity: 0.50, moveAbility: 0.0),
                // Beat 4: snare + open hat
                Marker(startTick: 3 * q,     stopTick: 3 * q + s,     intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s,     intensity: 0.35, moveAbility: 0.0),
                // Beat 4.5: hat
                Marker(startTick: 3 * q + e, stopTick: 3 * q + e + s, intensity: 0.50, moveAbility: 0.0),
            ],
            name: "energize_drums_4onfloor_4q"
        ),
        // BETA: same 4-on-floor + extra kick on 4-and (syncopated)
        Atom(
            sizeQuarters: 4,
            type: .beta,
            markers: [
                // Same as alpha
                Marker(startTick: 0,         stopTick: s, intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 0,         stopTick: s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: e,         stopTick: e + s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: q + s, intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: q,         stopTick: q + s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: q + e,     stopTick: q + e + s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s, intensity: 0.95, moveAbility: 0.0),
                Marker(startTick: 2 * q,     stopTick: 2 * q + s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: 2 * q + e, stopTick: 2 * q + e + s, intensity: 0.50, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s, intensity: 0.75, moveAbility: 0.0),
                Marker(startTick: 3 * q,     stopTick: 3 * q + s, intensity: 0.35, moveAbility: 0.0),
                // Extra: kick on 4-and (syncopation)
                Marker(startTick: 3 * q + e, stopTick: 3 * q + e + s, intensity: 0.85, moveAbility: 0.0),
            ],
            name: "energize_drums_4onfloor_synco_4q"
        ),
        // GAMMA: 16th hi-hats added on top (busy)
        Atom(
            sizeQuarters: 4,
            type: .gamma,
            markers: {
                var m: [Marker] = []
                // Kick on 1 and 3
                m.append(Marker(startTick: 0,     stopTick: s, intensity: 0.95))
                m.append(Marker(startTick: 2 * q, stopTick: 2 * q + s, intensity: 0.95))
                // Snare on 2 and 4
                m.append(Marker(startTick: q,     stopTick: q + s, intensity: 0.75))
                m.append(Marker(startTick: 3 * q, stopTick: 3 * q + s, intensity: 0.75))
                // 16th hats
                for i in 0..<16 {
                    m.append(Marker(startTick: i * s, stopTick: i * s + s / 2, intensity: 0.50))
                }
                return m
            }(),
            name: "energize_drums_busy_4q"
        ),
        // Fill — classic snare roll into downbeat (last bar of section).
        Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: {
                var m: [Marker] = []
                // Bars 1-3: standard kick/snare, just to keep energy up.
                m.append(Marker(startTick: 0,     stopTick: s, intensity: 0.95))
                m.append(Marker(startTick: q,     stopTick: q + s, intensity: 0.75))
                m.append(Marker(startTick: 2 * q, stopTick: 2 * q + s, intensity: 0.95))
                // Beat 4: 16th snare roll crescendo.
                for i in 0..<4 {
                    let tick = 3 * q + i * s
                    m.append(Marker(
                        startTick: tick,
                        stopTick: tick + s,
                        intensity: 0.70 + Double(i) * 0.05  // 0.70 → 0.85
                    ))
                }
                return m
            }(),
            name: "energize_drums_fill_snareroll_4q"
        ),
    ]
}
