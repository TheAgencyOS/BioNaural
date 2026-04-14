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
        musicalClass: MusicalClass
    ) -> RealPattern {
        var notes: [RPNote] = []

        for event in vp.events {
            switch event {

            case .note(let weirdness, let position, let length, let velocity, let type):
                let jittered = humanizePosition(position, type: type)
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
        loopLengthTicks: Int
    ) -> MusicPattern {
        var mpTracks: [MPTrack] = []

        for trackInput in tracks {
            let rp = trackInput.rp
            let mclass = trackInput.musicalClass
            let octave = middleOctave(of: mclass.octaveRange)
            var notes: [MPNote] = []

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

                    let pitch = WeirdnessResolver.resolve(
                        weirdness: rpNote.weirdness,
                        type: rpNote.type,
                        velocity: rpNote.velocity,
                        hc: hcEntry,
                        octave: octave
                    )

                    // Trim length so the note doesn't extend past the loop.
                    let maxLength = loopLengthTicks - absoluteTick
                    let length = min(rpNote.lengthTicks, maxLength)

                    notes.append(MPNote(
                        pitch: pitch,
                        velocity: rpNote.velocity,
                        positionTicks: absoluteTick,
                        lengthTicks: length
                    ))
                }
                tileOffset += max(1, rp.lengthTicks)
            }

            let channel: UInt8 = (rp.role == .drums) ? 9 : channelForRole(rp.role)
            mpTracks.append(MPTrack(
                role: rp.role,
                gmProgram: trackInput.gmProgram,
                channel: channel,
                notes: notes
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
    /// Phase 4 keeps it simple: chord tracks emit `.chord`, drum tracks
    /// emit `.note(.rhythmic)`, everything else emits `.note(.mixed)` or
    /// `.note(.comp)` based on role.
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

        let weirdness = musicalClass.weirdnessRange.lower
        return .note(
            weirdness: weirdness,
            position: position,
            length: length,
            velocity: velocity,
            type: noteType(for: musicalClass.role)
        )
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

    /// Apply small humanization jitter to a position. Only melodic
    /// `.mixed` notes wobble — bass and chord tones (`.comp`), scale
    /// solos (`.solo`), and drums (`.rhythmic`) stay locked to the grid
    /// so all tracks share phase with the drum clock.
    private static func humanizePosition(_ position: Int, type: NoteType) -> Int {
        guard type == .mixed else { return position }
        let jitter = Int.random(in: -5...5)
        return max(0, position + jitter)
    }

    /// Pick a sensible octave from a class's range (the middle).
    private static func middleOctave(of range: ClosedRange<Int>) -> Int {
        return (range.lowerBound + range.upperBound) / 2
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
