// MicroVariationEngine.swift
// BioNaural
//
// Injects subtle, continuous variation into long-running sessions
// (30+ minutes) so the audio never feels static or perfectly looped.
//
// Four variation mechanisms:
// 1. Stem volume drift — slow sinusoidal LFOs per stem, unsynchronized
// 2. MIDI parameter evolution — gradual density/velocity/register drift
// 3. Scale color changes — occasional passing tones in sleep mode
// 4. Carrier drift — already in BinauralBeatNode (Brownian walk ±5Hz)
//
// All variation is imperceptible moment-to-moment but prevents the
// brain from habituating to a static pattern over 1-8 hour sessions.
//
// Threading: Sendable. Pure computation — call from control loop.

import BioNauralShared
import Foundation

// MARK: - MicroVariationEngine

public struct MicroVariationEngine: Sendable {

    // MARK: - Configuration

    private let mode: FocusMode

    // MARK: - Volume Drift LFOs (one per stem, unsynchronized phases)

    /// Phase accumulators for 4 stem LFOs. Using prime-ish periods prevents
    /// them from ever synchronizing: (137s, 191s, 251s, 307s).
    private var padsPhase: Double = 0
    private var texturePhase: Double = 0
    private var bassPhase: Double = 0
    private var rhythmPhase: Double = 0

    /// LFO periods in seconds — primes prevent pattern repetition.
    private let padsPeriod: Double = 137.0
    private let texturePeriod: Double = 191.0
    private let bassPeriod: Double = 251.0
    private let rhythmPeriod: Double = 307.0

    // MARK: - MIDI Evolution State

    /// Session-progress-based density modifier.
    /// Starts at 1.0, evolves over 10-minute windows.
    private var densityEvolutionFactor: Double = 1.0

    /// Gradual velocity center shift (±5 from baseline).
    private var velocityCenterOffset: Int = 0

    /// Octave register drift (±1 from base range).
    private var registerShift: Int = 0

    /// Time of last register change.
    private var lastRegisterChangeAt: Date = .distantPast

    // MARK: - Passing Tone State (Sleep mode only)

    /// Countdown to next passing tone (seconds).
    private var nextPassingToneIn: TimeInterval = 300.0 // 5 min initial
    private var lastPassingToneAt: Date = .distantPast

    // MARK: - Init

    public init(mode: FocusMode) {
        self.mode = mode

        // Randomize initial LFO phases so they start at different points
        padsPhase = Double.random(in: 0..<(2.0 * .pi))
        texturePhase = Double.random(in: 0..<(2.0 * .pi))
        bassPhase = Double.random(in: 0..<(2.0 * .pi))
        rhythmPhase = Double.random(in: 0..<(2.0 * .pi))
    }

    // MARK: - Volume Drift

    /// Compute per-stem volume offsets from slow sinusoidal LFOs.
    /// Call at 10Hz (control loop rate). Returns offsets in [-amplitude, +amplitude].
    public mutating func volumeDriftOffsets(
        deltaTime: TimeInterval
    ) -> StemVolumeDrift {
        let amplitude = Theme.Transition.volumeDriftAmplitude

        // Advance phases
        padsPhase += (2.0 * .pi / padsPeriod) * deltaTime
        texturePhase += (2.0 * .pi / texturePeriod) * deltaTime
        bassPhase += (2.0 * .pi / bassPeriod) * deltaTime
        rhythmPhase += (2.0 * .pi / rhythmPeriod) * deltaTime

        // Wrap phases to prevent precision loss after hours
        padsPhase = padsPhase.truncatingRemainder(dividingBy: 2.0 * .pi)
        texturePhase = texturePhase.truncatingRemainder(dividingBy: 2.0 * .pi)
        bassPhase = bassPhase.truncatingRemainder(dividingBy: 2.0 * .pi)
        rhythmPhase = rhythmPhase.truncatingRemainder(dividingBy: 2.0 * .pi)

        return StemVolumeDrift(
            pads: Float(sin(padsPhase)) * amplitude,
            texture: Float(sin(texturePhase)) * amplitude,
            bass: Float(sin(bassPhase)) * amplitude,
            rhythm: Float(sin(rhythmPhase)) * amplitude
        )
    }

    // MARK: - MIDI Parameter Evolution

