// SessionViewModel.swift
// BioNaural
//
// @Observable view model driving the session screen. Coordinates the audio
// engine, biometric processing, session timing, Pomodoro cycling, Energize
// safety guardrails, and manual frequency adjustment. All thresholds and
// durations from Theme and Constants tokens.

import SwiftUI
import BioNauralShared
import OSLog

// MARK: - EnergizePhase

/// Discrete phase within an Energize session.
enum EnergizePhase: String, Sendable {
    case warmUp
    case ramp
    case sustain
    case coolDown
    case completed

    var displayName: String {
        switch self {
        case .warmUp:    return "Warming Up"
        case .ramp:      return "Ramping"
        case .sustain:   return "Energizing"
        case .coolDown:  return "Cooling Down"
        case .completed: return "Complete"
        }
    }
}

// MARK: - SafetyAlert

/// A safety condition surfaced to the user during Energize sessions.
struct SafetyAlert: Identifiable, Sendable {
    let id = UUID()
    let message: String
    let severity: Severity

    enum Severity: Sendable {
        case caution
        case warning
        case critical
    }
}

// MARK: - PomodoroState

/// Tracks the current position within a Pomodoro cycle.
struct PomodoroState: Sendable {
    var currentCycle: Int = 1
    var totalCycles: Int = Constants.defaultPomodoroCycles
    var isBreak: Bool = false

    var phaseLabel: String {
        if isBreak {
            return "Break \(currentCycle)/\(totalCycles)"
        }
        return "Focus \(currentCycle)/\(totalCycles)"
    }
}

// MARK: - SessionViewModel

@Observable
@MainActor
final class SessionViewModel {

    // MARK: - Published State

    /// Current heart rate from biometric processing (BPM).
    private(set) var currentHR: Double = 0

    /// Current heart-rate variability (ms).
    private(set) var currentHRV: Double = 0

    /// Current binaural beat frequency (Hz).
    private(set) var currentBeatFrequency: Double = 0

    /// Current biometric activation state.
    private(set) var currentState: BiometricState = .calm

    /// The session's focus mode.
    private(set) var sessionMode: FocusMode

    /// Seconds elapsed since session start.
    private(set) var elapsedTime: TimeInterval = 0

    /// Whether audio is actively playing.
    private(set) var isPlaying: Bool = false

    /// Whether the session is running in adaptive (biometric-driven) mode.
    private(set) var isAdaptiveMode: Bool = false

    /// Number of adaptive frequency changes during this session.
    private(set) var adaptationCount: Int = 0

    /// Pre-session check-in mood (0 = wired, 1 = calm). `nil` if skipped.
    var checkInMood: Double?

    /// Pre-session check-in goal. `nil` if skipped.
    var checkInGoal: FocusMode?

    /// Active safety alert for Energize mode. `nil` when safe.
    private(set) var safetyAlert: SafetyAlert?

    /// Current phase of an Energize session.
    private(set) var energizePhase: EnergizePhase = .warmUp

    /// Pomodoro state (Focus mode with Pomodoro enabled).
    private(set) var pomodoroState: PomodoroState?

    /// Whether the sleep-mode screen blanking is active.
    private(set) var isSleepBlanked: Bool = false

    /// Whether the session has ended (triggers post-session summary).
    private(set) var isSessionComplete: Bool = false

    /// Ordered adaptation events recorded during this session.
    private(set) var adaptationEvents: [AdaptationEventRecord] = []

    /// Head stillness score from AirPods motion tracking.
    /// 0.0 = very still (deep focus), 1.0 = lots of movement (distracted).
    /// `nil` when AirPods are not connected or do not support motion.
    private(set) var headStillnessScore: Double?

    // MARK: - Private State

    private var sessionTimer: Timer?
    private var sessionStartDate: Date?
    private var targetDurationSeconds: TimeInterval
    private var pomodoroPhaseEndTime: TimeInterval = 0

    /// Accumulated seconds where the user has been in `.calm` state with
    /// HR below `Theme.Audio.SleepDetection.hrCeilingBPM`. Reset to zero
    /// whenever the condition breaks. Used only in Sleep mode.
    private var sleepCalmAccumulatedSeconds: TimeInterval = 0

