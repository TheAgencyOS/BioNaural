// BiometricState.swift
// BioNaural
//
// Biometric state model and classifier with hysteresis, dwell-time gating,
// and skip-transition prevention. All thresholds from Theme.Audio tokens.
// NOTE: The BiometricState enum is also declared in BioNauralShared. This
// file re-exports or shadows it with an Int-rawValue version that adds
// Comparable conformance and transition helpers for the adaptive engine.

import Foundation
import BioNauralShared

// MARK: - BiometricState

/// Discrete biometric activation state derived from normalized heart rate.
///
/// Ordered from lowest to highest activation. The classifier enforces
/// sequential transitions — no skipping from `.calm` to `.elevated`.
///
/// This local enum shadows BioNauralShared.BiometricState to add Int raw
/// values, Comparable conformance, and transition helpers needed by the
/// adaptive engine.
public enum BiometricState: Int, CaseIterable, Comparable, Sendable {
    case calm = 0
    case focused = 1
    case elevated = 2
    case peak = 3

    public static func < (lhs: BiometricState, rhs: BiometricState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable label for logging and UI.
    public var displayName: String {
        switch self {
        case .calm:     return "Calm"
        case .focused:  return "Focused"
        case .elevated: return "Elevated"
        case .peak:     return "Peak"
        }
    }

    /// The next higher state, or `nil` if already at `.peak`.
    var higher: BiometricState? {
        BiometricState(rawValue: rawValue + 1)
    }

    /// The next lower state, or `nil` if already at `.calm`.
    var lower: BiometricState? {
        BiometricState(rawValue: rawValue - 1)
    }
}

// MARK: - StateClassifier

/// Classifies normalized heart rate into a `BiometricState` using hysteresis
/// thresholds and minimum dwell time to prevent rapid oscillation.
///
/// **Hysteresis:** Enter thresholds are offset +h from boundaries, exit
/// thresholds are offset -h (where h = `Theme.Audio.Hysteresis.band`).
///
/// **Dwell time:** A state must be occupied for at least
/// `Theme.Audio.Hysteresis.minDwellTime` before a transition is allowed.
///
/// **No skip transitions:** The classifier only moves one state at a time.
/// Calm cannot jump directly to Elevated.
///
/// Thread-safety: owned exclusively by `BiometricProcessor` (an actor).
public final class StateClassifier {

    // MARK: - State

    private(set) var currentState: BiometricState = .calm
    private var stateEnteredAt: Date = .distantPast

    // MARK: - Configuration (from Theme.Audio tokens)

    /// Zone boundaries: the nominal HR_normalized values separating states.
    /// [0] = calm/focused, [1] = focused/elevated, [2] = elevated/peak.
    private let boundaries: [Double]

    /// Hysteresis offset applied symmetrically to each boundary.
    private let hysteresis: Double

    /// Minimum seconds in a state before a transition is permitted.
    private let dwellTime: TimeInterval

    // MARK: - Derived Thresholds

    /// Enter thresholds (boundary + hysteresis) — must exceed to move up.
    private let enterThresholds: [Double]

    /// Exit thresholds (boundary - hysteresis) — must drop below to move down.
    private let exitThresholds: [Double]

    // MARK: - Init

    public init() {
        let zones = Theme.Audio.HRZone.self
        let b = [zones.calmMax, zones.focusedMax, zones.elevatedMax]
        let h = Theme.Audio.Hysteresis.band
        self.boundaries = b
        self.hysteresis = h
        self.dwellTime = Theme.Audio.Hysteresis.minDwellTime
        self.enterThresholds = b.map { $0 + h }
        self.exitThresholds = b.map { $0 - h }
    }

    // MARK: - Public API

    /// Classify the current normalized heart rate into a `BiometricState`.
    ///
    /// Enforces hysteresis (enter/exit offsets), dwell time (minimum seconds
    /// in a state), and sequential transitions (no skipping).
    ///
    /// - Parameters:
    ///   - hrNormalized: Heart rate reserve normalized value in [0.0, 1.0].
    ///   - timestamp: Current timestamp for dwell-time enforcement.
    /// - Returns: The current (possibly unchanged) `BiometricState`.
    @discardableResult
    public func classify(hrNormalized: Double, timestamp: Date) -> BiometricState {
        let dwellElapsed = timestamp.timeIntervalSince(stateEnteredAt)
        let dwellSatisfied = dwellElapsed >= dwellTime

        guard dwellSatisfied else {
            // Dwell time not met — hold current state
            return currentState
        }

        // Check for upward transition (one step only)
        if let candidateUp = currentState.higher {
            let boundaryIndex = currentState.rawValue // index into boundaries
            if boundaryIndex < enterThresholds.count,
               hrNormalized > enterThresholds[boundaryIndex] {
                transitionTo(candidateUp, at: timestamp)
                return currentState
            }
        }

        // Check for downward transition (one step only)
        if let candidateDown = currentState.lower {
            let boundaryIndex = currentState.rawValue - 1 // boundary below current
            if boundaryIndex >= 0, boundaryIndex < exitThresholds.count,
               hrNormalized < exitThresholds[boundaryIndex] {
                transitionTo(candidateDown, at: timestamp)
            }
        }

        return currentState
    }

    /// Reset the classifier to `.calm` with a fresh dwell timer.
    public func reset() {
        currentState = .calm
        stateEnteredAt = .distantPast
    }

    // MARK: - Private

    private func transitionTo(_ newState: BiometricState, at timestamp: Date) {
        currentState = newState
        stateEnteredAt = timestamp
    }
}
