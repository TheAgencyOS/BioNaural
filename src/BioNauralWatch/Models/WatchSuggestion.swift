// WatchSuggestion.swift
// BioNauralWatch
//
// Simple value type representing the output of the suggestion engine.
// Contains the recommended mode, duration, display strings, and the
// biometric context that informed the suggestion.

import Foundation
import BioNauralShared

struct WatchSuggestion: Sendable {
    /// The recommended focus mode.
    let mode: FocusMode
    /// Suggested duration in minutes, or nil if no history to draw from.
    let durationMinutes: Int?
    /// Headline shown on the idle screen (varies by learning stage).
    let title: String
    /// Supporting context line explaining why this mode was chosen.
    let contextText: String
    /// The user's current heart rate at the time the suggestion was computed, if available.
    let currentHR: Double?
    /// The biometric state classification at the time of suggestion, if HR was available.
    let currentHRState: BiometricState?
}
