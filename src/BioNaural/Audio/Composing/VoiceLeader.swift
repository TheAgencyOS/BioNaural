// VoiceLeader.swift
// BioNaural — v3 Composing Core
//
// Parsimonious voice leading for the chord track. Given the previous
// chord's MIDI voicing and the target chord's pitch classes, assign
// each target pitch class to a MIDI note (in an allowed octave range)
// that minimizes total voice motion from the previous chord.
//
// This is the classical "optimal bijection" problem in voice leading:
// find a permutation σ such that sum over i of |previous[i] -
// newMidi[σ(i)]| is minimized, where newMidi[j] is whichever octave
// of the j-th target pitch class is closest to previous[σ^-1(j)].
//
// Our chords are small — 3-5 voices typically — so a brute-force
// permutation search over n! ≤ 120 is trivially fast and gives the
// exact optimum without needing a Hungarian-algorithm implementation.
// For chords larger than 8 voices (which we never ship) we fall
// back to a greedy heuristic.
//
// Common-tone preservation is automatic: if a pitch class appears in
// both chords, the pair (previous_voice_on_X, new_voice_on_X) has
// cost 0 in the assignment matrix, so it beats every other pairing
// and the shared voice stays put.
//
// Neo-Riemannian P/L/R transformations are the textbook triad
// version of this idea; what we have here generalizes to 7ths,
// 9ths, and sus voicings that N-R theory doesn't formally cover.

import Foundation

public enum VoiceLeader {

    // MARK: - Public API

    /// Compute a parsimonious voicing of `chordPitchClasses` relative
    /// to `previous`. Finds the optimal voice-to-pitch-class
    /// assignment that minimizes total voice motion.
    ///
    /// - Parameters:
    ///   - chordPitchClasses: 0-11 semitones from C for every tone
    ///     in the target chord (e.g. A♭maj7 = [8, 0, 3, 7]).
    ///   - octaveRange: allowed octaves for the resulting MIDI notes.
    ///     MIDI value = `(octave + 1) * 12 + pitchClass`.
    ///   - previous: MIDI notes of the previous chord's voicing, or
    ///     empty for the first chord in a progression.
    /// - Returns: Sorted MIDI notes for the target chord — one per
    ///   input pitch class.
    public static func voicing(
        chordPitchClasses: [Int],
        octaveRange: ClosedRange<Int>,
        previous: [UInt8]
    ) -> [UInt8] {
        guard !chordPitchClasses.isEmpty else { return [] }

        // First chord — no previous to lead from. Emit a stacked
        // voicing centered in the middle octave so subsequent
        // chords have something musical to lead FROM.
        guard !previous.isEmpty else {
            return defaultStack(
                pitchClasses: chordPitchClasses,
                octaveRange: octaveRange
            )
        }

        // Per-target candidate MIDI notes — one entry per octave
        // in the allowed range.
        let candidates: [[Int]] = chordPitchClasses.map { pc in
            let np = normalize(pc)
            var list: [Int] = []
            for octave in octaveRange {
                let midi = (octave + 1) * 12 + np
                if (0...127).contains(midi) {
                    list.append(midi)
                }
            }
            return list
        }

        let n = chordPitchClasses.count
        let p = previous.count
        let size = max(n, p)

        // Cost matrix: cost[i][j] = minimum |previous[i] - candidate|
        // over all octaves of the j-th target pitch class. Entries
        // for padding rows/columns (when n != p) have prohibitive
        // cost so they're picked last.
        var cost = Array(repeating: Array(repeating: 1_000_000, count: size), count: size)
        var bestMidiForPair = Array(repeating: Array(repeating: 0, count: size), count: size)

        for i in 0..<p {
            for j in 0..<n {
                let prev = Int(previous[i])
                guard let nearest = candidates[j].min(by: {
                    abs($0 - prev) < abs($1 - prev)
                }) else { continue }
                cost[i][j] = abs(nearest - prev)
                bestMidiForPair[i][j] = nearest
            }
        }

        // Solve the assignment exactly for small n, fall back to
        // greedy for the rare larger case.
        let assignment: [Int]
        if size <= 8 {
            assignment = bruteForceOptimalAssignment(cost: cost)
        } else {
            assignment = greedyAssignment(cost: cost)
        }

        // Materialize the new voicing from the optimal assignment.
        // Track which target indices got a previous voice; any
        // uncovered targets (when n > p) get placed near the
        // voicing center after the main assignment.
        var voicingNotes: [Int] = []
        var coveredTargets = Set<Int>()
        for i in 0..<min(p, size) {
            let j = assignment[i]
            if j < n {
                voicingNotes.append(bestMidiForPair[i][j])
                coveredTargets.insert(j)
            }
        }

        if coveredTargets.count < n {
            let center = voicingNotes.isEmpty
                ? defaultCenterMidi(octaveRange: octaveRange)
                : voicingNotes.reduce(0, +) / voicingNotes.count
            for j in 0..<n where !coveredTargets.contains(j) {
                if let nearest = candidates[j].min(by: {
                    abs($0 - center) < abs($1 - center)
                }) {
                    voicingNotes.append(nearest)
                }
            }
        }

        return voicingNotes
            .sorted()
            .map { UInt8(max(0, min(127, $0))) }
    }

