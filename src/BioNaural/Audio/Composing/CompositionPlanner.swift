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
        arcIntensity: Double = 1.0,
        styleMemory: SessionStyleMemory? = nil
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
            // Apply the session-arc intensity multiplier and the
            // HRV-derived weirdness ceiling. Low intensity narrows
            // atom variety and scales velocity down so intro / outro
            // phases feel sparser; elevated/peak biometric states
            // cap tonal tension for parasympathetic recovery.
            let mclass = applyArcIntensity(
                arcIntensity,
                biometricState: biometricState,
                to: baseClass
            )

            let molecule: Molecule
            let shuffleOffset = seed?.roleAtomOffset[role] ?? 0
            let generatedPool = seed?.generatedAtoms[role] ?? []
            if role == .bass, let drums = drumMolecule, shouldInterlockBassWithDrums(mode: mode) {
                molecule = deriveBassMolecule(from: drums, musicalClass: mclass, loopLengthTicks: loopLengthTicks)
            } else {
                molecule = buildMolecule(
                    mode: mode,
                    role: role,
                    musicalClass: mclass,
                    loopLengthTicks: loopLengthTicks,
                    styleMemory: styleMemory,
                    shuffleOffset: shuffleOffset,
                    generatedAtoms: generatedPool
                )
            }
            // Record the atoms we chose so the next regeneration's
            // buildMolecule will bias its candidate ordering toward
            // the same atoms — stylistic continuity across blocks.
            if let styleMemory {
                for atom in molecule.atoms {
                    styleMemory.record(role: role, atomName: atom.name)
                }
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

        // Biometric-driven tempo modulation. Sleep and Relax music
        // research (Pelletier 2004; Dickson & Schubert 2019) supports
        // the "iso principle" — match the user's current arousal,
        // then slow the music to pull them down. Implemented as a
        // small BPM offset applied per biometric state at
        // regeneration time. Focus keeps its tempo stable for
        // habituation.
        let biometricTempoDelta = biometricTempoAdjustment(
            for: mode,
            state: biometricState
        )
        let adjustedTempo = max(30.0, min(180.0, tonality.tempo + biometricTempoDelta))

        return CompositionPlan(
            tempoBPM: adjustedTempo,
            loopLengthTicks: loopLengthTicks,
            harmonicContext: hc,
            tracks: tracks
        )
    }

    /// Per-mode biometric tempo offset in BPM. Applied on top of
    /// the seed's session tempo at MusicPattern build time.
    /// Research basis: the iso principle (Altshuler, via Pelletier
    /// 2004 meta-analysis on music and stress reduction) says
    /// matching-then-leading works better than immediate
    /// deceleration for parasympathetic engagement.
    private static func biometricTempoAdjustment(
        for mode: FocusMode,
        state: BiometricState
    ) -> Double {
        switch mode {
        case .sleep:
            switch state {
            case .calm:     return 0.0
            case .focused:  return -1.0
            case .elevated: return -3.0   // slow down to pull them down
            case .peak:     return -5.0
            }
        case .relaxation:
            switch state {
            case .calm:     return 0.0
            case .focused:  return 0.0
            case .elevated: return -2.0
            case .peak:     return -4.0
            }
        case .focus:
            // Focus holds tempo stable for habituation — the
            // research on lo-fi study beats (Ribeiro et al. 2019)
            // supports a steady pulse over an adaptive one.
            return 0.0
        case .energize:
            return 0.0
        }
    }

    /// Convenience: run the full pipeline to produce a MusicPattern.
    public static func buildMusicPattern(
        mode: FocusMode,
        biometricState: BiometricState,
        tonality: SessionTonality,
        seed: CompositionSeed? = nil,
        arcIntensity: Double = 1.0,
        styleMemory: SessionStyleMemory? = nil
    ) -> MusicPattern {
        let p = plan(
            mode: mode,
            biometricState: biometricState,
            tonality: tonality,
            seed: seed,
            arcIntensity: arcIntensity,
            styleMemory: styleMemory
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

    /// Apply the session-arc intensity multiplier AND a biometric
    /// HRV-derived weirdness ceiling to a MusicalClass. Returns a
    /// new MusicalClass with scaled density, velocity, atom types,
    /// and tonal-tension range.
    ///
    /// HRV mapping: elevated / peak states reduce the weirdness
    /// ceiling to favor consonant intervals, backed by the 2021
    /// biofeedback study showing harmonic-consonance shifts push
    /// HRV toward parasympathetic recovery.
    private static func applyArcIntensity(
        _ intensity: Double,
        biometricState: BiometricState,
        to base: MusicalClass
    ) -> MusicalClass {
        // Drums are exempt from arc-intensity scaling. Their
        // velocityRange is carefully calibrated so atom-intensity
        // tiers map to the right resolver drum tiers (kick / snare /
        // hat); scaling that range with the phase intensity pushes
        // tiers out of the right resolver buckets and produces a
        // different drum sound in intro/outro phases than in the
        // body of the session. Keep drums at their base class
        // throughout — constant rhythm is more important than
        // session-arc dynamics for the rhythmic spine.
        if base.role == .drums { return base }

        let clamped = max(0.2, min(1.2, intensity))
        let cappedWeirdness = weirdnessCap(for: biometricState, base: base.weirdnessRange)

        let noArcChange = abs(intensity - 1.0) <= 0.01
        let noWeirdnessChange = cappedWeirdness == base.weirdnessRange
        if noArcChange && noWeirdnessChange { return base }

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
            name: base.name + "_arc\(Int(clamped * 100))_bio\(biometricState)",
            role: base.role,
            allowedAtomTypes: newAtomTypes,
            atomicRepetitiveness: base.atomicRepetitiveness,
            weirdnessRange: cappedWeirdness,
            density: newDensity,
            allowedEventTypes: base.allowedEventTypes,
            octaveRange: base.octaveRange,
            velocityRange: newVelocityRange,
            allowedAtomSizes: base.allowedAtomSizes,
            contour: base.contour
        )
    }

    /// HRV → weirdness ceiling. Elevated and peak arousal states cap
    /// the upper bound of the weirdness range so chord tones and
    /// scale tones stay closer to the consonant center. Calm and
    /// focused states pass the range through unchanged.
    private static func weirdnessCap(
        for state: BiometricState,
        base: WeirdnessRange
    ) -> WeirdnessRange {
        let cap: Double
        switch state {
        case .calm, .focused: return base
        case .elevated:       cap = 0.50   // mild ceiling
        case .peak:           cap = 0.30   // safe ceiling
        }
        let newUpper = min(base.upper.value, cap)
        let newLower = min(base.lower.value, newUpper)
        return WeirdnessRange(Weirdness(newLower), Weirdness(newUpper))
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

        // MARK: Focus — research-grounded. Each chord held for 2 bars
        // (Kämpfe 2011: predictability minimizes cognitive load).
        // Only 4 chords total per 8-bar loop. Simple ii-V-I family
        // progressions — the lo-fi convention that research
        // validated indirectly via the "simple/repetitive" finding.
        case .focus:
            if minorScale {
                return [
                    // im7 (2 bars) - ♭VImaj7 (2 bars) - repeat
                    [(0,.minor7),(0,.minor7),(8,.major7),(8,.major7),
                     (0,.minor7),(0,.minor7),(8,.major7),(8,.major7)],
                    // im7 (2) - IVmaj7 (2) - im7 (2) - IVmaj7 (2)
                    [(0,.minor7),(0,.minor7),(5,.major7),(5,.major7),
                     (0,.minor7),(0,.minor7),(5,.major7),(5,.major7)],
                    // im9 (2) - ♭VIImaj7 (2) - repeat
                    [(0,.minor9),(0,.minor9),(10,.major7),(10,.major7),
                     (0,.minor9),(0,.minor9),(10,.major7),(10,.major7)],
                ]
            } else {
                return [
                    // Imaj7 (2 bars) - IVmaj7 (2 bars) - repeat
                    [(0,.major7),(0,.major7),(5,.major7),(5,.major7),
                     (0,.major7),(0,.major7),(5,.major7),(5,.major7)],
                    // Imaj9 (2) - vi7 (2) - repeat
                    [(0,.major9),(0,.major9),(9,.minor7),(9,.minor7),
                     (0,.major9),(0,.major9),(9,.minor7),(9,.minor7)],
                    // Imaj7 (2) - ii7 (2) - Imaj7 (2) - V7 (2)
                    [(0,.major7),(0,.major7),(2,.minor7),(2,.minor7),
                     (0,.major7),(0,.major7),(7,.dominant7),(7,.dominant7)],
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
        loopLengthTicks: Int,
        styleMemory: SessionStyleMemory? = nil,
        shuffleOffset: Int = 0,
        generatedAtoms: [Atom] = []
    ) -> Molecule {
        // Prepend any parametrically-generated atoms so .same
        // repetitiveness picks from the session-unique pool first,
        // and the shuffle offset cycles through generated atoms
        // before falling back to the hand-authored library.
        let filteredGenerated = generatedAtoms.filter { atom in
            musicalClass.allowedAtomTypes.contains(atom.type)
                && musicalClass.allowedAtomSizes.contains(atom.sizeQuarters)
        }
        var allMatching = filteredGenerated + AtomLibrary.allAtoms(mode: mode, role: role).filter { atom in
            musicalClass.allowedAtomTypes.contains(atom.type)
                && musicalClass.allowedAtomSizes.contains(atom.sizeQuarters)
        }
        // Stylistic continuity: reorder the candidate pool so atoms
        // the session has recently played float to the front. The
        // rest of the ordering stays intact, so the selection still
        // has the original variety on a fresh session.
        if let styleMemory, !styleMemory.isEmpty(for: role) {
            allMatching.sort { a, b in
                styleMemory.recency(role: role, atomName: a.name)
                    > styleMemory.recency(role: role, atomName: b.name)
            }
        }
        // Drums get a dedicated path: one hand-picked atom repeats
        // for the entire loop with no A/B swap, no empty bars, and
        // no fill substitution. A constant rhythmic spine is more
        // important than variety for hypnotic modes. The shuffle
        // offset lets the user cycle through available drum atoms
        // via the "new drums" button in the mix panel.
        if role == .drums {
            let playable = allMatching.filter { !$0.name.contains("empty") }
            let pool = playable.isEmpty ? allMatching : playable
            guard let first = pool.first, first.lengthTicks > 0 else {
                return Molecule(atoms: [], repetitiveness: .same)
            }
            let idx = ((shuffleOffset % pool.count) + pool.count) % pool.count
            let drumAtom = pool[idx]
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

        // For .same repetitiveness we want the SAME atom across the
        // entire loop — that's the whole point of .same. The old
        // code split candidates into poolA/poolB and used pool[0]
        // from each, which swapped atoms mid-loop and produced
        // clunky unmusical transitions on focus bass + melody.
        //
        // Now: .same uses candidates[0] for the whole loop.
        // .none/.diff cycles through candidates across both sections.
        let sectionBoundaryTicks = sectionBars * Composing.ticksPerBar
        let half = max(1, candidates.count / 2)
        let poolA = Array(candidates.prefix(half))
        let poolB = candidates.count > half ? Array(candidates.suffix(from: half)) : candidates

        // shuffleOffset comes from seed.roleAtomOffset[role] and is
        // bumped when the user taps the mix-panel reshuffle button
        // for this track. For .same it selects a different atom
        // from the full candidate pool; for .none/.diff it rotates
        // the cycling start index.
        let wrappedOffset = candidates.isEmpty
            ? 0
            : ((shuffleOffset % candidates.count) + candidates.count) % candidates.count
        var atoms: [Atom] = []
        var filled = 0
        var i = 0
        while filled < loopLengthTicks {
            let atom: Atom
            switch musicalClass.atomicRepetitiveness {
            case .same:
                atom = candidates[wrappedOffset]
            case .none, .diff:
                let pool = filled < sectionBoundaryTicks ? poolA : poolB
                atom = pool[(i + wrappedOffset) % pool.count]
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
