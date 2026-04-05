// HealthKitService.swift
// BioNaural
//
// Concrete HealthKit integration using HKHealthStore.
// All queries use HKSampleQueryDescriptor with async/await (iOS 17+).
// Returns nil gracefully when unavailable or denied — never throws
// on permission issues.

// MARK: - Info.plist Requirements
// The following keys MUST be present in the app's Info.plist for HealthKit to function:
//
// NSHealthShareUsageDescription:
//   "BioNaural reads your heart rate, HRV, sleep, activity, and blood oxygen data
//    to personalize adaptive audio sessions in real time."
//
// NSHealthUpdateUsageDescription:
//   "BioNaural logs your mindfulness sessions, emotional state, and workout data
//    to Apple Health to track your wellness journey."
//
// UIBackgroundModes must include: "audio" (for background playback)
// UIBackgroundModes should include: "processing" (for background sleep data observer)
//
// com.apple.developer.healthkit entitlement must be enabled in Signing & Capabilities.

import Foundation
import HealthKit
import UIKit
import os

/// Production HealthKit service that reads biometric context and writes
/// mindful session data.
///
/// Thread-safe via `@unchecked Sendable` — `HKHealthStore` is documented
/// as safe to use from any thread; the logger and type sets are immutable
/// after init.
public final class HealthKitService: HealthKitServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let healthStore: HKHealthStore
    private let logger = Logger(subsystem: "com.bionaural.app", category: "HealthKit")
    private let calendar: Calendar

    // MARK: - GAP 6: Sleep Observer State

    /// Retains the sleep observer query so it is not deallocated.
    private var sleepObserverQuery: HKObserverQuery?

    // MARK: - GAP 7: Authorization Change Tracking

    /// Continuation backing `authorizationStatusChanged`.
    private let authContinuation: AsyncStream<Bool>.Continuation
    private let _authorizationStatusChanged: AsyncStream<Bool>

    /// Tracks the last known authorization state across foreground checks.
    private var lastKnownAuthStatus: Bool = false

    // MARK: - Type Sets

    /// All quantity and category types BioNaural reads from HealthKit.
    private let readTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        types.insert(HKQuantityType(.heartRate))
        types.insert(HKQuantityType(.heartRateVariabilitySDNN))
        types.insert(HKQuantityType(.restingHeartRate))
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKQuantityType(.oxygenSaturation))
        types.insert(HKQuantityType(.stepCount))
        types.insert(HKQuantityType(.activeEnergyBurned))
        return types
    }()

    /// Types BioNaural writes to HealthKit.
    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        types.insert(HKCategoryType(.mindfulSession))
        // State of Mind available iOS 18+, added via authorization if available
        types.insert(HKWorkoutType.workoutType())
        return types
    }()

    // MARK: - HealthKitServiceProtocol

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public var authorizationStatusChanged: AsyncStream<Bool> {
        _authorizationStatusChanged
    }

    // MARK: - Initialization

    /// Creates a new HealthKit service.
    ///
    /// - Parameters:
    ///   - healthStore: The `HKHealthStore` instance to use. Defaults to a
    ///     new store. Injectable for testing edge cases.
    ///   - calendar: Calendar used for date calculations. Defaults to `.current`.
    public init(healthStore: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.healthStore = healthStore
        self.calendar = calendar

        // Set up the authorization status AsyncStream.
        var capturedAuth: AsyncStream<Bool>.Continuation?
        let stream = AsyncStream<Bool>(bufferingPolicy: .bufferingNewest(1)) { c in
            capturedAuth = c
        }
        self.authContinuation = capturedAuth!
        self._authorizationStatusChanged = stream

        // GAP 7: Listen for app foreground events to re-check authorization.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        authContinuation.finish()
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws {
        guard isAvailable else {
            logger.info("HealthKit not available on this device — skipping authorization.")
            return
        }

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        logger.info("HealthKit authorization request completed.")
    }

    // MARK: - Resting Heart Rate

    public func latestRestingHR() async -> Double? {
        guard isAvailable else { return nil }

        let restingHRType = HKQuantityType(.restingHeartRate)
        let cutoff = Date.now.addingTimeInterval(-48 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: restingHRType, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard let sample = results.first else { return nil }
            let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            logger.debug("Resting HR: \(bpm, privacy: .private) BPM")
            return bpm
        } catch {
            logger.warning("Failed to query resting HR: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - HRV

    public func latestHRV() async -> Double? {
        guard isAvailable else { return nil }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrvType, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard let sample = results.first else { return nil }
            let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            logger.debug("HRV (SDNN): \(ms, privacy: .private) ms")
            return ms
        } catch {
            logger.warning("Failed to query HRV: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Sleep

    public func lastNightSleep() async -> (hours: Double, deepSleepMinutes: Double, stages: [SleepStage])? {
        guard isAvailable else { return nil }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKCategorySample.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard !results.isEmpty else { return nil }

            var stages: [SleepStage] = []
            var totalAsleepSeconds: TimeInterval = 0
            var deepSleepSeconds: TimeInterval = 0

            for sample in results {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard let stage = sleepStage(from: sample.value) else { continue }

                stages.append(SleepStage(stage: stage, duration: duration))

                switch stage {
                case .core, .deep, .rem:
                    totalAsleepSeconds += duration
                    if stage == .deep {
                        deepSleepSeconds += duration
                    }
                case .awake:
                    // Awake stages are tracked in the breakdown but do not
                    // count toward total asleep time.
                    break
                }
            }

            guard totalAsleepSeconds > 0 else { return nil }

            let hours = totalAsleepSeconds / 3600.0
            let deepMinutes = deepSleepSeconds / 60.0

            logger.debug("Sleep: \(hours, privacy: .private)h total, \(deepMinutes, privacy: .private)min deep")
            return (hours: hours, deepSleepMinutes: deepMinutes, stages: stages)

        } catch {
            logger.warning("Failed to query sleep: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Steps

    public func stepsToday() async -> Int? {
        guard isAvailable else { return nil }

        let stepType = HKQuantityType(.stepCount)
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: .now,
            options: .strictStartDate
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum
        )

        do {
            let result = try await descriptor.result(for: healthStore)
            guard let sum = result?.sumQuantity() else { return nil }
            let steps = Int(sum.doubleValue(for: .count()))
            logger.debug("Steps today: \(steps, privacy: .private)")
            return steps
        } catch {
            logger.warning("Failed to query steps: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Oxygen Saturation

    public func oxygenSaturation() async -> Double? {
        guard isAvailable else { return nil }

        let spo2Type = HKQuantityType(.oxygenSaturation)
        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: spo2Type, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard let sample = results.first else { return nil }
            let percentage = sample.quantity.doubleValue(for: .percent())
            logger.debug("SpO2: \(percentage, privacy: .private)")
            return percentage
        } catch {
            logger.warning("Failed to query SpO2: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Write: Mindful Session

    public func saveMindfulSession(start: Date, end: Date) async {
        guard isAvailable else { return }

        let mindfulType = HKCategoryType(.mindfulSession)
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        do {
            try await healthStore.save(sample)
            logger.info("Saved mindful session: \(start) – \(end)")
        } catch {
            logger.warning("Failed to save mindful session: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Write: State of Mind

    public func saveStateOfMind(valence: Double, label: String, association: String) async {
        guard isAvailable else { return }

        if #available(iOS 18.0, *) {
            // Map the string label from SessionOutcomeRecorder to HKStateOfMind.Label
            let resolvedLabel: HKStateOfMind.Label = {
                switch label.lowercased() {
                case "focused":   return .content
                case "calm":      return .calm
                case "peaceful":  return .relieved
                case "energized": return .happy
                default:          return .calm
                }
            }()

            let resolvedAssociation: HKStateOfMind.Association = .selfCare

            let stateOfMind = HKStateOfMind(
                date: Date(),
                kind: .momentaryEmotion,
                valence: valence,
                labels: [resolvedLabel],
                associations: [resolvedAssociation]
            )

            do {
                try await healthStore.save(stateOfMind)
                logger.info("Saved State of Mind: valence=\(valence), label=\(label)")
            } catch {
                logger.warning("Failed to save State of Mind: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.info("State of Mind requires iOS 18+ — skipping save.")
        }
    }

    // MARK: - Write: Workout

    public func saveWorkout(activityType: UInt, start: Date, end: Date, energyBurned: Double?) async {
        guard isAvailable else { return }

        let workoutActivityType = HKWorkoutActivityType(rawValue: activityType) ?? .mindAndBody
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutActivityType

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)

        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)

            if let kcal = energyBurned {
                let energyType = HKQuantityType(.activeEnergyBurned)
                let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
                let energySample = HKQuantitySample(
                    type: energyType,
                    quantity: energyQuantity,
                    start: start,
                    end: end
                )
                try await builder.addSamples([energySample])
            }

            let workout = try await builder.finishWorkout()
            if let workout {
                logger.info("Saved workout: \(workout.workoutActivityType.rawValue) from \(start) to \(end)")
            }
        } catch {
            logger.warning("Failed to save workout: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - GAP 4: Active Energy Burned

    public func activeEnergyToday() async -> Double? {
        guard isAvailable else { return nil }

        let energyType = HKQuantityType(.activeEnergyBurned)
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: .now,
            options: .strictStartDate
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: energyType, predicate: predicate),
            options: .cumulativeSum
        )

        do {
            let result = try await descriptor.result(for: healthStore)
            guard let sum = result?.sumQuantity() else { return nil }
            let kcal = sum.doubleValue(for: .kilocalorie())
            logger.debug("Active energy today: \(kcal, privacy: .private) kcal")
            return kcal
        } catch {
            logger.warning("Failed to query active energy: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - GAP 5: Multi-Day Averages

    public func averageRestingHR(days: Int) async -> Double? {
        guard isAvailable, days > 0 else { return nil }

        let restingHRType = HKQuantityType(.restingHeartRate)
        let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: restingHRType, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard !results.isEmpty else { return nil }

            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let total = results.reduce(0.0) { $0 + $1.quantity.doubleValue(for: bpmUnit) }
            let average = total / Double(results.count)
            logger.debug("Average resting HR (\(days)d): \(average, privacy: .private) BPM over \(results.count) samples")
            return average
        } catch {
            logger.warning("Failed to query average resting HR: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func averageHRV(days: Int) async -> Double? {
        guard isAvailable, days > 0 else { return nil }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrvType, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard !results.isEmpty else { return nil }

            let msUnit = HKUnit.secondUnit(with: .milli)
            let total = results.reduce(0.0) { $0 + $1.quantity.doubleValue(for: msUnit) }
            let average = total / Double(results.count)
            logger.debug("Average HRV (\(days)d): \(average, privacy: .private) ms over \(results.count) samples")
            return average
        } catch {
            logger.warning("Failed to query average HRV: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - GAP 6: Sleep Observer for Background Delivery

    /// Starts an HKObserverQuery on sleep analysis and enables daily background delivery.
    ///
    /// - Note: For background delivery to fire when the app is suspended, the
    ///   Info.plist must include `UIBackgroundModes` with `"processing"` or `"fetch"`
    ///   in addition to the existing `"audio"` entry.
    public func startSleepObserver(handler: @escaping @Sendable () -> Void) async throws {
        guard isAvailable else {
            logger.info("HealthKit not available — skipping sleep observer.")
            return
        }

        let sleepType = HKCategoryType(.sleepAnalysis)

        // Enable background delivery so the observer fires even when the app is suspended.
        try await healthStore.enableBackgroundDelivery(for: sleepType, frequency: .daily)
        logger.info("Enabled daily background delivery for sleepAnalysis.")

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                self?.logger.warning("Sleep observer error: \(error.localizedDescription, privacy: .public)")
                completionHandler()
                return
            }

            self?.logger.info("Sleep observer triggered — invoking handler.")
            handler()
            completionHandler()
        }

        // Retain the query and execute it on the health store.
        sleepObserverQuery = query
        healthStore.execute(query)
        logger.info("Sleep observer query started.")
    }

    // MARK: - GAP 7: Authorization Status Refresh

    /// Re-checks authorization status for all read types and emits a change
    /// event on `authorizationStatusChanged` if the status transitioned.
    public func refreshAuthorizationStatus() {
        guard isAvailable else { return }

        Task {
            do {
                let status = try await healthStore.statusForAuthorizationRequest(
                    toShare: writeTypes,
                    read: readTypes
                )
                // .unnecessary means all types are already determined (user has seen the prompt).
                let isAuthorized = (status == .unnecessary)

                if isAuthorized != lastKnownAuthStatus {
                    let wasNewlyAuthorized = isAuthorized && !lastKnownAuthStatus
                    lastKnownAuthStatus = isAuthorized
                    authContinuation.yield(wasNewlyAuthorized)
                    logger.info("Authorization status changed: authorized=\(isAuthorized)")
                }
            } catch {
                logger.warning("Failed to check authorization status: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Called when the app returns to the foreground. Re-checks HealthKit authorization.
    @objc private func handleDidBecomeActive() {
        refreshAuthorizationStatus()
    }

    // MARK: - Heart Rate (GAP 8)

    public func latestHeartRate() async -> Double? {
        guard isAvailable else { return nil }

        let hrType = HKQuantityType(.heartRate)
        let cutoff = Date.now.addingTimeInterval(-1 * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .reverse)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [sortDescriptor],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard let sample = results.first else { return nil }
            let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            logger.debug("Latest HR: \(bpm, privacy: .private) BPM")
            return bpm
        } catch {
            logger.warning("Failed to query heart rate: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func heartRateHistory(hours: Int) async -> [(date: Date, bpm: Double)]? {
        guard isAvailable, hours > 0 else { return nil }

        let hrType = HKQuantityType(.heartRate)
        let cutoff = Date.now.addingTimeInterval(-Double(hours) * 60 * 60)
        let predicate = HKQuery.predicateForSamples(
            withStart: cutoff,
            end: .now,
            options: .strictStartDate
        )
        let sortDescriptor = SortDescriptor(\HKQuantitySample.startDate, order: .forward)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [sortDescriptor]
        )

        do {
            let results = try await descriptor.result(for: healthStore)
            guard !results.isEmpty else { return nil }

            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let history = results.map { sample in
                (date: sample.startDate, bpm: sample.quantity.doubleValue(for: bpmUnit))
            }
            logger.debug("HR history: \(history.count) samples over \(hours)h")
            return history
        } catch {
            logger.warning("Failed to query HR history: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Maps an `HKCategoryValueSleepAnalysis` raw value to a `SleepStage.Stage`.
    ///
    /// Returns `nil` for stage values that are not relevant (e.g., `.inBed`),
    /// so callers can skip those samples.
    private func sleepStage(from categoryValue: Int) -> SleepStage.Stage? {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: categoryValue) else {
            return nil
        }
        switch value {
        case .awake:
            return .awake
        case .asleepREM:
            return .rem
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .inBed, .asleepUnspecified:
            // inBed is not a sleep stage. asleepUnspecified is counted as core
            // for total-time purposes but we map it to core for simplicity.
            return value == .asleepUnspecified ? .core : nil
        @unknown default:
            return nil
        }
    }
}
