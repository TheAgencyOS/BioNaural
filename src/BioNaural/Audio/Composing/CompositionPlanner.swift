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
        tonality: SessionTonality,
        seed: CompositionSeed? = nil
    ) -> CompositionPlan {

        let loopLengthTicks = loopBars * Composing.ticksPerBar
        let hc = buildHarmonicContext(
            mode: mode,
            tonality: tonality,
            loopLengthTicks: loopLengthTicks,
            variant: seed?.progressionVariant ?? 0
        )

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
            let rp = PatternBuilder.buildRP(
                from: vp,
                musicalClass: mclass,
                swingTicks: seed?.swingTicks ?? 0
            )
            let gmProgram = seed?.gmPrograms[role] ?? gmProgram(for: role, mode: mode)
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
        tonality: SessionTonality,
        seed: CompositionSeed? = nil
    ) -> MusicPattern {
        let p = plan(mode: mode, biometricState: biometricState, tonality: tonality, seed: seed)
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
        loopLengthTicks: Int,
        variant: Int = 0
    ) -> HarmonicContext {
        let rootSemitone = Int(tonality.root.intValue)
        let minor = isMinorScale(tonality: tonality)
        let progression = progressionFor(mode: mode, minorScale: minor, variant: variant)

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

    /// Per-mode 8-bar chord progression pool. Each mode carries multiple
    /// variants so a session with a different seed produces a different
    /// harmonic feel — not just different notes on the same chord motion.
    /// Each entry is `(semitone offset from tonic, chord family)`.
    private static func progressionFor(
        mode: FocusMode,
        minorScale: Bool,
        variant: Int
    ) -> [(offset: Int, family: ChordFamily)] {
        let pool = progressionPool(mode: mode, minorScale: minorScale)
        let idx = ((variant % pool.count) + pool.count) % pool.count
        return pool[idx]
    }

    private static func progressionPool(
        mode: FocusMode,
        minorScale: Bool
    ) -> [[(offset: Int, family: ChordFamily)]] {
        switch mode {

        // MARK: Sleep — barely-moving drones and pedal tones
        case .sleep:
            if minorScale {
                return [
                    // i pedal with a single iv departure
                    [(0,.minor),(0,.minor),(0,.minor),(5,.minor),
                     (0,.minor),(0,.minor),(8,.major),(0,.minor)],
                    // i - VI drift
                    [(0,.minor),(0,.minor),(8,.major),(0,.minor),
                     (0,.minor),(8,.major),(5,.minor),(0,.minor)],
                    // brief phrygian colour
                    [(0,.minor),(1,.major),(0,.minor),(0,.minor),
                     (0,.minor),(8,.major),(0,.minor),(0,.minor)],
                ]
            } else {
                return [
                    // I pedal with a late IV
                    [(0,.major),(0,.major),(0,.major),(9,.minor),
                     (0,.major),(0,.major),(5,.major),(0,.major)],
                    // I - IV breathing
                    [(0,.major),(0,.major),(5,.major),(0,.major),
                     (0,.major),(5,.major),(9,.minor),(0,.major)],
                    // lydian float (I - II)
                    [(0,.major),(0,.major),(2,.major),(0,.major),
                     (0,.major),(2,.major),(0,.major),(0,.major)],
                ]
            }

        // MARK: Relaxation — gentle, slowly pulsing motion
        case .relaxation:
            if minorScale {
                return [
                    // i - ♭VI - iv - ♭VII x2
                    [(0,.minor),(8,.major),(5,.minor),(10,.major),
                     (0,.minor),(8,.major),(5,.minor),(10,.major)],
                    // i - v - ♭VI - ♭VII (Andalusian softened)
                    [(0,.minor),(7,.minor),(8,.major),(10,.major),
                     (0,.minor),(7,.minor),(8,.major),(10,.major)],
                    // dorian: i - IV - i - ♭VII
                    [(0,.minor),(5,.major),(0,.minor),(10,.major),
                     (0,.minor),(5,.major),(0,.minor),(10,.major)],
                ]
            } else {
                return [
                    // I - vi - IV - V (classic)
                    [(0,.major),(9,.minor),(5,.major),(7,.major),
                     (0,.major),(9,.minor),(5,.major),(7,.major)],
                    // I - iii - IV - V (soft)
                    [(0,.major),(4,.minor),(5,.major),(7,.major),
                     (0,.major),(4,.minor),(5,.major),(7,.major)],
                    // I - IV - vi - V (lydian-friendly)
                    [(0,.major),(5,.major),(9,.minor),(7,.major),
                     (0,.major),(5,.major),(9,.minor),(7,.major)],
                ]
            }

        // MARK: Focus — steady, predictable, lo-fi rotations
        case .focus:
            if minorScale {
                return [
                    // i - ♭VII - ♭VI - ♭VII x2
                    [(0,.minor),(10,.major),(8,.major),(10,.major),
                     (0,.minor),(10,.major),(8,.major),(10,.major)],
                    // ii - v - i - ♭VII (jazz-tinged)
                    [(2,.minor),(7,.minor),(0,.minor),(10,.major),
                     (2,.minor),(7,.minor),(0,.minor),(10,.major)],
                    // i - iv - v - i (plaintive)
                    [(0,.minor),(5,.minor),(7,.minor),(0,.minor),
                     (0,.minor),(5,.minor),(7,.minor),(0,.minor)],
                ]
            } else {
                return [
                    // I - V - vi - IV (four-chord loop)
                    [(0,.major),(7,.major),(9,.minor),(5,.major),
                     (0,.major),(7,.major),(9,.minor),(5,.major)],
                    // vi - IV - I - V
                    [(9,.minor),(5,.major),(0,.major),(7,.major),
                     (9,.minor),(5,.major),(0,.major),(7,.major)],
                    // ii - V - I - vi (jazz 2-5-1)
                    [(2,.minor),(7,.major),(0,.major),(9,.minor),
                     (2,.minor),(7,.major),(0,.major),(9,.minor)],
                ]
            }

        // MARK: Energize — forward motion, driving changes
        case .energize:
            if minorScale {
                return [
                    // i - ♭VII - ♭VI - V (harmonic minor punch)
                    [(0,.minor),(10,.major),(8,.major),(7,.major),
                     (0,.minor),(10,.major),(8,.major),(7,.major)],
                    // i - ♭VI - ♭VII - i (rock)
                    [(0,.minor),(8,.major),(10,.major),(0,.minor),
                     (0,.minor),(8,.major),(10,.major),(0,.minor)],
                    // i - iv - ♭VI - V (minor pop)
                    [(0,.minor),(5,.minor),(8,.major),(7,.major),
                     (0,.minor),(5,.minor),(8,.major),(7,.major)],
                ]
            } else {
                return [
                    // I - V - ♭VII - IV (anthemic)
                    [(0,.major),(7,.major),(10,.major),(5,.major),
                     (0,.major),(7,.major),(10,.major),(5,.major)],
                    // I - IV - V - IV (house)
                    [(0,.major),(5,.major),(7,.major),(5,.major),
                     (0,.major),(5,.major),(7,.major),(5,.major)],
                    // vi - IV - I - V (uplift)
                    [(9,.minor),(5,.major),(0,.major),(7,.major),
                     (9,.minor),(5,.major),(0,.major),(7,.major)],
                ]
            }
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
        let allMatching = AtomLibrary.allAtoms(mode: mode, role: role).filter { atom in
            musicalClass.allowedAtomTypes.contains(atom.type)
                && musicalClass.allowedAtomSizes.contains(atom.sizeQuarters)
        }
        // Split out fills so they're reserved for section endings,
        // then use the rest as the body pool.
        let fills = allMatching.filter { $0.name.contains("fill") }
        let candidates = allMatching.filter { !$0.name.contains("fill") }
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
                atom = pool[0]
            case .none, .diff:
                atom = pool[i % pool.count]
            }
            atoms.append(atom)
            filled += atom.lengthTicks
            i += 1
            if atom.lengthTicks <= 0 { break }
        }

        // Section-ending fills: replace the atom that covers the last
        // beat of each section with a fill of matching size if one is
        // available. Gives the phrase a turnaround instead of a hard
        // loop point.
        if !fills.isEmpty {
            var cursor = 0
            for (idx, atom) in atoms.enumerated() {
                let atomEnd = cursor + atom.lengthTicks
                let endsSectionA = cursor < sectionBoundaryTicks && atomEnd >= sectionBoundaryTicks
                let endsSectionB = cursor < loopLengthTicks && atomEnd >= loopLengthTicks
                if endsSectionA || endsSectionB {
                    if let fill = fills.first(where: { $0.sizeQuarters == atom.sizeQuarters }) {
                        atoms[idx] = fill
                    }
                }
                cursor += atom.lengthTicks
            }
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
