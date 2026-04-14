// CompositionSeed.swift
// BioNaural — v3 Composing Core
//
// A CompositionSeed carries every randomized choice that turns a
// FocusMode into a unique session: the root key, the scale, the GM
// SoundFont programs for each track role, and an index into the
// mode's progression pool. The seed is generated once at session
// start and reused across biometric regenerations so the listener
// never hears an instrument change mid-session — only density,
// articulation, and pattern detail vary.
//
// Sleep leans toward low, warm keys (F, C, G) and scales with minimal
// dissonance (pentatonicMinor, lydian for dreamy stretches).
// Relaxation uses gentle modes (lydian, dorian, major) over G/D/A
// pivots. Focus cycles lo-fi piano keys (C, G, F) and the
// pentatonicMajor/dorian/minor family. Energize picks bright or
// driving modes (major, mixolydian, lydian) over D/G/A.

import BioNauralShared
import Foundation
@preconcurrency import Tonic

// MARK: - DrumKit

/// Percussion character for a focus session. The seed picks one at
/// session start; the WeirdnessResolver translates drum-atom marker
/// intensities into kit-appropriate MIDI notes at resolve time.
///
/// - sparseKit: kick + snare + hat + sidestick, very restrained, no fills
/// - congas: low/mid/high conga + shaker, head-nod Latin feel
/// - tabla: low floor tom (bayan) + low/mid tom + timbale (tabla slap),
///          trance-drone companion
public enum DrumKit: String, Sendable, Hashable, CaseIterable {
    case sparseKit
    case congas
    case tabla
}

// MARK: - CompositionSeed

public struct CompositionSeed: Sendable, Hashable {

    /// The mode this seed was generated for. Seeds are not reusable
    /// across modes — a new seed is generated on mode switch.
    public let mode: FocusMode

    /// The randomized root note for the session.
    public let root: NoteClass

    /// The randomized scale for the session.
    public let scale: Scale

    /// The randomized GM program numbers per track role. Mutable so
    /// AudioEngine.reshuffleRole can swap in a new instrument for
    /// one specific track without disturbing the others.
    public var gmPrograms: [TrackRole: UInt8]

    /// Index into the mode's chord progression pool.
    public let progressionVariant: Int

    /// Per-session tempo offset in BPM applied to the mode's default
    /// tempo. Ranges are small (±6 BPM typical) so each session keeps
    /// its mode character but feels distinct in pulse.
    public let tempoOffsetBPM: Double

    /// Swing amount in ticks. Positive values delay every off-8th note
    /// within an atom, producing shuffle / lo-fi feel. 0 = straight,
    /// ~40 = light swing, ~80 = hard shuffle.
    public let swingTicks: Int

    /// Percussion kit for focus sessions. Nil for modes that don't
    /// carry drums (sleep, relaxation) or for a future custom mode.
    public let drumKit: DrumKit?

    /// Per-role "shuffle" counter. Incremented each time the user
    /// taps a "new melody / new bass / new drums / new ambient"
    /// button in the mix panel. CompositionPlanner uses it as an
    /// index offset into the candidate atom pool so each press
    /// picks a different atom from the current pool without
    /// regenerating the whole seed.
    public var roleAtomOffset: [TrackRole: Int] = [:]

    /// Parametrically-generated atoms per role, created at
    /// seed-generation time. These are prepended to the hand-authored
    /// AtomLibrary pool by CompositionPlanner.buildMolecule so each
    /// session has its own rhythmic vocabulary. Stable for the life
    /// of the seed — regenerations during biometric/arc changes
    /// pick from the same generated pool.
    public let generatedAtoms: [TrackRole: [Atom]]

    // MARK: - Generation

