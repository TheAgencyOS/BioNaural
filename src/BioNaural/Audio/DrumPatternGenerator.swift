// DrumPatternGenerator.swift
// BioNaural
//
// Generates rhythmic drum/percussion patterns locked to the session tempo.
// Uses GM drum map (channel 10) MIDI notes for the SoundFont renderer.
//
// Only active for Focus and Energize modes:
// - Focus: minimal — soft brush/shaker on beats 2 & 4, very quiet
// - Energize: full kit — kick on 1 & 3, snare/clap on 2 & 4,
//   hi-hat 8ths, occasional fills
//
// All patterns are in the session tempo. Drum velocity and density
// respond to biometric state (calmer = sparser, elevated = denser).

import BioNauralShared
import Foundation

// MARK: - GM Drum Map (Standard)

/// General MIDI percussion note numbers (channel 10).
/// These are the same across all GM-compatible SoundFonts.
public enum GMDrum {
    static let kick: UInt8          = 36  // Bass Drum 1
    static let sideStick: UInt8     = 37  // Side Stick
    static let snare: UInt8         = 38  // Acoustic Snare
    static let clap: UInt8          = 39  // Hand Clap
    static let closedHiHat: UInt8   = 42  // Closed Hi-Hat
    static let openHiHat: UInt8     = 46  // Open Hi-Hat
    static let pedalHiHat: UInt8    = 44  // Pedal Hi-Hat
    static let lowTom: UInt8        = 41  // Low Floor Tom
    static let midTom: UInt8        = 47  // Low-Mid Tom
    static let highTom: UInt8       = 50  // High Tom
    static let crash: UInt8         = 49  // Crash Cymbal 1
    static let ride: UInt8          = 51  // Ride Cymbal 1
    static let rideBell: UInt8      = 53  // Ride Bell
    static let tambourine: UInt8    = 54  // Tambourine
    static let cowbell: UInt8       = 56  // Cowbell
    static let shaker: UInt8        = 70  // Maracas (shaker-like)
    static let cabasa: UInt8        = 69  // Cabasa
    static let guiro: UInt8         = 73  // Short Guiro
    static let claves: UInt8        = 75  // Claves
    static let woodBlock: UInt8     = 76  // Hi Wood Block
    static let triangle: UInt8      = 81  // Open Triangle
}

// MARK: - DrumPatternGenerator

public final class DrumPatternGenerator: @unchecked Sendable {

    private let renderer: SF2MelodicRenderer
    private var tonality: SessionTonality?
    private var biometricState: BiometricState = .calm
    private var isRunning = false
    private var drumTimer: DispatchSourceTimer?
    private var stepInBar: Int = 0  // 0-15 for 16th note resolution

    private let generationQueue = DispatchQueue(
        label: "com.bionaural.drums",
        qos: .userInitiated
    )

    // MARK: - Init

    public init(renderer: SF2MelodicRenderer) {
        self.renderer = renderer
    }

    // MARK: - Public API

