// AdaptationEngine.swift
// BioNaural
//
// Maps biometric state to audio parameter targets. Mode-dependent sigmoid
// and ramp functions convert normalized HR into beat frequency, carrier,
// amplitude, and mix levels. All constants from Theme.Audio tokens.
// No side effects — pure computation given inputs.

import Foundation
import BioNauralShared

// MARK: - AudioTargets

/// Complete set of audio parameter targets produced by the adaptation engine.
/// These are *target* values — slew rate limiting is applied downstream by
/// `BiometricProcessor` before writing to `AudioParameters`.
public struct AudioTargets: Sendable, Equatable {

    /// Binaural beat frequency in Hz (the perceptual frequency difference).
    public var beatFrequency: Double

    /// Carrier (base) frequency in Hz.
    public var carrierFrequency: Double

    /// Binaural layer amplitude [0.0, 1.0].
    public var binauralAmplitude: Double

    /// Ambient texture level [0.0, 1.0].
    public var ambientLevel: Double

    /// Melodic layer level [0.0, 1.0].
    public var melodicLevel: Double

    /// Harmonic content [0.0, 1.0] — 0 = pure sine, 1 = rich harmonics.
    public var harmonicContent: Double

    public init(
        beatFrequency: Double,
        carrierFrequency: Double,
        binauralAmplitude: Double,
        ambientLevel: Double,
        melodicLevel: Double,
        harmonicContent: Double
    ) {
        self.beatFrequency = beatFrequency
        self.carrierFrequency = carrierFrequency
        self.binauralAmplitude = binauralAmplitude
        self.ambientLevel = ambientLevel
        self.melodicLevel = melodicLevel
        self.harmonicContent = harmonicContent
    }

    /// Neutral defaults used during data loss or initialization.
    public static let neutral = AudioTargets(
        beatFrequency: Theme.Audio.Neutral.beatFrequency,
        carrierFrequency: Theme.Audio.Neutral.carrierFrequency,
        binauralAmplitude: Theme.Audio.Neutral.amplitude,
        ambientLevel: Theme.Audio.Neutral.ambientLevel,
        melodicLevel: Theme.Audio.Neutral.melodicLevel,
        harmonicContent: Theme.Audio.Neutral.harmonicContent
    )
}

// MARK: - AdaptationEngineProtocol

/// Contract for the component that maps biometric signals to audio targets.
///
/// v1 uses `AdaptationEngine` (deterministic sigmoids).
/// v1.5 will provide an ML-backed implementation. Both conform to this protocol.
public protocol AdaptationEngineProtocol: Sendable {

    /// Compute target audio parameters for the given biometric snapshot.
    ///
    /// - Parameters:
    ///   - mode: Active focus mode (determines mapping function).
    ///   - hrNormalized: Heart rate reserve normalized [0.0, 1.0].
    ///   - hrvNormalized: HRV normalized [0.0, 1.0], nil if unavailable.
    ///   - trend: Current HR trend direction.
    ///   - trendMagnitude: Raw fast-slow EMA divergence (BPM).
    ///   - sessionProgress: Fraction of session elapsed [0.0, 1.0].
    /// - Returns: Target audio parameters (pre-slew-limiting).
    func computeTargets(
        mode: FocusMode,
        hrNormalized: Double,
        hrvNormalized: Double?,
        trend: HRTrend,
        trendMagnitude: Double,
        sessionProgress: Double
    ) -> AudioTargets
}

// MARK: - AdaptationEngine

/// Deterministic v1 adaptation engine.
///
/// Implements mode-dependent mapping functions:
/// - **Focus:** Negative feedback sigmoid (HR up -> beat freq down).
/// - **Relaxation:** Gentle downward bias toward alpha (8-11 Hz).
/// - **Sleep:** Time-based theta-to-delta ramp with biometric modifiers.
/// - **Energize:** Positive feedback sigmoid (HR up -> beat freq up) with
///   IZOF targeting, asymmetric gain, and mandatory session arc
///   (warm-up -> ramp -> sustain -> cool-down).
///
/// All numeric parameters sourced from `Theme.Audio.ModeDefaults` and
/// `Theme.Audio.SecondaryMapping` tokens.
public struct AdaptationEngine: AdaptationEngineProtocol {

