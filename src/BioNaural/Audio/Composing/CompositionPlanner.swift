// CompositionPlanner.swift
// BioNaural — v3 Composing Core
//
// Top-down session planner. Takes a FocusMode + BiometricState + the
// shared SessionTonality and produces the inputs PatternBuilder needs:
//
//   - A HarmonicContext (4-bar chord progression)
//   - One (RealPattern, MusicalClass, gmProgram) per active track role
//   - Loop length in ticks + tempo
//
// Handing these to PatternBuilder.buildMP yields a complete MusicPattern
// ready for MIDIFileBuilder → MusicPatternPlayer.
//
// Pure: no side effects, safe to call on any thread.

import BioNauralShared
import Foundation
@preconcurrency import Tonic

// MARK: - Plan output

public struct CompositionPlan {
    public let tempoBPM: Double
    public let loopLengthTicks: Int
    public let harmonicContext: HarmonicContext
    public let tracks: [(rp: RealPattern, musicalClass: MusicalClass, gmProgram: UInt8)]
}

// MARK: - CompositionPlanner

public enum CompositionPlanner {

    /// Number of bars in a single loop of the generated MusicPattern.
    /// The loop repeats via AVAudioSequencer's native looping — 4 bars
    /// is long enough to feel musical and short enough to regenerate
    /// quickly on biometric change.
    public static let loopBars: Int = 4

    public static func plan(
        mode: FocusMode,
        biometricState: BiometricState,
        tonality: SessionTonality
    ) -> CompositionPlan {

        let loopLengthTicks = loopBars * Composing.ticksPerBar
        let hc = buildHarmonicContext(tonality: tonality, loopLengthTicks: loopLengthTicks)

        var tracks: [(rp: RealPattern, musicalClass: MusicalClass, gmProgram: UInt8)] = []

        for role in ClassLibrary.roles(for: mode) {
            guard let mclass = ClassLibrary.musicalClass(
                mode: mode,
                role: role,
                biometricState: biometricState
            ) else { continue }

            let molecule = buildMolecule(mode: mode, role: role, musicalClass: mclass, loopLengthTicks: loopLengthTicks)
            guard !molecule.atoms.isEmpty else { continue }

            let vp = PatternBuilder.buildVP(from: molecule, musicalClass: mclass)
            let rp = PatternBuilder.buildRP(from: vp, musicalClass: mclass)
            let gmProgram = gmProgram(for: role, mode: mode)
            tracks.append((rp: rp, musicalClass: mclass, gmProgram: gmProgram))
        }

        return CompositionPlan(
            tempoBPM: tonality.tempo,
            loopLengthTicks: loopLengthTicks,
            harmonicContext: hc,
            tracks: tracks
        )
    }

    /// Convenience: run the full pipeline to produce a MusicPattern.
    public static func buildMusicPattern(
        mode: FocusMode,
        biometricState: BiometricState,
        tonality: SessionTonality
    ) -> MusicPattern {
        let p = plan(mode: mode, biometricState: biometricState, tonality: tonality)
        return PatternBuilder.buildMP(
            tracks: p.tracks,
            harmonicContext: p.harmonicContext,
            tempoBPM: p.tempoBPM,
            loopLengthTicks: p.loopLengthTicks
        )
    }

    // MARK: - Harmonic Context

    /// Build a 4-bar progression rooted at the session tonality. Chord
    /// qualities are chosen to match the scale quality so the chord
    /// track's thirds stay consonant with solo/mixed tracks drawing from
    /// the same scale.
    private static func buildHarmonicContext(
        tonality: SessionTonality,
        loopLengthTicks: Int
    ) -> HarmonicContext {
        let rootSemitone = Int(tonality.root.intValue)
        let progression: [(offset: Int, family: ChordFamily)] = isMinorScale(tonality: tonality)
            ? [
                (0, .minor),   // i
                (8, .major),   // ♭VI
                (10, .major),  // ♭VII
                (0, .minor)    // i
            ]
            : [
                (0, .major),   // I
                (7, .major),   // V
                (9, .minor),   // vi
                (5, .major)    // IV
            ]

        let barTicks = Composing.ticksPerBar
        var entries: [HarmonicContextEntry] = []
        for (i, chord) in progression.enumerated() {
            let start = i * barTicks
            let end = start + barTicks
            guard start < loopLengthTicks else { break }
            let tonic = noteClass(for: (rootSemitone + chord.offset) % 12)
            entries.append(HarmonicContextEntry(
                startTick: start,
                endTick: min(end, loopLengthTicks),
                tone: tonality.root,
                scale: tonality.scale,
                tonic: tonic,
                family: chord.family
            ))
        }
        return HarmonicContext(entries: entries)
    }

