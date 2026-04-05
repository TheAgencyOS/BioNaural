// HeadMotionService.swift
// BioNaural
//
// Concrete implementation of HeadMotionServiceProtocol using
// CMHeadphoneMotionManager to track AirPods Pro/Max head movement.
// Computes a rolling-window stillness score from gyroscope rotation
// rate magnitudes. No SwiftUI imports — pure service layer.
//
// Concurrency domain: @MainActor (for @Observable / SwiftUI binding).
// CMHeadphoneMotionManager delivers updates on the specified OperationQueue;
// we marshal results back to MainActor for publication.

import CoreMotion
import Foundation
import OSLog
import Observation

// MARK: - Constants

/// All tunable thresholds for head motion stillness calculation.
/// No magic numbers — every value is a named constant.
private enum HeadMotionConstants {

    /// Duration of the rolling window for stillness calculation (seconds).
    static let rollingWindowDuration: TimeInterval = 30.0

    /// Rotation rate magnitude (rad/s) at or below which the head is
    /// considered "perfectly still." Values below this floor are clamped to 0.
    static let rotationRateStillnessFloor: Double = 0.01

    /// Rotation rate magnitude (rad/s) at or above which the head is
    /// considered "maximally moving." Values above this ceiling are clamped to 1.
    static let rotationRateMovementCeiling: Double = 1.5

    /// Interval between motion updates from CMHeadphoneMotionManager (seconds).
    /// ~100 Hz is the native rate; we sample at 50 Hz to reduce CPU overhead
    /// while retaining sufficient resolution for stillness detection.
    static let motionUpdateInterval: TimeInterval = 1.0 / 50.0

    /// Maximum number of samples retained in the rolling window.
    /// Computed from window duration and update interval.
    static let maxWindowSamples: Int = Int(rollingWindowDuration / motionUpdateInterval)
}

// MARK: - HeadMotionService

@Observable
@MainActor
final class HeadMotionService: HeadMotionServiceProtocol {

    // MARK: - Published State

    /// Whether the device supports headphone motion (AirPods Pro/Max).
    private(set) var isAvailable: Bool = false

    /// Whether motion tracking is actively running.
    private(set) var isTracking: Bool = false

    /// The computed stillness score (0.0 = still, 1.0 = moving), or `nil`.
    private(set) var stillnessScore: Double?

    // MARK: - Private State

    /// The CoreMotion headphone motion manager.
    @ObservationIgnored
    private let motionManager = CMHeadphoneMotionManager()

    /// Dedicated operation queue for motion updates (off main thread).
    @ObservationIgnored
    private let motionQueue = OperationQueue()

    /// Rolling window of rotation rate magnitudes (rad/s).
    /// Newest samples are appended; oldest are trimmed when exceeding capacity.
    @ObservationIgnored
    private var rotationRateSamples: [Double] = []

    /// Logger for head motion diagnostics.
    @ObservationIgnored
    private static let log = Logger.headMotion

    // MARK: - Init

    init() {
        motionQueue.name = "com.bionaural.headmotion"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInitiated

        rotationRateSamples.reserveCapacity(HeadMotionConstants.maxWindowSamples)

        isAvailable = motionManager.isDeviceMotionAvailable

        if isAvailable {
            Self.log.info("Head motion tracking is available (AirPods detected)")
        } else {
            Self.log.info("Head motion tracking unavailable — no supported AirPods")
        }
    }

    // MARK: - HeadMotionServiceProtocol

    func startTracking() {
        guard isAvailable else {
            Self.log.debug("startTracking called but head motion is unavailable — ignoring")
            return
        }

        guard !isTracking else {
            Self.log.debug("startTracking called but already tracking — ignoring")
            return
        }

        // Clear any stale data from a previous session.
        rotationRateSamples.removeAll(keepingCapacity: true)
        stillnessScore = nil

        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            if let error {
                Self.log.error("Head motion update error: \(error.localizedDescription)")
                return
            }

            guard let motion else { return }

            let rotationRate = motion.rotationRate
            let magnitude = sqrt(
                rotationRate.x * rotationRate.x +
                rotationRate.y * rotationRate.y +
                rotationRate.z * rotationRate.z
            )

            Task { @MainActor [weak self] in
                self?.processSample(magnitude: magnitude)
            }
        }

        isTracking = true
        Self.log.info("Head motion tracking started (window: \(HeadMotionConstants.rollingWindowDuration)s)")
    }

    func stopTracking() {
        guard isTracking else { return }

        motionManager.stopDeviceMotionUpdates()
        isTracking = false
        stillnessScore = nil
        rotationRateSamples.removeAll(keepingCapacity: true)

        Self.log.info("Head motion tracking stopped")
    }

    // MARK: - Sample Processing

    /// Processes a single rotation rate magnitude sample and recomputes the stillness score.
    private func processSample(magnitude: Double) {
        // Append to rolling window.
        rotationRateSamples.append(magnitude)

        // Trim to window capacity.
        if rotationRateSamples.count > HeadMotionConstants.maxWindowSamples {
            let overflow = rotationRateSamples.count - HeadMotionConstants.maxWindowSamples
            rotationRateSamples.removeFirst(overflow)
        }

        // Recompute stillness score from the rolling window.
        stillnessScore = computeStillnessScore()
    }

    /// Computes the stillness score from the rolling window of rotation rate magnitudes.
    ///
    /// Algorithm:
    /// 1. Compute the mean rotation rate magnitude over the window.
    /// 2. Normalize to [0, 1] using the stillness floor and movement ceiling.
    /// 3. Clamp to [0, 1].
    ///
    /// A mean magnitude at or below `rotationRateStillnessFloor` yields 0.0 (perfectly still).
    /// A mean magnitude at or above `rotationRateMovementCeiling` yields 1.0 (max movement).
    private func computeStillnessScore() -> Double {
        guard !rotationRateSamples.isEmpty else { return 0.0 }

        let sum = rotationRateSamples.reduce(0.0, +)
        let mean = sum / Double(rotationRateSamples.count)

        let floor = HeadMotionConstants.rotationRateStillnessFloor
        let ceiling = HeadMotionConstants.rotationRateMovementCeiling
        let range = ceiling - floor

        guard range > 0 else { return 0.0 }

        let normalized = (mean - floor) / range
        return min(max(normalized, 0.0), 1.0)
    }
}

// MARK: - MockHeadMotionService

/// Mock implementation for SwiftUI previews and unit tests.
@Observable
@MainActor
final class MockHeadMotionService: HeadMotionServiceProtocol {

    private(set) var isAvailable: Bool
    private(set) var isTracking: Bool = false
    var stillnessScore: Double?

    init(isAvailable: Bool = true, stillnessScore: Double? = 0.15) {
        self.isAvailable = isAvailable
        self.stillnessScore = stillnessScore
    }

    func startTracking() {
        guard isAvailable else { return }
        isTracking = true
    }

    func stopTracking() {
        isTracking = false
    }
}