    public init() {}

    public func computeTargets(
        mode: FocusMode,
        hrNormalized: Double,
        hrvNormalized: Double?,
        trend: HRTrend,
        trendMagnitude: Double,
        sessionProgress: Double
    ) -> AudioTargets {
        let beatFreq = computeBeatFrequency(
            mode: mode,
            hrNormalized: hrNormalized,
            sessionProgress: sessionProgress
        )
        let carrierFreq = computeCarrierFrequency(
            mode: mode,
            trendMagnitude: trendMagnitude
        )
        let binauralAmp = computeBinauralAmplitude(hrNormalized: hrNormalized)
        let ambient = computeAmbientLevel(hrNormalized: hrNormalized)
        let harmonic = computeHarmonicContent(hrNormalized: hrNormalized)
        let melodic = computeMelodicLevel(hrNormalized: hrNormalized, mode: mode)

        return AudioTargets(
            beatFrequency: beatFreq,
            carrierFrequency: carrierFreq,
            binauralAmplitude: binauralAmp,
            ambientLevel: ambient,
            melodicLevel: melodic,
            harmonicContent: harmonic
        )
    }

    // MARK: - Beat Frequency

    private func computeBeatFrequency(
        mode: FocusMode,
        hrNormalized: Double,
        sessionProgress: Double
    ) -> Double {
        switch mode {
        case .focus:
            return computeFocusBeat(hrNormalized: hrNormalized)
        case .relaxation:
            return computeRelaxationBeat(hrNormalized: hrNormalized)
        case .sleep:
            return computeSleepBeat(
                hrNormalized: hrNormalized,
                sessionProgress: sessionProgress
            )
        case .energize:
            return computeEnergizeBeat(
                hrNormalized: hrNormalized,
                sessionProgress: sessionProgress
            )
        }
    }

    /// Focus: negative feedback sigmoid. HR up -> beat frequency down (calming).
    /// `beat = max - (max - min) * sigmoid(k * (hr - midpoint))`
    private func computeFocusBeat(hrNormalized: Double) -> Double {
        let p = Theme.Audio.ModeDefaults.Focus.self
        let s = sigmoid(p.sigmoidSteepness * (hrNormalized - p.sigmoidMidpoint))
        return p.beatFrequencyMax - (p.beatFrequencyMax - p.beatFrequencyMin) * s
    }

    /// Relaxation: gentle downward bias toward alpha.
    /// `beat = max - (max - min) * sigmoid(k * (depth - midpoint))`
    /// Floor at `beatMin` Hz to prevent sleep drift.
    private func computeRelaxationBeat(hrNormalized: Double) -> Double {
        let p = Theme.Audio.ModeDefaults.Relaxation.self
        // Relaxation depth: inverse of activation. Lower HR = deeper relaxation.
        let depth = 1.0 - hrNormalized
        let s = sigmoid(p.sigmoidSteepness * (depth - p.sigmoidMidpoint))
        let beat = p.beatFrequencyMax - (p.beatFrequencyMax - p.beatFrequencyMin) * s
        return max(beat, p.beatFrequencyMin)
    }

