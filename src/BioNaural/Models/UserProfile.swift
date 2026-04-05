// UserProfile.swift
// BioNaural
//
// SwiftData model for user preferences and physiological baselines.
// Singleton in practice — the app creates one on first launch and
// updates it as the user configures settings and completes calibration.

import Foundation
import SwiftData
import BioNauralShared

/// Persistent user preferences and physiological baselines.
///
/// The adaptive algorithm reads baselines to normalize heart-rate data.
/// The UI reads preferences to configure session defaults. The learning
/// system updates baselines as more data is collected.
@Model
public final class UserProfile {

    // MARK: - Identity

    /// Unique profile identifier.
    @Attribute(.unique)
    public var id: UUID

    // MARK: - Physiological Baselines

    /// Resting heart rate baseline (BPM), established during calibration
    /// or imported from HealthKit. `nil` until calibration completes.
    public var baselineRestingHR: Double?

    /// Resting HRV baseline (ms RMSSD), established during calibration
    /// or imported from HealthKit. `nil` until calibration completes.
    public var baselineHRV: Double?

    /// Date of the most recent calibration session. `nil` if the user
    /// has never calibrated.
    public var calibrationDate: Date?

    // MARK: - Session Preferences

    /// The user's preferred session mode, stored as a `FocusMode` raw value.
    public var preferredMode: String

    /// Default session duration in minutes.
    public var preferredDurationMinutes: Int

    /// How aggressively the adaptive algorithm responds to biometric changes.
    /// `0.0` = minimal adaptation, `1.0` = maximum sensitivity.
    public var adaptationSensitivity: Double

    // MARK: - UX Preferences

    /// Whether haptic feedback is delivered during sessions (e.g. breathing
    /// cues, state transitions).
    public var hapticFeedbackEnabled: Bool

    /// Sound style preference: "nature", "musical", "minimal", or "mix".
    public var soundPreference: String

    // MARK: - Pomodoro

    /// Whether the Pomodoro timer is active in Focus mode.
    public var pomodoroEnabled: Bool

    /// Number of focus/break cycles in a Pomodoro set.
    public var pomodoroCycles: Int

    // MARK: - Notifications

    /// Whether session reminders are enabled.
    public var notificationsEnabled: Bool

    /// Scheduled time for the daily session reminder. `nil` if no reminder
    /// is configured.
    public var sessionReminderTime: Date?

    /// Whether the weekly session summary notification is enabled.
    public var weeklySummaryEnabled: Bool

    // MARK: - Initialization

    /// Creates a new user profile with sensible defaults.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - baselineRestingHR: Resting HR baseline (BPM), or `nil`.
    ///   - baselineHRV: Resting HRV baseline (ms), or `nil`.
    ///   - calibrationDate: Date of last calibration, or `nil`.
    ///   - preferredMode: Default mode as `FocusMode` raw value. Defaults to `"focus"`.
    ///   - preferredDurationMinutes: Default duration. Defaults to `25`.
    ///   - adaptationSensitivity: Adaptation sensitivity (0-1). Defaults to `0.5`.
    ///   - hapticFeedbackEnabled: Enable haptics. Defaults to `true`.
    ///   - soundPreference: Sound style. Defaults to `"mix"`.
    ///   - pomodoroEnabled: Enable Pomodoro. Defaults to `false`.
    ///   - pomodoroCycles: Pomodoro cycle count. Defaults to `4`.
    ///   - notificationsEnabled: Enable notifications. Defaults to `false`.
    ///   - sessionReminderTime: Reminder time, or `nil`.
    public init(
        id: UUID = UUID(),
        baselineRestingHR: Double? = nil,
        baselineHRV: Double? = nil,
        calibrationDate: Date? = nil,
        preferredMode: String = FocusMode.focus.rawValue,
        preferredDurationMinutes: Int = 25,
        adaptationSensitivity: Double = 0.5,
        hapticFeedbackEnabled: Bool = true,
        soundPreference: String = "mix",
        pomodoroEnabled: Bool = false,
        pomodoroCycles: Int = 4,
        notificationsEnabled: Bool = false,
        sessionReminderTime: Date? = nil,
        weeklySummaryEnabled: Bool = false
    ) {
        self.id = id
        self.baselineRestingHR = baselineRestingHR
        self.baselineHRV = baselineHRV
        self.calibrationDate = calibrationDate
        self.preferredMode = preferredMode
        self.preferredDurationMinutes = preferredDurationMinutes
        self.adaptationSensitivity = adaptationSensitivity
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.soundPreference = soundPreference
        self.pomodoroEnabled = pomodoroEnabled
        self.pomodoroCycles = pomodoroCycles
        self.notificationsEnabled = notificationsEnabled
        self.sessionReminderTime = sessionReminderTime
        self.weeklySummaryEnabled = weeklySummaryEnabled
    }

    // MARK: - Convenience

    /// The user's preferred mode as a typed `FocusMode` enum value.
    ///
    /// Returns `nil` if the stored string does not match a known case.
    public var focusMode: FocusMode? {
        FocusMode(rawValue: preferredMode)
    }

    /// Whether the user has completed at least one calibration session.
    public var isCalibrated: Bool {
        baselineRestingHR != nil && baselineHRV != nil && calibrationDate != nil
    }
}