    /// Audio engine reference (injected). Exposed for mix level bindings.
    let audioEngine: AudioEngineProtocol

    /// Head motion service reference (injected). Tracks AirPods stillness.
    private let headMotionService: (any HeadMotionServiceProtocol)?

    deinit {
        // Invalidate timer to remove it from the RunLoop. The [weak self]
        // closure prevents crashes, but an orphaned timer still consumes
        // RunLoop cycles until invalidated.
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Initialization

    init(
        mode: FocusMode,
        durationMinutes: Int,
        isAdaptive: Bool,
        pomodoroEnabled: Bool,
        audioEngine: AudioEngineProtocol,
        headMotionService: (any HeadMotionServiceProtocol)? = nil
    ) {
        self.sessionMode = mode
        self.targetDurationSeconds = TimeInterval(durationMinutes * 60)
        self.isAdaptiveMode = isAdaptive
        self.audioEngine = audioEngine
        self.headMotionService = headMotionService
        self.currentBeatFrequency = mode.defaultBeatFrequency

        if pomodoroEnabled && mode == .focus {
            self.pomodoroState = PomodoroState()
            self.pomodoroPhaseEndTime = TimeInterval(Constants.pomodoroFocusMinutes * 60)
        }

        if mode == .energize {
            self.energizePhase = .warmUp
        }
    }

    // MARK: - Session Lifecycle

    /// Starts the session: configures audio, begins timer, starts playback.
    func startSession() {
        guard !isPlaying else { return }

        do {
            try audioEngine.setup()
            try audioEngine.start(mode: sessionMode)
        } catch {
            Logger.audio.error("Session audio start failed: \(error.localizedDescription)")
        }

        sessionStartDate = Date()
        isPlaying = true
        elapsedTime = 0

        // Start AirPods head motion tracking (degrades gracefully if unavailable).
        headMotionService?.startTracking()

        startTimer()
    }

    /// Stops the session: halts audio, stops timer, records final state.
    func stopSession() {
        if sessionMode == .energize && energizePhase != .coolDown && energizePhase != .completed {
            // Force a minimum cool-down before fully stopping.
            beginCoolDown()
            return
        }

        audioEngine.stop()
        headMotionService?.stopTracking()
        isPlaying = false
        stopTimer()
        isSessionComplete = true
    }

    /// Pauses playback and timing.
    func pause() {
        guard isPlaying else { return }
        audioEngine.pause()
        isPlaying = false
        stopTimer()
    }

    /// Resumes playback and timing.
    func resume() {
        guard !isPlaying else { return }
        audioEngine.resume()
        isPlaying = true
        startTimer()
    }

    /// Manually adjusts the binaural beat frequency within the mode's range.
    ///
    /// - Parameter frequency: The desired beat frequency in Hz.
    func adjustFrequency(to frequency: Double) {
        let clamped = min(max(frequency, sessionMode.frequencyRange.lowerBound),
                          sessionMode.frequencyRange.upperBound)
        currentBeatFrequency = clamped
        audioEngine.parameters.beatFrequency = clamped
    }

    /// Wakes the display during sleep mode (reveals data for a few seconds).
    func revealData() {
        guard sessionMode == .sleep else { return }
        isSleepBlanked = false
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Theme.Animation.Duration.tapToRevealDismiss
        ) { [weak self] in
            self?.isSleepBlanked = true
        }
    }

    // MARK: - Biometric Updates (called by BiometricProcessor)

