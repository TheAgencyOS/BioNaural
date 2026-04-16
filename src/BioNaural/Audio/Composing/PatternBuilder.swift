// PatternBuilder.swift
// BioNaural — v3 Composing Core
//
// The orchestrator that runs the full Atom → Molecule → VP → RP → MP
// transformation pipeline. Each phase is a pure function; PatternBuilder
// just chains them together.
//
// Pipeline:
//   1. Molecule (assembled from AtomLibrary by CompositionPlanner)
//   2. → VirtualPattern    via buildVP()    — rhythm + abstract weirdness
//   3. → RealPattern       via buildRP()    — expand chords, humanize
//   4. → MusicPattern      via buildMP()    — apply HC, tile across loop
//
// All steps are pure (no side effects, no I/O). They run on whatever
// thread the caller chooses. CompositionPlanner runs them on a background
// queue at session start (or on biometric change).

import Foundation
import BioNauralShared

// MARK: - PatternBuilder

public enum PatternBuilder {

    // MARK: - Molecule → VirtualPattern

    /// Convert a Molecule into a VirtualPattern using the Class rules.
    /// Each Marker becomes one VPEvent (note for melodic/drum tracks,
    /// chord for the chord track).
    public static func buildVP(
        from molecule: Molecule,
        musicalClass: MusicalClass
    ) -> VirtualPattern {
        var events: [VPEvent] = []
        var atomTickOffset = 0

        for atom in molecule.atoms {
            for marker in atom.markers {
                let position = atomTickOffset + marker.startTick
                let length = max(1, marker.lengthTicks)
                let velocity = mapIntensityToVelocity(
                    marker.intensity,
                    range: musicalClass.velocityRange
                )

                let event = makeEvent(
                    musicalClass: musicalClass,
                    position: position,
                    length: length,
                    velocity: velocity
                )
                events.append(event)
            }
            atomTickOffset += atom.lengthTicks
        }

        return VirtualPattern(
            lengthTicks: molecule.lengthTicks,
            events: events,
            role: musicalClass.role
        )
    }

    // MARK: - VirtualPattern → RealPattern

    /// Expand chord/arpeggio events into individual NOTE events.
    /// Apply light humanization: small position jitter for melodic
    /// notes (none for rhythmic / drum notes).
    public static func buildRP(
        from vp: VirtualPattern,
        musicalClass: MusicalClass,
        swingTicks: Int = 0
    ) -> RealPattern {
        var notes: [RPNote] = []

        for event in vp.events {
            switch event {

            case .note(let weirdness, let position, let length, let velocity, let type):
                let swung = applySwing(position: position, swingTicks: swingTicks, role: vp.role)
                let jittered = humanizePosition(swung, type: type)
                notes.append(RPNote(
                    weirdness: weirdness,
                    positionTicks: jittered,
                    lengthTicks: length,
                    velocity: velocity,
                    type: type
                ))

            case .chord(let numNotes, let weirdnessRange, let simultaneousnessTicks,
                        let position, let length, let velocity):
                // Spread N notes across the weirdness range; each gets
                // a slight position offset for humanization.
                for i in 0..<numNotes {
                    let t = numNotes > 1 ? Double(i) / Double(numNotes - 1) : 0.0
                    let w = Weirdness(
                        weirdnessRange.lower.value
                        + t * (weirdnessRange.upper.value - weirdnessRange.lower.value)
                    )
                    notes.append(RPNote(
                        weirdness: w,
                        positionTicks: position + i * simultaneousnessTicks,
                        lengthTicks: length,
                        velocity: velocity,
                        type: .comp
                    ))
                }

            case .polynote(let numNotes, let baseWeirdness, let weirdnessDelta,
                           let position, let length, let velocity):
                // Treat as a chord-like spread but with type .mixed.
                for i in 0..<numNotes {
                    let offset = (Double(i) - Double(numNotes - 1) / 2.0) * weirdnessDelta
                    let w = Weirdness(baseWeirdness.value + offset)
                    notes.append(RPNote(
                        weirdness: w,
                        positionTicks: position,
                        lengthTicks: length,
                        velocity: velocity,
                        type: .mixed
                    ))
                }

            case .arpeggio(let numNotes, let weirdnessSequence, let position,
                           let length, let noteLengthTicks, let velocity):
                // Spread notes in sequence across the arpeggio length.
                let stride = numNotes > 0 ? length / numNotes : length
                for i in 0..<numNotes {
                    let w = i < weirdnessSequence.count
                        ? weirdnessSequence[i]
                        : weirdnessSequence.last ?? Weirdness.safe
                    notes.append(RPNote(
                        weirdness: w,
                        positionTicks: position + i * stride,
                        lengthTicks: noteLengthTicks,
                        velocity: velocity,
                        type: .solo
                    ))
                }
            }
        }

        return RealPattern(
            lengthTicks: vp.lengthTicks,
            notes: notes,
            role: vp.role
        )
    }

