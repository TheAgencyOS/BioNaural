// MIDIFileBuilder.swift
// BioNaural — v3 Composing Core
//
// Serializes a MusicPattern into a Standard MIDI File (SMF Type 1)
// in memory. The resulting Data is fed directly to AVAudioSequencer,
// which plays it sample-accurately on the audio thread.
//
// Format:
//   MThd header (PPQN from pattern)
//   MTrk 0: tempo meta only
//   MTrk 1..N: one per MPTrack (program change + note events)
//
// All multi-byte values are big-endian. Delta times use VLQ encoding.

import Foundation
import BioNauralShared

public enum MIDIFileBuilder {

    public static func build(from pattern: MusicPattern) -> Data {
        var data = Data()
        let numTracks = UInt16(1 + pattern.tracks.count)

        // --- MThd header chunk ---
        data.append("MThd".data(using: .ascii)!)
        data.append(uint32BE(6))              // header length
        data.append(uint16BE(1))              // format 1 (multi-track)
        data.append(uint16BE(numTracks))
        data.append(uint16BE(UInt16(pattern.ticksPerQuarter)))

        // --- Track 0: tempo ---
        data.append(buildTempoTrack(bpm: pattern.tempoBPM))

        // --- Music tracks ---
        for track in pattern.tracks {
            data.append(buildMusicTrack(track))
        }

        return data
    }

    // MARK: - Tempo track

    private static func buildTempoTrack(bpm: Double) -> Data {
        var body = Data()
        let usPerQuarter = UInt32(60_000_000.0 / bpm)

        // Delta 0, FF 51 03, 3 bytes of microseconds per quarter
        body.append(vlq(0))
        body.append(contentsOf: [0xFF, 0x51, 0x03])
        body.append(UInt8((usPerQuarter >> 16) & 0xFF))
        body.append(UInt8((usPerQuarter >> 8) & 0xFF))
        body.append(UInt8(usPerQuarter & 0xFF))

        // End of track: delta 0, FF 2F 00
        body.append(vlq(0))
        body.append(contentsOf: [0xFF, 0x2F, 0x00])

        return wrapTrackChunk(body)
    }

    // MARK: - Music track

    private static func buildMusicTrack(_ track: MPTrack) -> Data {
        var body = Data()
        let channel = track.channel & 0x0F

        // Program change at delta 0: Cn pp
        body.append(vlq(0))
        body.append(0xC0 | channel)
        body.append(track.gmProgram & 0x7F)

        // Build combined event list: note-on + note-off, sorted by tick.
        // note-offs sort BEFORE note-ons at the same tick to avoid
        // cutting off notes that start on the same tick.
        struct Event {
            let tick: Int
            let kind: Int  // 0 = off, 1 = on
            let pitch: UInt8
            let velocity: UInt8
        }
        var events: [Event] = []
        events.reserveCapacity(track.notes.count * 2)
        for n in track.notes {
            let off = max(n.positionTicks + 1, n.positionTicks + n.lengthTicks)
            events.append(Event(tick: n.positionTicks, kind: 1, pitch: n.pitch, velocity: n.velocity))
            events.append(Event(tick: off, kind: 0, pitch: n.pitch, velocity: 0))
        }
        events.sort { a, b in
            if a.tick != b.tick { return a.tick < b.tick }
            return a.kind < b.kind
        }

        var lastTick = 0
        for e in events {
            let delta = max(0, e.tick - lastTick)
            body.append(vlq(UInt32(delta)))
            if e.kind == 1 {
                body.append(0x90 | channel)
                body.append(e.pitch & 0x7F)
                body.append(max(1, e.velocity) & 0x7F)
            } else {
                body.append(0x80 | channel)
                body.append(e.pitch & 0x7F)
                body.append(0x00)
            }
            lastTick = e.tick
        }

        // End of track
        body.append(vlq(0))
        body.append(contentsOf: [0xFF, 0x2F, 0x00])

        return wrapTrackChunk(body)
    }

    // MARK: - Chunk framing

    private static func wrapTrackChunk(_ body: Data) -> Data {
        var chunk = Data()
        chunk.append("MTrk".data(using: .ascii)!)
        chunk.append(uint32BE(UInt32(body.count)))
        chunk.append(body)
        return chunk
    }

    // MARK: - Encoders

    private static func uint16BE(_ v: UInt16) -> Data {
        return Data([UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }

    private static func uint32BE(_ v: UInt32) -> Data {
        return Data([
            UInt8((v >> 24) & 0xFF),
            UInt8((v >> 16) & 0xFF),
            UInt8((v >> 8) & 0xFF),
            UInt8(v & 0xFF)
        ])
    }

    /// Variable-length quantity — MIDI's 7-bit-per-byte delta encoding.
    private static func vlq(_ value: UInt32) -> Data {
        var buffer: [UInt8] = [UInt8(value & 0x7F)]
        var v = value >> 7
        while v > 0 {
            buffer.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }
        return Data(buffer)
    }
}
