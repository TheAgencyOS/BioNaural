// Color+Theme.swift
// BioNaural
//
// Convenience extensions bridging Color to the Theme token system. Provides
// hex-string initialization and semantic color lookup for modes and biometric
// states. All returned colors derive from Theme.Colors — no hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - Hex String Initializer

extension Color {

    /// Creates a Color from a CSS-style hex string.
    ///
    /// Supports formats: "#6E7CF7", "6E7CF7", "#FFF", "FFF".
    /// Falls back to `Color.clear` for malformed input.
    ///
    /// - Parameter hex: A hex color string, optionally prefixed with "#".
    init(hex string: String) {
        var hexString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        // Expand shorthand (e.g. "FFF" -> "FFFFFF")
        if hexString.count == 3 {
            hexString = hexString.map { "\($0)\($0)" }.joined()
        }

        guard hexString.count == 6,
              let hexValue = UInt(hexString, radix: 16)
        else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 0)
            return
        }

        self.init(hex: hexValue)
    }
}

// MARK: - Mode Color

extension Color {

    /// Returns the Theme color associated with a `FocusMode`.
    ///
    /// - Parameter mode: The session mode.
    /// - Returns: The corresponding mode color from `Theme.Colors`.
    static func modeColor(for mode: FocusMode) -> Color {
        switch mode {
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        }
    }
}

// MARK: - Biometric Signal Color

extension Color {

    /// Returns the Theme signal color associated with a `BiometricState`.
    ///
    /// Maps each activation level to the corresponding color from the
    /// Theme biometric signal palette.
    ///
    /// - Parameter state: The current biometric activation state.
    /// - Returns: The corresponding signal color from `Theme.Colors`.
    static func biometricColor(for state: BiometricState) -> Color {
        switch state {
        case .calm:     return Theme.Colors.signalCalm
        case .focused:  return Theme.Colors.signalFocus
        case .elevated: return Theme.Colors.signalElevated
        case .peak:     return Theme.Colors.signalPeak
        }
    }
}