    // MARK: - RealPattern → MusicPattern

    /// Tile RPs across a loop length, applying the Harmonic Context to
    /// resolve every Weirdness into a concrete MIDI pitch. Returns a
    /// MusicPattern that's ready to serialize to a Standard MIDI File.
    ///
    /// - Parameters:
    ///   - tracks: per-track (RP, Class, GM program) tuples.
    ///   - harmonicContext: time-stamped chord/key data covering the loop.
    ///   - tempoBPM: tempo for the resulting MP.
    ///   - loopLengthTicks: total length of the loop in ticks. RPs tile
    ///     across this length (each RP repeats `loopLengthTicks / RP.length` times).
    public static func buildMP(
        tracks: [(rp: RealPattern, musicalClass: MusicalClass, gmProgram: UInt8)],
        harmonicContext: HarmonicContext,
        tempoBPM: Double,
        loopLengthTicks: Int,
        drumKit: DrumKit = .sparseKit
    ) -> MusicPattern {
        var mpTracks: [MPTrack] = []

        for trackInput in tracks {
            let rp = trackInput.rp
            let mclass = trackInput.musicalClass
            let baseOctave = middleOctave(of: mclass.octaveRange)
            var notes: [MPNote] = []
            var lastPitch: UInt8? = nil

            // Precompute parsimonious chord voicings per HC entry for
            // the chord track. Every HC entry's voicing is chosen to
            // minimize voice motion from the previous entry's voicing,
            // so chord changes glide by common tones instead of
            // jumping in parallel.
            let chordVoicings: [Int: [UInt8]] = {
                guard rp.role == .chords else { return [:] }
                return precomputeChordVoicings(
                    harmonicContext: harmonicContext,
                    octaveRange: mclass.octaveRange
                )
            }()

            // Tile the RP across the full loop length. Each tile uses
            // the same rhythmic pattern but different pitches because
            // the active HC entry may have changed.
            var tileOffset = 0
            while tileOffset < loopLengthTicks {
                for rpNote in rp.notes {
                    let absoluteTick = tileOffset + rpNote.positionTicks
                    if absoluteTick >= loopLengthTicks { continue }

                    let hcEntry = harmonicContext.entry(at: absoluteTick)
                        ?? defaultHarmonicEntry(at: absoluteTick)

                    // Contour bias — shift octave based on phrase position
                    // so melodic tracks have a sense of direction that
                    // matches the mode (sleep descends, energize ascends).
                    let progress = Double(absoluteTick) / Double(max(1, loopLengthTicks))
                    let octave = applyContour(
                        base: baseOctave,
                        range: mclass.octaveRange,
                        contour: mclass.contour,
                        type: rpNote.type,
                        progress: progress
                    )

                    var pitch: UInt8
                    if rp.role == .chords,
                       let voicing = chordVoicings[hcEntry.startTick],
                       !voicing.isEmpty {
                        // Map weirdness to an index into the precomputed
                        // parsimonious voicing: weirdness 0 → lowest voice,
                        // weirdness 1 → highest. Keeps the chord-tone spread
                        // intact while the voicing itself moves minimally.
                        let idx = min(voicing.count - 1, max(0, Int(rpNote.weirdness.value * Double(voicing.count))))
                        pitch = voicing[idx]
                    } else {
                        pitch = WeirdnessResolver.resolve(
                            weirdness: rpNote.weirdness,
                            type: rpNote.type,
                            velocity: rpNote.velocity,
                            hc: hcEntry,
                            octave: octave,
                            drumKit: drumKit
                        )
                    }

                    // Voice-leading: if this melodic note is more than
                    // 7 semitones away from the previous one, transpose
                    // by octaves toward the previous pitch so the line
                    // moves by small intervals instead of big leaps.
                    if (rpNote.type == .mixed || rpNote.type == .solo), let prev = lastPitch {
                        pitch = voiceLead(pitch: pitch, toward: prev, octaveRange: mclass.octaveRange)
                    }
                    if rpNote.type == .mixed || rpNote.type == .solo {
                        lastPitch = pitch
                    }

                    // Dynamic density: velocity rides a half-sine envelope
                    // across the loop so the phrase has a sense of swell
                    // and release instead of flat dynamics.
                    let shapedVelocity = applyDensityEnvelope(
                        velocity: rpNote.velocity,
                        progress: progress,
                        role: rp.role
                    )

                    // Trim length so the note doesn't extend past the loop.
                    let maxLength = loopLengthTicks - absoluteTick
                    let length = min(rpNote.lengthTicks, maxLength)

                    notes.append(MPNote(
                        pitch: pitch,
                        velocity: shapedVelocity,
                        positionTicks: absoluteTick,
                        lengthTicks: length
                    ))
                }
                tileOffset += max(1, rp.lengthTicks)
            }

            let channel: UInt8 = (rp.role == .drums) ? 9 : channelForRole(rp.role)
            let ccs = buildExpressionCCs(role: rp.role, loopLengthTicks: loopLengthTicks)

            // Drum tracks get GrooVAE-inspired humanization: per-
            // voice microtiming offsets and metric velocity shaping
            // so the rhythm section reads as a human drummer rather
            // than a quantized grid.
            let finalNotes: [MPNote]
            if rp.role == .drums {
                finalNotes = DrumHumanizer.humanize(
                    notes: notes,
                    loopLengthTicks: loopLengthTicks,
                    ticksPerBar: Composing.ticksPerBar
                )
            } else {
                finalNotes = notes
            }

            mpTracks.append(MPTrack(
                role: rp.role,
                gmProgram: trackInput.gmProgram,
                channel: channel,
                notes: finalNotes,
                controlChanges: ccs
            ))
        }

        return MusicPattern(
            totalLengthTicks: loopLengthTicks,
            tempoBPM: tempoBPM,
            tracks: mpTracks
        )
    }

