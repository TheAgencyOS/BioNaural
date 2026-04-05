// ParameterSelector.swift
// BioNaural
//
// Abstraction layer for parameter selection strategy. v1 uses deterministic
// mapping via AdaptationEngine. v1.5 swaps in an ML-backed implementation.
// The rest of the pipeline is oblivious to which is active.

import Foundation
import BioNauralShared
// MARK: - ParameterSelectorProtocol
/// Contract for the component that selects audio parameters given
/// biometric context. Designed for hot-swapping between deterministic (v1)
/// and ML-backed (v1.5) strategies without refactoring the pipeline.
public protocol ParameterSelectorProtocol: Sendable {
    /// Select audio parameter targets for the current biometric snapshot.
    ///
    /// - Parameters:
    ///   - mode: Active focus mode.
    ///   - biometricState: Classified discrete state (calm/focused/elevated/peak).
    ///   - hrNormalized: Heart rate reserve normalized [0.0, 1.0].
    ///   - hrvNormalized: HRV normalized [0.0, 1.0], nil if unavailable.
    ///   - trend: Current HR trend direction.
    ///   - trendMagnitude: Raw fast-slow EMA divergence (BPM).
    ///   - sessionProgress: Fraction of session elapsed [0.0, 1.0].
    /// - Returns: Target audio parameters (pre-slew-limiting).
    func selectParameters(
        mode: FocusMode,
        biometricState: BiometricState,
        hrNormalized: Double,
        hrvNormalized: Double?,
        trend: HRTrend,
        trendMagnitude: Double,
        sessionProgress: Double
    ) -> AudioTargets
}
// MARK: - DeterministicParameterSelector
/// v1 implementation — wraps `AdaptationEngine` and forwards all calls.
///
/// The `biometricState` parameter is available for logging, analytics, and
/// future rule-based overrides but the v1 mapping functions operate directly
/// on continuous `hrNormalized` to avoid quantization artifacts.
public struct DeterministicParameterSelector: ParameterSelectorProtocol {
    private let engine: AdaptationEngine
    public init(engine: AdaptationEngine = AdaptationEngine()) {
        self.engine = engine
    }
    public func selectParameters(
        mode: FocusMode,
        biometricState: BiometricState,
        hrNormalized: Double,
        hrvNormalized: Double?,
        trend: HRTrend,
        trendMagnitude: Double,
        sessionProgress: Double
    ) -> AudioTargets {
        engine.computeTargets(
            mode: mode,
            hrNormalized: hrNormalized,
            hrvNormalized: hrvNormalized,
            trend: trend,
            trendMagnitude: trendMagnitude,
            sessionProgress: sessionProgress
        )
    }
}