    /// Build a fresh random seed for the given mode using `generator`
    /// (defaults to SystemRandomNumberGenerator for production; tests
    /// can pass a deterministic generator).
    public static func random<G: RandomNumberGenerator>(
        for mode: FocusMode,
        using generator: inout G
    ) -> CompositionSeed {
        let root = pick(rootPool(for: mode), using: &generator)
        let scale = pick(scalePool(for: mode), using: &generator)
        let variant = Int.random(in: 0..<progressionVariantCount(for: mode), using: &generator)

        var programs: [TrackRole: UInt8] = [:]
        for role in TrackRole.allCases {
            if let pool = programPool(mode: mode, role: role) {
                programs[role] = pick(pool, using: &generator)
            }
        }

        let tempoRange = tempoOffsetRange(for: mode)
        let tempoOffset = Double.random(in: tempoRange, using: &generator)
        let swing = swingTicks(for: mode)
        let drumKit: DrumKit? = (mode == .focus) ? .sparseKit : nil

        // Randomize roleAtomOffset so two back-to-back sessions
        // start with different atom picks instead of always landing
        // on candidates[0]. The molecule builder applies this as
        // `shuffleOffset % candidates.count`, so any int in a
        // reasonable range wraps onto a real candidate.
        var atomOffsets: [TrackRole: Int] = [:]
        for role in TrackRole.allCases {
            atomOffsets[role] = Int.random(in: 0..<16, using: &generator)
        }

        // Parametrically generate atoms per role so each session
        // has its own rhythmic vocabulary. Currently only Focus
        // has generators; Sleep and Relax continue to use the
        // hand-authored AtomLibrary pools.
        var generated: [TrackRole: [Atom]] = [:]
        if mode == .focus {
            generated[.drums]  = AtomGenerator.generateFocusDrumAtoms(count: 8, using: &generator)
            generated[.bass]   = AtomGenerator.generateFocusBassAtoms(count: 8, using: &generator)
            generated[.melody] = AtomGenerator.generateFocusMelodyAtoms(count: 8, using: &generator)
        }

        var seed = CompositionSeed(
            mode: mode,
            root: root,
            scale: scale,
            gmPrograms: programs,
            progressionVariant: variant,
            tempoOffsetBPM: tempoOffset,
            swingTicks: swing,
            drumKit: drumKit,
            generatedAtoms: generated
        )
        seed.roleAtomOffset = atomOffsets
        return seed
    }

    /// Per-mode tempo variation ranges. Sleep and relaxation get small
    /// ranges (pulse matters less); focus and energize get slightly
    /// wider windows so two sessions feel distinct in drive.
    public static func tempoOffsetRange(for mode: FocusMode) -> ClosedRange<Double> {
        switch mode {
        // Sleep stays slow and steady.
        case .sleep:       return -4.0 ... 2.0
        // Relaxation: ambient sits 55-70 BPM — default is 60, ±5.
        case .relaxation:  return -5.0 ... 5.0
        // Focus: slow trip-hop / hip-hop. Default tempo is 72 so
        // -4..+14 puts sessions at 68-86 BPM — the head-nod pocket
        // where Nujabes, J Dilla, Massive Attack, and DJ Shadow
        // built their focus-adjacent music. Slower than we had
        // before (was 80-100) per user feedback.
        case .focus:       return -4.0 ... 14.0
        // Energize: legacy mode, hidden from UI. Kept for data
        // compatibility but no user path currently selects it.
        case .energize:    return -32.0 ... -18.0
        }
    }

    /// Per-mode swing amount (PPQN = 480). Focus gets classic lo-fi
    /// shuffle; relaxation gets a hint of rubato; sleep and energize
    /// stay straight.
    public static func swingTicks(for mode: FocusMode) -> Int {
        switch mode {
        case .sleep:       return 0
        case .relaxation:  return 0
        // Focus is trip-hop / lo-fi hip-hop now. Real lo-fi has
        // classic ~56-58% swing on the off-8ths; 48 ticks at 480
        // PPQN is a light Dilla shuffle that reads as "groovy"
        // without dragging the pocket.
        case .focus:       return 48
        case .energize:    return 48
        }
    }

    /// Convenience: random seed using the system generator.
    public static func random(for mode: FocusMode) -> CompositionSeed {
        var gen = SystemRandomNumberGenerator()
        return random(for: mode, using: &gen)
    }

    // MARK: - Pools

    /// Root-note pools per mode. Low/warm keys for rest modes, brighter
    /// keys for energize. All carry over well to the aligned binaural
    /// carrier so the beat frequency stays inside each mode's band.
    public static func rootPool(for mode: FocusMode) -> [NoteClass] {
        switch mode {
        case .sleep:       return [.F, .C, .G, .Bb, .Eb]
        case .relaxation:  return [.G, .D, .A, .F, .C]
        case .focus:       return [.C, .G, .F, .D, .A]
        case .energize:    return [.D, .G, .A, .E, .C]
        }
    }

    /// Scale pools per mode. Each mode's pool leans toward the emotional
    /// character of the genre — sleep gets modal colour (lydian / aeolian
    /// style pentatonic); energize gets bright mixolydian/major.
    public static func scalePool(for mode: FocusMode) -> [Scale] {
        switch mode {
        // Sleep: minimal dissonance, pad-friendly modes.
        case .sleep:       return [.pentatonicMinor, .lydian, .minor]
        // Relaxation: floating modal palette.
        case .relaxation:  return [.lydian, .dorian, .major, .pentatonicMajor, .mixolydian]
        // Focus: trancey + rhythmic. Minor-leaning modal palette
        // (dorian, natural minor, pentatonicMinor) — hypnotic, dark,
        // motion-oriented.
        case .focus:       return [.dorian, .minor, .pentatonicMinor, .dorian, .minor]
        // Energize: hip-hop / boom-bap territory — overwhelmingly
        // minor (minor 7 / min9 flavors) with a bit of dorian colour.
        case .energize:    return [.minor, .dorian, .minor, .dorian, .pentatonicMinor]
        }
    }

