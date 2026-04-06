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
    /// Focus: steady root on beats 1 & 3 (stable foundation)
    /// Energize: syncopated root-5th-octave (driving forward motion)
    private func bassNoteForPattern(tonality: SessionTonality) -> UInt8 {
        // Use the chord root from the current chord progression (updated by GenerativeMIDIEngine)
        // Fall back to tonality root in octave 2
        let rootNote = currentChordRoot > 0 ? currentChordRoot : tonality.rootMIDI(octave: 2)

        // Get scale-valid notes in bass range for passing tones
        let bassNotes = tonality.validNotes(octaveRange: 1...3)
        let fifth = closestNote(to: Int(rootNote) + 7, in: bassNotes)
        let fourth = closestNote(to: Int(rootNote) + 5, in: bassNotes)
        let octaveUp = closestNote(to: Int(rootNote) + 12, in: bassNotes)

        switch tonality.mode {
        case .focus:
            // Simple root-fifth pattern. Steady, non-distracting.
            let step = patternStep % 4
            switch step {
            case 0, 2: return rootNote              // Root on beats 1 & 3
            case 1:    return fifth                  // 5th (in scale)
            case 3:    return rootNote               // Root again
            default:   return rootNote
            }

        case .energize:
            // Syncopated root-5th-octave pattern (in scale)
            let step = patternStep % 8
            switch step {
            case 0:    return rootNote               // Root (downbeat)
            case 1:    return rootNote               // Root (hold)
            case 2:    return fifth                   // 5th (in scale)
            case 3:    return octaveUp               // Octave up
            case 4:    return fifth                   // 5th
            case 5:    return rootNote               // Root
            case 6:    return fourth                  // 4th (in scale, approach)
            case 7:    return fifth                   // 5th (resolve)
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
            // Sustained notes — nearly legato, warm foundation
            return tonality.beatDuration * 1.8
        case .energize:
            // Full, resonant bass notes — NOT short clicks.
            // Duration covers most of the note interval so notes connect.
            // At 120 BPM with 8th-note pattern: beatDuration = 0.5s,
            // interval = 0.25s, so duration = 0.9 × 0.5 = 0.45s (resonant)
            return tonality.beatDuration * 0.9
        default:
            return tonality.beatDuration * 1.5
        }
    }
}
