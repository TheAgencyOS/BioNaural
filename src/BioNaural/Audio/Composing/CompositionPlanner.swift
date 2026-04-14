// CompositionPlanner.swift
// BioNaural — v3 Composing Core
//
// Top-down session planner. Takes a FocusMode + BiometricState + the
// shared SessionTonality and produces the inputs PatternBuilder needs:
//
//   - A HarmonicContext (mode-specific 8-bar chord progression)
//   - One (RealPattern, MusicalClass, gmProgram) per active track role
//   - Loop length in ticks + tempo
//
// Each mode gets its own chord progression (sleep = minimal motion,
// energize = driving), phrase structure with A/B sections, and for
// energize modes the bass track is derived from the drum kick pattern
// so low end locks with the kick by construction.
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
    /// 8 bars = two 4-bar phrases (A / B). Long enough to feel like
    /// a real section, short enough to regenerate quickly on biometric
    /// change and stay memory-light.
    public static let loopBars: Int = 8

    /// Bars per phrase section. A runs [0, sectionBars), B runs
    /// [sectionBars, loopBars).
    public static let sectionBars: Int = 4

    public static func plan(
        mode: FocusMode,
        biometricState: BiometricState,
        tonality: SessionTonality
    ) -> CompositionPlan {

        let loopLengthTicks = loopBars * Composing.ticksPerBar
        let hc = buildHarmonicContext(mode: mode, tonality: tonality, loopLengthTicks: loopLengthTicks)

        // Build the drum molecule first. The bass molecule in rhythmic
        // modes will be derived from it so kick and bass interlock.
        var drumMolecule: Molecule? = nil
        var tracks: [(rp: RealPattern, musicalClass: MusicalClass, gmProgram: UInt8)] = []

        for role in ClassLibrary.roles(for: mode) {
            guard let mclass = ClassLibrary.musicalClass(
                mode: mode,
                role: role,
                biometricState: biometricState
            ) else { continue }

            let molecule: Molecule
            if role == .bass, let drums = drumMolecule, shouldInterlockBassWithDrums(mode: mode) {
                molecule = deriveBassMolecule(from: drums, musicalClass: mclass, loopLengthTicks: loopLengthTicks)
            } else {
                molecule = buildMolecule(
                    mode: mode,
                    role: role,
                    musicalClass: mclass,
                    loopLengthTicks: loopLengthTicks
                )
            }
            if role == .drums { drumMolecule = molecule }
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

    /// Build a mode-specific 8-bar progression. Each mode has a
    /// characteristic chord motion — sleep barely moves, energize
    /// drives hard — and the quality (major vs minor) adapts to the
    /// session scale so the chord thirds stay consonant with the
    /// scale used by solo/mixed tracks.
    private static func buildHarmonicContext(
        mode: FocusMode,
        tonality: SessionTonality,
        loopLengthTicks: Int
    ) -> HarmonicContext {
        let rootSemitone = Int(tonality.root.intValue)
        let minor = isMinorScale(tonality: tonality)
        let progression = progressionFor(mode: mode, minorScale: minor)

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

    /// Per-mode 8-bar chord progression (one chord per bar).
    /// Each entry is `(semitone offset from tonic, chord family)`.
    private static func progressionFor(
        mode: FocusMode,
        minorScale: Bool
    ) -> [(offset: Int, family: ChordFamily)] {
        switch mode {
        case .sleep:
            // Minimal motion — long tonic stretches with one gentle departure.
            return minorScale
                ? [
                    (0, .minor), (0, .minor), (0, .minor), (5, .minor),   // i   i   i   iv
                    (0, .minor), (0, .minor), (8, .major), (0, .minor)    // i   i   ♭VI i
                ]
                : [
                    (0, .major), (0, .major), (0, .major), (9, .minor),   // I   I   I   vi
                    (0, .major), (0, .major), (5, .major), (0, .major)    // I   I   IV  I
                ]

        case .relaxation:
            // Gentle breathing — classic soft progression, then repeat.
            return minorScale
                ? [
                    (0, .minor), (8, .major), (5, .minor), (10, .major),  // i   ♭VI iv  ♭VII
                    (0, .minor), (8, .major), (5, .minor), (7, .minor)    // i   ♭VI iv  v
                ]
                : [
                    (0, .major), (9, .minor), (5, .major), (7, .major),   // I   vi  IV  V
                    (0, .major), (9, .minor), (5, .major), (7, .major)    // (repeat)
                ]

        case .focus:
            // Steady, predictable — classic lo-fi / study rotation.
            return minorScale
                ? [
                    (0, .minor), (10, .major), (8, .major), (10, .major), // i   ♭VII ♭VI ♭VII
                    (0, .minor), (10, .major), (8, .major), (7, .major)   // i   ♭VII ♭VI V
                ]
                : [
                    (0, .major), (7, .major), (9, .minor), (5, .major),   // I   V   vi  IV
                    (0, .major), (7, .major), (9, .minor), (5, .major)    // (repeat)
                ]

        case .energize:
            // Driving progression with bar-start harmonic punches.
            return minorScale
                ? [
                    (0, .minor), (10, .major), (8, .major), (7, .major),  // i   ♭VII ♭VI V
                    (0, .minor), (10, .major), (8, .major), (7, .major)   // (repeat)
                ]
                : [
                    (0, .major), (7, .major), (10, .major), (5, .major),  // I   V   ♭VII IV
                    (0, .major), (7, .major), (10, .major), (5, .major)   // (repeat)
                ]
        }
    }

    /// Map a 0-11 semitone value back to a NoteClass.
    private static func noteClass(for semitone: Int) -> NoteClass {
        let table: [NoteClass] = [.C, .Cs, .D, .Ds, .E, .F, .Fs, .G, .Gs, .A, .As, .B]
        return table[((semitone % 12) + 12) % 12]
    }

    /// True if the session's scale has a minor 3rd relative to its root.
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
        return hasMinor && !hasMajor
    }

    // MARK: - Molecule assembly

    /// Fill a loop's worth of atoms for the given role, respecting the
    /// class's allowed atom types and sizes. Splits the loop into an A
    /// section and a B section so the second half of the phrase can
    /// draw from different atom choices than the first — gives the
    /// listener a sense of a piece that's developing rather than
    /// cycling a single cell.
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

        // Section boundary in ticks. Anything before → A pool, after → B.
        let sectionBoundaryTicks = sectionBars * Composing.ticksPerBar
        let half = max(1, candidates.count / 2)
        let poolA = Array(candidates.prefix(half))
        let poolB = candidates.count > half ? Array(candidates.suffix(from: half)) : candidates

        var atoms: [Atom] = []
        var filled = 0
        var i = 0
        while filled < loopLengthTicks {
            let pool = filled < sectionBoundaryTicks ? poolA : poolB
            let atom: Atom
            switch musicalClass.atomicRepetitiveness {
            case .same:
                // Still respect A/B sections — same atom within section,
                // potentially different atom in section B.
                atom = pool[0]
            case .none, .diff:
                atom = pool[i % pool.count]
            }
            atoms.append(atom)
            filled += atom.lengthTicks
            i += 1
            if atom.lengthTicks <= 0 { break }
        }
        return Molecule(atoms: atoms, repetitiveness: musicalClass.atomicRepetitiveness)
    }

    // MARK: - Bass/drum interlock

    /// Should the bass track be derived from the drum pattern rather than
    /// built independently? True for modes where rhythmic lock matters.
    private static func shouldInterlockBassWithDrums(mode: FocusMode) -> Bool {
        switch mode {
        case .energize: return true
        case .focus:    return false   // focus drums are minimal; keep bass independent
        case .sleep, .relaxation: return false
        }
    }

    /// Build a bass molecule whose markers land on the same ticks as
    /// the kick hits in a drum molecule. Kicks are identified by
    /// Marker.intensity >= 0.85 (that's where the drum resolver fires
    /// note 36). This produces a bass that moves with the kick and
    /// guarantees low-end/kick phase alignment without having to author
    /// interlocked bass patterns by hand.
    private static func deriveBassMolecule(
        from drums: Molecule,
        musicalClass: MusicalClass,
        loopLengthTicks: Int
    ) -> Molecule {
        // Flatten drum markers into absolute-tick kicks.
        var kickTicks: [Int] = []
        var atomTickOffset = 0
        for atom in drums.atoms {
            for marker in atom.markers where marker.intensity >= 0.85 {
                let absTick = atomTickOffset + marker.startTick
                if absTick < loopLengthTicks {
                    kickTicks.append(absTick)
                }
            }
            atomTickOffset += atom.lengthTicks
        }
        kickTicks.sort()
        guard !kickTicks.isEmpty else {
            // No kicks to follow → fall back to the hand-authored bass atoms.
            return Molecule(atoms: [], repetitiveness: musicalClass.atomicRepetitiveness)
        }

        // One big atom whose length matches the loop, markers = kick hits.
        let barTicks = Composing.ticksPerBar
        let barCount = max(1, loopLengthTicks / barTicks)
        let sizeQuarters = barCount * 4
        let velocityCenter = Double(musicalClass.velocityRange.lowerBound + musicalClass.velocityRange.upperBound) / 2.0 / 127.0

        var markers: [Marker] = []
        for (i, tick) in kickTicks.enumerated() {
            let nextTick = i + 1 < kickTicks.count ? kickTicks[i + 1] : loopLengthTicks
            let stopTick = min(nextTick, tick + barTicks / 2) // cap to 2 beats
            markers.append(Marker(
                startTick: tick,
                stopTick: stopTick,
                intensity: velocityCenter,
                moveAbility: 0.0
            ))
        }

        let interlocked = Atom(
            sizeQuarters: sizeQuarters,
            type: .alpha,
            markers: markers,
            name: "derived_bass_from_kick"
        )
        return Molecule(atoms: [interlocked], repetitiveness: .same)
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