    /// Ingests a new biometric reading from the processing pipeline.
    func updateBiometrics(
        heartRate: Double,
        hrv: Double?,
        state: BiometricState,
        beatFrequency: Double
    ) {
        let oldFrequency = currentBeatFrequency

        currentHR = heartRate
        if let hrv { currentHRV = hrv }
        currentState = state
        currentBeatFrequency = beatFrequency

        // Record adaptation event if frequency changed.
        let threshold = Theme.Audio.SlewRate.beatFrequencyMax * Theme.Audio.ControlLoop.intervalSeconds
        if abs(beatFrequency - oldFrequency) > threshold {
            adaptationCount += 1
            let event = AdaptationEventRecord(
                timestamp: elapsedTime,
                reason: "Biometric adaptation",
                oldBeatFrequency: oldFrequency,
                newBeatFrequency: beatFrequency,
                heartRateAtTime: heartRate
            )
            adaptationEvents.append(event)
        }

        // Energize safety checks.
        if sessionMode == .energize {
            evaluateEnergizeSafety(heartRate: heartRate, hrv: hrv)
        }

        // Sleep detection: track sustained calm + low HR.
        if sessionMode == .sleep {
            evaluateSleepDetection(heartRate: heartRate, state: state)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        sessionTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    private func tick() {
        elapsedTime += 1

        // Read latest head stillness score from AirPods motion service.
        headStillnessScore = headMotionService?.stillnessScore

        // Pomodoro phase cycling.
        if let pomo = pomodoroState {
            if elapsedTime >= pomodoroPhaseEndTime {
                cyclePomodoro(pomo)
            }
        }

        // Energize phase progression.
        if sessionMode == .energize {
            updateEnergizePhase()
        }

        // Sleep mode auto-dim.
        if sessionMode == .sleep {
            let dimThreshold = Theme.Animation.Duration.sleepAutoDim
            if elapsedTime >= dimThreshold && !isSleepBlanked {
                isSleepBlanked = true
            }
        }

        // Session end check.
        if elapsedTime >= targetDurationSeconds {
            if sessionMode == .energize && energizePhase != .coolDown {
                beginCoolDown()
            } else {
                stopSession()
            }
        }
    }

    // MARK: - Pomodoro Cycling

    private func cyclePomodoro(_ state: PomodoroState) {
        var next = state

        if state.isBreak {
            // Break ended, start next focus block.
            next.isBreak = false
            next.currentCycle += 1

            if next.currentCycle > state.totalCycles {
                // All cycles complete.
                pomodoroState = nil
                stopSession()
                return
            }

            pomodoroPhaseEndTime = elapsedTime + TimeInterval(Constants.pomodoroFocusMinutes * 60)
        } else {
            // Focus ended, start break.
            next.isBreak = true
            pomodoroPhaseEndTime = elapsedTime + TimeInterval(Constants.pomodoroBreakMinutes * 60)
        }

        pomodoroState = next
    }

    // MARK: - Energize Phase Management

    private func updateEnergizePhase() {
        let minutesElapsed = elapsedTime / 60.0

        switch energizePhase {
        case .warmUp:
            if minutesElapsed >= Theme.Audio.Safety.warmUpMinutes {
                energizePhase = .ramp
            }
        case .ramp:
            if minutesElapsed >= Theme.Audio.Safety.rampPhaseEndMinutes {
                energizePhase = .sustain
            }
        case .sustain:
            let maxMinutes = Theme.Audio.Safety.maxSessionMinutes
            let coolDownStart = maxMinutes - Theme.Audio.Safety.coolDownMinutes
            if minutesElapsed >= coolDownStart {
                beginCoolDown()
            }
        case .coolDown, .completed:
            break
        }
    }

    private func beginCoolDown() {
        energizePhase = .coolDown
        let coolDownDuration = Theme.Audio.Safety.coolDownMinutes * 60
        targetDurationSeconds = elapsedTime + coolDownDuration
    }

    // MARK: - Computed Presentation Helpers

    /// The Pomodoro cycle label (e.g. "Focus 1/4"), or `nil` if Pomodoro is not active.
    var pomodoroCycleLabel: String? {
        pomodoroState?.phaseLabel
    }

    /// The Energize phase label (e.g. "Warming Up"), or `nil` if not an Energize session.
    var energizePhaseLabel: String? {
        guard sessionMode == .energize else { return nil }
        return energizePhase.displayName
    }

    /// Whether the Energize session is currently in the cool-down phase.
    var isEnergizePhaseCoolDown: Bool {
        sessionMode == .energize && energizePhase == .coolDown
    }

    /// Display name for the session, switching to "Cool-down" during mandatory cool-down.
    var sessionDisplayName: String {
        if isInMandatoryCoolDown {
            return "Cool-down"
        }
        return sessionMode.displayName
    }

    /// Whether the session is running in manual (non-adaptive) mode.
    var isManualMode: Bool {
        !isAdaptiveMode
    }

    /// Whether the session is in a mandatory Energize cool-down.
    var isInMandatoryCoolDown: Bool {
        sessionMode == .energize && energizePhase == .coolDown
    }

    /// Cool-down progress from 0.0 (just started) to 1.0 (complete).
    var coolDownProgress: Double {
        guard isInMandatoryCoolDown else { return 0.0 }
        let coolDownDuration = Theme.Audio.Safety.coolDownMinutes * 60
        guard coolDownDuration > 0 else { return 1.0 }
        let coolDownStartTime = targetDurationSeconds - coolDownDuration
        let elapsed = elapsedTime - coolDownStartTime
        return min(max(elapsed / coolDownDuration, 0.0), 1.0)
    }

    /// Formatted remaining cool-down time (e.g. "1:30"), or `nil` if not in cool-down.
    var formattedCoolDownRemaining: String? {
        guard isInMandatoryCoolDown else { return nil }
        let remaining = max(targetDurationSeconds - elapsedTime, 0)
        return formatTimeInterval(remaining)
    }

    /// Formatted remaining session time (e.g. "24:15"), or `nil` if untimed.
    var formattedRemainingTime: String? {
        guard targetDurationSeconds > 0 else { return nil }
        let remaining = max(targetDurationSeconds - elapsedTime, 0)
        return formatTimeInterval(remaining)
    }

    /// Formatted elapsed time (e.g. "5:30").
    var formattedElapsedTime: String {
        formatTimeInterval(elapsedTime)
    }

    /// Whether Pomodoro is active and currently in a break phase.
    var isPomodoroBreak: Bool {
        pomodoroState?.isBreak ?? false
    }

    /// Formatted heart rate string (e.g. "72").
    var formattedHeartRate: String {
        String(format: "%.0f", currentHR)
    }

    /// Formatted HRV string (e.g. "45 ms"), or `nil` if no HRV data.
    var formattedHRV: String? {
        guard currentHRV > 0 else { return nil }
        return String(format: "%.0f ms", currentHRV)
    }

    /// Formatted beat frequency string (e.g. "15.0 Hz").
    var formattedBeatFrequency: String {
        String(format: "%.1f Hz", currentBeatFrequency)
    }

    /// Formatted head stillness string (e.g. "92% still"), or `nil` if unavailable.
    var formattedStillness: String? {
        guard let score = headStillnessScore else { return nil }
        let stillnessPercent = Int(round((1.0 - score) * 100))
        return "\(stillnessPercent)% still"
    }

    /// Whether head motion data is available from AirPods.
    var isHeadMotionAvailable: Bool {
        headStillnessScore != nil
    }

    /// Whether biometric data should be visible.
    /// In sleep mode, data is hidden when the screen is blanked. Otherwise always visible.
    var isDataVisible: Bool {
        if sessionMode == .sleep {
            return !isSleepBlanked
        }
        return true
    }

    /// The theme color for the current session mode.
    var modeColor: Color {
        Color.modeColor(for: sessionMode)
    }

    /// Target session duration in minutes (for settings UI).
    var targetDurationMinutes: Double {
        targetDurationSeconds / 60.0
    }

    /// Adjusts the target session duration mid-session.
    func adjustDuration(minutes: Double) {
        let clamped = min(max(minutes, Double(Constants.minimumSessionMinutes)), Double(Constants.maxSessionMinutes))
        targetDurationSeconds = clamped * 60.0
    }

    // MARK: - Actions

    /// Toggles between pause and resume.
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Adjusts the manual beat frequency by a relative delta (Hz).
    func adjustManualFrequency(by delta: Double) {
        adjustFrequency(to: currentBeatFrequency + delta)
    }

    /// Dismisses the current safety alert.
    func dismissSafetyAlert() {
        safetyAlert = nil
    }

    /// Switches the ambient soundscape bed during a session.
    ///
    /// - Parameter bedName: The ambient bed identifier (e.g. "rain", "wind").
    func selectSoundscape(_ bedName: String) {
        audioEngine.selectSoundscape(bedName)
    }

    // MARK: - Formatting Helpers

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Energize Safety

    private func evaluateEnergizeSafety(heartRate: Double, hrv: Double?) {
        // Hard stop: absolute HR ceiling.
        if heartRate >= Theme.Audio.Safety.hrHardStopBPM {
            safetyAlert = SafetyAlert(
                message: "Heart rate is very high. Session will cool down now.",
                severity: .critical
            )
            beginCoolDown()
            return
        }

        // HRV floor check.
        if let hrv, hrv < Theme.Audio.Safety.hrvFloor {
            safetyAlert = SafetyAlert(
                message: "HRV dropped below safe threshold. Transitioning to cool-down.",
                severity: .warning
            )
            beginCoolDown()
            return
        }

        // Dismiss stale alerts after banner duration.
        if safetyAlert != nil {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Theme.Animation.Duration.safetyBannerDismiss
            ) { [weak self] in
                self?.safetyAlert = nil
            }
        }
    }

    // MARK: - Sleep Detection

    /// Checks whether the user appears to have fallen asleep during a Sleep
    /// session by tracking sustained calm biometric state with low heart rate.
    ///
    /// When the user stays in `.calm` state with HR below the detection
    /// ceiling for the required duration, the session auto-stops (which
    /// triggers the audio engine's graceful fade-out).
    private func evaluateSleepDetection(heartRate: Double, state: BiometricState) {
        let ceiling = Theme.Audio.SleepDetection.hrCeilingBPM
        let requiredDuration = Theme.Audio.SleepDetection.sustainedCalmDurationSeconds

        if state == .calm && heartRate > 0 && heartRate < ceiling {
            // Biometric updates arrive ~1 Hz from the Watch pipeline,
            // so each call represents roughly one second of elapsed time.
            sleepCalmAccumulatedSeconds += Theme.Audio.ControlLoop.intervalSeconds

            if sleepCalmAccumulatedSeconds >= requiredDuration {
                stopSession()
            }
        } else {
            // Condition broken — reset the accumulator.
            sleepCalmAccumulatedSeconds = 0
        }
    }

    // MARK: - Biometric Adaptive Feedback

    // Target HR ranges per mode (what we're trying to achieve)
    private var targetHRRange: ClosedRange<Double> {
        switch sessionMode {
        case .sleep:       return 45...55   // Deep sleep HR target
        case .relaxation:  return 55...65   // Relaxed resting HR
        case .focus:       return 60...72   // Alert but calm
        case .energize:    return 100...140 // Active workout zone
        }
    }

    // Target HRV ranges (higher = more relaxed parasympathetic activity)
    private var targetHRVRange: ClosedRange<Double> {
        switch sessionMode {
        case .sleep:       return 50...80   // High HRV = deep parasympathetic
        case .relaxation:  return 40...70
        case .focus:       return 35...55
        case .energize:    return 10...30   // Low HRV during exercise is normal
        }
    }

    /// Baseline HR (user's resting). In production, read from HealthKit.
    private let baselineHR: Double = 65

    /// Inject a simulated biometric reading and apply CORRECTIVE feedback.
    ///
    /// The adaptive engine compares current biometrics against the target
    /// range for the active mode. If the user is outside the target, the
    /// audio parameters are adjusted to STEER them back:
    ///
    /// - Sleep: HR too high → lower beat frequency (deeper theta/delta),
    ///   increase ambient volume, slower carrier to encourage settling
    /// - Focus: HR too high → lower frequency to calm; HR too low → raise
    ///   frequency to increase alertness
    /// - Energize: HR too low → raise frequency and volume to motivate
    func injectSimulatedBiometric(hr: Double, hrv: Double) {
        currentHR = hr
        currentHRV = hrv

        // Classify biometric state
        let state: BiometricState
        if hr > 120 { state = .peak }
        else if hr > 90 { state = .elevated }
        else if hr > 70 { state = .focused }
        else { state = .calm }
        currentState = state

        // === DEVIATION from target — how far off are we? ===
        let targetMidHR = (targetHRRange.lowerBound + targetHRRange.upperBound) / 2
        let hrDeviation = hr - targetMidHR // positive = too high, negative = too low
        let hrDeviationNormalized = hrDeviation / 40.0 // normalized to ±1 range

        let targetMidHRV = (targetHRVRange.lowerBound + targetHRVRange.upperBound) / 2
        let hrvDeviation = hrv - targetMidHRV

        let isInTargetHR = targetHRRange.contains(hr)
        let isAboveTarget = hr > targetHRRange.upperBound
        let isBelowTarget = hr < targetHRRange.lowerBound

        // === CORRECTIVE BEAT FREQUENCY ===
        // The key insight: the beat frequency should LEAD the user toward
        // the target state, not mirror their current state.
        let beatFreq: Double
        switch sessionMode {
        case .sleep:
            if isInTargetHR {
                // In target — maintain deep delta for sustained sleep
                beatFreq = 2.5
            } else if isAboveTarget {
                // HR too high (restless) — use theta (6 Hz) to calm down,
                // then ramp toward delta as HR drops
                let urgency = min(1, abs(hrDeviationNormalized))
                beatFreq = 2.5 + urgency * 4.0 // 2.5→6.5 Hz (delta→theta)
            } else {
                // HR below target (very deep) — maintain delta
                beatFreq = 2.0
            }

        case .relaxation:
            if isInTargetHR {
                // In target — sustain alpha 10 Hz
                beatFreq = 10.0
            } else if isAboveTarget {
                // Too activated — start at user's level then guide down
                // "Pace and lead": meet them at 12 Hz, guide to 8 Hz
                let urgency = min(1, abs(hrDeviationNormalized))
                beatFreq = 10.0 + urgency * 2.0 // 10→12 Hz (meet then lead)
            } else {
                beatFreq = 9.0 // Slightly deeper alpha
            }

        case .focus:
            if isInTargetHR {
                // In target — steady beta 15 Hz
                beatFreq = 15.0
            } else if isAboveTarget {
                // Too distracted/anxious — lower to SMR (12-14 Hz) to calm
                beatFreq = 13.0
            } else {
                // Too drowsy — raise to high beta (16-18 Hz) to sharpen
                beatFreq = 17.0
            }

        case .energize:
            if isInTargetHR {
                // In target — maintain high beta/gamma
                beatFreq = 25.0
            } else if isBelowTarget {
                // Not activated enough — push higher (gamma 30+ Hz)
                let urgency = min(1, abs(hrDeviationNormalized))
                beatFreq = 25.0 + urgency * 10.0 // 25→35 Hz
            } else {
                // Over target (safety) — back off slightly
                beatFreq = 20.0
            }
        }

        // Apply beat frequency with slew rate limiting (max 0.3 Hz/s, ~0.9 Hz per 3s reading)
        let maxChange = 0.9 // Max change per 3-second reading interval
        let currentFreq = audioEngine.parameters.beatFrequency
        let clampedFreq = max(currentFreq - maxChange, min(currentFreq + maxChange, beatFreq))
        audioEngine.parameters.beatFrequency = clampedFreq
        currentBeatFrequency = clampedFreq

        // === CORRECTIVE CARRIER FREQUENCY ===
        // Lower carrier = warmer/calming, higher = brighter/alerting
        let carrierAdjust: Double
        if sessionMode == .sleep || sessionMode == .relaxation {
            carrierAdjust = isAboveTarget ? -20.0 : 0 // Warmer to calm
        } else if sessionMode == .energize {
            carrierAdjust = isBelowTarget ? 30.0 : 0 // Brighter to energize
        } else {
            carrierAdjust = 0
        }
        let baseCarrier = audioEngine.parameters.carrierFrequency
        audioEngine.parameters.carrierFrequency = max(100, min(600, baseCarrier + carrierAdjust * 0.1))

        // Volume levels (ambient, melodic, binaural sliders) are
        // user-controlled and must NOT be overridden by the adaptive
        // engine. Only beat frequency and carrier are adjusted here.
    }
}