    /// Sleep: time-based theta-to-delta ramp with biometric modifier.
    /// Primary: linear ramp from `beatStart` to `beatEnd` over `rampDuration`.
    /// If HR stays elevated, hold rather than forcing descent.
    private func computeSleepBeat(
        hrNormalized: Double,
        sessionProgress: Double
    ) -> Double {
        let p = Theme.Audio.ModeDefaults.Sleep.self
        let clampedProgress = min(max(sessionProgress, 0.0), 1.0)

        // Base ramp: linear from beatStart to beatEnd
        let rampBeat = p.beatFrequencyStart
            - (p.beatFrequencyStart - p.beatFrequencyEnd) * clampedProgress

        // Biometric modifier: if HR is elevated (>0.5 normalized), slow the
        // descent by blending back toward the start frequency proportionally.
        let elevationFactor = max(0.0, hrNormalized - 0.5) * 2.0 // 0..1 above midpoint
        let modifiedBeat = rampBeat + (p.beatFrequencyStart - rampBeat) * elevationFactor * 0.5

        return max(modifiedBeat, p.beatFrequencyEnd)
    }

    // MARK: - Energize Beat Frequency

    /// Session arc phase for Energize mode.
    /// The Energize session follows a mandatory arc:
    /// 1. **Warm-up:** alpha -> low beta, ignores biometrics.
    /// 2. **Ramp:** beta -> high beta, biometric-driven.
    /// 3. **Sustain:** IZOF zone, biometric-driven.
    /// 4. **Cool-down:** taper to alpha, non-skippable.
    enum EnergizePhase {
        case warmUp(fraction: Double)
        case ramp
        case sustain
        case coolDown(fraction: Double)
    }

    /// Determine the current Energize session phase from session progress.
    /// Boundaries are derived from `Theme.Audio.Safety` warm-up and cool-down
    /// tokens relative to `Theme.Audio.Safety.maxSessionMinutes`.
    private func energizePhase(sessionProgress: Double) -> EnergizePhase {
        let safety = Theme.Audio.Safety.self
        let totalSeconds = safety.maxSessionMinutes * 60.0
        guard totalSeconds > 0 else { return .sustain }

        let warmUpFraction = (safety.warmUpMinutes * 60.0) / totalSeconds
        let coolDownFraction = (safety.coolDownMinutes * 60.0) / totalSeconds
        let coolDownStart = 1.0 - coolDownFraction

        if sessionProgress < warmUpFraction {
            // Warm-up: 0..warmUpFraction -> fraction 0..1
            let fraction = sessionProgress / warmUpFraction
            return .warmUp(fraction: fraction)
        } else if sessionProgress >= coolDownStart {
            // Cool-down: coolDownStart..1.0 -> fraction 0..1
            let fraction = (sessionProgress - coolDownStart) / coolDownFraction
            return .coolDown(fraction: min(max(fraction, 0.0), 1.0))
        } else {
            // Active phase: ramp then sustain. Split at the midpoint of
            // the active window.
            let activeStart = warmUpFraction
            let activeDuration = coolDownStart - activeStart
            let activeProgress = (sessionProgress - activeStart) / activeDuration
            if activeProgress < 0.3 {
                return .ramp
            } else {
                return .sustain
            }
        }
    }

    /// Energize: positive feedback sigmoid with session arc.
    /// - **Warm-up** (first `warmUpMinutes`): Linear ramp from alpha (10 Hz) to
    ///   low beta (`beatFrequencyMin`). Biometrics are ignored.
    /// - **Ramp/Sustain**: Positive sigmoid mapping — HR up -> beat frequency up.
    ///   `beat = beatMin + (beatMax - beatMin) * sigmoid(k * (HR_norm - midpoint))`
    /// - **Cool-down** (final `coolDownMinutes`): Taper from current beat to alpha.
    ///   Non-skippable.
    private func computeEnergizeBeat(
        hrNormalized: Double,
        sessionProgress: Double
    ) -> Double {
        let p = Theme.Audio.ModeDefaults.Energize.self
        let safety = Theme.Audio.Safety.self
        let phase = energizePhase(sessionProgress: sessionProgress)

        switch phase {
        case .warmUp(let fraction):
            // Linear ramp: alpha -> low beta (beatFrequencyMin)
            let alphaStart = safety.warmUpStartFrequency
            return alphaStart + (p.beatFrequencyMin - alphaStart) * fraction

        case .ramp, .sustain:
            // Positive feedback sigmoid: HR up -> beat frequency UP
            let s = sigmoid(p.sigmoidSteepness * (hrNormalized - p.sigmoidMidpoint))
            return p.beatFrequencyMin + (p.beatFrequencyMax - p.beatFrequencyMin) * s

        case .coolDown(let fraction):
            // Taper from current active position toward alpha
            let s = sigmoid(p.sigmoidSteepness * (hrNormalized - p.sigmoidMidpoint))
            let activeBeat = p.beatFrequencyMin + (p.beatFrequencyMax - p.beatFrequencyMin) * s
            let alphaTarget = safety.coolDownRestingFrequency
            return activeBeat + (alphaTarget - activeBeat) * fraction
        }
    }

