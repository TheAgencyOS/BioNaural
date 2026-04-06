// WatchBreathingHaptics.swift
// BioNauralWatch
//
// Delivers subtle haptic breathing cues during relaxation and sleep sessions.
// Taps guide the user through a breathing rhythm that gradually slows as
// their biometric state improves (HR decreases toward calm).

import Foundation
import WatchKit
import BioNauralShared
import os

/// Guides the user through a breathing cycle using haptic taps on Apple Watch.
///
/// The breathing pattern consists of two phases per cycle:
/// 1. **Inhale**: evenly-spaced haptic taps over the inhale duration.
/// 2. **Exhale**: silence (no taps) for the exhale duration.
///
/// The cycle adapts in real time: as the user's heart rate decreases, the
/// total cycle duration stretches from `initialCycleDuration` to
/// `targetCycleDuration`, producing a slower, deeper breathing rhythm.
///
/// Only active during `.relaxation` and `.sleep` modes. Automatically stops
/// when the user sustains a `.calm` biometric state.
@MainActor
final class WatchBreathingHaptics {

    // MARK: - Timing Constants

    /// Supported modes for breathing haptics.
    private static let supportedModes: Set<FocusMode> = [.relaxation, .sleep]

    /// Initial total cycle duration in seconds (inhale + exhale).
    private static let initialCycleDuration: TimeInterval = WatchDesign.BreathingHaptics.initialCycleDuration

    /// Target total cycle duration after full adaptation (inhale + exhale).
    private static let targetCycleDuration: TimeInterval = WatchDesign.BreathingHaptics.targetCycleDuration

    /// Initial inhale phase duration in seconds.
    private static let initialInhaleDuration: TimeInterval = WatchDesign.BreathingHaptics.initialInhaleDuration

    /// Target inhale phase duration after full adaptation.
    private static let targetInhaleDuration: TimeInterval = WatchDesign.BreathingHaptics.targetInhaleDuration

    /// Initial exhale phase duration in seconds (initialCycle - initialInhale).
    private static let initialExhaleDuration: TimeInterval = WatchDesign.BreathingHaptics.initialExhaleDuration

    /// Target exhale phase duration after full adaptation (targetCycle - targetInhale).
    private static let targetExhaleDuration: TimeInterval = WatchDesign.BreathingHaptics.targetExhaleDuration

    /// Number of haptic taps per inhale phase.
    private static let tapsPerInhale: Int = WatchDesign.BreathingHaptics.tapsPerInhale

    /// Seconds of sustained calm required before auto-stopping.
    private static let sustainedCalmThreshold: TimeInterval = WatchDesign.BreathingHaptics.sustainedCalmThreshold

    /// UserDefaults key for the user's haptic breathing preference.
    private static let hapticsEnabledKey = "com.bionaural.watch.breathingHapticsEnabled"

    // MARK: - State

    /// Whether the breathing cycle is currently running.
    private(set) var isActive: Bool = false

    /// Current adaptation factor (0.0 = initial, 1.0 = fully adapted).
    /// Driven by heart rate improvement relative to session start.
    private(set) var adaptationFactor: Double = 0.0

    private var inhaleTimer: Timer?
    private var cycleTimer: Timer?
    private var tapIndex: Int = 0
    private var isInhalePhase: Bool = true

    /// Heart rate at the start of the session — used as the adaptation baseline.
    private var baselineHeartRate: Double?

    /// Timestamp when the user first entered sustained calm.
    private var calmEntryDate: Date?

    private let logger = Logger(subsystem: "com.bionaural.watch", category: "BreathingHaptics")

    // MARK: - Computed Timing

    /// Current inhale duration, interpolated between initial and target.
    private var currentInhaleDuration: TimeInterval {
        Self.initialInhaleDuration + adaptationFactor
            * (Self.targetInhaleDuration - Self.initialInhaleDuration)
    }

    /// Current exhale duration, interpolated between initial and target.
    private var currentExhaleDuration: TimeInterval {
        Self.initialExhaleDuration + adaptationFactor
            * (Self.targetExhaleDuration - Self.initialExhaleDuration)
    }

    /// Interval between taps during the inhale phase.
    private var tapInterval: TimeInterval {
        currentInhaleDuration / TimeInterval(Self.tapsPerInhale)
    }

    // MARK: - Preferences

    /// Whether the user has enabled breathing haptics. Defaults to true.
    var isEnabled: Bool {
        get {
            // Default to true if the key has never been set.
            if UserDefaults.standard.object(forKey: Self.hapticsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.hapticsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.hapticsEnabledKey)
        }
    }