    // MARK: - Helpers

    /// Map a Marker's 0.0-1.0 intensity into a MIDI velocity within the
    /// Class's allowed range.
    private static func mapIntensityToVelocity(
        _ intensity: Double,
        range: ClosedRange<UInt8>
    ) -> UInt8 {
        let lo = Double(range.lowerBound)
        let hi = Double(range.upperBound)
        let v = lo + max(0.0, min(1.0, intensity)) * (hi - lo)
        return UInt8(max(1, min(127, Int(v.rounded()))))
    }

    /// Build the appropriate VPEvent for the given class + marker info.
    /// Chord tracks emit `.chord`, drum tracks emit `.note(.rhythmic)`,
    /// everything else emits `.note(.mixed)` or `.note(.comp)` based on
    /// role. Melodic and solo notes vary weirdness deterministically
    /// across the marker position within the bar so the melody line
    /// actually moves through scale tones instead of repeating a
    /// single pitch.
    private static func makeEvent(
        musicalClass: MusicalClass,
        position: Int,
        length: Int,
        velocity: UInt8
    ) -> VPEvent {
        let allowsChord = musicalClass.allowedEventTypes.contains(.chord)

        if musicalClass.role == .chords && allowsChord {
            return .chord(
                numNotes: 3,
                weirdnessRange: musicalClass.weirdnessRange,
                simultaneousnessTicks: 0,
                position: position,
                length: length,
                velocity: velocity
            )
        }

        let weirdness = melodicWeirdness(
            for: musicalClass,
            position: position
        )
        return .note(
            weirdness: weirdness,
            position: position,
            length: length,
            velocity: velocity,
            type: noteType(for: musicalClass.role)
        )
    }

