// BiometricProcessor.swift
// BioNaural
//
// The main actor orchestrating the biometric processing pipeline.
// Ingests raw HR samples, runs the 10 Hz control loop, and writes
// slew-rate-limited parameters to the lock-free AudioParameters store.
// Concurrency domain: Swift actor. May allocate, lock, await.
// Writes to AudioParameters via atomics — no locks cross the audio boundary.

import Foundation
import BioNauralShared

// MARK: - BiometricSample

/// A single biometric reading from WatchConnectivity or HealthKit.
public struct LocalBiometricSample: Sendable {

    /// Heart rate in BPM.
    public let heartRate: Double

    /// HRV (RMSSD) in milliseconds, if available.
    public let hrv: Double?

    /// Signal quality score [0.0, 1.0]. 1.0 = clean, 0.0 = unreliable.
    public let signalQuality: Double

    /// Timestamp of the measurement.
    public let timestamp: Date

    public init(
        heartRate: Double,
        hrv: Double? = nil,
        signalQuality: Double = 1.0,
        timestamp: Date = Date()
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.signalQuality = min(max(signalQuality, 0.0), 1.0)
        self.timestamp = timestamp
    }
}

// MARK: - BiometricSnapshot

/// Published snapshot of the current biometric processing state.
/// Consumed by the UI layer (ViewModels) and analytics.
public struct BiometricSnapshot: Sendable {
    public let state: BiometricState
    public let hrSmoothed: Double
    public let hrNormalized: Double
    public let trend: HRTrend
    public let trendMagnitude: Double
    public let targets: AudioTargets
    public let timestamp: Date
}

// MARK: - SafetyEvent

/// Events emitted when Energize-mode safety guardrails fire.
///
/// The UI layer subscribes to these via `safetyEventStream` and presents
/// appropriate feedback (e.g., "Adjusting to keep you comfortable" or an
/// emergency alert dialog).
public enum SafetyEvent: Sendable, Equatable {
    /// HR exceeded baseline + ceiling or absolute 100 BPM.
    /// The engine is ramping to calming alpha frequencies.
    case hrCeilingBreached(currentHR: Double)

    /// HR exceeded the hard stop threshold (fraction of age-predicted max
    /// or absolute BPM limit). Emergency theta ramp activated.
    case hrHardStop(currentHR: Double)

    /// RMSSD dropped below the HRV floor. Stimulation is being reduced.
    case hrvFloorBreached(rmssd: Double)

    /// RMSSD crashed more than the threshold percentage from session baseline.
    /// Beat frequency reduced by 3 Hz immediately.
    case hrvCrash(rmssd: Double, sessionBaseline: Double)

    /// HR rose faster than the rate-of-change limit within 60 seconds.
    /// Frequency escalation frozen.
    case hrRateOfChangeLimitHit(deltaBPM: Double)

    /// Session has reached the maximum duration for Energize mode.
    /// Mandatory cool-down is beginning.
    case sessionTimeCap

    /// Mandatory cool-down phase has begun. Non-skippable.
    case coolDownStarted
}

// MARK: - BiometricProcessor

