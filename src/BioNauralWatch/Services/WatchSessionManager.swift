// WatchSessionManager.swift
// BioNauralWatch
//
// Coordinates the workout session, WatchConnectivity, and adaptive
// algorithm on Watch. Supports both companion mode (iPhone drives
// adaptation, Watch streams HR) and standalone mode (Watch runs the
// adaptive algorithm locally).
//
// Integrates the Watch audio engine, adaptation engine, pause/resume,
// and post-session flow.

import Foundation
import BioNauralShared
import SwiftUI
@preconcurrency import WatchConnectivity
import HealthKit
import WatchKit
import os

/// Central coordinator for the Watch app's session lifecycle.
///
/// Responsibilities:
/// - Owns `WatchHealthKitService` for HR streaming.
/// - Owns `WatchAudioEngine` for binaural beat playback.
/// - Owns `WatchAdaptationEngine` for real-time parameter mapping.
/// - Receives commands from iPhone via WCSession delegate.
/// - Can initiate sessions locally (standalone mode).
/// - In standalone mode: runs the adaptive algorithm on-Watch,
///   reads HR directly from local HealthKit, and syncs summary to iPhone
///   when connectivity is restored.
/// - Manages: start -> stream HR -> adapt audio -> detect stop ->
///   end workout -> build results -> show post-session -> sync to iPhone.
@MainActor
@Observable
final class WatchSessionManager: NSObject {

    // MARK: - Published State

    /// Whether a session is currently active.
    private(set) var isSessionActive: Bool = false

    /// The mode of the current session, if active.
    private(set) var activeMode: FocusMode?

    /// Elapsed time of the current session in seconds.
    private(set) var elapsedSeconds: TimeInterval = 0

    /// Current heart rate from the Watch sensor (BPM).
    private(set) var currentHeartRate: Double?

    /// Summary of the last completed session.
    private(set) var lastSessionSummary: WatchSessionSummary?

    /// Whether the Watch is running in standalone mode (no iPhone).
    private(set) var isStandaloneMode: Bool = false

    /// Whether the session is currently paused.
    private(set) var isPaused: Bool = false

    /// Current binaural beat frequency being produced (Hz).
    private(set) var currentBeatFrequency: Double = 0

    /// Results from the last completed session (for post-session view).
    private(set) var lastSessionResult: WatchSessionResult?

    /// Whether the post-session summary screen should be shown.
    private(set) var showPostSession: Bool = false

    /// Whether a battery warning alert should be shown.
    private(set) var showBatteryWarning: Bool = false

    /// The battery warning message, if applicable.
    private(set) var batteryWarningMessage: String = ""

    /// The mode pending behind a battery warning confirmation.
    private(set) var pendingSessionMode: FocusMode?
    private var pendingSessionDuration: Int?

    // MARK: - Dependencies

    private let healthKitService: WatchHealthKitService
    private let healthStore: HKHealthStore
    private let logger = Logger(subsystem: "com.bionaural.watch", category: "SessionManager")

    // MARK: - Audio

    private let audioEngine = WatchAudioEngine()
    private var adaptationEngine = WatchAdaptationEngine()
    private var adaptationTimer: Timer?

    // MARK: - Session State

    private var sessionStartDate: Date?
    private var elapsedTimer: Timer?
    private var targetDurationSeconds: TimeInterval?

    // MARK: - Breathing Haptics

    /// Adaptive breathing haptic cues for relaxation and sleep sessions.
    private let breathingHaptics = WatchBreathingHaptics()

    // MARK: - Standalone Adaptive State

    /// Simplified on-Watch heart rate analyzer for standalone sessions.
    private var heartRateAnalyzer: WatchHeartRateAnalyzer?

    /// Current biometric state classification for standalone mode.
    private(set) var currentBiometricState: BiometricState = .calm

    /// Count of biometric state transitions during the session.
    private var adaptationCount: Int = 0

    /// Heart rate at session start (for outcome recording).
    private var startHeartRate: Double?

    // MARK: - Adaptation Tracking

    /// Date when calm/deep state was first entered (for time-to-calm).
    private var calmEntryDate: Date?