    /// Deterministic per-position weirdness value for a melodic note.
    /// Previously every melody note got `weirdnessRange.lower`, which
    /// collapsed the melody to a single repeating pitch. Now we walk
    /// a fixed sequence of weirdness values spanning the class's
    /// allowed range, keyed by the marker's tick position modulo the
    /// sequence length so the same bar always plays the same melodic
    /// shape. Drums and bass keep their stable root resolution via
    /// other code paths — this only affects melody/pad/texture.
    private static func melodicWeirdness(
        for musicalClass: MusicalClass,
        position: Int
    ) -> Weirdness {
        switch musicalClass.role {
        case .melody, .pad, .texture:
            // Walk a stepped sequence inside the class's range so the
            // melody picks different scale / chord tones across
            // positions. 6-step scan covers root → 5th → 3rd → 7th →
            // 2nd → back to root territory in the safety-ordered
            // resolver tables. The step is chosen by the marker's
            // sixteenth-note index in the bar, so bar structure
            // maps directly to pitch shape.
            let lower = musicalClass.weirdnessRange.lower.value
            let upper = musicalClass.weirdnessRange.upper.value
            let span = max(0.0, upper - lower)
            guard span > 0.0001 else { return musicalClass.weirdnessRange.lower }
            let steps: [Double] = [0.00, 0.25, 0.55, 0.15, 0.80, 0.40, 0.05, 0.65]
            let sixteenthIndex = (position / (Composing.ticksPerQuarter / 4))
            let stepIdx = ((sixteenthIndex % steps.count) + steps.count) % steps.count
            let t = steps[stepIdx]
            return Weirdness(lower + span * t)
        default:
            // Bass, chords, drums, etc. stay at the safest tone —
            // the existing behavior.
            return musicalClass.weirdnessRange.lower
        }
    }

    /// Map a track role to the appropriate NoteType for pitch resolution.
    private static func noteType(for role: TrackRole) -> NoteType {
        switch role {
        case .melody:  return .mixed   // chord-aware but scale-flexible
        case .bass:    return .comp    // chord root driven
        case .chords:  return .comp    // chord tones
        case .drums:   return .rhythmic
        case .pad:     return .mixed
        case .texture: return .mixed
        }
    }

    /// MIDI channel for a track role. Drums always go on GM channel 9.
    private static func channelForRole(_ role: TrackRole) -> UInt8 {
        switch role {
        case .melody:  return 0
        case .bass:    return 1
        case .chords:  return 2
        case .drums:   return 9   // GM standard
        case .pad:     return 3
        case .texture: return 4
        }
    }

    /// Walk the HarmonicContext entries in order and build a
    /// parsimonious voicing for each chord, using VoiceLeader to
    /// minimize voice motion from the previous chord. Returns a
    /// map keyed by `entry.startTick` so the buildMP note loop
    /// can look up the voicing for the HC entry active at any tick.
    private static func precomputeChordVoicings(
        harmonicContext: HarmonicContext,
        octaveRange: ClosedRange<Int>
    ) -> [Int: [UInt8]] {
        var voicings: [Int: [UInt8]] = [:]
        var previous: [UInt8] = []
        for entry in harmonicContext.entries {
            let intervals = entry.family.intervals
            let tonicPc = Int(entry.tonic.intValue)
            let pitchClasses = intervals.map { tonicPc + $0 }
            let voicing = VoiceLeader.voicing(
                chordPitchClasses: pitchClasses,
                octaveRange: octaveRange,
                previous: previous
            )
            voicings[entry.startTick] = voicing
            previous = voicing
        }
        return voicings
    }

