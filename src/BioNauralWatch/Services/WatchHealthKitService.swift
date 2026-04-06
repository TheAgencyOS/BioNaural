// WatchHealthKitService.swift
// BioNauralWatch
//
// Manages HKWorkoutSession + HKLiveWorkoutBuilder on Apple Watch for
// real-time heart rate streaming. Streams BiometricSample to iPhone
// via WCSession and buffers samples when the phone is unreachable.

import Foundation
import BioNauralShared
import HealthKit
import WatchKit
import WatchConnectivity
import os

/// Real-time heart rate streaming service for watchOS.
///
/// Creates an `HKWorkoutSession` with `.mindAndBody` activity type,
/// starts an `HKLiveWorkoutBuilder`, and uses `HKAnchoredObjectQuery`
/// to receive heart rate samples as they arrive from the sensor.
///
/// Each sample is:
/// 1. Published via a callback for local on-Watch consumption.
/// 2. Sent to iPhone via `WCSession.sendMessage`.
/// 3. Buffered when iPhone is unreachable, flushed via `transferUserInfo` on reconnection.
@MainActor
final class WatchHealthKitService: NSObject, ObservableObject {

    // MARK: - Published State

    /// The most recent heart rate value (BPM).
    @Published private(set) var currentHeartRate: Double?

    /// Whether the workout session is currently running.
    @Published private(set) var isWorkoutActive: Bool = false

    // MARK: - Callbacks

    /// Invoked for each new heart rate sample. Used by WatchSessionManager
    /// to feed the local adaptive algorithm in standalone mode.
    var onHeartRateSample: ((BiometricSample) -> Void)?

    // MARK: - Dependencies

    private let healthStore: HKHealthStore
    private let logger = Logger(subsystem: "com.bionaural.watch", category: "HealthKit")

    // MARK: - Workout State

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var queryAnchor: HKQueryAnchor?

    // MARK: - Sample Buffer (Disconnect Recovery)

    /// Samples buffered while iPhone is unreachable.
    private var sampleBuffer: [[String: Any]] = []

    /// Maximum buffer size before oldest samples are dropped.
    private let maxBufferSize: Int = WatchDesign.Session.maxSampleBuffer

    // MARK: - Heartbeat Ping

    /// Timer for connection health pings.
    private var heartbeatTimer: Timer?

    // MARK: - HealthKit Types

    private let heartRateType = HKQuantityType.quantityType(
        forIdentifier: .heartRate
    )!

    private let mindAndBodyType = HKWorkoutActivityType.mindAndBody

