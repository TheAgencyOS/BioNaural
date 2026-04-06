// SessionTonality.swift
// BioNaural
//
// Master key, scale, and tempo for a session. ALL audio layers must
// reference this single source of truth to ensure harmonic coherence:
//
// - BinauralBeatNode: carrier frequency tuned to a harmonic of the root
// - GenerativeMIDIEngine: melody, chords, bass, drums all in same key/tempo
// - MelodicLayer: file selection filtered by key compatibility
// - AmbienceLayer: pitched ambient beds transposed to match (when applicable)
//
// The tonality is set once at session start and remains stable throughout
// (stability aids entrainment and habituation). Biometric adaptation changes
// beat frequency, stem volumes, and density — NOT key or tempo.

import BioNauralShared
import Foundation
@preconcurrency import Tonic

// MARK: - SessionTonality

/// Immutable tonality context for a session. Created at session start,
/// shared across all audio layers.
public struct SessionTonality: Sendable {

    /// The root note (e.g., C, F, G, D).
    public let root: NoteClass

    /// The scale type (e.g., pentatonic major, Lydian, major).
    public let scale: Scale

    /// The full Tonic Key (root + scale).
    public let key: Key

    /// Tempo in BPM. Determines note spacing, drum patterns, bass rhythm.
    public let tempo: Double

    /// The root frequency in Hz (for carrier frequency alignment).
    /// Computed as the nearest harmonic of the root note to the mode's
    /// default carrier frequency.
    public let rootFrequencyHz: Double

    /// Carrier frequency aligned to a harmonic of the root note.
    /// This ensures the binaural beat carrier doesn't clash with the
    /// musical key. The carrier is the nearest octave/harmonic of the
    /// root that falls within the mode's carrier range.
    public let alignedCarrierFrequency: Double

    /// The mode this tonality was created for.
    public let mode: FocusMode

    // MARK: - Init

    /// Create a session tonality from a mode and biometric state.
    public init(mode: FocusMode, biometricState: BiometricState = .calm) {
        self.mode = mode
        self.root = ScaleMapper.rootNote(for: mode)
        self.scale = ScaleMapper.scale(for: mode, biometricState: biometricState)
        self.key = Key(root: root, scale: scale)
        self.tempo = Self.defaultTempo(for: mode)

        // Compute root frequency (A4 = 440 Hz standard)
        // NoteClass.intValue gives semitones from C: C=0, D=2, F=5, G=7
        let rootMidi = Double(root.intValue) + 60.0 // Middle octave (C4 = 60)
        self.rootFrequencyHz = 440.0 * pow(2.0, (rootMidi - 69.0) / 12.0)

        // Align carrier to nearest octave of root within the mode's range
        self.alignedCarrierFrequency = Self.alignCarrier(
            rootHz: self.rootFrequencyHz,
            modeCarrier: mode.defaultCarrierFrequency
        )
    }

    // MARK: - Tempo Defaults

    /// Mode-specific default tempo (BPM) from FunctionalMusicTheory.md.
    private static func defaultTempo(for mode: FocusMode) -> Double {
        switch mode {
        case .sleep:       return 50.0   // Very slow, decelerating feel
        case .relaxation:  return 60.0   // Resting heart rate zone
        case .focus:       return 72.0   // Steady working pace
        case .energize:    return 120.0  // Active/workout cadence
        }
    }

    // MARK: - Carrier Alignment

    /// Find the nearest octave of `rootHz` that falls close to `modeCarrier`.
    /// This ensures the binaural carrier is harmonically related to the music.
    ///
    /// Example: If root = F (174.6 Hz) and mode carrier = 150 Hz,
    /// the aligned carrier would be 174.6 Hz (F3) — the nearest F octave.
    private static func alignCarrier(rootHz: Double, modeCarrier: Double) -> Double {
        // Generate octaves of the root from 50 Hz to 800 Hz
        var candidates: [Double] = []
        var freq = rootHz
        // Go down to find lowest octave above 50 Hz
        while freq > 50.0 { freq /= 2.0 }
        // Now go up collecting candidates
        while freq < 800.0 {
            freq *= 2.0
            if freq >= 80.0 && freq <= 700.0 {
                candidates.append(freq)
            }
        }

        // Also add the 5th (perfect fifth = 3:2 ratio) as a candidate
        for oct in candidates {
            let fifth = oct * 1.5
            if fifth >= 80.0 && fifth <= 700.0 {
                candidates.append(fifth)
            }
        }

        // Pick the candidate nearest to the mode's default carrier
        guard let best = candidates.min(by: {
            abs($0 - modeCarrier) < abs($1 - modeCarrier)
        }) else {
            return modeCarrier // Fallback to default
        }

        return best
    }

    // MARK: - Beat Duration

    /// Duration of one beat in seconds (derived from tempo).
    public var beatDuration: TimeInterval {
        60.0 / tempo
    }

    /// Duration of one bar (4 beats) in seconds.
    public var barDuration: TimeInterval {
        beatDuration * 4.0
    }

    // MARK: - MIDI Note Helpers

    /// Returns the root MIDI note number at the given octave.
    public func rootMIDI(octave: Int) -> UInt8 {
        let midi = root.intValue + (octave * 12)
        return UInt8(max(0, min(127, midi)))
    }

    /// Returns scale-valid MIDI notes within the given range.
    public func validNotes(octaveRange: ClosedRange<Int>) -> [UInt8] {
        key.noteSet.array.flatMap { note -> [UInt8] in
            octaveRange.compactMap { octave -> UInt8? in
                let midi = Int(note.intValue) + (octave * 12)
                guard midi >= 0, midi <= 127 else { return nil }
                return UInt8(midi)
            }
        }.sorted()
    }
}
