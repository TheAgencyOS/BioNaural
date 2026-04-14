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

public final class MusicPatternPlayer: @unchecked Sendable {

    // MARK: - Dependencies

    private weak var engine: AVAudioEngine?
    private weak var voices: MultiVoiceRenderer?

    // MARK: - State

    private var sequencer: AVAudioSequencer?
    private var currentPattern: MusicPattern?

    /// A swap queued by `crossfadeTo` that will fire at the next bar
    /// boundary. Only one swap can be pending at a time — a new request
    /// supersedes the previous one.
    private var pendingSwap: DispatchWorkItem?

    /// Master submixer volume target to restore after a crossfade swap.
    /// Captured when the fade starts so we can restore any user mix.
    private var preFadeMasterVolume: Float = 1.0

    /// Length of the crossfade ramp at each end of a swap.
    private static let fadeDuration: TimeInterval = 0.15

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

    /// Schedule a crossfade swap to a new pattern at the next bar boundary.
    /// Fades the master submixer down, stops the old sequencer, loads the
    /// new pattern, restarts, and fades back up. Supersedes any pending
    /// swap. Falls back to an immediate `play` if nothing is running yet.
    public func crossfadeTo(pattern: MusicPattern) {
        guard let seq = sequencer, seq.isPlaying else {
            try? play(pattern: pattern)
            return
        }

        pendingSwap?.cancel()

        let delay = secondsUntilNextBar(sequencer: seq, tempoBPM: pattern.tempoBPM)
        let work = DispatchWorkItem { [weak self] in
            self?.performCrossfade(to: pattern)
        }
        pendingSwap = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performCrossfade(to pattern: MusicPattern) {
        guard let voices = voices else { return }
        let restoreVolume = voices.masterSubmixer.volume
        preFadeMasterVolume = restoreVolume

        Task { @MainActor in
            await self.rampMasterVolume(from: restoreVolume, to: 0.0, duration: Self.fadeDuration)
            do {
                try self.play(pattern: pattern)
                await self.rampMasterVolume(from: 0.0, to: restoreVolume, duration: Self.fadeDuration)
            } catch {
                Self.logger.error("crossfade swap failed: \(error.localizedDescription)")
                self.voices?.masterSubmixer.volume = restoreVolume
            }
        }
    }

    /// Seconds from now until the next downbeat (bar boundary) in the
    /// currently running sequencer. Uses `currentPositionInBeats` and the
    /// pattern's tempo — 4 beats per bar.
    private func secondsUntilNextBar(sequencer: AVAudioSequencer, tempoBPM: Double) -> TimeInterval {
        let beatsPerBar: Double = 4
        let current = sequencer.currentPositionInBeats
        let nextBar = (floor(current / beatsPerBar) + 1) * beatsPerBar
        let beatsRemaining = max(0.0, nextBar - current)
        let secondsPerBeat = 60.0 / max(1.0, tempoBPM)
        return beatsRemaining * secondsPerBeat
    }

    /// Ramp the master submixer volume from `start` to `target` over
    /// `duration`. @MainActor so it can touch the audio graph directly
    /// without Sendable hops. Uses `Task.sleep` between steps; the total
    /// fade is a handful of main-thread hops, which AVAudioMixerNode
    /// smooths internally.
    @MainActor
    private func rampMasterVolume(
        from start: Float,
        to target: Float,
        duration: TimeInterval
    ) async {
        let steps = 8
        let stepNanos = UInt64((duration / Double(steps)) * 1_000_000_000)
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: stepNanos)
            let t = Float(i) / Float(steps)
            let value = start + (target - start) * t
            voices?.masterSubmixer.volume = value
        }
    }

    /// Stop playback and release the sequencer. All active notes are cut.
    public func stop() {
        pendingSwap?.cancel()
        pendingSwap = nil
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