    /// Compute evolved MIDI parameters based on session progress.
    /// Call when generating each note.
    public mutating func midiEvolution(
        sessionProgress: Double,
        now: Date = Date()
    ) -> MIDIEvolution {
        // Density evolution: subtle wave over 10-minute windows
        // Sleep mode reduces density continuously; other modes oscillate
        switch mode {
        case .sleep:
            // Continuous reduction: starts at 1.0, reaches 0.3 by session end
            densityEvolutionFactor = max(0.3, 1.0 - sessionProgress * 0.7)
        case .focus, .relaxation:
            // Subtle oscillation: ±10% over 10-minute cycles
            let cyclePeriod = 600.0 // 10 minutes in seconds
            let t = sessionProgress * 3600.0 // Approximate session time
            densityEvolutionFactor = 1.0 + 0.1 * sin(2.0 * .pi * t / cyclePeriod)
        case .energize:
            // Slight increase during warm-up, plateau, slight decrease in cool-down
            if sessionProgress < 0.2 {
                densityEvolutionFactor = 0.8 + sessionProgress * 1.0 // 0.8→1.0
            } else if sessionProgress > 0.85 {
                let cooldownProgress = (sessionProgress - 0.85) / 0.15
                densityEvolutionFactor = 1.0 - cooldownProgress * 0.3 // 1.0→0.7
            } else {
                densityEvolutionFactor = 1.0
            }
        }

        // Velocity center drifts ±5 over session
        let velocityWave = sin(sessionProgress * .pi * 4) // 2 full cycles
        velocityCenterOffset = Int(velocityWave * 5)

        // Register shift: change once per 10-minute window (max)
        let timeSinceRegister = now.timeIntervalSince(lastRegisterChangeAt)
        if timeSinceRegister > 600.0 { // 10 minutes
            // Small chance of shifting register
            if Double.random(in: 0...1) < 0.3 {
                registerShift = Int.random(in: -1...1)
                lastRegisterChangeAt = now
            }
        }

        return MIDIEvolution(
            densityMultiplier: densityEvolutionFactor,
            velocityCenterOffset: velocityCenterOffset,
            registerShift: registerShift
        )
    }

    // MARK: - Passing Tones (Sleep Mode)

    /// Check if a passing tone should be introduced.
    /// Passing tones are single notes outside the current scale that
    /// resolve by step — they add color without disrupting the tonal center.
    public mutating func shouldInsertPassingTone(
        deltaTime: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        guard mode == .sleep else { return false }

        nextPassingToneIn -= deltaTime

        if nextPassingToneIn <= 0 {
            // Reset timer: next passing tone in 5-10 minutes
            nextPassingToneIn = TimeInterval.random(
                in: 300.0...600.0
            )
            lastPassingToneAt = now
            return true
        }

        return false
    }

    /// Generate a passing tone MIDI note number from a target scale degree.
    /// The passing tone is one semitone above or below the target, and
    /// should be immediately followed by the target (resolution by step).
    public func passingTone(
        nearNote: UInt8,
        scaleNotes: [UInt8]
    ) -> UInt8? {
        guard !scaleNotes.isEmpty else { return nil }

        // Choose direction: approach from one semitone above or below
        let direction: Int8 = Bool.random() ? 1 : -1
        let passing = Int(nearNote) + Int(direction)

        guard passing >= 0, passing <= 127 else { return nil }
        let passingNote = UInt8(passing)

        // Ensure the passing tone is NOT in the scale (otherwise it's not "passing")
        if scaleNotes.contains(passingNote) {
            // Try the other direction
            let altPassing = Int(nearNote) - Int(direction)
            guard altPassing >= 0, altPassing <= 127 else { return nil }
            let altNote = UInt8(altPassing)
            if scaleNotes.contains(altNote) { return nil }
            return altNote
        }

        return passingNote
    }
}

// MARK: - Output Types

/// Per-stem volume offsets from slow LFO drift.
public struct StemVolumeDrift: Sendable {
    public let pads: Float
    public let texture: Float
    public let bass: Float
    public let rhythm: Float
}

/// Evolved MIDI parameters for long sessions.
public struct MIDIEvolution: Sendable {
    /// Multiplier on the base note density (1.0 = unchanged).
    public let densityMultiplier: Double
    /// Offset to add to base velocity center (±5).
    public let velocityCenterOffset: Int
    /// Octave register shift from base range (±1).
    public let registerShift: Int
}
