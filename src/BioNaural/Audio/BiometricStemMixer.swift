// BiometricStemMixer.swift
// BioNaural
//
// Maps biometric state to per-stem volume targets for the StemAudioLayer.
// Each focus mode has a distinct mixing strategy defined in Theme.Audio.StemMix.
// The mixer interpolates smoothly between discrete state targets using the
// continuous HR_normalized value from the adaptation engine.
//
// Threading: This type is a pure computation — no state, no side effects.
// It reads Theme tokens and returns StemVolumeTargets. The caller
// (typically the biometric control loop at 10 Hz) writes the result
// to AudioParameters.

import BioNauralShared
import Foundation

/// Computes per-stem volume targets based on the current biometric state
/// and focus mode. All volume values and interpolation logic reference
/// `Theme.Audio.StemMix` tokens — no hardcoded values.
public struct BiometricStemMixer: Sendable {

    // MARK: - Public API

    /// Compute stem volume targets for the current mode and biometric state.
    ///
    /// Uses continuous interpolation between the two bracketing biometric
    /// states rather than discrete jumps. This produces smooth volume
    /// transitions as HR_normalized moves through its range.
    ///
    /// - Parameters:
    ///   - mode: The active focus mode.
    ///   - hrNormalized: Heart rate reserve normalized `[0.0 ... 1.0]`.
    ///     `0.0` = resting, `1.0` = max exertion.
    /// - Returns: Per-stem volume targets ready for `AudioParameters.applyStemVolumes`.
    public func computeTargets(
        mode: FocusMode,
        hrNormalized: Double
    ) -> StemVolumeTargets {
        let clamped = min(max(hrNormalized, 0.0), 1.0)
        let (lower, upper, fraction) = bracketState(hrNormalized: clamped, mode: mode)
        return interpolate(from: lower, to: upper, fraction: Float(fraction))
    }

    // MARK: - State Bracketing

    /// Determines the two biometric state targets that bracket the current
    /// HR_normalized value, plus the interpolation fraction between them.
    ///
    /// Zone boundaries come from `Theme.Audio.HRZone`:
    /// - Calm:     0.00 – 0.20
    /// - Focused:  0.20 – 0.45
    /// - Elevated: 0.45 – 0.70
    /// - Peak:     0.70 – 1.00
    private func bracketState(
        hrNormalized: Double,
        mode: FocusMode
    ) -> (lower: StemVolumeTargets, upper: StemVolumeTargets, fraction: Double) {

        let calmMax = Theme.Audio.HRZone.calmMax
        let focusedMax = Theme.Audio.HRZone.focusedMax
        let elevatedMax = Theme.Audio.HRZone.elevatedMax

        let targets = modeTargets(for: mode)

        if hrNormalized <= calmMax {
            // Fully in Calm zone — no interpolation needed.
            return (targets.calm, targets.calm, 0.0)
        } else if hrNormalized <= focusedMax {
            let fraction = (hrNormalized - calmMax) / (focusedMax - calmMax)
            return (targets.calm, targets.focused, fraction)
        } else if hrNormalized <= elevatedMax {
            let fraction = (hrNormalized - focusedMax) / (elevatedMax - focusedMax)
            return (targets.focused, targets.elevated, fraction)
        } else {
            let fraction = min((hrNormalized - elevatedMax) / (1.0 - elevatedMax), 1.0)
            return (targets.elevated, targets.peak, fraction)
        }
    }

    // MARK: - Mode Target Lookup

    /// Returns the four-state volume target set for a given mode.
    private func modeTargets(for mode: FocusMode) -> ModeVolumes {
        switch mode {
        case .focus:
            return ModeVolumes(
                calm: Theme.Audio.StemMix.Focus.calm,
                focused: Theme.Audio.StemMix.Focus.focused,
                elevated: Theme.Audio.StemMix.Focus.elevated,
                peak: Theme.Audio.StemMix.Focus.peak
            )
        case .relaxation:
            return ModeVolumes(
                calm: Theme.Audio.StemMix.Relaxation.calm,
                focused: Theme.Audio.StemMix.Relaxation.focused,
                elevated: Theme.Audio.StemMix.Relaxation.elevated,
                peak: Theme.Audio.StemMix.Relaxation.peak
            )
        case .sleep:
            return ModeVolumes(
                calm: Theme.Audio.StemMix.Sleep.calm,
                focused: Theme.Audio.StemMix.Sleep.focused,
                elevated: Theme.Audio.StemMix.Sleep.elevated,
                peak: Theme.Audio.StemMix.Sleep.peak
            )
        case .energize:
            return ModeVolumes(
                calm: Theme.Audio.StemMix.Energize.calm,
                focused: Theme.Audio.StemMix.Energize.focused,
                elevated: Theme.Audio.StemMix.Energize.elevated,
                peak: Theme.Audio.StemMix.Energize.peak
            )
        }
    }

    // MARK: - Interpolation

    /// Linearly interpolates between two stem volume target sets.
    private func interpolate(
        from lower: StemVolumeTargets,
        to upper: StemVolumeTargets,
        fraction: Float
    ) -> StemVolumeTargets {
        StemVolumeTargets(
            pads: lower.pads + (upper.pads - lower.pads) * fraction,
            texture: lower.texture + (upper.texture - lower.texture) * fraction,
            bass: lower.bass + (upper.bass - lower.bass) * fraction,
            rhythm: lower.rhythm + (upper.rhythm - lower.rhythm) * fraction
        )
    }
}

// MARK: - Mode Volumes (Private Helper)

/// Groups the four biometric-state volume targets for a single mode.
private struct ModeVolumes {
    let calm: StemVolumeTargets
    let focused: StemVolumeTargets
    let elevated: StemVolumeTargets
    let peak: StemVolumeTargets
}
