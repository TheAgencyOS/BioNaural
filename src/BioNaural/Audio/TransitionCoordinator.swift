// TransitionCoordinator.swift
// BioNaural
//
// Sequences multi-parameter audio transitions so biometric changes
// feel natural, not jarring. Sits between BiometricProcessor and
// AudioParameters/GenerativeMIDIEngine.
//
// Key principles:
// 1. Change parameters in priority order (volumes first, frequency last)
// 2. Use sigmoid/smoothstep curves, never linear interpolation
// 3. Sleep mode gets extra protection (half-rate, volume-only response)
// 4. Minimum dwell times prevent rapid oscillation
// 5. Cross-parameter constraints prevent harmonic chaos
//
// This struct is pure computation — no side effects, no I/O, no
// AudioEngine references. Callers feed in state, get back parameter
// update instructions.
//
// Threading: Sendable. All state is value-typed.

import BioNauralShared
import Foundation

// MARK: - TransitionCoordinator

public struct TransitionCoordinator: Sendable {

    // MARK: - State

    private var mode: FocusMode
    private var currentBiometricState: BiometricState = .calm
    private var previousBiometricState: BiometricState = .calm
    private var stateEnteredAt: Date = .distantPast
    private var lastContentCrossfadeAt: Date = .distantPast
    private var lastMIDIRegisterChangeAt: Date = .distantPast

    // Sleep-specific tracking
    private var isDeepSleep: Bool = false
    private var deepSleepEnteredAt: Date?
    private var isRestless: Bool = false
    private var restlessnessEndedAt: Date?
    private var restingHR: Double = 60.0

    // Current interpolation progress for multi-step transitions
    private var densityTransitionProgress: Double = 1.0 // 1.0 = complete
    private var densityTransitionStartTime: Date?
    private var targetDensityMultiplier: Double = 1.0
    private var currentDensityMultiplier: Double = 1.0

    // MARK: - Init

    public init(mode: FocusMode, restingHR: Double = 60.0) {
        self.mode = mode
        self.restingHR = restingHR
    }

    // MARK: - Update Mode

    public mutating func setMode(_ newMode: FocusMode) {
        mode = newMode
        // Reset sleep tracking when leaving sleep mode
        if newMode != .sleep {
            isDeepSleep = false
            deepSleepEnteredAt = nil
            isRestless = false
            restlessnessEndedAt = nil
        }
    }

    public mutating func setRestingHR(_ hr: Double) {
        restingHR = hr
    }

    // MARK: - Process Biometric Update

