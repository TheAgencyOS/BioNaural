// VirtualPattern.swift
// BioNaural — v3 Composing Core
//
// A Virtual Pattern (VP) is a sequence of musical events that describes
// what should happen WITHOUT specifying actual pitches. Pitches come
// later from the Harmonic Context via the Weirdness resolver.
//
// This is the central abstraction from NWL spec 3.6.1: "VPs are
// completely independent of harmonic context."
//
// One VP can be reused across any chord, any key, any mode — the
// resolver always picks coherent pitches at MP build time.

import Foundation

// MARK: - NoteType

/// How a note's pitch should be resolved when the Harmonic Context
/// is applied (RP → MP step). This determines whether the note
/// listens to the scale (Tone+Mode) or the chord (Tonic+Family).
public enum NoteType: String, Sendable, Hashable, CaseIterable {
    /// COMP — accompaniment. Resolved against Tonic + Family.
    /// Used for bass and chord-following parts.
    case comp
    /// SOLO — melodic line. Resolved against Tone + Mode (scale).
    /// Used for ostinatos and tonality-driven leads.
    case solo
    /// MIXED — both. Influenced by chord tones but stays in scale.
    /// Used for melodies that should follow chord changes.
    case mixed
    /// RHYTHMIC — drum hit. Weirdness selects which drum element.
    case rhythmic
}

// MARK: - VPEvent

/// A single musical event in a Virtual Pattern. All events have an
/// abstract Weirdness instead of a concrete pitch.
public enum VPEvent: Hashable, Sendable {

    /// A single note.
    case note(
        weirdness: Weirdness,
        position: Int,        // tick offset from start of VP
        length: Int,          // ticks
        velocity: UInt8,
        type: NoteType
    )

    /// Multiple simultaneous notes (a chord).
    case chord(
        numNotes: Int,
        weirdnessRange: WeirdnessRange,
        simultaneousnessTicks: Int,  // small offset between notes for humanization
        position: Int,
        length: Int,
        velocity: UInt8
    )

    /// A polyphonic event resolved with mixed harmonic+melodic context.
    case polynote(
        numNotes: Int,
        baseWeirdness: Weirdness,
        weirdnessDelta: Double,   // variation around baseWeirdness
        position: Int,
        length: Int,
        velocity: UInt8
    )

    /// A sequence of (non-simultaneous) notes.
    case arpeggio(
        numNotes: Int,
        weirdnessSequence: [Weirdness],
        position: Int,
        length: Int,                // total length of arpeggio
        noteLengthTicks: Int,
        velocity: UInt8
    )
}

// MARK: - VirtualPattern

/// A complete Virtual Pattern: sequence of events for one Block.
public struct VirtualPattern: Hashable, Sendable {

    /// Length of this VP in MIDI ticks.
    public let lengthTicks: Int

    /// The events in playback order.
    public let events: [VPEvent]

    /// The track role this VP was built for (informs the resolver).
    public let role: TrackRole

    public init(lengthTicks: Int, events: [VPEvent], role: TrackRole) {
        self.lengthTicks = lengthTicks
        self.events = events
        self.role = role
    }
}
