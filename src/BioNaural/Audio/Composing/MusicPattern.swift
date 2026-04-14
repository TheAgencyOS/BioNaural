// MusicPattern.swift
// BioNaural — v3 Composing Core
//
// A Music Pattern (MP) is the FINAL MIDI sequence — actual pitches,
// actual velocities, actual timings, multiple tracks. It is built by
// applying the Harmonic Context to each track's Real Pattern.
//
// The MP is what gets serialized to a Standard MIDI File and handed
// to AVAudioSequencer for playback. Once we have an MP, no more
// musical decisions are made — Apple's sequencer just plays it.
//
// NWL spec 3.6.4.

import Foundation

// MARK: - MPNote

/// A fully-resolved MIDI note in a Music Pattern. Has a concrete
/// pitch, velocity, position, and length. Ready for playback.
public struct MPNote: Hashable, Sendable {

    /// MIDI note number (0-127). Already resolved from Weirdness +
    /// Harmonic Context.
    public let pitch: UInt8

    /// MIDI velocity (1-127).
    public let velocity: UInt8

    /// Absolute tick position from the start of the Music Pattern.
    public let positionTicks: Int

    /// Note length in ticks.
    public let lengthTicks: Int

    public init(
        pitch: UInt8,
        velocity: UInt8,
        positionTicks: Int,
        lengthTicks: Int
    ) {
        self.pitch = pitch
        self.velocity = max(1, min(127, velocity))
        self.positionTicks = positionTicks
        self.lengthTicks = lengthTicks
    }
}

// MARK: - MPTrack

/// A single CC (Control Change) event — used for expression swells,
/// modulation wheel vibrato, brightness changes, etc.
public struct MPControlChange: Hashable, Sendable {
    public let positionTicks: Int
    public let controller: UInt8
    public let value: UInt8

    public init(positionTicks: Int, controller: UInt8, value: UInt8) {
        self.positionTicks = positionTicks
        self.controller = controller
        self.value = value
    }
}

/// A single track in a Music Pattern.
public struct MPTrack: Hashable, Sendable {

    /// The track role (melody, bass, drums, chords).
    public let role: TrackRole

    /// The General MIDI program number (instrument) for this track.
    public let gmProgram: UInt8

    /// The MIDI channel (0-15). Drums always go on channel 9 (GM standard).
    public let channel: UInt8

    /// The notes in this track, sorted by position.
    public let notes: [MPNote]

    /// Continuous-controller events interleaved with the notes.
    /// Serialized into the track chunk alongside note events.
    public let controlChanges: [MPControlChange]

    public init(
        role: TrackRole,
        gmProgram: UInt8,
        channel: UInt8,
        notes: [MPNote],
        controlChanges: [MPControlChange] = []
    ) {
        self.role = role
        self.gmProgram = gmProgram
        self.channel = channel
        self.notes = notes.sorted { $0.positionTicks < $1.positionTicks }
        self.controlChanges = controlChanges.sorted { $0.positionTicks < $1.positionTicks }
    }
}

// MARK: - MusicPattern

/// A complete Music Pattern: all tracks, all notes, ready to play.
public struct MusicPattern: Hashable, Sendable {

    /// Total length of the pattern in MIDI ticks.
    public let totalLengthTicks: Int

    /// Tempo in BPM. Used when building the Standard MIDI File.
    public let tempoBPM: Double

    /// PPQN (ticks per quarter). Always Composing.ticksPerQuarter (480).
    public let ticksPerQuarter: Int

    /// All tracks in the pattern.
    public let tracks: [MPTrack]

    public init(
        totalLengthTicks: Int,
        tempoBPM: Double,
        ticksPerQuarter: Int = Composing.ticksPerQuarter,
        tracks: [MPTrack]
    ) {
        self.totalLengthTicks = totalLengthTicks
        self.tempoBPM = tempoBPM
        self.ticksPerQuarter = ticksPerQuarter
        self.tracks = tracks
    }

    /// Total length in seconds at the configured tempo.
    public var totalLengthSeconds: Double {
        let secondsPerTick = (60.0 / tempoBPM) / Double(ticksPerQuarter)
        return Double(totalLengthTicks) * secondsPerTick
    }

    /// Look up a track by role.
    public func track(role: TrackRole) -> MPTrack? {
        tracks.first { $0.role == role }
    }
}
