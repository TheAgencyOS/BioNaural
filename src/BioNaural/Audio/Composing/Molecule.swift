// Molecule.swift
// BioNaural — v3 Composing Core
//
// A Molecule is an ordered list of Atoms that fills exactly one Block.
// The PatternBuilder assembles Molecules from the AtomLibrary based on
// the Class rules for the current track.
//
// Molecule → VP transformation happens in PatternBuilder.

import Foundation

// MARK: - AtomicRepetitiveness

/// Controls how Atoms are sequenced within a Molecule (NWL spec 3.4.6).
public enum AtomicRepetitiveness: String, Sendable, Hashable, CaseIterable {
    /// No specific repetitiveness — atoms are picked freely.
    case none
    /// Same Atom is used throughout the entire Molecule (loop).
    case same
    /// Force different Atoms — no two adjacent atoms repeat.
    case diff
}

// MARK: - Molecule

/// A list of Atoms whose total length matches the parent Block.
public struct Molecule: Hashable, Sendable {

    /// The atoms in playback order.
    public let atoms: [Atom]

    /// The repetitiveness rule used to build this molecule.
    public let repetitiveness: AtomicRepetitiveness

    public init(atoms: [Atom], repetitiveness: AtomicRepetitiveness = .none) {
        self.atoms = atoms
        self.repetitiveness = repetitiveness
    }

    /// Total length in quarter notes.
    public var sizeQuarters: Int {
        atoms.reduce(0) { $0 + $1.sizeQuarters }
    }

    /// Total length in MIDI ticks.
    public var lengthTicks: Int {
        atoms.reduce(0) { $0 + $1.lengthTicks }
    }
}