    /// Accumulated seconds in deep biometric state.
    private var deepStateSeconds: TimeInterval = 0

    /// Time elapsed before first calm state was reached.
    private var timeToCalm: TimeInterval?

    /// All HR samples collected during the session (for average).
    private var hrSamples: [Double] = []

    // MARK: - Persistence Keys

    private enum StorageKey {
        static let lastSessionSummary = "com.bionaural.watch.lastSessionSummary"
    }

    // MARK: - Initialization

    override init() {
        let store = HKHealthStore()
        self.healthStore = store
        self.healthKitService = WatchHealthKitService(healthStore: store)
        super.init()

        loadLastSessionSummary()
        setupHealthKitCallbacks()
        activateWCSession()
    }

    // MARK: - Setup

    private func setupHealthKitCallbacks() {
        healthKitService.onHeartRateSample = { [weak self] sample in
            Task { @MainActor in
                self?.handleHeartRateSample(sample)
            }
        }
    }

    private func activateWCSession() {
        guard WCSession.isSupported() else {
            logger.info("WCSession not supported.")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        logger.info("WCSession activation requested from Watch.")
    }

    // MARK: - Start Session

    /// Starts a new session in the given mode.
    ///
    /// Determines whether to run in companion mode (iPhone reachable)
    /// or standalone mode (Watch only). In both cases, starts the
    /// HealthKit workout session for HR streaming, the audio engine,
    /// and the adaptation timer.
    ///
    /// - Parameters:
    ///   - mode: The focus mode to use.
    ///   - durationMinutes: Optional target duration in minutes.
    func startSession(mode: FocusMode, durationMinutes: Int?) {
        guard !isSessionActive else {
            logger.warning("Session already active — ignoring start.")
            return
        }

        // Battery safety check
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let battery = device.batteryLevel

        if battery >= 0 && battery < WatchDesign.Battery.blockThreshold {
            batteryWarningMessage = "Battery too low for a session. Charge your Watch first."
            showBatteryWarning = true
            return
        }

        if battery >= 0 && battery < WatchDesign.Battery.warningThreshold {
            pendingSessionMode = mode
            pendingSessionDuration = durationMinutes
            batteryWarningMessage = "Battery at \(Int(battery * 100))%. Session may end unexpectedly."
            showBatteryWarning = true
            return
        }

        activeMode = mode
        isSessionActive = true
        isPaused = false
        sessionStartDate = Date()
        elapsedSeconds = 0
        adaptationCount = 0
        startHeartRate = nil
        currentHeartRate = nil
        calmEntryDate = nil
        deepStateSeconds = 0
        timeToCalm = nil
        hrSamples = []
        currentBeatFrequency = mode.defaultBeatFrequency

        if let minutes = durationMinutes {
            targetDurationSeconds = TimeInterval(minutes * 60)
        } else {
            targetDurationSeconds = nil
        }

        // Determine mode: companion (iPhone drives) or standalone (Watch drives)
        let session = WCSession.default
        isStandaloneMode = !session.isReachable

        if !isStandaloneMode {
            // Send start command to iPhone
            sendCommandToiPhone(.start(mode))
        } else {
            // Initialize standalone adaptive state
            heartRateAnalyzer = WatchHeartRateAnalyzer()
            adaptationEngine = WatchAdaptationEngine()
            currentBiometricState = .calm
            logger.info("Starting standalone session — adaptive algorithm on Watch.")
        }

        // Start audio engine
        audioEngine.start(mode: mode)
        audioEngine.parameters.configure(for: mode)

        // Start adaptation timer at 10 Hz
        startAdaptationTimer()

        // Start workout + HR streaming
        Task {
            do {
                try await healthKitService.requestAuthorization()
                try await healthKitService.startWorkout()
            } catch {
                logger.error("Failed to start workout: \(error.localizedDescription, privacy: .public)")
                resetSessionState()
            }
        }

        startElapsedTimer()
        breathingHaptics.start(for: mode)
        logger.info("Session started: mode=\(mode.rawValue), standalone=\(self.isStandaloneMode)")
    }

    // MARK: - Battery Warning

    /// Called when user confirms they want to proceed despite low battery.
    func confirmBatteryWarning() {
        showBatteryWarning = false
        if let mode = pendingSessionMode {
            let duration = pendingSessionDuration
            pendingSessionMode = nil
            pendingSessionDuration = nil
            startSession(mode: mode, durationMinutes: duration)
        }
    }

    /// Called when user dismisses the battery warning.
    func dismissBatteryWarning() {
        showBatteryWarning = false
        pendingSessionMode = nil
        pendingSessionDuration = nil
    }

    // MARK: - Volume Control

    /// Sets the entrainment (binaural beat) volume via Digital Crown.
    ///
    /// - Parameter volume: Normalized volume [0.0 ... 1.0].
    func setEntrainmentVolume(_ volume: Double) {
        audioEngine.parameters.amplitude = volume
    }

    // MARK: - Pause Session

    /// Pauses the current session. Stops audio and adaptation but keeps
    /// the elapsed timer and HR streaming active.
    func pauseSession() {
        guard isSessionActive, !isPaused else { return }

        isPaused = true
        audioEngine.pause()
        stopAdaptationTimer()

        logger.info("Session paused.")
    }

    // MARK: - Resume Session

    /// Resumes a paused session. Restarts audio and adaptation timer.
    func resumeSession() {
        guard isSessionActive, isPaused else { return }

        isPaused = false
        audioEngine.resume()
        startAdaptationTimer()

        logger.info("Session resumed.")
    }

    // MARK: - Stop Session

    /// Stops the current session, saves the workout, builds session results,
    /// records the summary, and syncs to iPhone.
    func stopSession() {
        guard isSessionActive else { return }

        let endDate = Date()
        let duration = sessionStartDate.map { endDate.timeIntervalSince($0) } ?? elapsedSeconds
        let mode = activeMode ?? .focus

        stopElapsedTimer()
        stopAdaptationTimer()
        breathingHaptics.stop()
        audioEngine.stop()

        Task {
            await healthKitService.stopWorkout()

            // Build post-session result
            let averageHR: Double? = hrSamples.isEmpty ? nil : hrSamples.reduce(0, +) / Double(hrSamples.count)
            let hrDelta: Double?
            if let start = startHeartRate, let avg = averageHR {
                hrDelta = avg - start
            } else {
                hrDelta = nil
            }

            let result = WatchSessionResult(
                mode: mode,
                durationSeconds: duration,
                averageHR: averageHR,
                hrDelta: hrDelta,
                adaptationCount: adaptationCount,
                deepStateMinutes: deepStateSeconds / 60.0,
                timeToCalm: timeToCalm
            )

            lastSessionResult = result
            showPostSession = true

            // Record session summary (for idle screen last-session card)
            let summary = WatchSessionSummary(
                mode: mode,
                durationSeconds: duration,
                endDate: endDate
            )
            lastSessionSummary = summary
            saveLastSessionSummary(summary)

            // Update learning profile
            var profile = WatchLearningProfile.load()
            profile.recordSession(mode: mode, duration: duration, date: endDate)
            profile.save()

            // Sync summary to iPhone
            syncSessionSummaryToiPhone(
                mode: mode,
                duration: duration,
                startDate: sessionStartDate ?? endDate,
                endDate: endDate
            )

            if !isStandaloneMode {
                sendCommandToiPhone(.stop)
            }

            resetSessionState()
            logger.info("Session stopped: duration=\(Int(duration))s, mode=\(mode.rawValue)")
        }
    }

    // MARK: - Post-Session Dismissal

    /// Dismisses the post-session summary screen.
    func dismissPostSession() {
        showPostSession = false
        lastSessionResult = nil
    }

    // MARK: - Heart Rate Handling

    private func handleHeartRateSample(_ sample: BiometricSample) {
        currentHeartRate = sample.bpm

        // Collect for average calculation
        hrSamples.append(sample.bpm)

        if startHeartRate == nil {
            startHeartRate = sample.bpm
        }

        // Feed HR to breathing haptics for adaptation
        breathingHaptics.updateHeartRate(sample.bpm)

        // In standalone mode, run local adaptive classification
        if isStandaloneMode, var analyzer = heartRateAnalyzer {
            let previousState = currentBiometricState
            let newState = analyzer.classify(bpm: sample.bpm)

            // Write the mutated struct back so EMA state accumulates
            // across samples. Without this, the dual-EMA smoothing and
            // hysteresis dwell time reset on every sample.
            heartRateAnalyzer = analyzer

            if newState != previousState {
                currentBiometricState = newState
                adaptationCount += 1
                healthKitService.playAdaptationHaptic()
                logger.debug("Biometric state transition: \(previousState.rawValue) -> \(newState.rawValue)")
            }

            // Auto-stop breathing cues when sustained calm is reached
            _ = breathingHaptics.checkSustainedCalm(state: currentBiometricState)
        }
    }

    // MARK: - Adaptation Timer

    /// Starts the adaptation timer at 10 Hz to drive real-time audio parameter updates.
    private func startAdaptationTimer() {
        adaptationTimer = Timer.scheduledTimer(
            withTimeInterval: WatchDesign.Audio.adaptationTickInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.processAdaptationTick()
            }
        }
    }