    /// Map a 0-11 semitone value back to a NoteClass.
    private static func noteClass(for semitone: Int) -> NoteClass {
        let table: [NoteClass] = [.C, .Cs, .D, .Ds, .E, .F, .Fs, .G, .Gs, .A, .As, .B]
        return table[((semitone % 12) + 12) % 12]
    }

    /// True if the session's scale has a minor 3rd relative to its root.
    /// Checked by scanning the Tonic Key's note set for a pitch class
    /// three semitones above the root — present in every minor/dorian/
    /// phrygian-family scale and absent in every major-family scale.
    private static func isMinorScale(tonality: SessionTonality) -> Bool {
        let rootPc = (Int(tonality.root.intValue) % 12 + 12) % 12
        let minorThirdPc = (rootPc + 3) % 12
        let majorThirdPc = (rootPc + 4) % 12
        var hasMinor = false
        var hasMajor = false
        for note in tonality.key.noteSet.array {
            let pc = (Int(note.noteClass.intValue) % 12 + 12) % 12
            if pc == minorThirdPc { hasMinor = true }
            if pc == majorThirdPc { hasMajor = true }
        }
        // Prefer minor only if minor 3rd is present AND major 3rd isn't.
        return hasMinor && !hasMajor
    }

    // MARK: - Molecule assembly

    /// Fill a loop's worth of atoms for the given role, respecting the
    /// class's allowed atom types and sizes. Cycles through matching
    /// atoms; if none match, returns an empty molecule.
    private static func buildMolecule(
        mode: FocusMode,
        role: TrackRole,
        musicalClass: MusicalClass,
        loopLengthTicks: Int
    ) -> Molecule {
        let candidates = AtomLibrary.allAtoms(mode: mode, role: role).filter { atom in
            musicalClass.allowedAtomTypes.contains(atom.type)
                && musicalClass.allowedAtomSizes.contains(atom.sizeQuarters)
        }
        guard !candidates.isEmpty else {
            return Molecule(atoms: [], repetitiveness: musicalClass.atomicRepetitiveness)
        }

        var atoms: [Atom] = []
        var filled = 0
        var i = 0
        while filled < loopLengthTicks {
            // .same → always pick the first matching atom for habituation.
            // .none/.diff → cycle through candidates for variety.
            let atom: Atom
            switch musicalClass.atomicRepetitiveness {
            case .same:
                atom = candidates[0]
            case .none, .diff:
                atom = candidates[i % candidates.count]
            }
            atoms.append(atom)
            filled += atom.lengthTicks
            i += 1
            // Safety: bail if atoms have zero length to avoid infinite loop.
            if atom.lengthTicks <= 0 { break }
        }
        return Molecule(atoms: atoms, repetitiveness: musicalClass.atomicRepetitiveness)
    }

    // MARK: - GM program selection

    private static func gmProgram(for role: TrackRole, mode: FocusMode) -> UInt8 {
        switch role {
        case .melody, .pad, .texture:
            switch mode {
            case .focus:       return UInt8(Theme.SF2.PresetIndex.focusPad)
            case .relaxation:  return UInt8(Theme.SF2.PresetIndex.relaxationStrings)
            case .sleep:       return UInt8(Theme.SF2.PresetIndex.sleepPad)
            case .energize:    return UInt8(Theme.SF2.PresetIndex.energizeBells)
            }
        case .chords:
            return UInt8(Theme.SF2.PresetIndex.pad)
        case .bass:
            return UInt8(Theme.SF2.PresetIndex.bass)
        case .drums:
            return 0  // drum kit — channel 9 selects the percussion bank
        }
    }
}
