// AtomGenerator.swift
// BioNaural — v3 Composing Core
//
// Parametric atom generators. The hand-authored AtomLibrary ships a
// handful of rhythmic variants per (mode, role) combo — enough for
// stylistic flavor but not enough for near-infinite session variety.
// This file adds rule-based generators that produce fresh atoms at
// seed-creation time so every session gets its own rhythmic content.
//
// Each generator takes a seeded RandomNumberGenerator and emits a
// batch of atoms sampled from a stylistic probability envelope. The
// envelopes are hand-tuned to each genre's conventions:
//
//   Focus — trip-hop / lo-fi hip-hop: kick on 1 + snare on 3 are
//   fixed anchors; ghost kicks land on the "and" of 2 / 3 / 4 with
//   staged probability; snare ghost notes sit on the "e" of 2 or 4;
//   hat patterns are drawn from {quarter / 8th / 16th / dotted}.
//
//   Bass follows the drum kick pattern for rhythmic lock but
//   varies its own internal voicing: sometimes held, sometimes
//   re-articulated, sometimes walking.
//
//   Melody draws 1-4 note positions from a beat-weighted distribution
//   (beats 1 and 3 most likely, offbeats less, 16ths rarely).
//
// Deterministic per seed: passing the same RNG state to any of the
// generators produces the same atom pool, so regeneration within a
// session stays consistent. Different seeds → different pools.

import BioNauralShared
import Foundation

public enum AtomGenerator {

    // MARK: - Tick helpers (480 PPQN)

    private static let q: Int = Composing.ticksPerQuarter        // 480 = 1 quarter
    private static let e: Int = Composing.ticksPerQuarter / 2    // 240 = 1 eighth
    private static let s: Int = Composing.ticksPerQuarter / 4    // 120 = 1 sixteenth

    // MARK: - Public API