    /// Called when BiometricProcessor reports a new biometric state.
    /// Returns a `TransitionPlan` describing what parameters to change and how.
    public mutating func processBiometricUpdate(
        newState: BiometricState,
        currentHR: Double,
        currentHRV: Double?,
        sessionProgress: Double,
        now: Date = Date()
    ) -> TransitionPlan {
        let timeSinceStateChange = now.timeIntervalSince(stateEnteredAt)
        let stateChanged = newState != currentBiometricState

        // Update sleep state tracking
        if mode == .sleep {
            updateSleepState(currentHR: currentHR, now: now)
        }

        // Check dwell time
        let minimumDwell = mode == .sleep
            ? Theme.Transition.minimumDwellSecondsSleep
            : Theme.Transition.minimumDwellSeconds

        if stateChanged && timeSinceStateChange < minimumDwell {
            // Too soon — don't change anything yet
            return TransitionPlan(instructions: [], mode: mode, isDeepSleep: isDeepSleep)
        }

        // Commit state change
        if stateChanged {
            previousBiometricState = currentBiometricState
            currentBiometricState = newState
            stateEnteredAt = now
        }

        // Build transition instructions in priority order
        var instructions: [TransitionInstruction] = []

        // Check if in restless cooldown
        if let cooldownEnd = restlessnessEndedAt,
           now.timeIntervalSince(cooldownEnd) < Theme.Transition.restlessCooldownSeconds {
            // In cooldown — no changes
            return TransitionPlan(instructions: [], mode: mode, isDeepSleep: isDeepSleep)
        }

        // Sleep restlessness detection
        if mode == .sleep && isDeepSleep {
            let hrSpike = currentHR - (restingHR + Theme.Transition.deepSleepHRThresholdAboveResting)
            if hrSpike > Theme.Transition.restlessnessHRSpike {
                // Restless! Volume-only response — NO frequency changes
                return buildRestlessnessResponse(now: now)
            }
        }

        // Priority 1: Stem volumes (fastest response)
        instructions.append(
            .stemVolumes(
                state: newState,
                slewRate: sleepAdjustedStemSlewRate
            )
        )

        // Priority 2: Beat frequency (slew-rate limited with smoothstep)
        if !isDeepSleep || mode != .sleep {
            instructions.append(
                .beatFrequency(
                    state: newState,
                    slewRate: sleepAdjustedBeatSlewRate,
                    curve: .smoothstep
                )
            )
        }

        // Priority 3: MIDI density (smooth transition over 2-5s)
        let newDensity = densityForState(newState)
        if abs(newDensity - currentDensityMultiplier) > 0.05 {
            targetDensityMultiplier = newDensity
            densityTransitionStartTime = now
            densityTransitionProgress = 0.0

            instructions.append(
                .midiDensity(
                    targetMultiplier: newDensity,
                    transitionDuration: Theme.Transition.midiDensitySmoothSeconds,
                    curve: .smoothstep
                )
            )
        }

        // Priority 4: MIDI register/velocity — handled per-note by GenerativeMIDIEngine
        // No explicit instruction needed; the engine reads biometric state directly.

        // Priority 5: Carrier frequency (subtle, slow)
        if !isDeepSleep {
            instructions.append(
                .carrierFrequency(
                    state: newState,
                    slewRate: Theme.Transition.carrierFrequencySlewRate,
                    curve: .tanh
                )
            )
        }

        // Priority 6: Content crossfade (only if state persists > 30s)
        if stateChanged {
            let timeSinceLastCrossfade = now.timeIntervalSince(lastContentCrossfadeAt)
            if timeSinceLastCrossfade > Theme.Transition.contentCrossfadeDwellSeconds && !isDeepSleep {
                // Check cross-parameter constraint: don't overlap with MIDI register change
                let timeSinceRegisterChange = now.timeIntervalSince(lastMIDIRegisterChangeAt)
                if timeSinceRegisterChange > Theme.Transition.crossParameterGapSeconds {
                    instructions.append(
                        .contentCrossfade(
                            duration: Theme.Transition.stemPackCrossfadeSeconds
                        )
                    )
                    lastContentCrossfadeAt = now
                }
            }
        }

        return TransitionPlan(instructions: instructions, mode: mode, isDeepSleep: isDeepSleep)
    }

    // MARK: - Density Interpolation

    /// Call at the control loop rate (10Hz) to get the current
    /// interpolated density multiplier during a transition.
    public mutating func interpolatedDensityMultiplier(now: Date = Date()) -> Double {
        guard let startTime = densityTransitionStartTime,
              densityTransitionProgress < 1.0 else {
            return currentDensityMultiplier
        }

        let elapsed = now.timeIntervalSince(startTime)
        let duration = Theme.Transition.midiDensitySmoothSeconds
        let t = min(1.0, elapsed / duration)

        // Smoothstep interpolation: t² × (3 - 2t)
        let smoothT = t * t * (3.0 - 2.0 * t)
        densityTransitionProgress = smoothT

        let interpolated = currentDensityMultiplier +
            (targetDensityMultiplier - currentDensityMultiplier) * smoothT

        if smoothT >= 1.0 {
            currentDensityMultiplier = targetDensityMultiplier
            densityTransitionStartTime = nil
        }

        return interpolated
    }

    // MARK: - Sleep State Tracking

    private mutating func updateSleepState(currentHR: Double, now: Date) {
        let deepSleepThreshold = restingHR + Theme.Transition.deepSleepHRThresholdAboveResting

        if currentHR < deepSleepThreshold {
            if deepSleepEnteredAt == nil {
                deepSleepEnteredAt = now
            }
            let duration = now.timeIntervalSince(deepSleepEnteredAt ?? now)
            if duration >= Theme.Transition.deepSleepConfirmationSeconds {
                isDeepSleep = true
            }
        } else {
            deepSleepEnteredAt = nil
            if isDeepSleep {
                // Exiting deep sleep
                isDeepSleep = false
            }
        }

        // Track restlessness resolution
        if isRestless && currentHR < deepSleepThreshold {
            isRestless = false
            restlessnessEndedAt = now
        }
    }

