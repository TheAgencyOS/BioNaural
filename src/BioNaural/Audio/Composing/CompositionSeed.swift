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

// MARK: - CompositionSeed

public struct CompositionSeed: Sendable, Hashable {

    /// The mode this seed was generated for. Seeds are not reusable
    /// across modes — a new seed is generated on mode switch.
    public let mode: FocusMode

    /// The randomized root note for the session.
    public let root: NoteClass

    /// The randomized scale for the session.
    public let scale: Scale

    /// The randomized GM program numbers per track role. Tracks not
    /// present in the role set for this mode are simply absent.
    public let gmPrograms: [TrackRole: UInt8]

    /// Index into the mode's chord progression pool.
    public let progressionVariant: Int

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

        return CompositionSeed(
            mode: mode,
            root: root,
            scale: scale,
            gmPrograms: programs,
            progressionVariant: variant
        )
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
        case .sleep:       return [.pentatonicMinor, .lydian, .minor]
        case .relaxation:  return [.lydian, .dorian, .major, .pentatonicMajor, .mixolydian]
        case .focus:       return [.pentatonicMajor, .dorian, .minor, .mixolydian]
        case .energize:    return [.major, .mixolydian, .lydian, .pentatonicMajor]
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

        // MARK: Sleep — ambient drone palette
        case (.sleep, .melody):  return [88, 89, 91, 94, 52, 46]      // pads, choir, harp
        case (.sleep, .bass):    return [89, 88, 42]                   // warm pad + cello
        case (.sleep, .chords):  return [48, 49, 52, 89, 94]           // strings, choir pads
        case (.sleep, .pad):     return [88, 89, 91, 94]
        case (.sleep, .texture): return [97, 94, 91]
        case (.sleep, .drums):   return nil

        // MARK: Relaxation — new-age / neo-classical palette
        case (.relaxation, .melody):  return [0, 4, 11, 46, 40, 73]     // piano, rhodes, vibes, harp, violin, flute
        case (.relaxation, .bass):    return [32, 42, 33]               // acoustic, cello, finger bass
        case (.relaxation, .chords):  return [48, 49, 89, 0, 88]
        case (.relaxation, .pad):     return [89, 91, 88]
        case (.relaxation, .texture): return [97, 94]
        case (.relaxation, .drums):   return nil

        // MARK: Focus — lo-fi / study palette
        case (.focus, .melody):  return [4, 5, 0, 11, 1]                // rhodes, dx, piano, vibes, bright piano
        case (.focus, .bass):    return [32, 33, 35]                    // acoustic, finger, fretless
        case (.focus, .chords):  return [4, 5, 0, 89]
        case (.focus, .drums):   return [0]                             // GM drum kit — program ignored, percussion bank
        case (.focus, .pad):     return [89, 88]
        case (.focus, .texture): return [97, 94]

        // MARK: Energize — synthwave / uplifting electronic palette
        case (.energize, .melody):  return [80, 81, 82, 85, 87, 30]     // leads + overdriven
        case (.energize, .bass):    return [38, 39, 34, 35]             // synth bass, pick bass, fretless
        case (.energize, .chords):  return [88, 50, 48, 63]             // new age pad, synth strings, strings, brass
        case (.energize, .drums):   return [0]
        case (.energize, .pad):     return [88, 89, 94]
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
