// HealthKitServiceProtocol.swift
// BioNaural
//
// Protocol defining the public surface of the HealthKit service.
// All methods degrade gracefully — returning nil when HealthKit is
// unavailable or authorization has been denied.

import Foundation

/// A single sleep stage with its duration, extracted from HealthKit sleep analysis.
public struct SleepStage: Sendable, Equatable {

    /// The type of sleep stage as reported by HealthKit.
    public enum Stage: String, Sendable, Equatable, CaseIterable {
        case awake
        case rem
        case core
        case deep
    }

    /// Which stage of sleep this represents.
    public let stage: Stage

    /// How long the user spent in this stage, in seconds.
    public let duration: TimeInterval

    public init(stage: Stage, duration: TimeInterval) {
        self.stage = stage
        self.duration = duration
    }
}

/// Contract for reading biometric context from HealthKit and writing
/// mindful session data back.
///
/// All read methods return `nil` when:
/// - HealthKit is not available on the device.
/// - The user has denied the relevant authorization.
/// - No matching samples exist in the requested time window.
///
/// Implementations must never throw on permission denial — silent
/// degradation is the contract.
public protocol HealthKitServiceProtocol: AnyObject, Sendable {

    /// Whether HealthKit is available on this device.
    var isAvailable: Bool { get }

    /// Requests read/write authorization for all data types used by BioNaural.
    ///
    /// - Throws: Only for unexpected system errors (not for user denial).
    ///   When the user denies authorization, subsequent queries simply return `nil`.
    func requestAuthorization() async throws

    /// The most recent resting heart rate sample within the last 48 hours.
    ///
    /// - Returns: Resting heart rate in BPM, or `nil` if unavailable.
    func latestRestingHR() async -> Double?

    /// The most recent HRV (SDNN) sample within the last 24 hours.
    ///
    /// - Returns: Heart rate variability in milliseconds, or `nil` if unavailable.
    func latestHRV() async -> Double?

    /// Sleep data from the most recent night (last 24 hours).
    ///
    /// Filters to asleep stages only (core, deep, REM). Awake-in-bed
    /// stages are included in the stage breakdown but not in total hours.
    ///
    /// - Returns: A tuple of total asleep hours, deep sleep minutes,
    ///   and a per-stage breakdown; or `nil` if no sleep data is available.
    func lastNightSleep() async -> (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])?

    /// Cumulative step count for the current calendar day.
    ///
    /// - Returns: Step count as an integer, or `nil` if unavailable.
    func stepsToday() async -> Int?

    /// The most recent blood oxygen saturation reading.
    ///
    /// - Returns: SpO2 as a percentage (e.g., 0.98 for 98%), or `nil`
    ///   if unavailable or the device does not support SpO2.
    func oxygenSaturation() async -> Double?

    /// Saves a mindful session to HealthKit.
    ///
    /// Used to log completed BioNaural sessions (Focus, Relaxation, Sleep, Energize)
    /// as mindfulness minutes in the Health app.
    ///
    /// - Parameters:
    ///   - start: The session start date.
    ///   - end: The session end date.
    func saveMindfulSession(start: Date, end: Date) async

    /// Saves a State of Mind sample to HealthKit (iOS 18+).
    ///
    /// Records the user's emotional state at the end of a BioNaural session,
    /// allowing Apple Health to surface mood trends alongside mindful minutes.
    ///
    /// - Parameters:
    ///   - valence: Emotional valence on a -1.0 to 1.0 scale.
    ///   - label: The primary emotion label (e.g., "focused", "calm").
    ///   - association: The context association (e.g., "selfCare").
    func saveStateOfMind(valence: Double, label: String, association: String) async

    /// Saves a workout session to HealthKit.
    ///
    /// Used to log Energize mode sessions as mind-and-body workouts.
    ///
    /// - Parameters:
    ///   - activityType: The HKWorkoutActivityType raw value for this workout.
    ///   - start: The workout start date.
    ///   - end: The workout end date.
    ///   - energyBurned: Optional active energy burned in kilocalories.
    func saveWorkout(activityType: UInt, start: Date, end: Date, energyBurned: Double?) async

    // MARK: - GAP 4: Active Energy Burned

    /// Cumulative active energy burned for the current calendar day.
    ///
    /// - Returns: Active energy in kilocalories, or `nil` if unavailable.
    func activeEnergyToday() async -> Double?

    // MARK: - GAP 5: Multi-Day Averages

    /// Average resting heart rate over the last N days.
    ///
    /// Queries all resting heart rate samples in the date range and
    /// computes the arithmetic mean.
    ///
    /// - Parameter days: Number of days to look back.
    /// - Returns: Average resting HR in BPM, or `nil` if no samples exist.
    func averageRestingHR(days: Int) async -> Double?

    /// Average HRV (SDNN) over the last N days.
    ///
    /// Queries all HRV samples in the date range and computes the
    /// arithmetic mean.
    ///
    /// - Parameter days: Number of days to look back.
    /// - Returns: Average HRV in milliseconds, or `nil` if no samples exist.
    func averageHRV(days: Int) async -> Double?

    // MARK: - GAP 6: Sleep Observer

    /// Starts an observer query on sleep analysis data for background delivery.
    ///
    /// When new sleep data arrives (typically daily), the provided handler
    /// is called so the app can refresh its user model.
    ///
    /// - Note: Requires `UIBackgroundModes: "processing"` or `"fetch"` in
    ///   Info.plist in addition to `"audio"` for background delivery to work.
    ///
    /// - Parameter handler: Closure invoked when new sleep data is available.
    func startSleepObserver(handler: @escaping @Sendable () -> Void) async throws

    // MARK: - GAP 7: Authorization Change Listener

    /// An `AsyncStream` that emits `true` when HealthKit authorization changes
    /// from denied/not-determined to authorized, and `false` otherwise.
    ///
    /// Observers (e.g., `UserModelBuilder`, `SessionViewModel`) can listen to
    /// this stream to react to permission changes while the app is in the foreground.
    var authorizationStatusChanged: AsyncStream<Bool> { get }

    // MARK: - GAP 8: Heart Rate Queries

    /// The most recent heart rate sample within the last hour.
    ///
    /// Useful for pre-session context when the Watch is not yet streaming
    /// (e.g., displaying "Your current HR is 72" on the session start screen).
    ///
    /// - Returns: Heart rate in BPM, or `nil` if no sample exists in the last hour.
    func latestHeartRate() async -> Double?

    /// Heart rate samples over the last N hours, sorted chronologically.
    ///
    /// Returns all HR samples in the window for trend display (e.g., a
    /// sparkline chart on the session preparation screen).
    ///
    /// - Parameter hours: Number of hours to look back.
    /// - Returns: An array of date/BPM pairs sorted ascending by date,
    ///   or `nil` if unavailable.
    func heartRateHistory(hours: Int) async -> [(date: Date, bpm: Double)]?
}