    private mutating func buildRestlessnessResponse(now: Date) -> TransitionPlan {
        isRestless = true

        // Volume-only response: increase pads (calming), decrease texture (stimulating)
        // Do NOT change beat frequency, carrier, or MIDI content
        return TransitionPlan(
            instructions: [
                .sleepRestlessnessResponse(
                    padVolumeBoost: 0.15,
                    textureVolumeReduce: 0.2,
                    slewRate: Theme.Transition.stemVolumeSlewRateSleep
                )
            ],
            mode: mode,
            isDeepSleep: true
        )
    }

    // MARK: - Helpers

    private var sleepAdjustedBeatSlewRate: Double {
        if mode == .sleep && isDeepSleep {
            return Theme.Transition.beatFrequencySlewRateSleep
        }
        return Theme.Transition.beatFrequencySlewRate
    }

    private var sleepAdjustedStemSlewRate: Float {
        if mode == .sleep && isDeepSleep {
            return Theme.Transition.stemVolumeSlewRateSleep
        }
        return Theme.Transition.stemVolumeSlewRate
    }

    private func densityForState(_ state: BiometricState) -> Double {
        switch mode {
        case .focus:
            switch state {
            case .calm:     return 0.7
            case .focused:  return 1.0
            case .elevated: return 1.2
            case .peak:     return 0.8
            }
        case .relaxation:
            switch state {
            case .calm:     return 0.7
            case .focused:  return 0.5
            case .elevated: return 0.3
            case .peak:     return 0.2
            }
        case .sleep:
            // Sleep mode: density always low, floors at zero after onset
            if isDeepSleep { return 0.0 }
            switch state {
            case .calm:     return 0.3
            case .focused:  return 0.2
            case .elevated: return 0.1
            case .peak:     return 0.0
            }
        case .energize:
            switch state {
            case .calm:     return 0.8
            case .focused:  return 1.0
            case .elevated: return 1.3
            case .peak:     return 1.5
            }
        }
    }
}

// MARK: - TransitionPlan

/// The output of TransitionCoordinator — a set of prioritized parameter
/// change instructions for the audio engine to execute.
public struct TransitionPlan: Sendable {

    public let instructions: [TransitionInstruction]
    public let mode: FocusMode
    public let isDeepSleep: Bool

    /// Whether this plan contains any actual changes.
    public var isEmpty: Bool { instructions.isEmpty }
}

// MARK: - TransitionInstruction

/// A single parameter change instruction with timing and curve information.
public enum TransitionInstruction: Sendable {

    /// Update stem volumes for the given biometric state.
    case stemVolumes(state: BiometricState, slewRate: Float)

    /// Update beat frequency with slew rate limiting and interpolation curve.
    case beatFrequency(state: BiometricState, slewRate: Double, curve: InterpolationCurve)

    /// Smoothly transition MIDI note density multiplier.
    case midiDensity(targetMultiplier: Double, transitionDuration: TimeInterval, curve: InterpolationCurve)

    /// Update carrier frequency with slew rate and curve.
    case carrierFrequency(state: BiometricState, slewRate: Double, curve: InterpolationCurve)

    /// Trigger a crossfade to a new stem pack or melodic content.
    case contentCrossfade(duration: TimeInterval)

    /// Sleep-specific restlessness response: volume-only, no frequency changes.
    case sleepRestlessnessResponse(padVolumeBoost: Float, textureVolumeReduce: Float, slewRate: Float)
}

// MARK: - InterpolationCurve

/// Describes how a parameter interpolates between old and new values.
public enum InterpolationCurve: Sendable {

    /// t² × (3 - 2t) — slow start and end, faster middle.
    case smoothstep

    /// tanh(kt) — smooth asymptotic approach.
    case tanh

    /// Standard linear interpolation (avoid for user-facing transitions).
    case linear

    /// Apply the curve to a normalized progress value [0, 1].
    public func apply(_ t: Double) -> Double {
        let clamped = max(0, min(1, t))
        switch self {
        case .smoothstep:
            return clamped * clamped * (3.0 - 2.0 * clamped)
        case .tanh:
            // Scale so that tanh(3) ≈ 0.995, giving near-complete transition
            return Foundation.tanh(clamped * 3.0) / Foundation.tanh(3.0)
        case .linear:
            return clamped
        }
    }
}
