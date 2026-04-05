// WatchSessionManager.swift
// BioNauralWatch
//
// Coordinates the workout session, WatchConnectivity, and adaptive
// algorithm on Watch. Supports both companion mode (iPhone drives
// adaptation, Watch streams HR) and standalone mode (Watch runs the
// adaptive algorithm locally).

import Foundation
import BioNauralShared
import SwiftUI
@preconcurrency import WatchConnectivity
import HealthKit
import os

/// Central coordinator for the Watch app's session lifecycle.
///
/// Responsibilities:
/// - Owns `WatchHealthKitService` for HR streaming.
/// - Receives commands from iPhone via WCSession delegate.
/// - Can initiate sessions locally (standalone mode).
/// - In standalone mode: runs a simplified adaptive algorithm on-Watch,
///   reads HR directly from local HealthKit, and syncs summary to iPhone
///   when connectivity is restored.
/// - Manages: start -> stream HR -> detect stop -> end workout ->
///   save to HealthKit -> sync summary to iPhone.
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

    // MARK: - Dependencies

    private let healthKitService: WatchHealthKitService
    private let healthStore: HKHealthStore
    private let logger = Logger(subsystem: "com.bionaural.watch", category: "SessionManager")

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
    /// HealthKit workout session for HR streaming.
    ///
    /// - Parameters:
    ///   - mode: The focus mode to use.
    ///   - durationMinutes: Optional target duration in minutes.
    func startSession(mode: FocusMode, durationMinutes: Int?) {
        guard !isSessionActive else {
            logger.warning("Session already active — ignoring start.")
            return
        }

        activeMode = mode
        isSessionActive = true
        sessionStartDate = Date()
        elapsedSeconds = 0
        adaptationCount = 0
        startHeartRate = nil
        currentHeartRate = nil

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
            currentBiometricState = .calm
            logger.info("Starting standalone session — adaptive algorithm on Watch.")
        }

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

    // MARK: - Stop Session

    /// Stops the current session, saves the workout, records the summary,
    /// and syncs to iPhone.
    func stopSession() {
        guard isSessionActive else { return }

        let endDate = Date()
        let duration = sessionStartDate.map { endDate.timeIntervalSince($0) } ?? elapsedSeconds
        let mode = activeMode ?? .focus

        stopElapsedTimer()
        breathingHaptics.stop()

        Task {
            await healthKitService.stopWorkout()

            // Record session summary
            let summary = WatchSessionSummary(
                mode: mode,
                durationSeconds: duration,
                endDate: endDate
            )
            lastSessionSummary = summary
            saveLastSessionSummary(summary)

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

    // MARK: - Heart Rate Handling

    private func handleHeartRateSample(_ sample: BiometricSample) {
        currentHeartRate = sample.bpm

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
        sessionStartDate = nil
        targetDurationSeconds = nil
        heartRateAnalyzer = nil
        adaptationCount = 0
        startHeartRate = nil
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
            // Future: implement pause/resume for workout session
            logger.info("Pause command received — not yet implemented.")
        case .resume:
            logger.info("Resume command received — not yet implemented.")
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
    /// Matches Theme.Audio.EMA.fast on iPhone.
    private let alphaFast: Double = 0.4

    /// Slow EMA alpha — stable (~10s effective window).
    /// Matches Theme.Audio.EMA.slow on iPhone.
    private let alphaSlow: Double = 0.1

    // MARK: - User Baseline

    /// Default resting heart rate (BPM). In a full implementation this
    /// would come from HealthKit's resting HR query.
    private let restingHR: Double = 65

    /// Estimated maximum heart rate (BPM). In a full implementation this
    /// would use the Tanaka formula with the user's age.
    private let estimatedMaxHR: Double = 190

    // MARK: - Hysteresis

    /// Band width for state transition hysteresis.
    /// Matches Theme.Audio.Hysteresis.band on iPhone.
    private let hysteresisBand: Double = 0.03

    /// Minimum dwell time before a state transition is accepted (seconds).
    /// Matches Theme.Audio.Hysteresis.minDwellTime on iPhone.
    private let minDwellTime: TimeInterval = 5.0

    private var lastState: BiometricState = .calm
    private var stateEntryDate: Date = Date()

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
