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

    /// Mode-specific bass patterns.
    /// Focus: steady root on beats 1 & 3 (stable foundation)
    /// Energize: syncopated root-5th-octave (driving forward motion)
    private func bassNoteForPattern(tonality: SessionTonality) -> UInt8 {
        // Bass octave: 1-2 (low register)
        let bassOctave = 2
        let rootNote = tonality.rootMIDI(octave: bassOctave)

        switch tonality.mode {
        case .focus:
            // Simple root-root pattern. Occasionally add the 5th.
            let step = patternStep % 4
            switch step {
            case 0, 2: return rootNote              // Root on beats 1 & 3
            case 1:    return rootNote + 7           // 5th (passing tone)
            case 3:    return rootNote               // Root again
            default:   return rootNote
            }

        case .energize:
            // Syncopated root-5th-octave-5th pattern
            let step = patternStep % 8
            switch step {
            case 0:    return rootNote               // Root (downbeat)
            case 1:    return rootNote               // Root (hold)
            case 2:    return rootNote + 7           // 5th
            case 3:    return rootNote + 12          // Octave up
            case 4:    return rootNote + 7           // 5th
            case 5:    return rootNote               // Root
            case 6:    return rootNote + 5           // 4th (chromatic approach)
            case 7:    return rootNote + 7           // 5th (resolve up)
            default:   return rootNote
            }

        default:
            // Sleep/Relaxation shouldn't reach here (guard in start)
            return rootNote
        }
    }

    private func bassNoteInterval(tonality: SessionTonality) -> TimeInterval {
        switch tonality.mode {
        case .focus:
            // Half notes (beats 1 & 3) at session tempo
            return tonality.beatDuration * 2.0
        case .energize:
            // Eighth notes for syncopated feel
            return tonality.beatDuration * 0.5
        default:
            return tonality.beatDuration
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
            // Sustained notes (nearly legato)
            return tonality.beatDuration * 1.8
        case .energize:
            // Shorter, punchy notes
            return tonality.beatDuration * 0.4
        default:
            return tonality.beatDuration
        }
    }
}
