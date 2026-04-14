// Weirdness.swift
// BioNaural — v3 Composing Core
//
// Weirdness is a 0.0-1.0 scalar that represents how "in/out of tonality"
// a note should sound. It's the single dial that quantifies tension.
//
//   0.0 = chord root (safest, in-the-pocket)
//   0.5 = scale tone (musical but adventurous)
//   1.0 = chromatic / non-scale (maximum tension)
//
// The Weirdness value is set on every event in a Virtual Pattern. It stays
// abstract through the VP→RP transformation and is only resolved to an
// actual MIDI pitch in the RP→MP step, where the Harmonic Context (current
// chord, current scale) is applied via a lookup table.
//
// This is the key abstraction from the NWL Composing Core spec (3.6.1):
// the same VP can be reused across any chord, any key, any mode, and the
// algorithm always picks musically coherent pitches.

import Foundation

// MARK: - Weirdness

/// A 0.0-1.0 value representing a note's tonal tension.
/// 0.0 = chord root, 1.0 = chromatic non-scale tension.
public struct Weirdness: Hashable, Sendable, Comparable {

    public let value: Double

    public init(_ value: Double) {
        self.value = max(0.0, min(1.0, value))
    }

    public static func < (lhs: Weirdness, rhs: Weirdness) -> Bool {
        lhs.value < rhs.value
    }

    // MARK: - Common Values

    /// Maximum stability — always picks the chord root.
    public static let zero = Weirdness(0.0)

    /// Safe — chord tones (root, 3rd, 5th, 7th).
    public static let safe = Weirdness(0.2)

    /// Musical — scale tones with mild tension.
    public static let mild = Weirdness(0.4)

    /// Adventurous — extensions (9th, 11th, 13th) and passing tones.
    public static let adventurous = Weirdness(0.6)

    /// Tension — non-chord scale tones, blue notes.
    public static let tension = Weirdness(0.8)

    /// Maximum — chromatic, out-of-scale.
    public static let maximum = Weirdness(1.0)
}

// MARK: - WeirdnessRange

/// A range of weirdness values for events that pick within a band.
public struct WeirdnessRange: Hashable, Sendable {

    public let lower: Weirdness
    public let upper: Weirdness

    public init(_ lower: Weirdness, _ upper: Weirdness) {
        self.lower = lower
        self.upper = upper
    }

    /// Convenience: range from a single value (lower == upper).
    public init(_ value: Weirdness) {
        self.lower = value
        self.upper = value
    }

    /// The midpoint of the range.
    public var center: Weirdness {
        Weirdness((lower.value + upper.value) / 2.0)
    }
}
