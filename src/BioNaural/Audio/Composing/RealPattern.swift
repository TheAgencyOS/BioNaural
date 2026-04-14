// RealPattern.swift
// BioNaural — v3 Composing Core
//
// A Real Pattern (RP) is a flat list of NOTE events with fixed weirdness.
// It is built from a VP by expanding chord/polynote/arpeggio events into
// individual notes and applying VP→RP humanization (timing/velocity jitter).
//
// Like the VP, an RP is still harmonic-context-free. The actual MIDI
// pitch is resolved later in RP→MP using the Harmonic Context.
//
// NWL spec 3.6.3.

import Foundation

// MARK: - RPNote

/// A single note in a Real Pattern. Has fixed weirdness — no more
/// chord/polynote/arpeggio expansion needed.
public struct RPNote: Hashable, Sendable {

    /// The tonal tension of this note.
    public let weirdness: Weirdness

    /// Tick offset from the start of the RP (post-humanization).
    public let positionTicks: Int

    /// Note length in ticks (post-humanization).
    public let lengthTicks: Int

    /// MIDI velocity 0-127 (post-humanization).
    public let velocity: UInt8

    /// How this note's pitch should be resolved at MP build time.
    public let type: NoteType

    public init(
        weirdness: Weirdness,
        positionTicks: Int,
        lengthTicks: Int,
        velocity: UInt8,
        type: NoteType
    ) {
        self.weirdness = weirdness
        self.positionTicks = positionTicks
        self.lengthTicks = lengthTicks
        self.velocity = velocity
        self.type = type
    }
}

// MARK: - RealPattern

/// A complete Real Pattern: flat list of notes for one Block.
public struct RealPattern: Hashable, Sendable {

    /// Length of this RP in MIDI ticks (matches the source VP).
    public let lengthTicks: Int

    /// The notes in playback order, sorted by positionTicks.
    public let notes: [RPNote]

    /// The track role this RP was built for.
    public let role: TrackRole

    public init(lengthTicks: Int, notes: [RPNote], role: TrackRole) {
        self.lengthTicks = lengthTicks
        self.notes = notes.sorted { $0.positionTicks < $1.positionTicks }
        self.role = role
    }
}
