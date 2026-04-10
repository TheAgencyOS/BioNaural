// BassLineGenerator.swift
// BioNaural
//
// Generates bass lines following the chord progression in the session key.
// Only active for Focus and Energize modes.
//
// v2: No internal timer. The master clock in GenerativeMIDIEngine calls
// tick() at 16th-note resolution. All tracks share one clock — zero drift.

import BioNauralShared
import Foundation

// MARK: - BassLineGenerator

public final class BassLineGenerator: @unchecked Sendable {

    private let renderer: NotePlayer
    private var mode: FocusMode = .focus
    private var isRunning = false
    private var activeNote: UInt8?
    private var currentChordRoot: UInt8 = 36
    private var tonality: SessionTonality?
    private var stepCount: Int = 0  // total 16th-note steps

    // MARK: - Init

    public init(renderer: NotePlayer) {
        self.renderer = renderer
    }

    // MARK: - Public API

    /// Prepare bass generator (no timer — master clock calls tick).
    public func start(tonality: SessionTonality) {
        guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }
        self.tonality = tonality
        self.mode = tonality.mode
        self.isRunning = true
        self.stepCount = 0
        self.activeNote = nil
        self.currentChordRoot = tonality.rootMIDI(octave: 2)
    }

    public func stop() {
        isRunning = false
        if let note = activeNote {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOff(note)
            }
            activeNote = nil
        }
    }

    /// Update chord root (called by GenerativeMIDIEngine on chord changes).
    public func updateChordRoot(_ midiNote: UInt8) {
        currentChordRoot = midiNote
    }

    /// Called by GenerativeMIDIEngine's master clock at 16th-note resolution.
    /// stepInBar: 0-15 (position within the current bar).
    /// NOTE: This runs on generationQueue. All renderer calls MUST
    /// dispatch to main thread (AVAudioUnitSampler is not thread-safe).
    public func tick(stepInBar: Int) {
        guard isRunning, let tonality else { return }

        switch mode {
        case .focus:
            tickFocus(stepInBar: stepInBar, tonality: tonality)
        case .energize:
            tickEnergize(stepInBar: stepInBar, tonality: tonality)
        default:
            break
        }

        stepCount += 1
    }

    // MARK: - Focus Bass (whole notes — root on beat 1)

    private func tickFocus(stepInBar: Int, tonality: SessionTonality) {
        // Play root on beat 1 only, sustain for entire bar
        if stepInBar == 0 {
            releaseActive()
            let note = clampBass(currentChordRoot)
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOn(note, velocity: 55)
            }
            activeNote = note
        }
        // Release at end of bar (step 15) to prepare for next bar
        if stepInBar == 15 {
            releaseActive()
        }
    }

    // MARK: - Energize Bass (quarter notes — root/5th locked to kick)

    private func tickEnergize(stepInBar: Int, tonality: SessionTonality) {
        let bassNotes = tonality.validNotes(octaveRange: 1...3)
        let root = clampBass(currentChordRoot)
        let fifth = closestNote(to: Int(root) + 7, in: bassNotes)

        // Quarter notes = beats 1, 2, 3, 4 = steps 0, 4, 8, 12
        guard stepInBar % 4 == 0 else { return }

        releaseActive()

        let beat = stepInBar / 4  // 0, 1, 2, 3

        let note: UInt8
        switch beat {
        case 0: note = root          // Beat 1: root (with kick)
        case 1: note = root          // Beat 2: root
        case 2: note = fifth         // Beat 3: fifth (with kick)
        case 3: note = root          // Beat 4: root
        default: note = root
        }

        DispatchQueue.main.async { [weak self] in
            self?.renderer.noteOn(note, velocity: 80)
        }
        activeNote = note
    }

    // MARK: - Helpers

    private func releaseActive() {
        if let note = activeNote {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOff(note)
            }
            activeNote = nil
        }
    }

    private func clampBass(_ note: UInt8) -> UInt8 {
        // Keep bass in range MIDI 28-55 (E1 to G3)
        var n = note
        while n > 55 { n -= 12 }
        while n < 28 { n += 12 }
        return n
    }

    private func closestNote(to target: Int, in scaleNotes: [UInt8]) -> UInt8 {
        guard !scaleNotes.isEmpty else { return UInt8(max(0, min(127, target))) }
        return scaleNotes.min(by: { abs(Int($0) - target) < abs(Int($1) - target) }) ?? UInt8(target)
    }
}
