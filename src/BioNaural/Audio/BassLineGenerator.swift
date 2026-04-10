// BassLineGenerator.swift
// BioNaural
//
// Generates bass lines following the chord progression in the session key.
// Only active for Focus and Energize modes.
//
// v2: No internal timer. Called via tick() from GenerativeMIDIEngine's
// master clock. All renderer calls happen directly — NO main thread
// dispatch (matches MIDISequencePlayer's proven pattern).

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
    private var stepCount: Int = 0

    // MARK: - Init

    public init(renderer: NotePlayer) {
        self.renderer = renderer
    }

    // MARK: - Public API

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
            renderer.noteOff(note)
            activeNote = nil
        }
    }

    public func updateChordRoot(_ midiNote: UInt8) {
        currentChordRoot = midiNote
    }

    /// Called by master clock at 16th-note resolution.
    public func tick(stepInBar: Int) {
        guard isRunning, let tonality else { return }

        switch mode {
        case .focus:    tickFocus(stepInBar: stepInBar, tonality: tonality)
        case .energize: tickEnergize(stepInBar: stepInBar, tonality: tonality)
        default:        break
        }

        stepCount += 1
    }

    // MARK: - Focus Bass

    private func tickFocus(stepInBar: Int, tonality: SessionTonality) {
        if stepInBar == 0 {
            releaseActive()
            let note = clampBass(currentChordRoot)
            renderer.noteOn(note, velocity: 55)
            activeNote = note
        }
        if stepInBar == 15 {
            releaseActive()
        }
    }

    // MARK: - Energize Bass

    private func tickEnergize(stepInBar: Int, tonality: SessionTonality) {
        let bassNotes = tonality.validNotes(octaveRange: 1...3)
        let root = clampBass(currentChordRoot)
        let fifth = closestNote(to: Int(root) + 7, in: bassNotes)

        guard stepInBar % 4 == 0 else { return }

        releaseActive()

        let beat = stepInBar / 4
        let note: UInt8
        switch beat {
        case 0: note = root
        case 1: note = root
        case 2: note = fifth
        case 3: note = root
        default: note = root
        }

        renderer.noteOn(note, velocity: 80)
        activeNote = note
    }

    // MARK: - Helpers

    private func releaseActive() {
        if let note = activeNote {
            renderer.noteOff(note)
            activeNote = nil
        }
    }

    private func clampBass(_ note: UInt8) -> UInt8 {
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
