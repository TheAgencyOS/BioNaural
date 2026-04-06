// WatchAdaptationEngine.swift
// BioNauralWatch
//
// Maps biometric state (HR normalized, trend) to audio parameter targets.
// Pure computation — no I/O, no side effects, no allocations beyond the
// returned struct. All numeric constants from WatchDesign.Audio tokens.
// Uses FrequencyMath.sigmoid for bounded parameter mapping.
//
// Control loop tick interval: 0.1 seconds (10 Hz).

import Foundation
import BioNauralShared

// MARK: - WatchAudioTargets

/// Complete set of audio parameter targets produced by the watch adaptation engine.
/// These are *target* values — slew rate limiting is applied before writing
/// to `WatchAudioParameters`.
struct WatchAudioTargets: Sendable, Equatable {

    /// Binaural beat frequency in Hz (the perceptual frequency difference).
    let beatFrequency: Double

    /// Carrier (base) frequency in Hz.
    let carrierFrequency: Double

    /// Binaural layer amplitude [0.0 ... 1.0].
    let amplitude: Double
}

// MARK: - WatchAdaptationEngine

/// Deterministic adaptation engine for watchOS.
///
/// Maps normalized heart rate and trend data to binaural beat parameters
/// using mode-dependent sigmoid/ramp functions. Applies slew rate limiting
/// to ensure imperceptible transitions between parameter values.
///
/// Mode mappings (all params from `WatchDesign.Audio.Mapping`):
/// - **Focus:** Negative feedback — HR up leads to beat down (calming).
/// - **Relaxation:** Gentle downward bias toward alpha range.
/// - **Sleep:** Time-based ramp from theta to delta with HR modifier.
/// - **Energize:** Positive feedback — HR up leads to beat up (activation).
struct WatchAdaptationEngine: Sendable {

    // MARK: - Slew Rate State

    /// Previous beat frequency target (Hz). Used for slew rate clamping.
    private var previousBeatFrequency: Double?

    /// Previous carrier frequency target (Hz). Used for slew rate clamping.
    private var previousCarrierFrequency: Double?

    /// Previous amplitude target. Used for slew rate clamping.
    private var previousAmplitude: Double?

    /// Control loop tick interval in seconds (10 Hz).
    private let tickInterval = WatchDesign.Audio.adaptationTickInterval

    // MARK: - Initializer

    init() {}

    // MARK: - Compute Targets

    /// Compute target audio parameters for the given biometric snapshot.
    ///
    /// - Parameters:
    ///   - hrNormalized: Heart rate reserve normalized [0.0, 1.0] via Karvonen method.
    ///   - hrTrend: Current HR trend magnitude (fast EMA - slow EMA, in BPM).
    ///   - mode: Active focus mode (determines mapping function).
    ///   - sessionProgress: Fraction of session elapsed [0.0, 1.0]. Used
    ///     primarily by Sleep mode for the theta-to-delta ramp.
    /// - Returns: Slew-rate-limited audio parameter targets.
    mutating func computeTargets(
        hrNormalized: Double,
        hrTrend: Double,
        mode: FocusMode,
        sessionProgress: Double
    ) -> WatchAudioTargets {
        // Compute raw (pre-slew) targets.
        let rawBeat = computeBeatFrequency(
            mode: mode,
            hrNormalized: hrNormalized,
            sessionProgress: sessionProgress
        )
        let rawCarrier = computeCarrierFrequency(
            mode: mode,
            hrTrend: hrTrend
        )
        let rawAmplitude = computeAmplitude(hrNormalized: hrNormalized)

        // Apply slew rate limiting.
        let maxBeatDelta = WatchDesign.Audio.SlewRate.beatFrequency * tickInterval
        let maxCarrierDelta = WatchDesign.Audio.SlewRate.carrierFrequency * tickInterval
        let maxAmpDelta = WatchDesign.Audio.SlewRate.amplitude * tickInterval

        let limitedBeat = slewLimit(
            current: rawBeat,
            previous: previousBeatFrequency,
            maxDelta: maxBeatDelta
        )
        let limitedCarrier = slewLimit(
            current: rawCarrier,
            previous: previousCarrierFrequency,
            maxDelta: maxCarrierDelta
        )
        let limitedAmplitude = slewLimit(
            current: rawAmplitude,
            previous: previousAmplitude,
            maxDelta: maxAmpDelta
        )

        // Store for next tick.
        previousBeatFrequency = limitedBeat
        previousCarrierFrequency = limitedCarrier
        previousAmplitude = limitedAmplitude

        return WatchAudioTargets(
            beatFrequency: limitedBeat,
            carrierFrequency: limitedCarrier,
            amplitude: limitedAmplitude
        )
    }