    private func stopAdaptationTimer() {
        adaptationTimer?.invalidate()
        adaptationTimer = nil
    }

    /// Called at 10 Hz to compute adaptive audio targets from current biometrics.
    private func processAdaptationTick() {
        guard isSessionActive, !isPaused else { return }
        guard let mode = activeMode else { return }

        // If no HR yet, hold current parameters
        guard let hr = currentHeartRate else { return }

        // Compute HR normalized via Karvonen method
        let hrNormalized = FrequencyMath.heartRateReserveNormalized(
            current: hr,
            resting: WatchDesign.Audio.defaultRestingHR,
            max: WatchDesign.Audio.defaultMaxHR
        )

        // Compute HR trend from dual-EMA (fast - slow)
        let hrTrend: Double
        if let analyzer = heartRateAnalyzer {
            // Use the analyzer's EMA state if available
            hrTrend = analyzer.currentTrend
        } else {
            hrTrend = 0
        }

        // Compute session progress
        let sessionProgress: Double
        if mode == .sleep {
            sessionProgress = min(elapsedSeconds / WatchDesign.Audio.SleepRamp.rampDuration, 1.0)
        } else if let target = targetDurationSeconds, target > 0 {
            sessionProgress = min(elapsedSeconds / target, 1.0)
        } else {
            sessionProgress = 0
        }

        // Compute adapted targets
        let targets = adaptationEngine.computeTargets(
            hrNormalized: hrNormalized,
            hrTrend: hrTrend,
            mode: mode,
            sessionProgress: sessionProgress
        )

        // Write targets to audio engine parameters
        audioEngine.parameters.beatFrequency = targets.beatFrequency
        audioEngine.parameters.baseFrequency = targets.carrierFrequency
        audioEngine.parameters.amplitude = targets.amplitude

        // Update UI-facing beat frequency
        currentBeatFrequency = targets.beatFrequency

        // Track deep state time
        trackDeepState()
    }

