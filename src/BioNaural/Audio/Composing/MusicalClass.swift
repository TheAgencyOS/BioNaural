// MusicalClass.swift
// BioNaural — v3 Composing Core
//
// A "Class" (the NWL spec uses this term — we call it MusicalClass to
// avoid colliding with Swift's `class` keyword) is the rule set the
// PatternBuilder uses to construct a Virtual Pattern from Atoms.
//
// A MusicalClass specifies (NWL spec 3.6.2):
//   - Which AtomTypes are allowed
//   - AtomicRepetitiveness preference
//   - Default Weirdness range for events
//   - Note density (how dense vs sparse)
//   - Allowed VP event types (note / chord / arpeggio / polynote)
//   - Default register / tessitura
//
// A MusicalClass is the bridge between the high-level musical intent
// (mode + biometric state + track role) and the low-level pattern
// generation. The ClassLibrary holds presets per (FocusMode, role).

import Foundation

// MARK: - VPEventType

/// The kinds of musical events a MusicalClass can produce.
/// Defined here so MusicalClass can constrain which event types are
/// allowed for a given track. (Concrete VPEvent enum lives in
/// VirtualPattern.swift to avoid circular references.)
public enum VPEventType: String, Sendable, Hashable, CaseIterable {
    /// Single note. Used for melody, bass, and drums.
    case note
    /// Multiple simultaneous notes (a chord).
    case chord
    /// Polyphonic event with mixed harmonic/melodic resolution.
    case polynote
    /// Arpeggiated sequence.
    case arpeggio
}

// MARK: - MelodicContour

/// Pitch-direction intent for a class. Drives a position-based octave
/// bias during pitch resolution so phrases have a sense of motion
/// appropriate to the mode — sleep descends, energize ascends, focus
/// and relaxation stay neutral.
public enum MelodicContour: String, Sendable, Hashable {
    case neutral
    case ascending
    case descending
    case archUpDown       // rise then fall
    case archDownUp       // fall then rise (cradle)
}

// MARK: - TrackRole

/// The role of a track in the ensemble. Drives Class selection and
/// also informs the Local Master/Slave linking later.
public enum TrackRole: String, Sendable, Hashable, CaseIterable {
    case melody
    case bass
    case chords
    case drums
    case pad
    case texture
}

// MARK: - MusicalClass

/// The rule set for building one Virtual Pattern.
public struct MusicalClass: Hashable, Sendable {

    /// Identifier for debugging / library lookup.
    public let name: String

    /// Track role this class is intended for.
    public let role: TrackRole

    /// Which AtomTypes this class allows (drawn from AtomLibrary).
    public let allowedAtomTypes: Set<AtomType>

    /// How atoms repeat within the Molecule.
    public let atomicRepetitiveness: AtomicRepetitiveness

    /// The weirdness range for events in this class.
    public let weirdnessRange: WeirdnessRange

    /// Note density 0.0-1.0 — informs how often events fire vs rest.
    public let density: Double

    /// VP event types this class is allowed to emit.
    public let allowedEventTypes: Set<VPEventType>

    /// Octave range for melodic content (e.g. 3...5 for mid-range).
    /// Drums ignore this.
    public let octaveRange: ClosedRange<Int>

    /// Velocity range for events (0-127).
    public let velocityRange: ClosedRange<UInt8>

    /// Atom sizes the molecule builder is allowed to use, in quarters.
    /// Typically [1, 2] or [2, 4].
    public let allowedAtomSizes: [Int]

    /// Pitch-direction intent for the track across a phrase.
    public let contour: MelodicContour

    public init(
        name: String,
        role: TrackRole,
        allowedAtomTypes: Set<AtomType>,
        atomicRepetitiveness: AtomicRepetitiveness,
        weirdnessRange: WeirdnessRange,
        density: Double,
        allowedEventTypes: Set<VPEventType>,
        octaveRange: ClosedRange<Int>,
        velocityRange: ClosedRange<UInt8>,
        allowedAtomSizes: [Int],
        contour: MelodicContour = .neutral
    ) {
        self.name = name
        self.role = role
        self.allowedAtomTypes = allowedAtomTypes
        self.atomicRepetitiveness = atomicRepetitiveness
        self.weirdnessRange = weirdnessRange
        self.density = max(0.0, min(1.0, density))
        self.allowedEventTypes = allowedEventTypes
        self.octaveRange = octaveRange
        self.velocityRange = velocityRange
        self.allowedAtomSizes = allowedAtomSizes
        self.contour = contour
    }
}