    // MARK: - Carrier Frequency

    /// Carrier frequency: mode base + trend modulation via tanh.
    /// Rising HR -> slightly brighter carrier. Falling -> warmer.
    private func computeCarrierFrequency(
        mode: FocusMode,
        trendMagnitude: Double
    ) -> Double {
        let ctrl = Theme.Audio.Control.self
        let base = mode.defaultCarrierFrequency
        let modulation = ctrl.carrierTrendModulation * tanh(trendMagnitude / ctrl.carrierTrendDivisor)
        let result = base + modulation

        // Clamp to mode's carrier range
        let range = mode.carrierFrequencyRange
        return min(max(result, range.lowerBound), range.upperBound)
    }

    // MARK: - Secondary Mappings

    /// Binaural amplitude: inverted parabola peaking at HR_norm = 0.5.
    /// `amplitude = base + scale * (1 - (2 * hr - 1)^2)`
    private func computeBinauralAmplitude(hrNormalized: Double) -> Double {
        let m = Theme.Audio.SecondaryMapping.self
        let centered = 2.0 * hrNormalized - 1.0
        let value = m.binauralAmplitudeBase + m.binauralAmplitudeScale * (1.0 - centered * centered)
        return min(max(value, 0.0), 1.0)
    }

    /// Ambient level: inverse to activation. Calm = rich ambient, peak = recedes.
    private func computeAmbientLevel(hrNormalized: Double) -> Double {
        let m = Theme.Audio.SecondaryMapping.self
        let level = m.ambientLevelBase - m.ambientLevelScale * hrNormalized
        return min(max(level, 0.0), 1.0)
    }

    /// Harmonic content: rises with activation.
    private func computeHarmonicContent(hrNormalized: Double) -> Double {
        let m = Theme.Audio.SecondaryMapping.self
        let content = m.harmonicContentBase + m.harmonicContentScale * hrNormalized
        return min(max(content, 0.0), 1.0)
    }

    /// Melodic level: mode-dependent. Focus/relaxation peak at moderate
    /// activation; sleep fades melodic content as delta deepens.
    private func computeMelodicLevel(hrNormalized: Double, mode: FocusMode) -> Double {
        switch mode {
        case .focus, .relaxation:
            // Peaks at midrange activation, similar to binaural amplitude curve
            let centered = 2.0 * hrNormalized - 1.0
            return min(max(0.4 + 0.4 * (1.0 - centered * centered), 0.0), 1.0)
        case .sleep:
            // Fades as user enters deeper sleep state (lower HR)
            return min(max(0.6 - 0.3 * (1.0 - hrNormalized), 0.0), 1.0)
        case .energize:
            // Higher melodic presence during energize — rises with activation
            let centered = 2.0 * hrNormalized - 1.0
            return min(max(0.5 + 0.3 * (1.0 - centered * centered), 0.0), 1.0)
        }
    }

    // MARK: - Math Utilities

    /// Standard logistic sigmoid: 1 / (1 + exp(-x)).
    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }
}
