import Foundation

/// Pure-function utilities for binaural beat frequency calculations and
/// biometric signal normalization.
///
/// All functions are stateless, deterministic, and suitable for use on any
/// thread including the audio render thread (no allocations, no locks).
public enum FrequencyMath {

    // MARK: - Sigmoid Mapping

    /// Standard logistic sigmoid function.
    ///
    /// Maps any real-valued input to the (0, 1) range. Used throughout the
    /// adaptive algorithm for smooth, bounded parameter mapping (e.g.,
    /// HR-to-frequency curves, success scoring normalization).
    ///
    /// ```
    /// sigmoid(x) = 1 / (1 + exp(-steepness * (x - midpoint)))
    /// ```
    ///
    /// - Parameters:
    ///   - x: The input value.
    ///   - midpoint: The x-value at which the output equals 0.5. Controls the
    ///     horizontal position of the curve.
    ///   - steepness: Controls the slope at the midpoint. Positive values create
    ///     an increasing curve (left-low, right-high). Negative values create a
    ///     decreasing curve (left-high, right-low). Larger absolute values
    ///     produce a sharper transition.
    /// - Returns: A value in the open interval (0, 1).
    public static func sigmoid(x: Double, midpoint: Double, steepness: Double) -> Double {
        1.0 / (1.0 + exp(-steepness * (x - midpoint)))
    }

    // MARK: - Heart Rate Normalization

    /// Computes the heart-rate-reserve normalized value.
    ///
    /// Heart Rate Reserve (HRR) normalization accounts for individual fitness
    /// by expressing the current heart rate as a proportion of the user's
    /// available range between resting and maximum.
    ///
    /// ```
    /// HR_normalized = (HR_current - HR_rest) / (HR_max - HR_rest)
    /// ```
    ///
    /// This is the Karvonen method and is superior to raw BPM comparison because
    /// a fit athlete at 60 BPM represents the same activation level as a
    /// sedentary user at 80 BPM.
    ///
    /// - Parameters:
    ///   - current: Current heart rate in BPM.
    ///   - resting: Resting heart rate in BPM (from HealthKit or baseline
    ///     calibration). Typical range: 45-85 BPM.
    ///   - max: Maximum heart rate in BPM. Commonly estimated via the Tanaka
    ///     formula: `208 - (0.7 * age)`.
    /// - Returns: A value clamped to 0.0...1.0, where 0.0 = resting and
    ///   1.0 = maximal effort. Returns 0.0 if `max <= resting` (invalid input).
    public static func heartRateReserveNormalized(
        current: Double,
        resting: Double,
        max: Double
    ) -> Double {
        let reserve = max - resting
        guard reserve > 0 else { return 0.0 }
        let normalized = (current - resting) / reserve
        return Swift.min(Swift.max(normalized, 0.0), 1.0)
    }

    // MARK: - Carrier Split

    /// Computes the left and right ear frequencies for a binaural beat.
    ///
    /// Binaural beats work by presenting slightly different frequencies to each
    /// ear. The brain perceives a "beat" at the difference frequency. This
    /// function splits a carrier frequency symmetrically around the desired
    /// beat frequency.
    ///
    /// ```
    /// left  = carrier - (beatFrequency / 2)
    /// right = carrier + (beatFrequency / 2)
    /// ```
    ///
    /// - Parameters:
    ///   - carrier: The center carrier frequency in Hz (e.g., 200 Hz).
    ///   - beatFrequency: The desired binaural beat frequency in Hz (e.g., 10 Hz).
    /// - Returns: A tuple of `(left: Double, right: Double)` frequencies in Hz.
    ///   The difference `right - left` equals `beatFrequency`.
    public static func carrierSplit(
        carrier: Double,
        beatFrequency: Double
    ) -> (left: Double, right: Double) {
        let halfBeat = beatFrequency / 2.0
        return (left: carrier - halfBeat, right: carrier + halfBeat)
    }

    // MARK: - BPM / RR Conversion

    /// Converts a heart rate in BPM to an RR interval in milliseconds.
    ///
    /// RR intervals (the time between successive heartbeats) are the basis for
    /// HRV computation (RMSSD, SDNN). This conversion is used when deriving
    /// approximate RR intervals from the Watch's 1 Hz BPM stream, as Apple
    /// Watch does not expose raw inter-beat intervals during live sessions.
    ///
    /// ```
    /// RR_ms = 60000 / BPM
    /// ```
    ///
    /// - Parameter bpm: Heart rate in beats per minute. Must be positive.
    /// - Returns: The RR interval in milliseconds. Returns 0 if `bpm` is
    ///   not positive (invalid input guard).
    public static func bpmToRRInterval(bpm: Double) -> Double {
        guard bpm > 0 else { return 0.0 }
        return 60_000.0 / bpm
    }
}
