// Atom.swift
// BioNaural — v3 Composing Core
//
// An Atom is the smallest rhythmic chunk in the composition pipeline.
// It contains zero or more Markers — abstract event placeholders that
// will become Virtual Pattern events during Molecule→VP transformation.
//
// Hierarchy (from NWL spec 3.7):
//   Marker → Atom → Molecule → VP → RP → MP
//
// An Atom doesn't know what notes will play. It only describes the
// rhythmic structure: when events happen, how loud, how moveable.

import Foundation

// MARK: - AtomType

/// The musical "intention" of an Atom. Determines which Atom the
/// PatternBuilder picks when filling a Molecule.
public enum AtomType: String, Sendable, Hashable, CaseIterable {
    /// Empty — silence for this slot.
    case empty
    /// ALPHA — simple, on-the-beat, baseline rhythm.
    case alpha
    /// BETA — syncopated, off-beat, more rhythmic interest.
    case beta
    /// GAMMA — busy, dense, fills and accents.
    case gamma
}

// MARK: - Marker

/// A Marker is the elemental rhythmic event inside an Atom. Each Marker
/// becomes one VP Event during Molecule→VP transformation.
public struct Marker: Hashable, Sendable {

    /// Tick offset within the Atom (0 = start of atom).
    /// Resolution: 480 PPQN (ticks per quarter note).
    public let startTick: Int

    /// Tick at which the event ends.
    public let stopTick: Int

    /// Intensity 0.0-1.0 — maps to MIDI velocity at MP build time.
    public let intensity: Double

    /// How freely this marker can be moved during humanization (VP→RP).
    /// 0.0 = locked to grid (kicks, downbeats).
    /// 1.0 = freely moveable (rubato leads).
    public let moveAbility: Double

    public init(
        startTick: Int,
        stopTick: Int,
        intensity: Double = 0.7,
        moveAbility: Double = 0.0
    ) {
        self.startTick = startTick
        self.stopTick = stopTick
        self.intensity = max(0.0, min(1.0, intensity))
        self.moveAbility = max(0.0, min(1.0, moveAbility))
    }

    /// Length in ticks.
    public var lengthTicks: Int {
        stopTick - startTick
    }
}

// MARK: - Atom

/// A small rhythmic chunk containing zero or more Markers.
/// Atoms are pre-defined in the AtomLibrary and assembled into Molecules.
public struct Atom: Hashable, Sendable {

    /// Atom length in quarter notes (typically 1, 2, or 4).
    public let sizeQuarters: Int

    /// Musical intention of this atom.
    public let type: AtomType

    /// Rhythmic events inside this atom.
    public let markers: [Marker]

    /// Optional name for debugging / library lookup.
    public let name: String

    public init(
        sizeQuarters: Int,
        type: AtomType,
        markers: [Marker],
        name: String = ""
    ) {
        self.sizeQuarters = sizeQuarters
        self.type = type
        self.markers = markers
        self.name = name
    }

    /// Total length in ticks (480 ticks per quarter).
    public var lengthTicks: Int {
        sizeQuarters * Composing.ticksPerQuarter
    }
}

// MARK: - Composing Constants

/// Shared constants for the composing core.
public enum Composing {
    /// Pulses Per Quarter note — MIDI tick resolution.
    /// 480 PPQN is standard for AVAudioSequencer and DAWs.
    public static let ticksPerQuarter: Int = 480

    /// Ticks per 4/4 bar.
    public static let ticksPerBar: Int = ticksPerQuarter * 4
}
