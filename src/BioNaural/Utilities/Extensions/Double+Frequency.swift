// Double+Frequency.swift
// BioNaural
//
// Numeric formatting extensions for binaural frequencies, biometrics, and
// session durations. Keeps format strings out of view code and ensures
// consistent display across the app.

import Foundation

// MARK: - Frequency Formatting

extension Double {

    /// Formatted as a binaural beat frequency: "10.0 Hz".
    ///
    /// Uses one decimal place — standard precision for binaural display.
    var formattedHz: String {
        String(format: "%.1f Hz", self)
    }

    /// Formatted as a frequency range: "6→2 Hz".
    ///
    /// Used for sleep mode display where the beat frequency ramps from a
    /// start value down to an end value over the session duration.
    ///
    /// - Parameter end: The target end frequency.
    /// - Returns: A string like "6→2 Hz".
    func formattedHzRange(to end: Double) -> String {
        let startText = String(format: "%.0f", self)
        let endText = String(format: "%.0f", end)
        return "\(startText)\u{2192}\(endText) Hz"
    }
}

// MARK: - Biometric Formatting

extension Double {

    /// Formatted as a heart rate: "72 BPM".
    var formattedBPM: String {
        String(format: "%.0f BPM", self)
    }

    /// Formatted as heart-rate variability: "45 ms".
    var formattedHRV: String {
        String(format: "%.0f ms", self)
    }
}

// MARK: - Duration Formatting

extension Double {

    /// Formatted as a session duration from a `TimeInterval` (seconds).
    ///
    /// - Less than one hour: "25:30" (mm:ss)
    /// - One hour or more: "1:02:30" (h:mm:ss)
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Int Duration Convenience

extension Int {

    /// Formatted as a session duration from whole seconds.
    ///
    /// Delegates to `Double.formattedDuration` for consistent output.
    var formattedDuration: String {
        Double(self).formattedDuration
    }
}
