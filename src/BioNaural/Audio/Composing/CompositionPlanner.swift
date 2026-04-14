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
        seed: CompositionSeed? = nil,
        arcIntensity: Double = 1.0
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
            guard let baseClass = ClassLibrary.musicalClass(
                mode: mode,
                role: role,
                biometricState: biometricState
            ) else { continue }
            // Apply the session-arc intensity multiplier. Low
            // intensity narrows atom variety and scales velocity
            // down so intro / outro phases feel noticeably sparser
            // than the body of the session.
            let mclass = applyArcIntensity(arcIntensity, to: baseClass)

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
        seed: CompositionSeed? = nil,
        arcIntensity: Double = 1.0
    ) -> MusicPattern {
        let p = plan(
            mode: mode,
            biometricState: biometricState,
            tonality: tonality,
            seed: seed,
            arcIntensity: arcIntensity
        )
        return PatternBuilder.buildMP(
            tracks: p.tracks,
            harmonicContext: p.harmonicContext,
            tempoBPM: p.tempoBPM,
            loopLengthTicks: p.loopLengthTicks,
            drumKit: seed?.drumKit ?? .sparseKit
        )
    }

    // MARK: - Arc intensity application

    /// Apply a session-arc intensity multiplier to a MusicalClass.
    /// Returns a new MusicalClass with scaled density, velocity, and
    /// (at very low intensity) narrowed atom types. Intensity 1.0 is
    /// a passthrough.
    private static func applyArcIntensity(
        _ intensity: Double,
        to base: MusicalClass
    ) -> MusicalClass {
        guard abs(intensity - 1.0) > 0.01 else { return base }
        let clamped = max(0.2, min(1.2, intensity))

        // Scale density.
        let newDensity = max(0.05, min(1.0, base.density * clamped))

        // Scale velocity range — low phases noticeably quieter.
        let loScale = Int(Double(base.velocityRange.lowerBound) * clamped)
        let hiScale = Int(Double(base.velocityRange.upperBound) * clamped)
        let newLo = UInt8(max(1, min(127, loScale)))
        let newHi = UInt8(max(Int(newLo) + 1, min(127, hiScale)))
        let newVelocityRange: ClosedRange<UInt8> = newLo...newHi

        // At very low intensity, strip beta and gamma atom types so
        // the phase stays minimal. Drums are exempt — drum atoms are
        // all alpha and drums are a rhythmic spine we want running.
        var newAtomTypes = base.allowedAtomTypes
        if clamped < 0.55 && base.role != .drums {
            newAtomTypes = newAtomTypes.filter { $0 == .alpha || $0 == .empty }
            if newAtomTypes.isEmpty { newAtomTypes = [.alpha] }
        }

        return MusicalClass(
            name: base.name + "_arc\(Int(clamped * 100))",
            role: base.role,
            allowedAtomTypes: newAtomTypes,
            atomicRepetitiveness: base.atomicRepetitiveness,
            weirdnessRange: base.weirdnessRange,
            density: newDensity,
            allowedEventTypes: base.allowedEventTypes,
            octaveRange: base.octaveRange,
            velocityRange: newVelocityRange,
            allowedAtomSizes: base.allowedAtomSizes,
            contour: base.contour
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

        // MARK: Relaxation — gentle motion built on extended chords.
        // Ambient and new-age live on maj7 / m7 / sus2 voicings — pure
        // triads sound empty in this register. These progressions
        // favor modal motion and long sustains.
        case .relaxation:
            if minorScale {
                return [
                    // dorian vamp: i7 - IV (i7 dorian → bright IV)
                    [(0,.minor7),(5,.major7),(0,.minor7),(5,.major7),
                     (0,.minor7),(5,.major7),(0,.minor7),(5,.major7)],
                    // i9 - ♭VImaj7 - iv9 - ♭VIImaj7
                    [(0,.minor9),(8,.major7),(5,.minor9),(10,.major7),
                     (0,.minor9),(8,.major7),(5,.minor9),(10,.major7)],
                    // im7 - v7 - ♭VImaj7 - iv7 (ECM-style)
                    [(0,.minor7),(7,.minor7),(8,.major7),(5,.minor7),
                     (0,.minor7),(7,.minor7),(8,.major7),(5,.minor7)],
                ]
            } else {
                return [
                    // Imaj7 - vi7 - IVmaj7 - V7 (classic soft jazz)
                    [(0,.major7),(9,.minor7),(5,.major7),(7,.dominant7),
                     (0,.major7),(9,.minor7),(5,.major7),(7,.dominant7)],
                    // Imaj9 - iii7 - IVmaj7 - V7 (lush)
                    [(0,.major9),(4,.minor7),(5,.major7),(7,.dominant7),
                     (0,.major9),(4,.minor7),(5,.major7),(7,.dominant7)],
                    // Isus2 - IVmaj7 - vi7 - Vsus4 (lydian float)
                    [(0,.sus2),(5,.major7),(9,.minor7),(7,.sus4),
                     (0,.sus2),(5,.major7),(9,.minor7),(7,.sus4)],
                ]
            }

        // MARK: Focus — ambient reframe. Long-sustain extended chords,
        // modal motion, no cadential dominants. Same feel as
        // relaxation but even more drifting and sparser.
        case .focus:
            if minorScale {
                return [
                    // im9 - ♭VImaj7 drone pair (two chords, slow move)
                    [(0,.minor9),(0,.minor9),(8,.major7),(8,.major7),
                     (0,.minor9),(0,.minor9),(8,.major7),(8,.major7)],
                    // dorian vamp: im7 - IVmaj7
                    [(0,.minor7),(5,.major7),(0,.minor7),(5,.major7),
                     (0,.minor7),(5,.major7),(0,.minor7),(5,.major7)],
                    // im7 - ♭VIImaj7 - ♭VImaj7 - ♭VIImaj7 (modal float)
                    [(0,.minor7),(10,.major7),(8,.major7),(10,.major7),
                     (0,.minor7),(10,.major7),(8,.major7),(10,.major7)],
                ]
            } else {
                return [
                    // Imaj9 pedal with one IVmaj7 departure
                    [(0,.major9),(0,.major9),(0,.major9),(5,.major7),
                     (0,.major9),(0,.major9),(5,.major7),(0,.major9)],
                    // Imaj7 - IVmaj7 - vi9 - IVmaj7 (lydian float)
                    [(0,.major7),(5,.major7),(9,.minor9),(5,.major7),
                     (0,.major7),(5,.major7),(9,.minor9),(5,.major7)],
                    // Isus2 - Imaj7 - IVmaj7 - Imaj7 (breath)
                    [(0,.sus2),(0,.major7),(5,.major7),(0,.major7),
                     (0,.sus2),(0,.major7),(5,.major7),(0,.major7)],
                ]
            }

        // MARK: Energize — hip-hop / boom-bap. Minor 7ths and m9s
        // over head-nod tempos. Think Nujabes, J Dilla, Madlib —
        // warm rhodes, subby bass, dusty drums.
        case .energize:
            if minorScale {
                return [
                    // im9 - ♭VIImaj7 - ♭VImaj7 - v7 (Nujabes)
                    [(0,.minor9),(10,.major7),(8,.major7),(7,.minor7),
                     (0,.minor9),(10,.major7),(8,.major7),(7,.minor7)],
                    // im7 - iv7 - ♭VIImaj7 - ♭IIImaj7 (moody loop)
                    [(0,.minor7),(5,.minor7),(10,.major7),(3,.major7),
                     (0,.minor7),(5,.minor7),(10,.major7),(3,.major7)],
                    // ii7 - V7 - im7 - ♭VIImaj7 (jazz 2-5-1 minor)
                    [(2,.minor7),(7,.dominant7),(0,.minor7),(10,.major7),
                     (2,.minor7),(7,.dominant7),(0,.minor7),(10,.major7)],
                ]
            } else {
                // Fallback for the rare major energize seed.
                return [
                    // Imaj7 - vi7 - ii7 - V7
                    [(0,.major7),(9,.minor7),(2,.minor7),(7,.dominant7),
                     (0,.major7),(9,.minor7),(2,.minor7),(7,.dominant7)],
                    // vi9 - ii7 - V7 - Imaj7
                    [(9,.minor9),(2,.minor7),(7,.dominant7),(0,.major7),
                     (9,.minor9),(2,.minor7),(7,.dominant7),(0,.major7)],
                    // Imaj9 - IVmaj7 - iii7 - vi7
                    [(0,.major9),(5,.major7),(4,.minor7),(9,.minor7),
                     (0,.major9),(5,.major7),(4,.minor7),(9,.minor7)],
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
        // Drums get a dedicated path: one hand-picked atom repeats
        // for the entire loop with no A/B swap, no empty bars, and
        // no fill substitution. A constant rhythmic spine is more
        // important than variety for hypnotic modes.
        if role == .drums {
            let drumAtom = allMatching.first { !$0.name.contains("empty") } ?? allMatching.first
            guard let drumAtom, drumAtom.lengthTicks > 0 else {
                return Molecule(atoms: [], repetitiveness: .same)
            }
            let count = max(1, loopLengthTicks / drumAtom.lengthTicks)
            return Molecule(
                atoms: Array(repeating: drumAtom, count: count),
                repetitiveness: .same
            )
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
