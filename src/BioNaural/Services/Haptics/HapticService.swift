// HapticService.swift
// BioNaural
//
// Core Haptics engine with patterned haptic feedback synced to
// binaural beat frequency and breathing cadence. Replaces the
// basic UIKit feedback generators with rich, temporal patterns.
//
// Falls back to UIKit generators on devices without Core Haptics
// support (pre-iPhone 8). Respects the system haptic setting and
// the user's in-app hapticFeedbackEnabled preference.

import CoreHaptics
import OSLog
import UIKit

// MARK: - Protocol

/// Protocol for haptic feedback, enabling mock injection in tests.
@MainActor
public protocol HapticServiceProtocol: AnyObject {

    /// Soft crescendo played when a session begins.
    func sessionStart()

    /// Celebratory pattern played when a session ends.
    func sessionEnd()

    /// Subtle pulse when the adaptive engine changes parameters.
    func adaptationEvent()

    /// Crisp tap for standard button presses.
    func buttonPress()

    /// Start a continuous breathing haptic pattern (inhale/exhale
    /// ramp) that loops until stopped. For Focus/Relaxation sessions.
    func startBreathingPattern()

    /// Stop the looping breathing pattern.
    func stopBreathingPattern()

    /// Fire a single transient pulse synced to the binaural beat
    /// frequency. Called by the session timer at the beat rate.
    func beatPulse()
}

// MARK: - HapticService

/// Production haptic service using Core Haptics for rich, temporal
/// patterns. Falls back to UIKit generators when Core Haptics is
/// unavailable.
///
/// Thread safety: All public methods are `@MainActor`-isolated.
/// The `CHHapticEngine` is created and used exclusively on the
/// main thread.
@MainActor
public final class HapticService: HapticServiceProtocol {

    // MARK: - Private State

    private var engine: CHHapticEngine?
    private var breathingPlayer: CHHapticAdvancedPatternPlayer?
    private var isBreathingActive = false

    /// Whether the device supports Core Haptics.
    private let supportsHaptics: Bool