    /// Tracks accumulated time in a calm/deep biometric state and time-to-calm.
    private func trackDeepState() {
        let isInDeepState = (currentBiometricState == .calm || currentBiometricState == .focused)

        if isInDeepState {
            if calmEntryDate == nil {
                calmEntryDate = Date()

                // Record time-to-calm on first entry
                if timeToCalm == nil, let start = sessionStartDate {
                    timeToCalm = Date().timeIntervalSince(start)
                    // Haptic celebration for reaching calm
                    WKInterfaceDevice.current().play(.success)
                }
            }
            // Accumulate deep state time (0.1s per tick)
            deepStateSeconds += WatchDesign.Audio.adaptationTickInterval
        } else {
            calmEntryDate = nil
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSessionActive else { return }
                if let start = self.sessionStartDate {
                    self.elapsedSeconds = Date().timeIntervalSince(start)
                }

                // Auto-stop if target duration reached
                if let target = self.targetDurationSeconds,
                   self.elapsedSeconds >= target {
                    self.stopSession()
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - WCSession Commands

    /// Sends a session command to iPhone via WCSession.
    private func sendCommandToiPhone(_ command: SessionCommand) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let message = WatchMessage.sessionCommand(command)
        guard let dict = message.toDictionary() else { return }

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [logger] error in
                logger.debug("Failed to send command to iPhone: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            // Deferred delivery via application context
            do {
                try session.updateApplicationContext(dict)
            } catch {
                logger.error("updateApplicationContext failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Syncs a completed session summary to iPhone for recording.
    private func syncSessionSummaryToiPhone(
        mode: FocusMode,
        duration: TimeInterval,
        startDate: Date,
        endDate: Date
    ) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let stateUpdate = SessionStateUpdate(
            isActive: false,
            isPaused: false,
            mode: mode,
            elapsed: duration
        )

        let message = WatchMessage.sessionState(stateUpdate)
        guard let dict = message.toDictionary() else { return }

        // Use transferUserInfo for guaranteed delivery of session summary
        session.transferUserInfo(dict)
        logger.info("Session summary synced to iPhone via transferUserInfo.")
    }

    // MARK: - State Reset

    private func resetSessionState() {
        isSessionActive = false
        activeMode = nil
        elapsedSeconds = 0
        currentHeartRate = nil
        isStandaloneMode = false
        isPaused = false
        sessionStartDate = nil
        targetDurationSeconds = nil
        heartRateAnalyzer = nil
        adaptationCount = 0
        startHeartRate = nil
        calmEntryDate = nil
        deepStateSeconds = 0
        timeToCalm = nil
        hrSamples = []
        currentBeatFrequency = 0
    }

    // MARK: - Persistence

    private func saveLastSessionSummary(_ summary: WatchSessionSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.lastSessionSummary)
    }

    private func loadLastSessionSummary() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.lastSessionSummary),
              let summary = try? JSONDecoder().decode(WatchSessionSummary.self, from: data) else {
            return
        }
        lastSessionSummary = summary
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    /// Handle session activation.
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                logger.error("WCSession activation failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            logger.info("WCSession activated on Watch. Reachable: \(session.isReachable)")
        }
    }

    /// Receives real-time messages from iPhone (session commands).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        let data = try? JSONSerialization.data(withJSONObject: message)
        Task { @MainActor in
            guard let data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            handleIncomingMessage(dict)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let data = try? JSONSerialization.data(withJSONObject: message)
        Task { @MainActor in
            guard let data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            handleIncomingMessage(dict)
        }
        replyHandler([:])
    }

    /// Receives application context updates (deferred commands).
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let data = try? JSONSerialization.data(withJSONObject: applicationContext)
        Task { @MainActor in
            guard let data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            handleIncomingMessage(dict)
        }
    }

    /// Handle reachability changes — if iPhone becomes reachable during
    /// a standalone session, flush buffered samples.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            logger.info("Watch reachability changed: \(session.isReachable)")
            if session.isReachable && isSessionActive {
                healthKitService.flushBufferedSamples()

                // If we were standalone and iPhone is now reachable,
                // switch to companion mode
                if isStandaloneMode {
                    isStandaloneMode = false
                    heartRateAnalyzer = nil
                    logger.info("Switching from standalone to companion mode.")
                }
            }
        }
    }

    // MARK: - Message Handling

    @MainActor
    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let watchMessage = WatchMessage.fromDictionary(message) else {
            // Not a recognized WatchMessage — ignore (may be a ping)
            return
        }

        switch watchMessage {
        case .sessionCommand(let command):
            handleSessionCommand(command)
        case .sessionState(let stateUpdate):
            handleStateUpdate(stateUpdate)
        case .heartRate:
            // Watch does not receive HR from iPhone — ignore
            break
        }
    }

    @MainActor
    private func handleSessionCommand(_ command: SessionCommand) {
        switch command {
        case .start(let mode):
            startSession(mode: mode, durationMinutes: nil)
        case .stop:
            stopSession()
        case .pause:
            pauseSession()
        case .resume:
            resumeSession()
        }
    }

    @MainActor
    private func handleStateUpdate(_ stateUpdate: SessionStateUpdate) {
        // Sync state from iPhone — used for keeping Watch display in sync
        // when iPhone initiates sessions.
        if stateUpdate.isActive && !isSessionActive {
            if let mode = stateUpdate.mode {
                startSession(mode: mode, durationMinutes: nil)
            }
        } else if !stateUpdate.isActive && isSessionActive {
            stopSession()
        }
    }
}

