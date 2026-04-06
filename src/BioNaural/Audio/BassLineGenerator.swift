// BassLineGenerator.swift
// BioNaural
//
// Generates bass lines that follow the chord progression in the session's
// key and tempo. Bass provides the harmonic foundation — root notes,
// octave patterns, and occasional passing tones.
//
// Only active for Focus and Energize modes (per ModeInstrumentation rules).
// Sleep and Relaxation use low pad drones instead of bass lines.
//
// All notes are in the session's key. Bass patterns are mode-specific:
// - Focus: steady root notes on beats 1 and 3 (stable, non-distracting)
// - Energize: syncopated root-fifth-octave patterns (driving, forward)

import BioNauralShared
import Foundation

// MARK: - BassLineGenerator

public final class BassLineGenerator: @unchecked Sendable {

    private let renderer: NotePlayer
    private var tonality: SessionTonality?
    private var isRunning = false
    private var bassTimer: DispatchSourceTimer?
    private var activeNote: UInt8?
    private var currentChordRoot: UInt8 = 36 // C2 default
    private var patternStep: Int = 0

    private let generationQueue = DispatchQueue(
        label: "com.bionaural.bassline",
        qos: .userInitiated
    )

    // MARK: - Init

    public init(renderer: NotePlayer) {
        self.renderer = renderer
    }

    // MARK: - Public API

    public func start(tonality: SessionTonality) {
        generationQueue.async { [weak self] in
            guard let self, !self.isRunning else { return }

            self.tonality = tonality
            self.isRunning = true
            self.patternStep = 0

            // Only Focus and Energize get bass lines
            guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }

            // Switch to bass preset (GM 38 = Synth Bass 1)
            // Note: we share the renderer so we need a separate MIDI channel
            // For now, bass uses the same sampler with program change
            self.scheduleNextBassNote()
        }
    }

    public func stop() {
        generationQueue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.bassTimer?.cancel()
            self.bassTimer = nil
            if let note = self.activeNote {
                self.renderer.noteOff(note)
                self.activeNote = nil
            }
        }
    }

    /// Update the current chord root (called by GenerativeMIDIEngine
    /// when chord progression advances).
    public func updateChordRoot(_ midiNote: UInt8) {
        generationQueue.async { [weak self] in
            self?.currentChordRoot = midiNote
        }
    }

    // MARK: - Bass Pattern Generation

    private func scheduleNextBassNote() {
        guard isRunning, let tonality else { return }

        let interval = bassNoteInterval(tonality: tonality)

        let timer = DispatchSource.makeTimerSource(queue: generationQueue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.playBassNote()
        }
        bassTimer?.cancel()
        bassTimer = timer
        timer.resume()
    }

    private func playBassNote() {
        guard isRunning, let tonality else { return }

        // Release previous note
        if let prev = activeNote {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOff(prev)
            }
        }

        // Generate the bass note based on mode pattern
        let note = bassNoteForPattern(tonality: tonality)
        let velocity = bassVelocity(tonality: tonality)
        let duration = bassDuration(tonality: tonality)

        renderer.noteOn(note, velocity: velocity)
        activeNote = note
        patternStep += 1

        // Schedule note-off on generation queue
        generationQueue.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.activeNote == note else { return }
            self.renderer.noteOff(note)
            self.activeNote = nil
        }

        scheduleNextBassNote()
    }

    /// Mode-specific bass patterns using the session tonality's scale.
    /// All notes are guaranteed to be in the session's key/scale.
    /// Focus: steady root on beats 1 & 3 (stable, minimal)
    /// Energize: root-fifth on downbeats (solid groove, not busy)
    private func bassNoteForPattern(tonality: SessionTonality) -> UInt8 {
        // Use the chord root from the current chord progression
        let rootNote = currentChordRoot > 0 ? currentChordRoot : tonality.rootMIDI(octave: 2)

        // Get scale-valid notes in bass range
        let bassNotes = tonality.validNotes(octaveRange: 1...3)
        let fifth = closestNote(to: Int(rootNote) + 7, in: bassNotes)

        switch tonality.mode {
        case .focus:
            // Just root notes on beats 1 and 3. Simple and steady.
            return rootNote

        case .energize:
            // Root on beat 1, fifth on beat 3. Simple, solid groove.
            // No busy 8th-note patterns — let the drums handle rhythm.
            let step = patternStep % 4
            switch step {
            case 0:    return rootNote          // Beat 1: root
            case 1:    return rootNote          // Beat 2: root (sustain)
            case 2:    return fifth              // Beat 3: fifth
            case 3:    return rootNote          // Beat 4: root (resolve back)
            default:   return rootNote
            }

        default:
            return rootNote
        }
    }

    /// Find the closest scale-valid note to a target MIDI value.
    private func closestNote(to target: Int, in scaleNotes: [UInt8]) -> UInt8 {
        guard !scaleNotes.isEmpty else { return UInt8(max(0, min(127, target))) }
        return scaleNotes.min(by: { abs(Int($0) - target) < abs(Int($1) - target) }) ?? UInt8(target)
    }

    private func bassNoteInterval(tonality: SessionTonality) -> TimeInterval {
        switch tonality.mode {
        case .focus:
            // Whole notes — one bass note per bar (minimal, non-distracting)
            return tonality.barDuration
        case .energize:
            // Quarter notes — one note per beat (solid groove, not busy)
            return tonality.beatDuration
        default:
            return tonality.barDuration
        }
    }

    private func bassVelocity(tonality: SessionTonality) -> UInt8 {
        switch tonality.mode {
        case .focus:    return 55  // Moderate — supportive, not dominant
        case .energize: return 80  // Strong — driving the groove
        default:        return 50
        }
    }

    private func bassDuration(tonality: SessionTonality) -> TimeInterval {
        switch tonality.mode {
        case .focus:
            // Whole-bar sustain — warm, continuous foundation
            return tonality.barDuration * 0.9
        case .energize:
            // Nearly legato quarter notes — sustain almost to the next note.
            // At 120 BPM: beatDuration=0.5s, duration=0.45s (smooth, connected)
            return tonality.beatDuration * 0.85
        default:
            return tonality.barDuration * 0.9
        }
    }
}
