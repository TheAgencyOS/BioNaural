// MockHealthKitService.swift
// BioNaural
//
// Configurable mock for unit and integration testing.
// Provides stub return values and call counters for every protocol method.

import Foundation

/// A fully configurable mock of `HealthKitServiceProtocol` for testing.
///
/// Each protocol method has:
/// - A **stub** property to control the return value.
/// - A **call counter** that increments on every invocation.
///
/// Example usage:
/// ```swift
/// let mock = MockHealthKitService()
/// mock.stubLatestRestingHR = 62.0
/// let hr = await mock.latestRestingHR()
/// XCTAssertEqual(hr, 62.0)
/// XCTAssertEqual(mock.latestRestingHRCallCount, 1)
/// ```
public final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {

    // MARK: - isAvailable

    /// Controls what `isAvailable` returns. Defaults to `true`.
    public var stubIsAvailable: Bool = true

    public var isAvailable: Bool { stubIsAvailable }

    // MARK: - requestAuthorization

    /// Number of times `requestAuthorization()` has been called.
    public private(set) var requestAuthorizationCallCount: Int = 0

    /// If non-nil, `requestAuthorization()` will throw this error.
    public var stubRequestAuthorizationError: Error?

    public func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let error = stubRequestAuthorizationError {
            throw error
        }
    }

    // MARK: - latestRestingHR

    /// Number of times `latestRestingHR()` has been called.
    public private(set) var latestRestingHRCallCount: Int = 0

    /// The value returned by `latestRestingHR()`. Defaults to `nil`.
    public var stubLatestRestingHR: Double?

    public func latestRestingHR() async -> Double? {
        latestRestingHRCallCount += 1
        return stubLatestRestingHR
    }

    // MARK: - latestHRV

    /// Number of times `latestHRV()` has been called.
    public private(set) var latestHRVCallCount: Int = 0

    /// The value returned by `latestHRV()`. Defaults to `nil`.
    public var stubLatestHRV: Double?

    public func latestHRV() async -> Double? {
        latestHRVCallCount += 1
        return stubLatestHRV
    }

    // MARK: - lastNightSleep

    /// Number of times `lastNightSleep()` has been called.
    public private(set) var lastNightSleepCallCount: Int = 0

    /// The value returned by `lastNightSleep()`. Defaults to `nil`.
    public var stubLastNightSleep: (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])?

    public func lastNightSleep() async -> (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])? {
        lastNightSleepCallCount += 1
        return stubLastNightSleep
    }

    // MARK: - stepsToday

    /// Number of times `stepsToday()` has been called.
    public private(set) var stepsTodayCallCount: Int = 0

    /// The value returned by `stepsToday()`. Defaults to `nil`.
    public var stubStepsToday: Int?

    public func stepsToday() async -> Int? {
        stepsTodayCallCount += 1
        return stubStepsToday
    }

    // MARK: - oxygenSaturation

    /// Number of times `oxygenSaturation()` has been called.
    public private(set) var oxygenSaturationCallCount: Int = 0

    /// The value returned by `oxygenSaturation()`. Defaults to `nil`.
    public var stubOxygenSaturation: Double?

    public func oxygenSaturation() async -> Double? {
        oxygenSaturationCallCount += 1
        return stubOxygenSaturation
    }

    // MARK: - saveMindfulSession

    /// Number of times `saveMindfulSession(start:end:)` has been called.
    public private(set) var saveMindfulSessionCallCount: Int = 0

    /// Captures the arguments from the most recent `saveMindfulSession` call.
    public private(set) var lastSavedMindfulSession: (start: Date, end: Date)?

    public func saveMindfulSession(start: Date, end: Date) async {
        saveMindfulSessionCallCount += 1
        lastSavedMindfulSession = (start: start, end: end)
    }

    // MARK: - saveStateOfMind

    /// Number of times `saveStateOfMind(valence:label:association:)` has been called.
    public private(set) var saveStateOfMindCallCount: Int = 0

    /// Captures the arguments from the most recent `saveStateOfMind` call.
    public private(set) var lastSavedStateOfMind: (valence: Double, label: String, association: String)?

    public func saveStateOfMind(valence: Double, label: String, association: String) async {
        saveStateOfMindCallCount += 1
        lastSavedStateOfMind = (valence: valence, label: label, association: association)
    }

    // MARK: - saveWorkout

    /// Number of times `saveWorkout(activityType:start:end:energyBurned:)` has been called.
    public private(set) var saveWorkoutCallCount: Int = 0

    /// Captures the arguments from the most recent `saveWorkout` call.
    public private(set) var lastSavedWorkout: (activityType: UInt, start: Date, end: Date, energyBurned: Double?)?

    public func saveWorkout(activityType: UInt, start: Date, end: Date, energyBurned: Double?) async {
        saveWorkoutCallCount += 1
        lastSavedWorkout = (activityType: activityType, start: start, end: end, energyBurned: energyBurned)
    }

    // MARK: - activeEnergyToday (GAP 4)

    /// Number of times `activeEnergyToday()` has been called.
    public private(set) var activeEnergyTodayCallCount: Int = 0

    /// The value returned by `activeEnergyToday()`. Defaults to `nil`.
    public var stubActiveEnergyToday: Double?

    public func activeEnergyToday() async -> Double? {
        activeEnergyTodayCallCount += 1
        return stubActiveEnergyToday
    }

    // MARK: - averageRestingHR (GAP 5)

    /// Number of times `averageRestingHR(days:)` has been called.
    public private(set) var averageRestingHRCallCount: Int = 0

    /// The value returned by `averageRestingHR(days:)`. Defaults to `nil`.
    public var stubAverageRestingHR: Double?

    public func averageRestingHR(days: Int) async -> Double? {
        averageRestingHRCallCount += 1
        return stubAverageRestingHR
    }

    // MARK: - averageHRV (GAP 5)

    /// Number of times `averageHRV(days:)` has been called.
    public private(set) var averageHRVCallCount: Int = 0

    /// The value returned by `averageHRV(days:)`. Defaults to `nil`.
    public var stubAverageHRV: Double?

    public func averageHRV(days: Int) async -> Double? {
        averageHRVCallCount += 1
        return stubAverageHRV
    }

    // MARK: - startSleepObserver (GAP 6)

    /// Number of times `startSleepObserver(handler:)` has been called.
    public private(set) var startSleepObserverCallCount: Int = 0

    /// If non-nil, `startSleepObserver(handler:)` will throw this error.
    public var stubStartSleepObserverError: Error?

    /// Captures the handler from the most recent `startSleepObserver` call.
    public private(set) var lastSleepObserverHandler: (() -> Void)?

    public func startSleepObserver(handler: @escaping @Sendable () -> Void) async throws {
        startSleepObserverCallCount += 1
        lastSleepObserverHandler = handler
        if let error = stubStartSleepObserverError {
            throw error
        }
    }

    // MARK: - authorizationStatusChanged (GAP 7)

    /// The `AsyncStream` exposed by the mock. Yields values pushed via
    /// `emitAuthorizationChange(_:)`.
    private let _authContinuation: AsyncStream<Bool>.Continuation
    private let _authStream: AsyncStream<Bool>

    public var authorizationStatusChanged: AsyncStream<Bool> {
        _authStream
    }

    /// Pushes a value into the `authorizationStatusChanged` stream for testing.
    public func emitAuthorizationChange(_ isAuthorized: Bool) {
        _authContinuation.yield(isAuthorized)
    }

    // MARK: - Initialization

    public init() {
        var continuation: AsyncStream<Bool>.Continuation!
        let stream = AsyncStream<Bool>(bufferingPolicy: .bufferingNewest(1)) { c in
            continuation = c
        }
        self._authContinuation = continuation
        self._authStream = stream
    }

    // MARK: - latestHeartRate (GAP 8)

    /// Number of times `latestHeartRate()` has been called.
    public private(set) var latestHeartRateCallCount: Int = 0

    /// The value returned by `latestHeartRate()`. Defaults to `nil`.
    public var stubLatestHeartRate: Double?

    public func latestHeartRate() async -> Double? {
        latestHeartRateCallCount += 1
        return stubLatestHeartRate
    }

    // MARK: - heartRateHistory (GAP 8)

    /// Number of times `heartRateHistory(hours:)` has been called.
    public private(set) var heartRateHistoryCallCount: Int = 0

    /// The value returned by `heartRateHistory(hours:)`. Defaults to `nil`.
    public var stubHeartRateHistory: [(date: Date, bpm: Double)]?

    public func heartRateHistory(hours: Int) async -> [(date: Date, bpm: Double)]? {
        heartRateHistoryCallCount += 1
        return stubHeartRateHistory
    }

    // MARK: - Convenience

    /// Resets all call counters and captured arguments to their initial state.
    public func reset() {
        requestAuthorizationCallCount = 0
        latestRestingHRCallCount = 0
        latestHRVCallCount = 0
        lastNightSleepCallCount = 0
        stepsTodayCallCount = 0
        oxygenSaturationCallCount = 0
        saveMindfulSessionCallCount = 0
        lastSavedMindfulSession = nil
        saveStateOfMindCallCount = 0
        lastSavedStateOfMind = nil
        saveWorkoutCallCount = 0
        lastSavedWorkout = nil
        activeEnergyTodayCallCount = 0
        averageRestingHRCallCount = 0
        averageHRVCallCount = 0
        startSleepObserverCallCount = 0
        lastSleepObserverHandler = nil
        latestHeartRateCallCount = 0
        heartRateHistoryCallCount = 0
    }
}
