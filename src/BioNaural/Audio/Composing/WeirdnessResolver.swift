// WeirdnessResolver.swift
// BioNaural — v3 Composing Core
//
// The single most important file in the v3 pipeline: this is where
// abstract Weirdness values become concrete MIDI pitches.
//
// The resolver takes a Weirdness value (0.0-1.0) plus a Harmonic Context
// entry (current Tone, Mode, Tonic, Family) and returns a MIDI note
// number. Different NoteTypes use different resolution strategies:
//
//   .comp     → chord-tone driven (Tonic + Family). Used for bass and chords.
//   .solo     → scale-tone driven (Tone + Mode). Used for ostinato leads.
//   .mixed    → both — chord tones at low weirdness, scale tones at high.
//   .rhythmic → drums. Velocity selects which GM drum element fires.
//
// Within each type, low weirdness picks the SAFEST option (root for
// chords, tonic for scales) and high weirdness picks more adventurous
// options (extensions, passing tones, chromatic tension).
//
// This is the abstraction from NWL spec 3.6.1 that makes the same VP
// reusable across any key/chord — pitches are decided LATE, not in
// the pattern itself.

import Foundation
import BioNauralShared
@preconcurrency import Tonic

// MARK: - WeirdnessResolver

public enum WeirdnessResolver {

    // MARK: - Public API

    /// Resolve a single note to a MIDI pitch using the appropriate
    /// strategy for its NoteType.
    public static func resolve(
        weirdness: Weirdness,
        type: NoteType,
        velocity: UInt8,
        hc: HarmonicContextEntry,
        octave: Int
    ) -> UInt8 {
        switch type {
        case .comp:     return resolveComp(weirdness: weirdness, hc: hc, octave: octave)
        case .solo:     return resolveSolo(weirdness: weirdness, hc: hc, octave: octave)
        case .mixed:    return resolveMixed(weirdness: weirdness, hc: hc, octave: octave)
        case .rhythmic: return resolveRhythmic(velocity: velocity)
        }
    }

    // MARK: - COMP — chord-tone driven (Tonic + Family)

    /// Pick a chord tone from the current chord. Low weirdness picks the
    /// safest tone (root, then 5th, then 3rd); high weirdness picks
    /// extensions (7th, 9th, 13th).
    public static func resolveComp(
        weirdness: Weirdness,
        hc: HarmonicContextEntry,
        octave: Int
    ) -> UInt8 {
        let baseMidi = (octave + 1) * 12 + Int(hc.tonic.intValue)
        let intervals = safetyOrderedIntervals(for: hc.family)
        guard !intervals.isEmpty else { return UInt8(clampMIDI(baseMidi)) }

        let idx = weirdnessIndex(weirdness, count: intervals.count)
        let interval = intervals[idx]
        return UInt8(clampMIDI(baseMidi + interval))
    }

    // MARK: - SOLO — scale-tone driven (Tone + Mode)

    /// Pick a scale tone from the current key. Low weirdness picks the
    /// safest scale degree (tonic, then 5th, then 3rd); high weirdness
    /// picks tense degrees (4th, 7th).
    public static func resolveSolo(
        weirdness: Weirdness,
        hc: HarmonicContextEntry,
        octave: Int
    ) -> UInt8 {
        let key = Key(root: hc.tone, scale: hc.scale)
        // Tonic returns [Note] from noteSet — extract semitone values.
        let scaleSemitones = key.noteSet.array.map { Int($0.noteClass.intValue) }
        guard !scaleSemitones.isEmpty else {
            // Fallback: just return the tonic
            return UInt8(clampMIDI((octave + 1) * 12 + Int(hc.tone.intValue)))
        }

        let safetyOrdered = safetyOrderedSemitones(scaleSemitones, from: Int(hc.tone.intValue))
        let idx = weirdnessIndex(weirdness, count: safetyOrdered.count)
        let chosenSemitone = safetyOrdered[idx]
        let midi = (octave + 1) * 12 + chosenSemitone
        return UInt8(clampMIDI(midi))
    }

    // MARK: - MIXED — chord-aware but scale-flexible