    /// Build a sequence of CC events shaped to the loop's phrase
    /// envelope. CC 11 (expression) crescendos and decrescendos with
    /// the density envelope so sustained voices breathe. CC 1 (mod
    /// wheel) adds a slow vibrato pulse on melodic tracks. Drums and
    /// bass get fewer CC events — they should stay tight.
    private static func buildExpressionCCs(role: TrackRole, loopLengthTicks: Int) -> [MPControlChange] {
        var ccs: [MPControlChange] = []
        let stepTicks = Composing.ticksPerBar / 2  // every half bar
        guard stepTicks > 0 else { return ccs }

        var tick = 0
        while tick < loopLengthTicks {
            let progress = Double(tick) / Double(max(1, loopLengthTicks))
            let curve = sin(.pi * max(0.0, min(1.0, progress)))

            let expressionFloor: Double
            switch role {
            case .drums, .bass: expressionFloor = 110  // mostly flat
            case .chords, .pad: expressionFloor =  88
            default:            expressionFloor =  72  // melody breathes
            }
            let expression = UInt8(max(1, min(127, Int((expressionFloor + (127.0 - expressionFloor) * curve).rounded()))))
            ccs.append(MPControlChange(positionTicks: tick, controller: 11, value: expression))

            // Mod wheel vibrato pulse on melody only — slow oscillation.
            if role == .melody {
                let vib = Int(15.0 + 15.0 * sin(2.0 * .pi * progress))
                ccs.append(MPControlChange(positionTicks: tick, controller: 1, value: UInt8(max(0, min(127, vib)))))
            }

            tick += stepTicks
        }
        return ccs
    }

    /// Apply a swing offset to a position. Shifts notes that land on
    /// an off-8th (tick % 480 == 240) by `swingTicks`. Applies to ALL
    /// roles including drums — trip-hop IS swung drums, and excluding
    /// them was producing a robotic, square feel. The DrumHumanizer
    /// adds additional per-voice micro-variation on top of the swing.
    private static func applySwing(position: Int, swingTicks: Int, role: TrackRole) -> Int {
        guard swingTicks > 0 else { return position }
        let q = Composing.ticksPerQuarter
        let e = q / 2
        let withinBeat = position % q
        if withinBeat == e {
            return position + swingTicks
        }
        return position
    }

    /// Nudge a freshly resolved melodic pitch toward a previous pitch
    /// by transposing in octaves when the interval exceeds a 5th.
    /// Keeps the line moving by small intervals instead of jumping
    /// around the scale. Does not exceed the class's octaveRange.
    private static func voiceLead(
        pitch: UInt8,
        toward previous: UInt8,
        octaveRange: ClosedRange<Int>
    ) -> UInt8 {
        var candidate = Int(pitch)
        let prevInt = Int(previous)
        let minMidi = (octaveRange.lowerBound + 1) * 12
        let maxMidi = (octaveRange.upperBound + 1) * 12 + 11
        // Shift up/down by octaves until within a 5th of previous.
        while candidate - prevInt > 7 && candidate - 12 >= minMidi {
            candidate -= 12
        }
        while prevInt - candidate > 7 && candidate + 12 <= maxMidi {
            candidate += 12
        }
        return UInt8(max(0, min(127, candidate)))
    }