// MARK: - WatchHeartRateAnalyzer

/// Simplified on-Watch heart rate analyzer for standalone mode.
///
/// Uses dual-EMA smoothing and HR reserve normalization to classify
/// biometric state. A lightweight version of the iPhone's
/// `HeartRateAnalyzer` + `BiometricState.classify`.
///
/// All thresholds reference shared `BiometricState` zone definitions
/// rather than hardcoded values.
struct WatchHeartRateAnalyzer {

    // MARK: - EMA State

    private var hrFast: Double?
    private var hrSlow: Double?

    // MARK: - EMA Parameters

    /// Fast EMA alpha — responsive (~2.5s effective window).
    /// Matches WatchDesign.Audio.EMA.fast.
    private let alphaFast: Double = WatchDesign.Audio.EMA.fast

    /// Slow EMA alpha — stable (~10s effective window).
    /// Matches WatchDesign.Audio.EMA.slow.
    private let alphaSlow: Double = WatchDesign.Audio.EMA.slow

    // MARK: - User Baseline

    /// Default resting heart rate (BPM).
    private let restingHR: Double = WatchDesign.Audio.defaultRestingHR

    /// Estimated maximum heart rate (BPM).
    private let estimatedMaxHR: Double = WatchDesign.Audio.defaultMaxHR

