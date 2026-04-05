import Foundation

/// Physiological activation state derived from heart-rate reserve normalization.
///
/// The adaptive algorithm classifies the user's current activation level into
/// one of four zones based on `HR_normalized` — the heart-rate reserve ratio
/// `(HR_current - HR_rest) / (HR_max - HR_rest)`. This value ranges from 0.0
/// (resting) to 1.0 (maximal effort).
///
/// State transitions use hysteresis and a 5-second dwell time to prevent
/// jittery classification. See Tech-AdaptiveAlgorithm.md for the full
/// control-loop specification.
public enum BiometricState: String, Codable, CaseIterable, Identifiable, Sendable {

    /// Resting or near-resting activation. HR_normalized 0.00-0.20.
    case calm

    /// Light activation consistent with focused cognitive work. HR_normalized 0.20-0.45.
    case focused

    /// Moderate activation — stress, physical exertion, or arousal. HR_normalized 0.45-0.70.
    case elevated

    /// High activation — peak exertion or acute stress. HR_normalized 0.70-1.00.
    case peak

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Zone Ranges

    /// The heart-rate-reserve normalized range for this state.
    ///
    /// `HR_normalized = (HR_current - HR_rest) / (HR_max - HR_rest)`
    ///
    /// These thresholds match the zone table defined in the Adaptive Algorithm
    /// specification:
    /// - calm:     0.00 - 0.20
    /// - focused:  0.20 - 0.45
    /// - elevated: 0.45 - 0.70
    /// - peak:     0.70 - 1.00
    public var hrNormalizedRange: ClosedRange<Double> {
        switch self {
        case .calm:     return 0.00...0.20
        case .focused:  return 0.20...0.45
        case .elevated: return 0.45...0.70
        case .peak:     return 0.70...1.00
        }
    }

    // MARK: - Classification

    /// Returns the biometric state for a given heart-rate-reserve normalized value.
    ///
    /// Values outside 0.0...1.0 are clamped. This is a stateless point-in-time
    /// classification; the adaptive engine applies hysteresis and dwell-time
    /// logic on top of this.
    ///
    /// - Parameter hrNormalized: The heart-rate reserve value (0.0 = resting,
    ///   1.0 = max effort). Clamped to 0.0...1.0.
    /// - Returns: The corresponding `BiometricState`.
    public static func classify(hrNormalized: Double) -> BiometricState {
        let clamped = min(max(hrNormalized, 0.0), 1.0)
        switch clamped {
        case 0.00...0.20: return .calm
        case 0.20...0.45: return .focused
        case 0.45...0.70: return .elevated
        default:          return .peak
        }
    }
}