    /// Shape velocity across the loop using a half-sine envelope so
    /// the phrase has breath — sparser at the edges, stronger in the
    /// middle. Drums get a tighter envelope (they should remain audible
    /// throughout); melodic tracks get a wider dynamic swing.
    private static func applyDensityEnvelope(
        velocity: UInt8,
        progress: Double,
        role: TrackRole
    ) -> UInt8 {
        // Drums are exempt. Their velocity is a direct tier selector
        // for the WeirdnessResolver, and they should keep a constant
        // rhythmic spine rather than breathing with the phrase.
        // DrumHumanizer still adds its own micro-variation later.
        if role == .drums { return velocity }

        let p = max(0.0, min(1.0, progress))
        // sin(π·p) peaks at p=0.5, zero at p=0 and p=1.
        let curve = sin(.pi * p)
        let floor: Double
        switch role {
        case .bass:           floor = 0.80
        case .chords, .pad:   floor = 0.70
        default:              floor = 0.60  // melody swells the most
        }
        let scale = floor + (1.0 - floor) * curve
        let shaped = Double(velocity) * scale
        return UInt8(max(1, min(127, Int(shaped.rounded()))))
    }

    /// Apply humanization jitter to a position. Different NoteTypes
    /// get different amounts of drift — melody gets the most
    /// (it's the foreground voice with the most expressive freedom),
    /// bass gets a small amount (breathes around the kick but stays
    /// close), drums and solo stay grid-locked (drums have their own
    /// DrumHumanizer pass; solo notes are rare).
    private static func humanizePosition(_ position: Int, type: NoteType) -> Int {
        let jitter: Int
        switch type {
        case .mixed:    jitter = Int.random(in: -10...10)  // melody — most drift
        case .comp:     jitter = Int.random(in: -6...6)    // bass/chords — subtle float
        case .solo:     jitter = Int.random(in: -4...4)    // scale solos — light
        case .rhythmic: return position                     // drums — DrumHumanizer handles this
        }
        return max(0, position + jitter)
    }

    /// Pick a sensible octave from a class's range (the middle).
    private static func middleOctave(of range: ClosedRange<Int>) -> Int {
        return (range.lowerBound + range.upperBound) / 2
    }

    /// Apply a mode's melodic-contour bias to an octave based on a
    /// note's position within the loop. Drum tracks and chord/bass
    /// (.comp) tracks never bias — only melodic notes (.mixed / .solo)
    /// get the phrase-shaped octave motion.
    private static func applyContour(
        base: Int,
        range: ClosedRange<Int>,
        contour: MelodicContour,
        type: NoteType,
        progress: Double
    ) -> Int {
        guard type == .mixed || type == .solo else { return base }
        guard contour != .neutral else { return base }

        let clampedProgress = max(0.0, min(1.0, progress))
        let shift: Int
        switch contour {
        case .ascending:
            if clampedProgress < 0.33       { shift = -1 }
            else if clampedProgress < 0.66  { shift =  0 }
            else                             { shift = +1 }
        case .descending:
            if clampedProgress < 0.33       { shift = +1 }
            else if clampedProgress < 0.66  { shift =  0 }
            else                             { shift = -1 }
        case .archUpDown:
            if clampedProgress < 0.25 || clampedProgress >= 0.75 { shift = 0 }
            else { shift = +1 }
        case .archDownUp:
            if clampedProgress < 0.25 || clampedProgress >= 0.75 { shift = 0 }
            else { shift = -1 }
        case .neutral:
            shift = 0
        }

        let target = base + shift
        return max(range.lowerBound, min(range.upperBound, target))
    }

    /// Defensive fallback when the HC has no entry for a tick (shouldn't
    /// happen in practice — the planner builds an HC that covers the
    /// whole loop). Returns C major / C major chord at tick 0.
    private static func defaultHarmonicEntry(at tick: Int) -> HarmonicContextEntry {
        return HarmonicContextEntry(
            startTick: tick,
            endTick: tick + Composing.ticksPerBar,
            tone: .C,
            scale: .major,
            tonic: .C,
            family: .major
        )
    }
}