    /// How many variant progressions the planner should choose from
    /// per mode. CompositionPlanner's progression lookup hashes
    /// `(mode, minorScale, variant)` into a pool.
    public static func progressionVariantCount(for mode: FocusMode) -> Int {
        switch mode {
        case .sleep:       return 3
        case .relaxation:  return 3
        case .focus:       return 3
        case .energize:    return 3
        }
    }

    /// GM program pools per (mode, role). Every option in a pool should
    /// be a plausible lead voice for that role within the mode's genre.
    /// Returning `nil` means that role isn't played for this mode.
    public static func programPool(mode: FocusMode, role: TrackRole) -> [UInt8]? {
        switch (mode, role) {

        // MARK: Sleep — ambient drone palette (widened).
        // GM pad family: 88 New Age, 89 Warm, 90 Polysynth,
        // 91 Choir, 92 Bowed, 93 Metallic, 94 Halo, 95 Sweep,
        // 98 Crystal, 99 Atmosphere, 100 Brightness.
        // Plus 52 Choir Aahs, 53 Voice Oohs, 46 Harp, 48 Strings,
        // 49 Slow Strings, 50 Synth Strings, 14 Tubular Bells.
        case (.sleep, .melody):  return [88, 89, 90, 91, 92, 94, 95, 98, 99, 52, 53, 46, 14]
        case (.sleep, .bass):    return [89, 88, 92, 42]               // warm pad, new age, bowed, cello
        case (.sleep, .chords):  return [48, 49, 50, 52, 53, 89, 91, 92, 94]
        case (.sleep, .pad):     return [88, 89, 90, 91, 94, 95, 99]
        case (.sleep, .texture): return [97, 94, 91, 98, 99, 100]      // shimmer / rain / crystal / atmosphere
        case (.sleep, .drums):   return nil

        // MARK: Relaxation — new-age / neo-classical palette (widened).
        // Keeps the warm acoustic voices (piano, rhodes, vibes, harp)
        // and adds more pad colors so two relaxation sessions sound
        // sonically different even when they share a scale.
        case (.relaxation, .melody):  return [0, 4, 11, 46, 5, 89, 88, 90, 92, 14, 98]
        case (.relaxation, .bass):    return [32, 42, 33, 89]           // acoustic, cello, finger, warm pad
        case (.relaxation, .chords):  return [48, 49, 50, 89, 0, 88, 91, 92, 94, 98]
        case (.relaxation, .pad):     return [88, 89, 90, 91, 92, 94, 95]
        case (.relaxation, .texture): return [97, 94, 98, 99, 100]
        case (.relaxation, .drums):   return nil

        // MARK: Focus — trip-hop / lo-fi hip-hop palette.
        // Electric piano + acoustic piano + vibes for the dusty
        // melodic voice; upright / electric bass for the walking
        // low end; warm pad + rhodes for sparse chord comping.
        case (.focus, .melody):  return [4, 0, 11, 5, 1]                // rhodes, acoustic piano, vibes, DX, bright piano
        case (.focus, .bass):    return [32, 33, 35]                    // acoustic bass, electric bass, fretless
        case (.focus, .chords):  return [4, 5, 89, 0]                   // rhodes, DX, warm pad, piano
        case (.focus, .drums):   return [0]                             // percussion bank (sparseKit)
        case (.focus, .pad):     return [89, 88, 90, 94]
        case (.focus, .texture): return [89, 88, 94, 95, 98]

        // MARK: Energize — hip-hop palette (was synthwave, reframed).
        // Rhodes and electric piano for the melodic hook, sub bass /
        // synth bass for the low end, brushed drums / 808 kit handled
        // by the drum bank. Minor 7ths and boom-bap over head-nod
        // tempos (85-102 BPM), not dance floor.
        case (.energize, .melody):  return [4, 5, 0, 11, 87, 80]        // rhodes, DX, piano, vibes, bass+lead, square
        case (.energize, .bass):    return [38, 39, 33, 35]             // synth bass 1/2, finger, fretless
        case (.energize, .chords):  return [4, 5, 89, 48]               // rhodes, DX, warm pad, strings
        case (.energize, .drums):   return [0]
        case (.energize, .pad):     return [89, 88]
        case (.energize, .texture): return [94, 97]
        }
    }

    // MARK: - Helpers

    private static func pick<T, G: RandomNumberGenerator>(
        _ array: [T],
        using generator: inout G
    ) -> T {
        precondition(!array.isEmpty, "CompositionSeed pool must not be empty")
        let index = Int.random(in: 0..<array.count, using: &generator)
        return array[index]
    }
}
