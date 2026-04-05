// HeartRateAnalyzer.swift
// BioNaural
//
// Pure computation — no side effects, no I/O, no framework imports beyond Foundation.
// Maintains dual-EMA state and provides smoothing, trend detection, artifact
// rejection, and HR reserve normalization. All thresholds from Theme.Audio tokens.

import Foundation

// MARK: - HRTrend

/// Direction of the heart rate trend derived from fast/slow EMA divergence.
public enum HRTrend: String, Sendable {
    case rising
    case falling
    case stable
}

// MARK: - HeartRateAnalyzer

/// Stateful heart rate signal processor.
///
/// Maintains dual exponential moving averages (fast and slow) and exposes
/// pure functions for artifact rejection, trend detection, and HR reserve
/// normalization. All numeric thresholds are sourced from `Theme.Audio` tokens.
///
/// Thread-safety: this type is **not** `Sendable`. It is owned exclusively by
/// `BiometricProcessor` (an actor) which serializes all access.
public final class HeartRateAnalyzer {

    // MARK: - Processed Result

    /// The result of processing a single raw HR sample.
    public struct ProcessedSample: Sendable {
        /// The accepted (or substituted) smoothed HR value (BPM).
        public let smoothed: Double
        /// Fast EMA value (BPM) — responsive to recent changes.
        public let fast: Double
        /// Slow EMA value (BPM) — stable baseline.
        public let slow: Double
        /// Whether the raw sample was rejected as an artifact.
        public let wasArtifact: Bool
    }

    // MARK: - State

    private var hrFast: Double?
    private var hrSlow: Double?
    private var lastSmoothed: Double?

    /// Number of artifacts observed in the current quality window.
    private(set) var recentArtifactCount: Int = 0

    /// Timestamps of recent artifacts for quality scoring.
    private var artifactTimestamps: [Date] = []

    // MARK: - Configuration (from Theme.Audio tokens)

    private let alphaFast: Double
    private let alphaSlow: Double
    private let artifactThreshold: Double
    private let trendDeadband: Double

    // MARK: - Init

    public init() {
        self.alphaFast = Theme.Audio.EMA.fast
        self.alphaSlow = Theme.Audio.EMA.slow
        self.artifactThreshold = Theme.Audio.ArtifactRejection.thresholdBPM
        self.trendDeadband = Theme.Audio.TrendDetection.deadband
    }

    // MARK: - Public API

    /// Process a raw heart rate sample. Performs artifact rejection then
    /// dual-EMA smoothing. Returns the processed sample with fast/slow values.
    ///
    /// - Parameters:
    ///   - rawHR: Raw heart rate in BPM from the sensor.
    ///   - timestamp: Timestamp of the sample (used for artifact tracking).
    /// - Returns: Processed sample containing smoothed, fast, and slow EMAs.
    public func process(rawHR: Double, timestamp: Date = Date()) -> ProcessedSample {
        // --- Artifact Rejection ---
        let wasArtifact: Bool
        let acceptedHR: Double

        if let previous = lastSmoothed {
            if abs(rawHR - previous) > artifactThreshold {
                // Reject: substitute last smoothed value
                wasArtifact = true
                acceptedHR = previous
                recordArtifact(at: timestamp)
            } else {
                wasArtifact = false
                acceptedHR = rawHR
            }
        } else {
            // First sample — always accept
            wasArtifact = false
            acceptedHR = rawHR
        }

        // --- Dual EMA Update ---
        let newFast: Double
        let newSlow: Double

        if let prevFast = hrFast, let prevSlow = hrSlow {
            newFast = alphaFast * acceptedHR + (1.0 - alphaFast) * prevFast
            newSlow = alphaSlow * acceptedHR + (1.0 - alphaSlow) * prevSlow
        } else {
            // Seed both EMAs with the first accepted value
            newFast = acceptedHR
            newSlow = acceptedHR
        }

        hrFast = newFast
        hrSlow = newSlow
        lastSmoothed = newSlow

        return ProcessedSample(
            smoothed: newSlow,
            fast: newFast,
            slow: newSlow,
            wasArtifact: wasArtifact
        )
    }

    /// Detect the current HR trend from fast/slow EMA divergence (MACD-style).
    ///
    /// - Returns: `.rising` if fast exceeds slow by more than the deadband,
    ///   `.falling` if below negative deadband, `.stable` otherwise.
    public func detectTrend() -> HRTrend {
        guard let fast = hrFast, let slow = hrSlow else { return .stable }
        let divergence = fast - slow
        if divergence > trendDeadband {
            return .rising
        } else if divergence < -trendDeadband {
            return .falling
        } else {
            return .stable
        }
    }

    /// The current trend magnitude (HR_fast - HR_slow). Returns 0 if not yet initialized.
    public var trendMagnitude: Double {
        guard let fast = hrFast, let slow = hrSlow else { return 0.0 }
        return fast - slow
    }

    /// Normalize a heart rate value to the 0.0-1.0 Heart Rate Reserve scale.
    ///
    /// - Parameters:
    ///   - heartRate: Current heart rate (BPM).
    ///   - restingHR: User's resting heart rate (BPM).
    ///   - maxHR: User's estimated maximum heart rate (BPM).
    /// - Returns: Clamped value in [0.0, 1.0].
    public func heartRateReserveNormalized(
        heartRate: Double,
        restingHR: Double,
        maxHR: Double
    ) -> Double {
        let reserve = maxHR - restingHR
        guard reserve > 0 else { return 0.0 }
        let normalized = (heartRate - restingHR) / reserve
        return min(max(normalized, 0.0), 1.0)
    }

    /// The number of artifacts within the given time window.
    /// Used by the processor to detect sustained quality issues.
    public func artifactCount(within window: TimeInterval, relativeTo now: Date) -> Int {
        artifactTimestamps.filter { now.timeIntervalSince($0) <= window }.count
    }

    /// Reset all internal state. Called when starting a new session.
    public func reset() {
        hrFast = nil
        hrSlow = nil
        lastSmoothed = nil
        recentArtifactCount = 0
        artifactTimestamps.removeAll()
    }

    // MARK: - Private

    private func recordArtifact(at timestamp: Date) {
        artifactTimestamps.append(timestamp)
        // Prune old entries (keep last 30 seconds)
        let cutoff = timestamp.addingTimeInterval(-30.0)
        artifactTimestamps.removeAll { $0 < cutoff }
        recentArtifactCount = artifactTimestamps.count
    }
}