    /// Generate a batch of focus drum atoms for one session. Each
    /// atom is a 4-quarter (1-bar) pattern with kick on beat 1,
    /// snare on beat 3, and randomized ghost kicks + hat style.
    public static func generateFocusDrumAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateFocusDrum(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of focus bass atoms. Each atom hits the root
    /// on beat 1 (lock with kick) and adds a random selection of
    /// secondary hits on off-beats / beat 3 "and" / beat 4.
    public static func generateFocusBassAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateFocusBass(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of focus melody atoms. 4-quarter bars with
    /// 1-4 sparse notes drawn from a beat-weighted position set.
    public static func generateFocusMelodyAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateFocusMelody(index: i, using: &generator))
        }
        return atoms
    }

    // MARK: - Sleep generators (public entry points)

    /// Generate a batch of sleep melody atoms — 4-quarter bars with
    /// 0-2 notes, long sustains, quiet velocities, descending
    /// contour reinforcement.
    public static func generateSleepMelodyAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateSleepMelody(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of sleep bass atoms — mostly whole-note
    /// drones, occasionally split into a slow half-note pair.
    public static func generateSleepBassAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateSleepBass(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of sleep chord atoms — sustained whole-note
    /// pads with occasional late-start swells for breath.
    public static func generateSleepChordAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateSleepChord(index: i, using: &generator))
        }
        return atoms
    }

    // MARK: - Relax generators (public entry points)

    /// Generate a batch of relax melody atoms — 2-4 notes per bar
    /// drawn from an arch-shaped position distribution.
    public static func generateRelaxMelodyAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateRelaxMelody(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of relax bass atoms — half-note or
    /// dotted-half patterns that breathe with the chord changes.
    public static func generateRelaxBassAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateRelaxBass(index: i, using: &generator))
        }
        return atoms
    }

    /// Generate a batch of relax chord atoms — sustained or
    /// half-change voicings with gentle movement.
    public static func generateRelaxChordAtoms<G: RandomNumberGenerator>(
        count: Int = 8,
        using generator: inout G
    ) -> [Atom] {
        var atoms: [Atom] = []
        for i in 0..<count {
            atoms.append(generateRelaxChord(index: i, using: &generator))
        }
        return atoms
    }

    // MARK: - Focus drums

    private static func generateFocusDrum<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // SPARSE focus percussion. 1-2 soft hits per bar MAX.
        // Tabla, conga, or shaker — never drum kit. The resolver
        // maps intensities to the softest available GM percussion:
        //   0.72 → low bongo / open conga (soft mid tone)
        //   0.55 → high bongo / mute conga (soft high tone)
        //   <0.45 → maracas (shaker)
        //
        // No 8th notes. No quarter-note pulse. Just 1-2 gentle
        // touches per bar that you barely register consciously.
        var markers: [Marker] = []

        let feel = Int.random(in: 0..<4, using: &generator)
        switch feel {
        case 0:
            // Single hit on beat 1 — the sparsest possible.
            markers.append(Marker(
                startTick: 0,
                stopTick: s,
                intensity: 0.72
            ))
        case 1:
            // Two hits: beat 1 and beat 3. Half-note pulse.
            markers.append(Marker(startTick: 0,     stopTick: s, intensity: 0.72))
            markers.append(Marker(startTick: 2 * q, stopTick: 2 * q + s, intensity: 0.55))
        case 2:
            // Single shaker on beat 1 only.
            markers.append(Marker(
                startTick: 0,
                stopTick: s,
                intensity: 0.30
            ))
        default:
            // Two shaker touches: beat 1 and beat 3.
            markers.append(Marker(startTick: 0,     stopTick: s, intensity: 0.30))
            markers.append(Marker(startTick: 2 * q, stopTick: 2 * q + s, intensity: 0.28))
        }

        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: markers,
            name: "gen_focus_drum_\(index)"
        )
    }

    // MARK: - Focus bass

    private static func generateFocusBass<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Research-grounded: simpler = less cognitive load.
        // Bass just holds the root for the full bar. Pitch changes
        // only when the HarmonicContext chord changes (every 2 bars
        // per the slowed-down progression). No passing tones, no
        // walking, no syncopation. A sub-bass drone anchor.
        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(
                    startTick: 0,
                    stopTick: 4 * q,
                    intensity: 0.70,
                    moveAbility: 0.0
                )
            ],
            name: "gen_focus_bass_\(index)"
        )
    }

    // MARK: - Focus melody

    private static func generateFocusMelody<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Research-optimal focus "melody": one sustained tone held
        // for the ENTIRE bar, or silence. Not a melodic phrase —
        // a pad-like sustained voice that reinforces the current
        // chord. The harmonic context (changing every 2 bars)
        // provides all the movement; the "melody" just picks one
        // chord/scale tone and holds it.
        //
        // Kämpfe 2011: fewer events = less cognitive load.
        // Brain.fm: long sustained tones, not melodic fragments.
        //
        // 80% chance of a sustained tone, 20% silence.
        let isSilent = Double.random(in: 0...1, using: &generator) < 0.20

        if isSilent {
            return Atom(
                sizeQuarters: 4,
                type: .empty,
                markers: [],
                name: "gen_focus_melody_\(index)"
            )
        }

        // Single tone starting on beat 1, held for the full bar.
        // Intensity varies slightly across generated atoms so
        // different bars have subtly different velocity — just
        // enough variation to prevent machine-perfect sameness.
        let intensity = 0.45 + Double.random(in: -0.05...0.10, using: &generator)

        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(
                    startTick: 0,
                    stopTick: 4 * q,
                    intensity: max(0.1, min(0.9, intensity)),
                    moveAbility: 0.0
                )
            ],
            name: "gen_focus_melody_\(index)"
        )
    }

    // MARK: - Sleep atom generators

    private static func generateSleepMelody<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Sleep melody is nearly silent. 0-2 notes per bar, held
        // long, never on the off-beats. Intensities low (0.40-0.55)
        // so the density envelope + metric curve keeps them quiet.
        let shape = [0, 1, 1, 2, 2, 2].randomElement(using: &generator) ?? 1

        if shape == 0 {
            // Full-bar rest — lets the pad breathe alone.
            return Atom(
                sizeQuarters: 4,
                type: .empty,
                markers: [],
                name: "gen_sleep_melody_\(index)"
            )
        }

        if shape == 1 {
            // One long note. Start tick randomized among beat 1,
            // "and" of 1, beat 2 so the note entries vary.
            let startCandidates = [0, e, q, q + e]
            let startTick = startCandidates.randomElement(using: &generator) ?? 0
            let intensity = 0.45 + Double.random(in: -0.05...0.10, using: &generator)
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: startTick,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.4
                    )
                ],
                name: "gen_sleep_melody_\(index)"
            )
        }

        // shape == 2: two-note fall. First on beat 1-2, second
        // later and quieter (descending contour reinforcement).
        let firstStart = [0, e].randomElement(using: &generator) ?? 0
        let secondStart = [2 * q, 2 * q + e, 3 * q].randomElement(using: &generator) ?? (2 * q)
        let firstIntensity = 0.48 + Double.random(in: -0.05...0.10, using: &generator)
        let secondIntensity = 0.38 + Double.random(in: -0.05...0.08, using: &generator)
        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(
                    startTick: firstStart,
                    stopTick: secondStart,
                    intensity: max(0.1, min(0.9, firstIntensity)),
                    moveAbility: 0.5
                ),
                Marker(
                    startTick: secondStart,
                    stopTick: 4 * q,
                    intensity: max(0.1, min(0.9, secondIntensity)),
                    moveAbility: 0.6
                )
            ],
            name: "gen_sleep_melody_\(index)"
        )
    }

    private static func generateSleepBass<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Mostly whole-note drones, occasionally a half-note pair.
        let shape = [0, 0, 0, 1].randomElement(using: &generator) ?? 0
        let intensity = 0.40 + Double.random(in: -0.05...0.08, using: &generator)

        if shape == 0 {
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.0
                    )
                ],
                name: "gen_sleep_bass_\(index)"
            )
        }

        // Two half notes — root then (potentially) a different
        // chord root as the HC changes on beat 3.
        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: [
                Marker(
                    startTick: 0,
                    stopTick: 2 * q,
                    intensity: max(0.1, min(0.9, intensity)),
                    moveAbility: 0.0
                ),
                Marker(
                    startTick: 2 * q,
                    stopTick: 4 * q,
                    intensity: max(0.1, min(0.9, intensity - 0.04)),
                    moveAbility: 0.0
                )
            ],
            name: "gen_sleep_bass_\(index)"
        )
    }

    private static func generateSleepChord<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Three variants: sustained whole-note pad, late-start
        // swell (enters after beat 1), or a breath-like two-half
        // fade. All at very low intensity so the reverb tail does
        // the heavy lifting.
        let shape = [0, 1, 2, 0, 0].randomElement(using: &generator) ?? 0
        let intensity = 0.38 + Double.random(in: -0.04...0.08, using: &generator)

        switch shape {
        case 1:
            // Late start — pad swells in around beat 2.
            let start = [q, q + e, q + q / 2].randomElement(using: &generator) ?? q
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: start,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.04)),
                        moveAbility: 0.3
                    )
                ],
                name: "gen_sleep_chord_\(index)"
            )
        case 2:
            // Two-half breath.
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 2 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.2
                    ),
                    Marker(
                        startTick: 2 * q,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.03)),
                        moveAbility: 0.2
                    )
                ],
                name: "gen_sleep_chord_\(index)"
            )
        default:
            // Default whole-note pad.
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.2
                    )
                ],
                name: "gen_sleep_chord_\(index)"
            )
        }
    }

    // MARK: - Relax atom generators

    private static func generateRelaxMelody<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Relax melody is gentle and arching. 2-4 notes per bar
        // drawn from a beat-weighted distribution, with intensities
        // that peak mid-phrase for a breath-like shape.
        let noteCount = [2, 2, 3, 3, 3, 4].randomElement(using: &generator) ?? 3

        // Position candidates — favor on-beats and gentle off-8ths.
        let positions: [Int] = [0, 0, q, q, 2 * q, 2 * q, 3 * q, q + e, 2 * q + e, 3 * q + e]
        var pool = positions
        var chosen: [Int] = []
        for _ in 0..<noteCount {
            guard !pool.isEmpty else { break }
            let idx = Int.random(in: 0..<pool.count, using: &generator)
            let tick = pool[idx]
            if !chosen.contains(tick) { chosen.append(tick) }
            pool.remove(at: idx)
        }
        chosen.sort()

        // Emit markers with an arch-shaped intensity curve — middle
        // notes slightly louder than the outer ones.
        var markers: [Marker] = []
        for (i, tick) in chosen.enumerated() {
            let next = (i + 1 < chosen.count) ? chosen[i + 1] : 4 * q
            let position = chosen.count == 1 ? 0.5 : Double(i) / Double(max(1, chosen.count - 1))
            let archBoost = sin(.pi * position) * 0.10
            let intensity = 0.55 + archBoost + Double.random(in: -0.04...0.04, using: &generator)
            markers.append(
                Marker(
                    startTick: tick,
                    stopTick: next,
                    intensity: max(0.1, min(0.9, intensity)),
                    moveAbility: 0.2
                )
            )
        }

        return Atom(
            sizeQuarters: 4,
            type: .alpha,
            markers: markers,
            name: "gen_relax_melody_\(index)"
        )
    }

    private static func generateRelaxBass<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Three patterns: whole note (drone), two halves (gentle
        // change on beat 3), dotted-half plus quarter (push into
        // beat 4). All at moderate intensity.
        let shape = [0, 0, 1, 1, 2].randomElement(using: &generator) ?? 0
        let intensity = 0.50 + Double.random(in: -0.05...0.08, using: &generator)

        switch shape {
        case 1:
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 2 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.0
                    ),
                    Marker(
                        startTick: 2 * q,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.03)),
                        moveAbility: 0.0
                    )
                ],
                name: "gen_relax_bass_\(index)"
            )
        case 2:
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 3 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.0
                    ),
                    Marker(
                        startTick: 3 * q,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.03)),
                        moveAbility: 0.0
                    )
                ],
                name: "gen_relax_bass_\(index)"
            )
        default:
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.0
                    )
                ],
                name: "gen_relax_bass_\(index)"
            )
        }
    }

    private static func generateRelaxChord<G: RandomNumberGenerator>(
        index: Int,
        using generator: inout G
    ) -> Atom {
        // Sustained whole notes or two-half voice changes, with
        // occasional gentle late swells.
        let shape = [0, 0, 1, 1, 2].randomElement(using: &generator) ?? 0
        let intensity = 0.46 + Double.random(in: -0.04...0.08, using: &generator)

        switch shape {
        case 1:
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 2 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.1
                    ),
                    Marker(
                        startTick: 2 * q,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.02)),
                        moveAbility: 0.1
                    )
                ],
                name: "gen_relax_chord_\(index)"
            )
        case 2:
            // Late swell.
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: q,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity - 0.04)),
                        moveAbility: 0.2
                    )
                ],
                name: "gen_relax_chord_\(index)"
            )
        default:
            return Atom(
                sizeQuarters: 4,
                type: .alpha,
                markers: [
                    Marker(
                        startTick: 0,
                        stopTick: 4 * q,
                        intensity: max(0.1, min(0.9, intensity)),
                        moveAbility: 0.1
                    )
                ],
                name: "gen_relax_chord_\(index)"
            )
        }
    }
}
