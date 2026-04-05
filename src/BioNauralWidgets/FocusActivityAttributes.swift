// FocusActivityAttributes.swift
// BioNauralWidgets
//
// ActivityAttributes defining the Live Activity data contract.
// Static properties describe the session configuration (set once at start).
// ContentState carries continuously-updated session telemetry.

import ActivityKit
import Foundation

// MARK: - FocusActivityAttributes

/// Defines the data contract for BioNaural's focus session Live Activity.
///
/// Static fields capture session configuration that does not change once the
/// activity starts. The mutable `ContentState` carries real-time telemetry
/// pushed from the main app process at ~1 Hz.
struct FocusActivityAttributes: ActivityAttributes {

    // MARK: - Static Properties (set once at session start)

    /// When the session began — used by `Text(timerInterval:)` for
    /// lock screen and Dynamic Island countdown.
    var sessionStartDate: Date

    /// User-selected target duration in minutes. Zero indicates an
    /// open-ended session with no predetermined length.
    var targetDurationMinutes: Int

    /// Human-readable mode name ("Focus", "Relaxation", "Sleep").
    var modeName: String

    /// Semantic color token name resolved by the widget to pick the
    /// correct mode accent color (e.g. "focus", "relaxation", "sleep").
    var modeColorName: String

    // MARK: - ContentState (updated throughout session)

    /// Mutable state pushed to the Live Activity via `Activity.update`.
    struct ContentState: Codable, Hashable {

        /// Seconds elapsed since session start. Drives progress
        /// calculations when a target duration is set.
        var elapsedSeconds: Int

        /// Current heart rate in BPM from Watch/BLE sensor.
        /// `nil` when no biometric source is connected.
        var currentHR: Int?

        /// Current mode display name (may differ from the static
        /// `modeName` if mode transitions are supported in future).
        var currentMode: String

        /// Active binaural beat frequency in Hz (e.g. 14.0 for beta).
        var beatFrequency: Double

        /// Whether audio playback is currently active.
        var isPlaying: Bool
    }
}
