// HarmonicContext.swift
// BioNaural — v3 Composing Core
//
// The Harmonic Context is a time-stamped list of (Tone, Mode, Tonic, Family)
// entries that describe the key/scale/chord at every moment of the piece.
// It is the data that resolves Weirdness → actual MIDI pitch in the
// RP → MP transformation.
//
// NWL spec 3.8.

import Foundation
import BioNauralShared
@preconcurrency import Tonic

// MARK: - ChordFamily

/// A chord quality — the set of intervals from the chord's tonic.
/// We define our own minimal enum here to avoid pulling in another
/// chord library; the resolver only needs to know the chord tones.
public enum ChordFamily: String, Sendable, Hashable, CaseIterable {
    case major          // 1 3 5
    case minor          // 1 b3 5
    case dominant7      // 1 3 5 b7
    case major7         // 1 3 5 7
    case minor7         // 1 b3 5 b7
    case minor7b5       // 1 b3 b5 b7
    case diminished     // 1 b3 b5
    case augmented      // 1 3 #5
    case sus2           // 1 2 5
    case sus4           // 1 4 5
    case major9         // 1 3 5 7 9
    case minor9         // 1 b3 5 b7 9
    case dominant9      // 1 3 5 b7 9
    case power          // 1 5 (no third)

    /// Returns the chord-tone intervals in semitones from the tonic.
    public var intervals: [Int] {
        switch self {
        case .major:       return [0, 4, 7]
        case .minor:       return [0, 3, 7]
        case .dominant7:   return [0, 4, 7, 10]
        case .major7:      return [0, 4, 7, 11]
        case .minor7:      return [0, 3, 7, 10]
        case .minor7b5:    return [0, 3, 6, 10]
        case .diminished:  return [0, 3, 6]
        case .augmented:   return [0, 4, 8]
        case .sus2:        return [0, 2, 7]
        case .sus4:        return [0, 5, 7]
        case .major9:      return [0, 4, 7, 11, 14]
        case .minor9:      return [0, 3, 7, 10, 14]
        case .dominant9:   return [0, 4, 7, 10, 14]
        case .power:       return [0, 7]
        }
    }
}

// MARK: - HarmonicContextEntry

/// A single time-stamped harmonic context entry. Each entry covers a
/// span of the piece (until the next entry takes over).
public struct HarmonicContextEntry: Hashable, Sendable {

    /// Tick at which this entry becomes active.
    public let startTick: Int

    /// Tick at which this entry ends (exclusive).
    public let endTick: Int

    /// The mode root note (e.g. C for "C Major").
    /// Provides the tonality / scale center.
    public let tone: NoteClass

    /// The mode/scale (e.g. Lydian, Dorian, Major).
    /// Defines which intervals from the tone are in scale.
    public let scale: Scale

    /// The current chord's root note.
    public let tonic: NoteClass

    /// The current chord quality.
    public let family: ChordFamily

    public init(
        startTick: Int,
        endTick: Int,
        tone: NoteClass,
        scale: Scale,
        tonic: NoteClass,
        family: ChordFamily
    ) {
        self.startTick = startTick
        self.endTick = endTick
        self.tone = tone
        self.scale = scale
        self.tonic = tonic
        self.family = family
    }

    /// True if this entry is active at the given tick.
    public func contains(tick: Int) -> Bool {
        tick >= startTick && tick < endTick
    }
}

// MARK: - HarmonicContext

/// A complete time-stamped sequence of harmonic context entries
/// covering one Block (or the entire loop).
public struct HarmonicContext: Hashable, Sendable {

    /// The entries in time order. Adjacent entries should not overlap.
    public let entries: [HarmonicContextEntry]

    public init(entries: [HarmonicContextEntry]) {
        self.entries = entries.sorted { $0.startTick < $1.startTick }
    }

    /// Returns the entry that covers the given tick, or the last entry
    /// if the tick is past the end (defensive fallback).
    public func entry(at tick: Int) -> HarmonicContextEntry? {
        for e in entries where e.contains(tick: tick) { return e }
        return entries.last
    }
}