/// The brain of BioNaural's adaptive audio system.
///
/// Owns the full signal processing pipeline:
/// 1. Ingest raw HR from WatchConnectivity
/// 2. Artifact rejection
/// 3. Dual-EMA smoothing
/// 4. Trend detection
/// 5. State classification (hysteresis + dwell)
/// 6. Mode-dependent parameter mapping
/// 7. Signal quality weighting
/// 8. Slew rate limiting
/// 9. Write to AudioParameters (lock-free atomics)
///
/// Publishes `BiometricSnapshot` updates via `AsyncStream` for UI consumption.
///
/// **Graceful degradation:** If no data arrives for 10 s, parameters freeze.
/// After 60 s, they drift linearly toward neutral defaults.
public actor BiometricProcessor {

    // MARK: - Dependencies

    private let analyzer: HeartRateAnalyzer
    private let classifier: StateClassifier
    private let selector: ParameterSelectorProtocol
    private let audioParameters: AudioParameters

    // MARK: - Session Configuration

    private var activeMode: FocusMode = .focus
    private var restingHR: Double
    private var maxHR: Double
    private var sessionStartTime: Date?

    /// Duration of the current session mode for progress calculation (seconds).
    /// Sleep uses the sleep ramp duration token; others default to the
    /// user-selected timer or a sensible fallback.
    private var sessionDuration: TimeInterval

    // MARK: - Control Loop State

    /// The most recent raw sample timestamp.
    private var lastSampleTimestamp: Date?

    /// The most recent smoothed HR value for fallback when no new sample arrives.
    private var lastSmoothedHR: Double?

    /// Current slew-rate-limited output values.
    private var currentOutput: AudioTargets

    /// Timer task driving the 10 Hz control loop.
    private var controlLoopTask: Task<Void, Never>?

    // MARK: - Energize Safety State

    /// The user's age, used for age-predicted max HR calculation.
    /// Defaults to 30 if not provided (conservative).
    private var userAge: Int

    /// Session-baseline HRV (RMSSD in ms), captured from early samples.
    private var sessionBaselineHRV: Double?

    /// Whether the session-baseline HRV has been locked (set after first
    /// valid HRV reading during the session).
    private var sessionBaselineHRVLocked: Bool = false

    /// HR value recorded 60 seconds ago, for rate-of-change detection.
    private var hrOneMinuteAgo: Double?

    /// Timestamp of the `hrOneMinuteAgo` reading.
    private var hrOneMinuteAgoTimestamp: Date?

    /// Whether frequency escalation is currently frozen by the
    /// rate-of-change guardrail.
    private var frequencyEscalationFrozen: Bool = false

    /// Whether the session has entered mandatory cool-down
    /// (non-skippable, even if user taps stop).
    private var inMandatoryCoolDown: Bool = false

    /// Whether the cool-down-started event has already been emitted
    /// (to avoid duplicate emissions).
    private var coolDownEventEmitted: Bool = false

    // MARK: - AsyncStream Publication

    private var snapshotContinuation: AsyncStream<BiometricSnapshot>.Continuation?

    /// Stream of biometric snapshots published at the control loop rate.
    /// Subscribe from ViewModels or analytics services.
    public let snapshotStream: AsyncStream<BiometricSnapshot>

    private var safetyEventContinuation: AsyncStream<SafetyEvent>.Continuation?

    /// Stream of safety events emitted when Energize guardrails trigger.
    /// Subscribe from ViewModels to present user-facing alerts.
    public let safetyEventStream: AsyncStream<SafetyEvent>

    // MARK: - Init

    /// Create a new processor.
    ///
    /// - Parameters:
    ///   - audioParameters: Lock-free parameter store shared with the audio render thread.
    ///   - selector: Parameter selection strategy (deterministic v1 or ML v1.5).
    ///   - restingHR: User's resting HR (BPM). Defaults to population average.
    ///   - maxHR: User's estimated max HR (BPM). Defaults to population average.
    ///   - sessionDuration: Expected session length in seconds.
    ///   - userAge: User's age in years (for age-predicted max HR). Defaults to 30.
    init(
        audioParameters: AudioParameters,
        selector: ParameterSelectorProtocol = DeterministicParameterSelector(),
        restingHR: Double = 72.0,
        maxHR: Double = 185.0,
        sessionDuration: TimeInterval = 1500.0,
        userAge: Int = 30
    ) {
        self.audioParameters = audioParameters
        self.selector = selector
        self.restingHR = restingHR
        self.maxHR = maxHR
        self.sessionDuration = sessionDuration
        self.userAge = userAge
        self.analyzer = HeartRateAnalyzer()
        self.classifier = StateClassifier()
        self.currentOutput = .neutral

        var capturedContinuation: AsyncStream<BiometricSnapshot>.Continuation?
        self.snapshotStream = AsyncStream { capturedContinuation = $0 }
        self.snapshotContinuation = capturedContinuation!

        var capturedSafety: AsyncStream<SafetyEvent>.Continuation?
        self.safetyEventStream = AsyncStream { capturedSafety = $0 }
        self.safetyEventContinuation = capturedSafety!
    }

    deinit {
        controlLoopTask?.cancel()
        snapshotContinuation?.finish()
        safetyEventContinuation?.finish()
    }

    // MARK: - Session Lifecycle

    /// Start the adaptive control loop for the given mode.
    ///
    /// - Parameters:
    ///   - mode: Focus mode determining the mapping function.
    ///   - sessionDuration: Total session length (seconds). Uses mode default if nil.
    public func startSession(mode: FocusMode, sessionDuration: TimeInterval? = nil) {
        stopSession()

        activeMode = mode
        sessionStartTime = Date()
        lastSmoothedHR = nil
        lastSampleTimestamp = nil

        if let duration = sessionDuration {
            self.sessionDuration = duration
        } else {
            switch mode {
            case .sleep:
                self.sessionDuration = Theme.Audio.ModeDefaults.Sleep.rampDuration
            case .energize:
                self.sessionDuration = Theme.Audio.Safety.maxSessionMinutes * 60.0
            case .focus, .relaxation:
                break // Keep the previously set duration
            }
        }

        // Reset Energize safety state
        sessionBaselineHRV = nil
        sessionBaselineHRVLocked = false
        hrOneMinuteAgo = nil
        hrOneMinuteAgoTimestamp = nil
        frequencyEscalationFrozen = false
        inMandatoryCoolDown = false
        coolDownEventEmitted = false

        analyzer.reset()
        classifier.reset()
        currentOutput = .neutral
        writeToAudioParameters(currentOutput)
        startControlLoop()
    }

    /// Stop the control loop and reset state.
    /// If the active mode is Energize and the session is in the mandatory
    /// cool-down phase, this method does NOT stop the session. The cool-down
    /// must complete. Call `forceStopSession()` only in true emergencies.
    public func stopSession() {
        if activeMode == .energize && inMandatoryCoolDown {
            // Cool-down is non-skippable. Ignore the stop request.
            return
        }
        forceStopSession()
    }

    /// Unconditionally stop the control loop. Used internally after
    /// cool-down completes or for emergency hard-stop scenarios.
    private func forceStopSession() {
        controlLoopTask?.cancel()
        controlLoopTask = nil
        sessionStartTime = nil
    }

    /// Update user biometric profile (e.g., after baseline calibration).
    public func updateProfile(restingHR: Double? = nil, maxHR: Double? = nil, userAge: Int? = nil) {
        if let resting = restingHR { self.restingHR = resting }
        if let max = maxHR { self.maxHR = max }
        if let age = userAge { self.userAge = age }
    }

    // MARK: - Sample Ingestion

    /// Ingest a biometric sample from WatchConnectivity or HealthKit.
    /// Safe to call from any isolation context — the actor serializes access.
    /// The sample is stored and consumed on the next control loop tick.
    public func ingest(_ sample: LocalBiometricSample) {
        latestSample = sample
        lastSampleTimestamp = sample.timestamp
    }

    /// The most recent unprocessed sample. The control loop reads and clears this.
    private var latestSample: LocalBiometricSample?

    // MARK: - Control Loop

    /// Start the 10 Hz control loop as a detached actor-isolated task.
    private func startControlLoop() {
        let interval = Theme.Audio.ControlLoop.intervalSeconds
        controlLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Single tick of the control loop. Runs every ~100 ms.
    ///
    /// Steps:
    /// 1. Read latest sample
    /// 2. Classify data freshness
    /// 3. Artifact reject + smooth (if sample available)
    /// 4. Normalize HR to reserve scale
    /// 5. Detect trend
    /// 6. Classify state (hysteresis + dwell)
    /// 7. Map to audio targets (mode-dependent)
    /// 8. Weight by signal quality
    /// 9. Slew rate limit
    /// 10. Write to AudioParameters
    /// 11. Publish snapshot
    private func tick() {
        let now = Date()

        // --- 1. Read latest sample ---
        let sample = latestSample
        latestSample = nil // consume

        // --- 2. Determine data freshness ---
        let dataAge = lastSampleTimestamp.map { now.timeIntervalSince($0) } ?? .infinity
        let dataState = classifyDataFreshness(age: dataAge)

        // --- 3. Process sample if available ---
        let processed: HeartRateAnalyzer.ProcessedSample?
        let signalQuality: Double

        if let sample {
            processed = analyzer.process(rawHR: sample.heartRate, timestamp: now)
            signalQuality = sample.signalQuality
            lastSmoothedHR = processed?.smoothed
        } else {
            processed = nil
            signalQuality = 0.0
        }

        // --- 4. Compute HR normalized ---
        let hrSmoothed = processed?.smoothed ?? lastSmoothedHR ?? restingHR
        let hrNormalized = analyzer.heartRateReserveNormalized(
            heartRate: hrSmoothed,
            restingHR: restingHR,
            maxHR: maxHR
        )

        // --- 5. Detect trend ---
        let trend = analyzer.detectTrend()
        let trendMag = analyzer.trendMagnitude

        // --- 6. Classify state ---
        let state = classifier.classify(hrNormalized: hrNormalized, timestamp: now)

        // --- 7. Compute session progress ---
        let sessionProgress = computeSessionProgress(now: now)

        // --- 8. Compute target parameters ---
        let rawTargets: AudioTargets
        switch dataState {
        case .fresh:
            rawTargets = selector.selectParameters(
                mode: activeMode,
                biometricState: state,
                hrNormalized: hrNormalized,
                hrvNormalized: nil, // HRV normalization planned for v1.1
                trend: trend,
                trendMagnitude: trendMag,
                sessionProgress: sessionProgress
            )
        case .frozen:
            // No new data for > freeze timeout — hold current output
            rawTargets = currentOutput
        case .drifting(let driftFraction):
            // Drift toward neutral over the drift window
            rawTargets = interpolateTargets(
                from: currentOutput,
                to: .neutral,
                fraction: driftFraction
            )
        }

        // --- 8b. Apply Energize safety guardrails (if active) ---
        let safeTargets: AudioTargets
        if activeMode == .energize {
            safeTargets = applyEnergizeSafetyGuardrails(
                targets: rawTargets,
                hrSmoothed: hrSmoothed,
                hrv: sample?.hrv,
                sessionProgress: sessionProgress,
                now: now
            )
        } else {
            safeTargets = rawTargets
        }

        // --- 9. Apply signal quality weighting ---
        let adaptationStrength = computeAdaptationStrength(
            signalQuality: signalQuality,
            dataState: dataState
        )

        let qualityWeightedTargets: AudioTargets
        if adaptationStrength < 1.0 {
            // Blend between current output (no change) and computed targets
            qualityWeightedTargets = interpolateTargets(
                from: currentOutput,
                to: safeTargets,
                fraction: adaptationStrength
            )
        } else {
            qualityWeightedTargets = safeTargets
        }

        // --- 10. Slew rate limit ---
        let dt = Theme.Audio.ControlLoop.intervalSeconds
        let slewLimited = applySlewRateLimit(
            current: currentOutput,
            target: qualityWeightedTargets,
            dt: dt
        )

        // --- 11. Update state and write to audio ---
        currentOutput = slewLimited
        writeToAudioParameters(slewLimited)

        // --- 12. Publish snapshot ---
        let snapshot = BiometricSnapshot(
            state: state,
            hrSmoothed: hrSmoothed,
            hrNormalized: hrNormalized,
            trend: trend,
            trendMagnitude: trendMag,
            targets: slewLimited,
            timestamp: now
        )
        snapshotContinuation?.yield(snapshot)
    }

    // MARK: - Data Freshness

    private enum DataFreshness {
        case fresh
        case frozen
        case drifting(fraction: Double)
    }

    private func classifyDataFreshness(age: TimeInterval) -> DataFreshness {
        let freezeTimeout = Theme.Audio.DataDropout.freezeTimeoutSeconds
        let driftTimeout = Theme.Audio.DataDropout.driftTimeoutSeconds

        if age <= freezeTimeout {
            return .fresh
        } else if age <= driftTimeout {
            // Linear interpolation through the drift window
            let driftDuration = driftTimeout - freezeTimeout
            let elapsed = age - freezeTimeout
            let fraction = min(elapsed / driftDuration, 1.0)
            return .drifting(fraction: fraction)
        } else {
            // Past drift timeout — fully drifted, hold neutral
            return .drifting(fraction: 1.0)
        }
    }

    // MARK: - Signal Quality

    private func computeAdaptationStrength(
        signalQuality: Double,
        dataState: DataFreshness
    ) -> Double {
        switch dataState {
        case .fresh:
            // adaptation_strength = base * signalQuality
            return signalQuality
        case .frozen:
            return 0.0
        case .drifting:
            // Drift targets are already computed — apply fully
            return 1.0
        }
    }

    // MARK: - Slew Rate Limiting

    /// Apply per-parameter slew rate limiting.
    /// `parameter[t] = parameter[t-1] + clamp(target - current, -maxDelta*dt, +maxDelta*dt)`
    private func applySlewRateLimit(
        current: AudioTargets,
        target: AudioTargets,
        dt: TimeInterval
    ) -> AudioTargets {
        let slew = Theme.Audio.SlewRate.self
        return AudioTargets(
            beatFrequency: slewLimit(
                current: current.beatFrequency,
                target: target.beatFrequency,
                maxRate: slew.beatFrequencyMax,
                dt: dt
            ),
            carrierFrequency: slewLimit(
                current: current.carrierFrequency,
                target: target.carrierFrequency,
                maxRate: slew.carrierFrequencyMax,
                dt: dt
            ),
            binauralAmplitude: slewLimit(
                current: current.binauralAmplitude,
                target: target.binauralAmplitude,
                maxRate: slew.amplitudeMax,
                dt: dt
            ),
            ambientLevel: slewLimit(
                current: current.ambientLevel,
                target: target.ambientLevel,
                maxRate: slew.ambientLevelMax,
                dt: dt
            ),
            melodicLevel: slewLimit(
                current: current.melodicLevel,
                target: target.melodicLevel,
                maxRate: slew.melodicLevelMax,
                dt: dt
            ),
            harmonicContent: slewLimit(
                current: current.harmonicContent,
                target: target.harmonicContent,
                maxRate: slew.harmonicContentMax,
                dt: dt
            )
        )
    }

    /// Clamp the change from `current` toward `target` to `maxRate * dt`.
    private func slewLimit(
        current: Double,
        target: Double,
        maxRate: Double,
        dt: TimeInterval
    ) -> Double {
        let maxDelta = maxRate * dt
        let delta = target - current
        let clampedDelta = min(max(delta, -maxDelta), maxDelta)
        return current + clampedDelta
    }

    // MARK: - Interpolation

    /// Linear interpolation between two AudioTargets.
    private func interpolateTargets(
        from a: AudioTargets,
        to b: AudioTargets,
        fraction t: Double
    ) -> AudioTargets {
        let t = min(max(t, 0.0), 1.0)
        return AudioTargets(
            beatFrequency: a.beatFrequency + (b.beatFrequency - a.beatFrequency) * t,
            carrierFrequency: a.carrierFrequency + (b.carrierFrequency - a.carrierFrequency) * t,
            binauralAmplitude: a.binauralAmplitude + (b.binauralAmplitude - a.binauralAmplitude) * t,
            ambientLevel: a.ambientLevel + (b.ambientLevel - a.ambientLevel) * t,
            melodicLevel: a.melodicLevel + (b.melodicLevel - a.melodicLevel) * t,
            harmonicContent: a.harmonicContent + (b.harmonicContent - a.harmonicContent) * t
        )
    }

    // MARK: - Audio Parameter Bridge

    /// Write computed targets to the lock-free AudioParameters store.
    /// This is the only point where the biometric domain touches the audio domain.
    private func writeToAudioParameters(_ targets: AudioTargets) {
        audioParameters.beatFrequency = targets.beatFrequency
        audioParameters.carrierFrequency = targets.carrierFrequency
        audioParameters.binauralVolume = targets.binauralAmplitude
        audioParameters.ambientVolume = targets.ambientLevel
        audioParameters.melodicVolume = targets.melodicLevel
    }

    // MARK: - Session Progress

    private func computeSessionProgress(now: Date) -> Double {
        guard let start = sessionStartTime, sessionDuration > 0 else { return 0.0 }
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / sessionDuration, 0.0), 1.0)
    }

    // MARK: - Energize Safety Guardrails

    /// Apply all Energize-mode safety guardrails to the computed targets.
    /// Guardrails are evaluated in priority order (hard stop > ceiling > HRV >
    /// rate-of-change > session cap > cool-down). Multiple guardrails can fire
    /// simultaneously; the most restrictive modification wins.
    ///
    /// All threshold values come from `Theme.Audio.Safety` tokens.
    private func applyEnergizeSafetyGuardrails(
        targets: AudioTargets,
        hrSmoothed: Double,
        hrv: Double?,
        sessionProgress: Double,
        now: Date
    ) -> AudioTargets {
        let safety = Theme.Audio.Safety.self
        var modified = targets

        // --- Capture session-baseline HRV from the first valid reading ---
        if let hrv, !sessionBaselineHRVLocked {
            sessionBaselineHRV = hrv
            sessionBaselineHRVLocked = true
        }

        // --- Track HR rate-of-change over 60-second window ---
        updateHRRateOfChangeTracking(hrSmoothed: hrSmoothed, now: now)

        // --- 1. HR Hard Stop (HIGHEST PRIORITY) ---
        // If HR > hrHardStopBPM OR HR > hrHardStopFractionOfMax * (220 - age)
        let agePredictedMax = 220.0 - Double(userAge)
        let hardStopThreshold = min(
            safety.hrHardStopBPM,
            safety.hrHardStopFractionOfMax * agePredictedMax
        )
        if hrSmoothed > hardStopThreshold {
            // Emergency: drop to theta immediately (Sleep start = theta onset)
            modified.beatFrequency = Theme.Audio.ModeDefaults.Sleep.beatFrequencyStart
            emitSafetyEvent(.hrHardStop(currentHR: hrSmoothed))
            return modified
        }

        // --- 2. HR Ceiling ---
        // If HR > baseline + hrCeilingAboveBaseline OR HR > 100
        let ceilingThreshold = min(restingHR + safety.hrCeilingAboveBaseline, 100.0)
        if hrSmoothed > ceilingThreshold {
            // Ramp to calming alpha frequencies
            let alphaFrequency = Theme.Audio.Neutral.beatFrequency
            modified.beatFrequency = alphaFrequency
            emitSafetyEvent(.hrCeilingBreached(currentHR: hrSmoothed))
        }

        // --- 3. HRV Floor ---
        // If RMSSD < hrvFloor -> back off stimulation
        if let hrv, hrv < safety.hrvFloor {
            // Reduce beat frequency toward low end of range
            let backOffTarget = Theme.Audio.ModeDefaults.Energize.beatFrequencyMin
            modified.beatFrequency = min(modified.beatFrequency, backOffTarget)
            emitSafetyEvent(.hrvFloorBreached(rmssd: hrv))
        }

        // --- 4. HRV Crash ---
        // If RMSSD drops > hrvCrashThreshold from session baseline
        if let hrv, let baseline = sessionBaselineHRV, baseline > 0 {
            let dropFraction = (baseline - hrv) / baseline
            if dropFraction > safety.hrvCrashThreshold {
                // Reduce frequency by 3 Hz immediately
                modified.beatFrequency -= 3.0
                modified.beatFrequency = max(
                    modified.beatFrequency,
                    Theme.Audio.ModeDefaults.Energize.beatFrequencyMin
                )
                emitSafetyEvent(.hrvCrash(rmssd: hrv, sessionBaseline: baseline))
            }
        }

        // --- 5. Rate-of-Change ---
        // If HR rises > hrRateOfChangeLimit BPM within 60 sec -> freeze escalation
        if frequencyEscalationFrozen {
            // Don't allow beat frequency to rise above current output
            modified.beatFrequency = min(modified.beatFrequency, currentOutput.beatFrequency)
        }

        // --- 6. Session Time Cap ---
        let maxSessionSeconds = safety.maxSessionMinutes * 60.0
        if let start = sessionStartTime {
            let elapsed = now.timeIntervalSince(start)
            if elapsed >= maxSessionSeconds {
                emitSafetyEvent(.sessionTimeCap)
                // Force into cool-down territory
                inMandatoryCoolDown = true
            }
        }

        // --- 7. Cool-Down ---
        // Final coolDownMinutes of every Energize session auto-tapers. Non-skippable.
        let coolDownFraction = (safety.coolDownMinutes * 60.0) / (safety.maxSessionMinutes * 60.0)
        let coolDownStart = 1.0 - coolDownFraction
        if sessionProgress >= coolDownStart {
            if !coolDownEventEmitted {
                emitSafetyEvent(.coolDownStarted)
                coolDownEventEmitted = true
            }
            inMandatoryCoolDown = true

            // Taper beat frequency toward alpha over cool-down duration
            let coolDownProgress = (sessionProgress - coolDownStart) / coolDownFraction
            let clampedProgress = min(max(coolDownProgress, 0.0), 1.0)
            let alphaTarget = Theme.Audio.Neutral.beatFrequency
            // swiftlint:disable:next shorthand_operator
            modified.beatFrequency = modified.beatFrequency + (alphaTarget - modified.beatFrequency) * clampedProgress

            // If cool-down is complete, end the session
            if clampedProgress >= 1.0 {
                forceStopSession()
            }
        }

        return modified
    }

    /// Track HR values over a 60-second sliding window for rate-of-change detection.
    private func updateHRRateOfChangeTracking(hrSmoothed: Double, now: Date) {
        let safety = Theme.Audio.Safety.self

        if let previousHR = hrOneMinuteAgo, let previousTime = hrOneMinuteAgoTimestamp {
            let elapsed = now.timeIntervalSince(previousTime)
            if elapsed >= 60.0 {
                let delta = hrSmoothed - previousHR
                if delta > safety.hrRateOfChangeLimit {
                    frequencyEscalationFrozen = true
                    emitSafetyEvent(.hrRateOfChangeLimitHit(deltaBPM: delta))
                } else {
                    // Unfreeze if the rate is back under the limit
                    frequencyEscalationFrozen = false
                }
                // Reset window
                hrOneMinuteAgo = hrSmoothed
                hrOneMinuteAgoTimestamp = now
            }
        } else {
            // First reading — initialize the window
            hrOneMinuteAgo = hrSmoothed
            hrOneMinuteAgoTimestamp = now
        }
    }

    /// Emit a safety event to subscribers. Deduplication is left to the UI layer.
    private func emitSafetyEvent(_ event: SafetyEvent) {
        safetyEventContinuation?.yield(event)
    }
}