    // MARK: - Lifecycle

    /// Starts the breathing haptic cycle for the given mode.
    ///
    /// Does nothing if the mode is not `.relaxation` or `.sleep`,
    /// or if the user has disabled breathing haptics.
    ///
    /// - Parameter mode: The current session's focus mode.
    func start(for mode: FocusMode) {
        guard Self.supportedModes.contains(mode) else {
            logger.debug("Breathing haptics not supported for mode: \(mode.rawValue)")
            return
        }

        guard isEnabled else {
            logger.debug("Breathing haptics disabled by user preference.")
            return
        }

        guard !isActive else {
            logger.debug("Breathing haptics already active — ignoring start.")
            return
        }

        isActive = true
        adaptationFactor = 0.0
        baselineHeartRate = nil
        calmEntryDate = nil

        logger.info("Breathing haptics started for mode: \(mode.rawValue)")
        beginCycle()
    }

    /// Stops the breathing haptic cycle and invalidates all timers.
    func stop() {
        guard isActive else { return }

        invalidateTimers()
        isActive = false
        adaptationFactor = 0.0
        baselineHeartRate = nil
        calmEntryDate = nil

        logger.info("Breathing haptics stopped.")
    }

    // MARK: - Heart Rate Adaptation

    /// Updates the adaptation factor based on the latest heart rate reading.
    ///
    /// As heart rate decreases from the session-start baseline, the adaptation
    /// factor increases from 0.0 toward 1.0, slowing the breathing cycle.
    /// A heart rate decrease of 10 BPM or more from baseline yields full
    /// adaptation.
    ///
    /// - Parameter bpm: The current heart rate in beats per minute.
    func updateHeartRate(_ bpm: Double) {
        guard isActive else { return }

        // Capture baseline from first reading
        if baselineHeartRate == nil {
            baselineHeartRate = bpm
            return
        }

        guard let baseline = baselineHeartRate else { return }

        // How many BPM has HR dropped from baseline?
        let drop = max(baseline - bpm, 0.0)

        // Full adaptation at 10 BPM decrease
        let fullAdaptationDropBPM: Double = WatchDesign.BreathingHaptics.fullAdaptationDropBPM
        adaptationFactor = min(drop / fullAdaptationDropBPM, 1.0)
    }

    /// Checks whether the user has reached sustained calm and should
    /// auto-stop breathing cues.
    ///
    /// - Parameter state: The current biometric state classification.
    /// - Returns: `true` if breathing haptics should stop (sustained calm reached).
    func checkSustainedCalm(state: BiometricState) -> Bool {
        guard isActive else { return false }

        if state == .calm {
            if calmEntryDate == nil {
                calmEntryDate = Date()
            }

            if let entry = calmEntryDate,
               Date().timeIntervalSince(entry) >= Self.sustainedCalmThreshold {
                logger.info("Sustained calm reached — auto-stopping breathing haptics.")
                stop()
                return true
            }
        } else {
            // Reset the calm timer if state leaves calm
            calmEntryDate = nil
        }

        return false
    }

    // MARK: - Cycle Engine

    /// Begins a full breathing cycle (inhale then exhale), scheduling
    /// the next cycle at completion.
    private func beginCycle() {
        guard isActive else { return }

        isInhalePhase = true
        tapIndex = 0

        // Play the first tap immediately
        playTap()
        tapIndex = 1

        // Schedule remaining taps for the inhale phase
        if Self.tapsPerInhale > 1 {
            inhaleTimer = Timer.scheduledTimer(
                withTimeInterval: tapInterval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isActive, self.isInhalePhase else {
                        self?.inhaleTimer?.invalidate()
                        return
                    }

                    self.playTap()
                    self.tapIndex += 1

                    if self.tapIndex >= Self.tapsPerInhale {
                        self.inhaleTimer?.invalidate()
                        self.inhaleTimer = nil
                        self.isInhalePhase = false
                    }
                }
            }
        } else {
            isInhalePhase = false
        }

        // Schedule the next cycle after the full cycle duration
        let cycleDuration = currentInhaleDuration + currentExhaleDuration
        cycleTimer = Timer.scheduledTimer(
            withTimeInterval: cycleDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.beginCycle()
            }
        }
    }

    /// Plays a single subtle haptic tap.
    private func playTap() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Invalidates all active timers.
    private func invalidateTimers() {
        inhaleTimer?.invalidate()
        inhaleTimer = nil
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}