    // MARK: - Beat Frequency

    /// Mode-dependent beat frequency mapping.
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
            return computeEnergizeBeat(hrNormalized: hrNormalized)
        }
    }

    /// Focus: negative feedback sigmoid. HR up -> beat frequency down.
    /// `beat = beatMax - (beatMax - beatMin) * sigmoid(steepness * (hr - midpoint))`
    private func computeFocusBeat(hrNormalized: Double) -> Double {
        let p = WatchDesign.Audio.Mapping.Focus.self
        let s = FrequencyMath.sigmoid(
            x: hrNormalized,
            midpoint: p.midpoint,
            steepness: p.steepness
        )
        return p.beatMax - (p.beatMax - p.beatMin) * s
    }

    /// Relaxation: gentle downward bias toward alpha range.
    /// `beat = beatMax - (beatMax - beatMin) * sigmoid(steepness * (hr - midpoint))`
    private func computeRelaxationBeat(hrNormalized: Double) -> Double {
        let p = WatchDesign.Audio.Mapping.Relaxation.self
        let s = FrequencyMath.sigmoid(
            x: hrNormalized,
            midpoint: p.midpoint,
            steepness: p.steepness
        )
        return p.beatMax - (p.beatMax - p.beatMin) * s
    }

    /// Sleep: time-based theta-to-delta ramp with HR modifier.
    /// Primary: linear ramp from `startFrequency` to `endFrequency` over session.
    /// If HR stays elevated, the descent is slowed proportionally.
    private func computeSleepBeat(
        hrNormalized: Double,
        sessionProgress: Double
    ) -> Double {
        let ramp = WatchDesign.Audio.SleepRamp.self
        let clampedProgress = min(max(sessionProgress, 0.0), 1.0)

        // Base ramp: linear from start to end.
        let rampBeat = ramp.startFrequency
            - (ramp.startFrequency - ramp.endFrequency) * clampedProgress

        // HR modifier: elevated HR slows descent by blending toward start.
        let elevationFactor = max(0.0, hrNormalized - 0.5) * 2.0
        let modifiedBeat = rampBeat
            + (ramp.startFrequency - rampBeat) * elevationFactor * WatchDesign.Audio.Mapping.Sleep.hrElevationBlendFactor

        return max(modifiedBeat, ramp.endFrequency)
    }

    /// Energize: positive feedback sigmoid. HR up -> beat frequency up.
    /// `beat = beatMin + (beatMax - beatMin) * sigmoid(steepness * (hr - midpoint))`
    private func computeEnergizeBeat(hrNormalized: Double) -> Double {
        let p = WatchDesign.Audio.Mapping.Energize.self
        let s = FrequencyMath.sigmoid(
            x: hrNormalized,
            midpoint: p.midpoint,
            steepness: p.steepness
        )
        return p.beatMin + (p.beatMax - p.beatMin) * s
    }

    // MARK: - Carrier Frequency

    /// Carrier frequency: mode default + trend modulation via tanh.
    /// Rising HR trend -> slightly brighter carrier. Falling -> warmer.
    private func computeCarrierFrequency(
        mode: FocusMode,
        hrTrend: Double
    ) -> Double {
        let sec = WatchDesign.Audio.SecondaryMapping.self
        let base = mode.defaultCarrierFrequency
        let modulation = sec.carrierTrendRange * tanh(hrTrend / sec.carrierTrendDivisor)
        let result = base + modulation

        // Clamp to mode's carrier range.
        let range = mode.carrierFrequencyRange
        return min(max(result, range.lowerBound), range.upperBound)
    }

    // MARK: - Amplitude

    /// Amplitude: inverted parabola peaking at HR_norm = 0.5.
    /// `amplitude = amplitudeBase + amplitudeScale * (1 - (2*hr - 1)^2)`
    private func computeAmplitude(hrNormalized: Double) -> Double {
        let sec = WatchDesign.Audio.SecondaryMapping.self
        let centered = 2.0 * hrNormalized - 1.0
        let value = sec.amplitudeBase + sec.amplitudeScale * (1.0 - centered * centered)
        return min(max(value, 0.0), 1.0)
    }

    // MARK: - Slew Rate Limiting

    /// Clamps the delta between current and previous values to `maxDelta`.
    /// On first call (no previous value), returns the current value unmodified.
    private func slewLimit(
        current: Double,
        previous: Double?,
        maxDelta: Double
    ) -> Double {
        guard let previous else { return current }
        let delta = current - previous
        let clampedDelta = min(max(delta, -maxDelta), maxDelta)
        return previous + clampedDelta
    }
}