    /// Use chord tones at low weirdness, scale tones at high weirdness.
    /// This is the natural choice for melodic lines that should follow
    /// the chord progression but stay in the key.
    public static func resolveMixed(
        weirdness: Weirdness,
        hc: HarmonicContextEntry,
        octave: Int
    ) -> UInt8 {
        if weirdness.value < 0.5 {
            // Lower half: chord tones, weirdness scaled to 0.0-1.0
            let scaledW = Weirdness(weirdness.value * 2.0)
            return resolveComp(weirdness: scaledW, hc: hc, octave: octave)
        } else {
            // Upper half: scale tones, weirdness scaled to 0.0-1.0
            let scaledW = Weirdness((weirdness.value - 0.5) * 2.0)
            return resolveSolo(weirdness: scaledW, hc: hc, octave: octave)
        }
    }

    // MARK: - RHYTHMIC — drums (velocity → GM drum element)

    /// Map a Marker's intensity-derived velocity to a GM drum note.
    /// The atom designer encodes drum role via intensity:
    ///   0.85+ → kick   (velocity ~108+)
    ///   0.65+ → snare  (velocity ~85+)
    ///   0.45+ → closed hi-hat (velocity ~60+)
    ///   0.30+ → open hi-hat / side stick (velocity ~40+)
    ///   else  → shaker / ghost
    public static func resolveRhythmic(velocity: UInt8) -> UInt8 {
        switch velocity {
        case 108...127: return 36  // Bass Drum 1 (kick)
        case 85...107:  return 38  // Acoustic Snare
        case 60...84:   return 42  // Closed Hi-Hat
        case 45...59:   return 46  // Open Hi-Hat
        case 25...44:   return 37  // Side Stick
        default:        return 70  // Maracas (shaker)
        }
    }

    // MARK: - Helpers

    /// Convert a 0.0-1.0 weirdness to an index into a list of length `count`.
    /// 0.0 → index 0 (safest), 1.0 → last index (most adventurous).
    private static func weirdnessIndex(_ w: Weirdness, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let raw = Int(w.value * Double(count))
        return min(count - 1, max(0, raw))
    }

    /// Order the chord's intervals from safest (root, 5th) to most
    /// adventurous (extensions). Returns semitone offsets from the chord root.
    private static func safetyOrderedIntervals(for family: ChordFamily) -> [Int] {
        switch family {
        case .major:       return [0, 7, 4]
        case .minor:       return [0, 7, 3]
        case .dominant7:   return [0, 7, 4, 10]
        case .major7:      return [0, 7, 4, 11]
        case .minor7:      return [0, 7, 3, 10]
        case .minor7b5:    return [0, 6, 3, 10]
        case .diminished:  return [0, 6, 3]
        case .augmented:   return [0, 8, 4]
        case .sus2:        return [0, 7, 2]
        case .sus4:        return [0, 7, 5]
        case .major9:      return [0, 7, 4, 11, 14]
        case .minor9:      return [0, 7, 3, 10, 14]
        case .dominant9:   return [0, 7, 4, 10, 14]
        case .power:       return [0, 7]
        }
    }

    /// Order scale semitone values from safest (tonic, 5th, 3rd) to most
    /// adventurous. The tonic is the reference point; each input semitone
    /// is reduced to its 0-11 distance from the tonic and ranked.
    private static func safetyOrderedSemitones(
        _ semitones: [Int],
        from toneSemitone: Int
    ) -> [Int] {
        // Compute (note semitone, interval-from-tone) pairs.
        let withInterval: [(semitone: Int, interval: Int)] = semitones.map {
            let raw = (($0 - toneSemitone) % 12 + 12) % 12
            return (semitone: $0, interval: raw)
        }

        // Lower priority = safer (picked first).
        // Standard tonal hierarchy: 1, 5, 3, 4, 6, 2, 7, tritone.
        let priority: [Int: Int] = [
            0: 0,           // root (tonic)
            7: 1,           // perfect 5th
            4: 2, 3: 2,     // major / minor 3rd
            5: 3,           // perfect 4th
            9: 4, 8: 4,     // major / minor 6th
            2: 5, 1: 5,     // major / minor 2nd
            11: 6, 10: 6,   // major / minor 7th
            6: 7            // tritone (#4 / b5)
        ]

        return withInterval.sorted { a, b in
            (priority[a.interval] ?? 99) < (priority[b.interval] ?? 99)
        }.map { $0.semitone }
    }

    /// Clamp a MIDI value to the legal 0-127 range.
    private static func clampMIDI(_ value: Int) -> Int {
        return max(0, min(127, value))
    }
}
