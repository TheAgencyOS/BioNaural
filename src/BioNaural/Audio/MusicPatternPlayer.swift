// MusicPatternPlayer.swift
// BioNaural — v3 Composing Core
//
// Thin wrapper around AVAudioSequencer. Takes a MusicPattern, serializes
// it via MIDIFileBuilder, loads the bytes into a sequencer, and wires each
// track's output to the matching sampler in MultiVoiceRenderer.
//
// Playback runs on the audio thread, sample-accurate, with native looping.
// No DispatchSourceTimer, no background scheduling, no per-tick code path.

import AVFoundation
import BioNauralShared
import OSLog

public final class MusicPatternPlayer {

    // MARK: - Dependencies

    private weak var engine: AVAudioEngine?
    private weak var voices: MultiVoiceRenderer?

    // MARK: - State

    private var sequencer: AVAudioSequencer?
    private var currentPattern: MusicPattern?

    private static let logger = Logger(
        subsystem: "com.bionaural",
        category: "MusicPatternPlayer"
    )

    // MARK: - Init

    public init(engine: AVAudioEngine, voices: MultiVoiceRenderer) {
        self.engine = engine
        self.voices = voices
    }

    // MARK: - Playback

    /// Load a MusicPattern into the sequencer and start playback.
    /// Must be called after the audio engine is running and voices are ready.
    public func play(pattern: MusicPattern) throws {
        guard let engine = engine, let voices = voices else { return }

        // Stop any in-flight playback first.
        stop()

        let data = MIDIFileBuilder.build(from: pattern)
        let seq = AVAudioSequencer(audioEngine: engine)
        try seq.load(from: data, options: [])

        // Route each MusicPattern track to the corresponding sampler voice.
        // Sequencer track indexing: track 0 in the SMF is the tempo track,
        // but AVAudioSequencer's `tracks` collection skips the tempo track
        // and exposes music tracks starting at index 0.
        let lengthInBeats = Double(pattern.totalLengthTicks) / Double(pattern.ticksPerQuarter)
        for (i, mpTrack) in pattern.tracks.enumerated() where i < seq.tracks.count {
            let seqTrack = seq.tracks[i]
            seqTrack.destinationAudioUnit = sampler(for: mpTrack.role, voices: voices)
            seqTrack.loopRange = AVBeatRange(start: 0, length: lengthInBeats)
            seqTrack.isLoopingEnabled = true
        }

        try seq.start()

        self.sequencer = seq
        self.currentPattern = pattern

        Self.logger.info("MusicPatternPlayer started — \(pattern.tracks.count) tracks, \(pattern.totalLengthTicks) ticks @ \(pattern.tempoBPM) BPM")
    }

    /// Stop playback and release the sequencer. All active notes are cut.
    public func stop() {
        if let seq = sequencer, seq.isPlaying {
            seq.stop()
        }
        sequencer = nil
        voices?.allNotesOff()
    }

    public var isPlaying: Bool {
        sequencer?.isPlaying ?? false
    }

    // MARK: - Helpers

    private func sampler(for role: TrackRole, voices: MultiVoiceRenderer) -> AVAudioUnit? {
        switch role {
        case .melody, .pad, .texture, .chords:
            return voices.melody.sampler
        case .bass:
            return voices.bass.sampler
        case .drums:
            return voices.drums.sampler
        }
    }
}