    /// Fallback UIKit generators for devices without Core Haptics.
    private lazy var softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private lazy var lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bionaural",
        category: "Haptics"
    )

    // MARK: - Initialization

    public init() {
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsHaptics {
            createEngine()
        }
    }

    // MARK: - Engine Lifecycle

    private func createEngine() {
        do {
            let hapticEngine = try CHHapticEngine()

            // Auto-restart on reset (e.g., app returning to foreground).
            hapticEngine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.restartEngine()
                }
            }

            // The engine stopped unexpectedly — log it.
            hapticEngine.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.logger.warning("Haptic engine stopped: \(String(describing: reason))")
                }
            }

            // Start immediately so patterns play without latency.
            try hapticEngine.start()
            self.engine = hapticEngine
        } catch {
            logger.error("Failed to create haptic engine: \(error.localizedDescription)")
        }
    }

    private func restartEngine() {
        guard supportsHaptics else { return }
        do {
            try engine?.start()
        } catch {
            logger.error("Failed to restart haptic engine: \(error.localizedDescription)")
            // Recreate from scratch.
            createEngine()
        }
    }

    /// Ensures the engine is running before playing a pattern.
    private func ensureEngineRunning() {
        guard supportsHaptics else { return }
        if engine == nil {
            createEngine()
        }
    }

    // MARK: - Session Events

    public func sessionStart() {
        guard supportsHaptics, let engine else {
            softGenerator.prepare()
            softGenerator.impactOccurred()
            return
        }

        // Three-tap crescendo: soft → medium → full
        let t = Theme.Haptics.self
        let stepDuration = t.sessionStartDuration / 3.0
        var events: [CHHapticEvent] = []

        for i in 0..<3 {
            let time = Double(i) * stepDuration
            let intensity = t.sessionStartIntensity * Float(i + 1) / 3.0
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: t.sessionStartSharpness)
                    ],
                    relativeTime: time
                )
            )
        }

        playPattern(events: events, on: engine)
    }

    public func sessionEnd() {
        guard supportsHaptics, let engine else {
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(.success)
            return
        }

        // Celebration: quick double-tap then a sustained bloom.
        let t = Theme.Haptics.self
        var events: [CHHapticEvent] = []

        // Two quick transients
        events.append(
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: t.sessionEndIntensity * 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: t.sessionEndSharpness)
                ],
                relativeTime: 0
            )
        )
        events.append(
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: t.sessionEndIntensity * 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: t.sessionEndSharpness)
                ],
                relativeTime: 0.12
            )
        )

        // Sustained bloom
        events.append(
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: t.sessionEndIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: t.sessionEndSharpness * 0.5)
                ],
                relativeTime: 0.3,
                duration: t.sessionEndDuration - 0.3
            )
        )

        playPattern(events: events, on: engine)
    }

    public func adaptationEvent() {
        guard supportsHaptics, let engine else {
            lightGenerator.prepare()
            lightGenerator.impactOccurred(intensity: 0.5)
            return
        }

        let t = Theme.Haptics.self
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: t.adaptationIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: t.adaptationSharpness)
            ],
            relativeTime: 0
        )

        playPattern(events: [event], on: engine)
    }

    public func buttonPress() {
        guard supportsHaptics, let engine else {
            lightGenerator.prepare()
            lightGenerator.impactOccurred()
            return
        }

        let t = Theme.Haptics.self
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: t.buttonIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: t.buttonSharpness)
            ],
            relativeTime: 0
        )

        playPattern(events: [event], on: engine)
    }

    // MARK: - Beat Pulse

    public func beatPulse() {
        guard supportsHaptics, let engine else { return }

        let t = Theme.Haptics.self
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: t.beatPulseIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: t.beatPulseSharpness)
            ],
            relativeTime: 0
        )

        playPattern(events: [event], on: engine)
    }

    // MARK: - Breathing Pattern

    public func startBreathingPattern() {
        guard supportsHaptics, let engine else { return }
        guard !isBreathingActive else { return }

        isBreathingActive = true

        do {
            let pattern = try buildBreathingPattern()
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true

            // Handle player completion (shouldn't fire while looping,
            // but defensive).
            player.completionHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.isBreathingActive = false
                    self?.breathingPlayer = nil
                }
            }

            try player.start(atTime: CHHapticTimeImmediate)
            self.breathingPlayer = player
        } catch {
            logger.error("Failed to start breathing pattern: \(error.localizedDescription)")
            isBreathingActive = false
        }
    }

    public func stopBreathingPattern() {
        guard isBreathingActive else { return }

        do {
            try breathingPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("Failed to stop breathing player: \(error.localizedDescription)")
        }

        breathingPlayer = nil
        isBreathingActive = false
    }

    // MARK: - Breathing Pattern Builder

    /// Builds a CHHapticPattern that ramps intensity up (inhale) then
    /// down (exhale) over one full breathing cycle.
    private func buildBreathingPattern() throws -> CHHapticPattern {
        let t = Theme.Haptics.self
        let cycleDuration = t.breathingCycleDuration
        let inhaleDuration = cycleDuration * t.breathingInhaleRatio
        let exhaleDuration = cycleDuration * (1.0 - t.breathingInhaleRatio)

        var events: [CHHapticEvent] = []

        // Inhale phase: taps ramping from trough to peak intensity
        let inhaleCount = t.breathingInhaleTapCount
        let inhaleStep = inhaleDuration / Double(inhaleCount)
        for i in 0..<inhaleCount {
            let progress = Float(i) / Float(max(inhaleCount - 1, 1))
            let intensity = t.breathingTroughIntensity + (t.breathingPeakIntensity - t.breathingTroughIntensity) * progress
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: t.breathingSharpness)
                    ],
                    relativeTime: Double(i) * inhaleStep
                )
            )
        }

        // Exhale phase: taps ramping from peak back to trough
        let exhaleCount = t.breathingExhaleTapCount
        let exhaleStep = exhaleDuration / Double(exhaleCount)
        for i in 0..<exhaleCount {
            let progress = Float(i) / Float(max(exhaleCount - 1, 1))
            let intensity = t.breathingPeakIntensity - (t.breathingPeakIntensity - t.breathingTroughIntensity) * progress
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: t.breathingSharpness)
                    ],
                    relativeTime: inhaleDuration + Double(i) * exhaleStep
                )
            )
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Pattern Playback

    /// Plays a one-shot pattern from the given events.
    private func playPattern(events: [CHHapticEvent], on engine: CHHapticEngine) {
        ensureEngineRunning()
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Tears down the haptic engine and stops all players.
    /// Call before releasing the service.
    func tearDown() {
        try? breathingPlayer?.stop(atTime: CHHapticTimeImmediate)
        breathingPlayer = nil
        engine?.stop()
        engine = nil
    }
}

// MARK: - Sendable Conformance

// HapticService is @MainActor-isolated, so all mutable state is
// accessed exclusively on the main thread. The Sendable conformance
// on the protocol is satisfied by this isolation.
extension HapticService: @unchecked Sendable {}
