// DrumPatternGenerator.swift
// BioNaural
//
// Generates rhythmic drum/percussion patterns locked to the session tempo.
// Uses GM drum map (channel 10) MIDI notes for the SoundFont renderer.
//
// v2: No internal timer. Called via tick() from GenerativeMIDIEngine's
// master clock. Note-offs tracked inline (no asyncAfter backlog).
// All renderer calls happen directly — NO main thread dispatch.

import BioNauralShared
import Foundation

// MARK: - GM Drum Map (Standard)

public enum GMDrum {
    static let kick: UInt8          = 36
    static let sideStick: UInt8     = 37
    static let snare: UInt8         = 38
    static let clap: UInt8          = 39
    static let closedHiHat: UInt8   = 42
    static let openHiHat: UInt8     = 46
    static let pedalHiHat: UInt8    = 44
    static let lowTom: UInt8        = 41
    static let midTom: UInt8        = 47
    static let highTom: UInt8       = 50
    static let crash: UInt8         = 49
    static let ride: UInt8          = 51
    static let rideBell: UInt8      = 53
    static let tambourine: UInt8    = 54
    static let cowbell: UInt8       = 56
    static let shaker: UInt8        = 70
    static let cabasa: UInt8        = 69
    static let guiro: UInt8         = 73
    static let claves: UInt8        = 75
    static let woodBlock: UInt8     = 76
    static let triangle: UInt8      = 81
}

// MARK: - DrumPatternGenerator

public final class DrumPatternGenerator: @unchecked Sendable {

    private let renderer: NotePlayer
    private var mode: FocusMode = .focus
    private var biometricState: BiometricState = .calm
    private var isRunning = false
    private var totalSteps: Int = 0

    /// Pending note-offs: (note, offTick). Processed inline at start of tick().
    private var pendingOffs: [(note: UInt8, offTick: Int)] = []

    // MARK: - Init

    public init(renderer: NotePlayer) {
        self.renderer = renderer
    }

    // MARK: - Public API

    public func start(tonality: SessionTonality) {
        guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }
        self.mode = tonality.mode
        self.isRunning = true
        self.totalSteps = 0
        self.pendingOffs.removeAll()
    }

    public func stop() {
        isRunning = false
        // Release all pending drum notes
        for off in pendingOffs {
            renderer.noteOff(off.note)
        }
        pendingOffs.removeAll()
        totalSteps = 0
    }

    public func updateBiometricState(_ state: BiometricState) {
        biometricState = state
    }

    /// Called by master clock at 16th-note resolution.
    public func tick(stepInBar: Int) {
        guard isRunning else { return }

        // 1. Process pending note-offs FIRST (release drums from previous ticks)
        let current = totalSteps
        let expired = pendingOffs.filter { $0.offTick <= current }
        for off in expired {
            renderer.noteOff(off.note)
        }
        pendingOffs.removeAll { $0.offTick <= current }

        // 2. Generate hits for this step
        let hits: [DrumHit]
        switch mode {
        case .focus:    hits = focusPattern(step: stepInBar)
        case .energize: hits = energizePattern(step: stepInBar)
        default:        hits = []
        }

        // 3. Play hits and schedule note-offs for next tick
        for hit in hits {
            renderer.noteOn(hit.note, velocity: hit.velocity)
            pendingOffs.append((note: hit.note, offTick: current + 1))
        }

        totalSteps += 1
    }

    // MARK: - Patterns

    private struct DrumHit {
        let note: UInt8
        let velocity: UInt8
    }

    private func focusPattern(step: Int) -> [DrumHit] {
        let velocity: UInt8
        switch biometricState {
        case .calm:     velocity = 25
        case .focused:  velocity = 35
        case .elevated: velocity = 30
        case .peak:     velocity = 20
        }

        switch step {
        case 4:  return [DrumHit(note: GMDrum.sideStick, velocity: velocity)]
        case 12: return [DrumHit(note: GMDrum.sideStick, velocity: velocity)]
        case 8 where biometricState == .focused:
            return [DrumHit(note: GMDrum.shaker, velocity: max(15, velocity - 10))]
        default: return []
        }
    }

    private func energizePattern(step: Int) -> [DrumHit] {
        var hits: [DrumHit] = []

        let kickVel: UInt8 = 90
        let snareVel: UInt8 = 80
        let hhVel: UInt8
        switch biometricState {
        case .calm:     hhVel = 45
        case .focused:  hhVel = 55
        case .elevated: hhVel = 65
        case .peak:     hhVel = 75
        }

        // Kick: beats 1 and 3
        if step == 0 || step == 8 {
            hits.append(DrumHit(note: GMDrum.kick, velocity: kickVel))
        }

        // Snare: beats 2 and 4
        if step == 4 || step == 12 {
            hits.append(DrumHit(note: GMDrum.snare, velocity: snareVel))
            if biometricState == .elevated || biometricState == .peak {
                hits.append(DrumHit(note: GMDrum.clap, velocity: snareVel - 15))
            }
        }

        // Hi-hat: every 8th note
        if step % 2 == 0 {
            let isOpen = step == 6 || step == 14
            let hhNote = isOpen ? GMDrum.openHiHat : GMDrum.closedHiHat
            hits.append(DrumHit(note: hhNote, velocity: hhVel))
        }

        // 16th hi-hats at elevated/peak
        if (biometricState == .elevated || biometricState == .peak) && step % 2 == 1 {
            hits.append(DrumHit(note: GMDrum.closedHiHat, velocity: max(25, hhVel - 20)))
        }

        // Tom fill every 4 bars
        if totalSteps > 0 && step >= 13 && (totalSteps / 16) % 4 == 3 {
            let fillNotes: [UInt8] = [GMDrum.highTom, GMDrum.midTom, GMDrum.lowTom]
            let fillIdx = step - 13
            if fillIdx < fillNotes.count {
                hits.append(DrumHit(note: fillNotes[fillIdx], velocity: 70))
            }
        }

        return hits
    }
}