    // MARK: - Initialization

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
        super.init()
    }

    // MARK: - Authorization

    /// Requests HealthKit authorization for heart rate reading and
    /// mindful session writing.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.info("HealthKit not available on this device.")
            return
        }

        let readTypes: Set<HKSampleType> = [heartRateType]
        let writeTypes: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        try await healthStore.requestAuthorization(
            toShare: writeTypes,
            read: readTypes
        )

        logger.info("HealthKit authorization requested.")
    }

    // MARK: - Start Workout

    /// Starts an HKWorkoutSession for mind-and-body with indoor location.
    ///
    /// - Throws: If the workout session cannot be created or started.
    func startWorkout() async throws {
        guard !isWorkoutActive else {
            logger.warning("Workout already active — ignoring start request.")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )

        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        session.delegate = self
        builder.delegate = self

        self.workoutSession = session
        self.workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        startHeartRateQuery()
        startHeartbeatPing()

        isWorkoutActive = true

        // Haptic: session start
        WKInterfaceDevice.current().play(.start)

        logger.info("Workout session started.")
    }

    // MARK: - Stop Workout

    /// Ends the workout session, saves data to HealthKit, and flushes
    /// any buffered samples.
    func stopWorkout() async {
        guard isWorkoutActive else { return }

        stopHeartRateQuery()
        stopHeartbeatPing()

        let endDate = Date()

        workoutSession?.end()

        if let builder = workoutBuilder {
            do {
                try await builder.endCollection(at: endDate)
                try await builder.finishWorkout()
                logger.info("Workout saved to HealthKit.")
            } catch {
                logger.error("Failed to save workout: \(error.localizedDescription, privacy: .public)")
            }
        }

        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        currentHeartRate = nil

        // Flush buffered samples to iPhone
        flushBufferedSamples()

        // Haptic: session end
        WKInterfaceDevice.current().play(.stop)

        logger.info("Workout session ended.")
    }

    // MARK: - Heart Rate Query

    /// Starts an anchored object query for heart rate samples.
    /// Fires for each new sample delivered by the sensor.
    private func startHeartRateQuery() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: queryAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, anchor, _ in
            Task { @MainActor in
                self?.queryAnchor = anchor
                self?.processHeartRateSamples(samples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, anchor, _ in
            Task { @MainActor in
                self?.queryAnchor = anchor
                self?.processHeartRateSamples(samples)
            }
        }

        healthStore.execute(query)
        heartRateQuery = query

        logger.debug("Heart rate anchored query started.")
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    /// Processes incoming HK heart rate samples into BiometricSample
    /// values and dispatches them.
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        for sample in quantitySamples {
            let bpm = sample.quantity.doubleValue(for: bpmUnit)

            // Reject implausible readings from sensor initialization or motion.
            guard bpm >= WatchDesign.Session.hrMinValid, bpm <= WatchDesign.Session.hrMaxValid else { continue }

            let timestamp = sample.startDate.timeIntervalSince1970

            // Map HKHeartRateMotionContext to confidence (0-2).
            let confidence = heartRateConfidence(from: sample)

            let biometricSample = BiometricSample(
                bpm: bpm,
                timestamp: timestamp,
                confidence: confidence
            )

            currentHeartRate = bpm
            onHeartRateSample?(biometricSample)
            sendSampleToiPhone(biometricSample)
        }
    }

    /// Extracts confidence from the sample's motion context metadata.
    private func heartRateConfidence(from sample: HKQuantitySample) -> Int {
        guard let contextValue = sample.metadata?[
            HKMetadataKeyHeartRateMotionContext
        ] as? NSNumber else {
            return 1 // Medium confidence when context unavailable
        }

        // HKHeartRateMotionContext: 0 = notSet, 1 = sedentary, 2 = active
        switch contextValue.intValue {
        case 1:  return 2 // Sedentary = high confidence
        case 2:  return 0 // Active = low confidence (motion artifacts)
        default: return 1 // Not set = medium
        }
    }

    // MARK: - WCSession Communication

    /// Sends a single heart rate sample to iPhone via WCSession.
    /// If iPhone is unreachable, buffers the sample for later delivery.
    private func sendSampleToiPhone(_ sample: BiometricSample) {
        let session = WCSession.default

        guard session.activationState == .activated else {
            bufferSample(sample)
            return
        }

        let message = WatchMessage.heartRate(sample)
        guard let dict = message.toDictionary() else {
            logger.warning("Failed to serialize BiometricSample to dictionary.")
            return
        }

        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.logger.debug("sendMessage failed — buffering: \(error.localizedDescription, privacy: .public)")
                    self?.bufferSample(sample)
                }
            }
        } else {
            bufferSample(sample)
        }
    }

    /// Adds a sample to the disconnect recovery buffer.
    private func bufferSample(_ sample: BiometricSample) {
        let dict = sample.toDictionary()
        sampleBuffer.append(dict)

        // Drop oldest if over capacity
        if sampleBuffer.count > maxBufferSize {
            let overflow = sampleBuffer.count - maxBufferSize
            sampleBuffer.removeFirst(overflow)
            logger.debug("Buffer overflow — dropped \(overflow) oldest samples.")
        }
    }

    /// Flushes all buffered samples to iPhone via transferUserInfo.
    /// Called when the session ends or when connectivity is restored.
    func flushBufferedSamples() {
        guard !sampleBuffer.isEmpty else { return }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = ["samples": sampleBuffer]
        session.transferUserInfo(payload)

        let count = sampleBuffer.count
        sampleBuffer.removeAll()
        logger.info("Flushed \(count) buffered samples via transferUserInfo.")
    }

    // MARK: - Heartbeat Ping

    /// Starts a periodic ping to verify connection health.
    private func startHeartbeatPing() {
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: WatchDesign.Session.heartbeatPingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sendHeartbeatPing()
            }
        }
    }

    private func stopHeartbeatPing() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    /// Sends a lightweight ping to iPhone. If reachability was restored,
    /// flushes any buffered samples.
    private func sendHeartbeatPing() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            return
        }

        // If we have buffered samples and phone is now reachable, flush
        if !sampleBuffer.isEmpty {
            flushBufferedSamples()
        }

        let ping: [String: Any] = ["ping": Date().timeIntervalSince1970]
        session.sendMessage(ping, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Haptic Feedback

    /// Plays a haptic click for adaptation events (state transitions).
    func playAdaptationHaptic() {
        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchHealthKitService: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                isWorkoutActive = true
                logger.info("Workout state: running")
            case .ended:
                isWorkoutActive = false
                logger.info("Workout state: ended")
            case .paused:
                logger.info("Workout state: paused")
            default:
                logger.info("Workout state: \(String(describing: toState))")
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            logger.error("Workout session failed: \(error.localizedDescription, privacy: .public)")
            await stopWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHealthKitService: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {
        // No-op — workout events (lap markers, etc.) not used in BioNaural.
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Heart rate data is collected via the anchored query, not here.
        // This delegate method fires for cumulative statistics updates.
    }
}