    // MARK: - Hysteresis

    /// Band width for state transition hysteresis.
    /// Matches WatchDesign.Audio.Hysteresis.band.
    private let hysteresisBand: Double = WatchDesign.Audio.Hysteresis.band

    /// Minimum dwell time before a state transition is accepted (seconds).
    /// Matches WatchDesign.Audio.Hysteresis.minDwellTime.
    private let minDwellTime: TimeInterval = WatchDesign.Audio.Hysteresis.minDwellTime

    private var lastState: BiometricState = .calm
    private var stateEntryDate: Date = Date()

    // MARK: - Trend Access

    /// Current HR trend magnitude (fast EMA - slow EMA, in BPM).
    /// Positive means HR is rising, negative means falling.
    var currentTrend: Double {
        guard let fast = hrFast, let slow = hrSlow else { return 0 }
        return fast - slow
    }

    // MARK: - Classification

    /// Processes a raw HR sample and returns the current biometric state.
    mutating func classify(bpm: Double) -> BiometricState {
        // Update dual EMAs
        let fast: Double
        let slow: Double

        if let prevFast = hrFast, let prevSlow = hrSlow {
            fast = alphaFast * bpm + (1.0 - alphaFast) * prevFast
            slow = alphaSlow * bpm + (1.0 - alphaSlow) * prevSlow
        } else {
            fast = bpm
            slow = bpm
        }

        hrFast = fast
        hrSlow = slow

        // Normalize using HR reserve (Karvonen method)
        let hrNormalized = FrequencyMath.heartRateReserveNormalized(
            current: slow,
            resting: restingHR,
            max: estimatedMaxHR
        )

        // Point-in-time classification
        let candidateState = BiometricState.classify(hrNormalized: hrNormalized)

        // Apply hysteresis + dwell time
        let now = Date()
        if candidateState != lastState {
            let dwellElapsed = now.timeIntervalSince(stateEntryDate)
            if dwellElapsed >= minDwellTime {
                lastState = candidateState
                stateEntryDate = now
                return candidateState
            }
        }

        return lastState
    }
}

// MARK: - WatchSessionSummary

/// Lightweight summary of the last completed session, stored by
/// `WatchSessionManager` for display on the idle screen.
struct WatchSessionSummary: Codable, Sendable {
    let mode: FocusMode
    let durationSeconds: TimeInterval
    let endDate: Date

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedTimeAgo: String {
        let interval = Date().timeIntervalSince(endDate)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}
