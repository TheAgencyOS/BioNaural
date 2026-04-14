// VoiceLeader.swift
// BioNaural — v3 Composing Core
//
// Parsimonious voice leading for the chord track. The existing
// WeirdnessResolver resolves each chord tone independently with no
// awareness of the previous chord's voicing, which produces
// awkward parallel motion — when a Cm9 voicing (C E♭ G B♭ D)
// jumps to A♭maj7 (A♭ C E♭ G), all four voices move downward
// together instead of one or two voices moving by a semitone.
//
// This helper computes the nearest voicing of a target chord given
// the previous chord's MIDI pitches. For each pitch class in the
// target chord, it picks the octave in the allowed range whose MIDI
// note is closest to any previous voice. Greedy, not globally
// optimal, but fast and audibly smoother than independent resolution
// for every 4-to-5-note voicing we ship.
//
// Neo-Riemannian P/L/R operations are the textbook triad version of
// this idea; what we have here generalizes to 7ths, 9ths, and
// sus voicings that NR theory doesn't formally cover.

import Foundation

public enum VoiceLeader {

    /// Compute a parsimonious voicing of `chordPitchClasses` relative
    /// to `previous`. Each pitch class is placed in whichever octave
    /// within `octaveRange` puts it closest to some previous voice.
    /// When `previous` is empty, falls back to a centered stack in
    /// the middle octave of the range.
    ///
    /// - Parameters:
    ///   - chordPitchClasses: 0-11 semitones from C for every tone
    ///     in the target chord (e.g. A♭maj7 = [8, 0, 3, 7]).
    ///   - octaveRange: allowed octaves for the resulting MIDI notes.
    ///     Each MIDI value is `(octave + 1) * 12 + pitchClass`.
    ///   - previous: MIDI notes of the previous chord's voicing, or
    ///     empty for the first chord in a progression.
    /// - Returns: One MIDI note per entry in `chordPitchClasses`,
    ///   sorted ascending so callers can index by "voice".
    public static func voicing(
        chordPitchClasses: [Int],
        octaveRange: ClosedRange<Int>,
        previous: [UInt8]
    ) -> [UInt8] {
        guard !chordPitchClasses.isEmpty else { return [] }

        // First chord of the progression — no previous to follow.
        // Emit a stacked voicing centered in the middle octave so
        // subsequent chords have something musical to lead from.
        guard !previous.isEmpty else {
            let midOctave = (octaveRange.lowerBound + octaveRange.upperBound) / 2
            let base = (midOctave + 1) * 12
            let voicing = chordPitchClasses
                .enumerated()
                .map { offset, pc -> UInt8 in
                    let midi = base + normalize(pc) + (offset > 0 && offset % 2 == 0 ? 12 : 0)
                    return UInt8(max(0, min(127, midi)))
                }
                .sorted()
            return voicing
        }

        // For each pitch class in the new chord, search every octave
        // in range and pick the candidate MIDI note whose minimum
        // distance to any previous voice is smallest. Break ties by
        // preferring candidates closer to the middle of the previous
        // voicing so the whole chord stays in the same register.
        let prevCenter = Double(previous.map { Int($0) }.reduce(0, +)) / Double(previous.count)
        var chosen: [UInt8] = []
        chosen.reserveCapacity(chordPitchClasses.count)

        for pc in chordPitchClasses {
            let normalizedPc = normalize(pc)
            var bestMidi = (octaveRange.lowerBound + 1) * 12 + normalizedPc
            var bestDistance = Int.max
            var bestCenterPenalty = Double.infinity

            for octave in octaveRange {
                let candidate = (octave + 1) * 12 + normalizedPc
                guard (0...127).contains(candidate) else { continue }
                let distance = previous
                    .map { abs(Int($0) - candidate) }
                    .min() ?? candidate
                let centerPenalty = abs(Double(candidate) - prevCenter)
                if distance < bestDistance
                    || (distance == bestDistance && centerPenalty < bestCenterPenalty) {
                    bestDistance = distance
                    bestMidi = candidate
                    bestCenterPenalty = centerPenalty
                }
            }

            chosen.append(UInt8(max(0, min(127, bestMidi))))
        }

        return chosen.sorted()
    }

    /// Normalize a semitone value into 0-11.
    private static func normalize(_ pc: Int) -> Int {
        return ((pc % 12) + 12) % 12
    }
}