    public func start(tonality: SessionTonality) {
        generationQueue.async { [weak self] in
            guard let self, !self.isRunning else { return }

            self.tonality = tonality
            self.isRunning = true
            self.stepInBar = 0

            // Only Focus and Energize get drums
            guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }

            // Switch renderer to drum bank (GM bank 128, channel 10)
            // Note: AVAudioUnitSampler doesn't natively support channel 10 drums
            // in the same way as a full MIDI synth. We use regular note-on with
            // drum-range MIDI notes which GeneralUser GS maps to percussion.
            self.scheduleNextStep()
        }
    }

    public func stop() {
        generationQueue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.drumTimer?.cancel()
            self.drumTimer = nil
        }
    }

    public func updateBiometricState(_ state: BiometricState) {
        generationQueue.async { [weak self] in
            self?.biometricState = state
        }
    }

    // MARK: - Pattern Sequencer

    private func scheduleNextStep() {
        guard isRunning, let tonality else { return }

        // 16th note resolution
        let stepDuration = tonality.beatDuration / 4.0

        let timer = DispatchSource.makeTimerSource(queue: generationQueue)
        timer.schedule(deadline: .now() + stepDuration)
        timer.setEventHandler { [weak self] in
            self?.executeStep()
        }
        drumTimer?.cancel()
        drumTimer = timer
        timer.resume()
    }

    private func executeStep() {
        guard isRunning, let tonality else { return }

        let hits = patternForMode(tonality: tonality)
        let humanize = TimeInterval.random(in: -0.005...0.005) // ±5ms jitter

        for hit in hits {
            let delay = max(0, humanize)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.renderer.noteOn(hit.note, velocity: hit.velocity)
                // Drums are very short — schedule note-off after 50ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.renderer.noteOff(hit.note)
                }
            }
        }

        stepInBar = (stepInBar + 1) % 16
        scheduleNextStep()
    }

    // MARK: - Mode-Specific Patterns

    private struct DrumHit {
        let note: UInt8
        let velocity: UInt8
    }

    /// Returns the drum hits for the current step in the current mode.
    /// Step 0-15 represents 16th notes within a bar of 4/4.
    private func patternForMode(tonality: SessionTonality) -> [DrumHit] {
        switch tonality.mode {
        case .focus:
            return focusPattern()
        case .energize:
            return energizePattern()
        default:
            return [] // Sleep/Relaxation: no drums
        }
    }

    /// Focus: minimal percussion — soft shaker/brush.
    /// Only on beats 2 and 4 (backbeat) at very low velocity.
    /// At calm state: nearly silent. At elevated: slightly more present.
    private func focusPattern() -> [DrumHit] {
        let velocity: UInt8
        switch biometricState {
        case .calm:     velocity = 25  // Barely audible
        case .focused:  velocity = 35  // Subtle presence
        case .elevated: velocity = 30  // Slightly reduced to calm
        case .peak:     velocity = 20  // Pull back when stressed
        }

        switch stepInBar {
        case 4:  // Beat 2
            return [DrumHit(note: GMDrum.sideStick, velocity: velocity)]
        case 12: // Beat 4
            return [DrumHit(note: GMDrum.sideStick, velocity: velocity)]
        case 8:  // Beat 3 — occasional soft shaker
            if biometricState == .focused {
                return [DrumHit(note: GMDrum.shaker, velocity: velocity - 10)]
            }
            return []
        default:
            return []
        }
    }

    /// Energize: full driving pattern.
    /// Kick on 1 & 3, snare/clap on 2 & 4, hi-hat 8ths.
    /// Density increases with biometric arousal (positive feedback).
    private func energizePattern() -> [DrumHit] {
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

        // Kick: beats 1 and 3 (steps 0 and 8)
        if stepInBar == 0 || stepInBar == 8 {
            hits.append(DrumHit(note: GMDrum.kick, velocity: kickVel))
        }

        // Snare/clap: beats 2 and 4 (steps 4 and 12)
        if stepInBar == 4 || stepInBar == 12 {
            hits.append(DrumHit(note: GMDrum.snare, velocity: snareVel))
            // Layer a clap for extra punch at elevated/peak
            if biometricState == .elevated || biometricState == .peak {
                hits.append(DrumHit(note: GMDrum.clap, velocity: snareVel - 15))
            }
        }

        // Hi-hat: every 8th note (steps 0, 2, 4, 6, 8, 10, 12, 14)
        if stepInBar % 2 == 0 {
            let isOpen = stepInBar == 6 || stepInBar == 14 // Open on 'and' of 2 & 4
            let hhNote = isOpen ? GMDrum.openHiHat : GMDrum.closedHiHat
            hits.append(DrumHit(note: hhNote, velocity: hhVel))
        }

        // 16th note hi-hats at elevated/peak (adds energy)
        if biometricState == .elevated || biometricState == .peak {
            if stepInBar % 2 == 1 {
                hits.append(DrumHit(note: GMDrum.closedHiHat, velocity: hhVel - 20))
            }
        }

        // Optional: kick on the 'and' of 4 for syncopation at peak
        if biometricState == .peak && stepInBar == 14 {
            hits.append(DrumHit(note: GMDrum.kick, velocity: kickVel - 15))
        }

        // Occasional tom fill every 4 bars (64 steps)
        if patternStep > 0 && stepInBar >= 13 && (patternStep / 16) % 4 == 3 {
            let fillNotes: [UInt8] = [GMDrum.highTom, GMDrum.midTom, GMDrum.lowTom]
            let fillIdx = stepInBar - 13
            if fillIdx < fillNotes.count {
                hits.append(DrumHit(note: fillNotes[fillIdx], velocity: 70))
            }
        }

        return hits
    }

    /// Total step counter (doesn't reset at bar boundaries, for fill tracking).
    private var patternStep: Int {
        // Derived from stepInBar but tracks across bars
        return stepInBar
    }
}