    // MARK: - Assignment solvers

    /// Brute-force minimum-cost assignment over all n! permutations.
    /// Exact optimum. Only viable for small n; our chords are ≤ 5
    /// voices in practice, so 5! = 120 permutations is trivially fast.
    private static func bruteForceOptimalAssignment(cost: [[Int]]) -> [Int] {
        let n = cost.count
        guard n > 0 else { return [] }

        var best = Array(0..<n)
        var bestCost = Int.max
        var current = Array(0..<n)

        func recurse(_ start: Int, partialCost: Int) {
            if partialCost >= bestCost { return }   // prune
            if start == n {
                if partialCost < bestCost {
                    bestCost = partialCost
                    best = current
                }
                return
            }
            for i in start..<n {
                current.swapAt(start, i)
                let stepCost = cost[start][current[start]]
                recurse(start + 1, partialCost: partialCost + stepCost)
                current.swapAt(start, i)
            }
        }

        recurse(0, partialCost: 0)
        return best
    }

    /// Greedy fallback for chords larger than 8 voices. Picks the
    /// cheapest row-column pair repeatedly. Non-optimal but fast and
    /// only used if someone passes an unusually large chord (we
    /// never do).
    private static func greedyAssignment(cost: [[Int]]) -> [Int] {
        let n = cost.count
        var result = Array(repeating: 0, count: n)
        var usedCols = Set<Int>()
        for i in 0..<n {
            var bestJ = 0
            var bestC = Int.max
            for j in 0..<n where !usedCols.contains(j) {
                if cost[i][j] < bestC {
                    bestC = cost[i][j]
                    bestJ = j
                }
            }
            result[i] = bestJ
            usedCols.insert(bestJ)
        }
        return result
    }

    // MARK: - Fallbacks

    /// First-chord voicing: stack pitch classes from the bottom of
    /// the octave range upward, assigning each successive pitch
    /// class to whichever register puts it above the previous one
    /// in the stack. Keeps the initial voicing compact and musical.
    private static func defaultStack(
        pitchClasses: [Int],
        octaveRange: ClosedRange<Int>
    ) -> [UInt8] {
        var result: [Int] = []
        var lastMidi = (octaveRange.lowerBound + 1) * 12 - 1
        for pc in pitchClasses {
            let np = normalize(pc)
            var bestMidi = (octaveRange.lowerBound + 1) * 12 + np
            for octave in octaveRange {
                let candidate = (octave + 1) * 12 + np
                if candidate > lastMidi {
                    bestMidi = candidate
                    break
                }
            }
            result.append(bestMidi)
            lastMidi = bestMidi
        }
        return result
            .sorted()
            .map { UInt8(max(0, min(127, $0))) }
    }

    private static func defaultCenterMidi(octaveRange: ClosedRange<Int>) -> Int {
        let middleOctave = (octaveRange.lowerBound + octaveRange.upperBound) / 2
        return (middleOctave + 1) * 12
    }

    // MARK: - Helpers

    private static func normalize(_ pc: Int) -> Int {
        return ((pc % 12) + 12) % 12
    }
}
