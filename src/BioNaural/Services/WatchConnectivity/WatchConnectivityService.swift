// WatchConnectivityService.swift
// BioNaural
//
// Concrete WatchConnectivity implementation for the iPhone side.
// Activates WCSession, streams BiometricSample via AsyncStream,
// and sends session commands to the Watch.
// Swift 6 safe: uses Data serialization for sending dictionaries
// across actor boundaries.

import Foundation
import os
import WatchConnectivity
import BioNauralShared

// MARK: - WatchConnectivityService

/// Production Watch connectivity service that bridges WCSession delegate
/// callbacks into structured Swift concurrency.
///
/// - Activates `WCSession` on initialization.
/// - Parses incoming messages into `BiometricSample` and yields them
///   through an `AsyncStream`.
/// - Handles buffered sample batches from `didReceiveUserInfo`
///   (Watch disconnect recovery).
/// - Sends commands via `sendMessage` (real-time) or
///   `updateApplicationContext` (fallback).
///
/// Swift 6 Sendable safety: All WCSession message dictionaries are
/// serialized to/from `Data` before crossing isolation boundaries.
/// The `@unchecked Sendable` conformance is required because `WCSession`
/// itself is not `Sendable`, but all mutable state is accessed exclusively
/// from the delegate queue or protected by the continuation.
public final class WatchConnectivityService: NSObject, @unchecked Sendable {

    // MARK: - Dependencies

    private let session: WCSession
    private let logger: Logger

    // MARK: - AsyncStream Infrastructure

    /// The continuation used to yield `BiometricSample` values into
    /// the public `heartRateSamples` stream.
    private let continuation: AsyncStream<BiometricSample>.Continuation

    /// An asynchronous stream of heart rate samples from the Watch.
    public let heartRateSamples: AsyncStream<BiometricSample>

    // MARK: - State

    /// Whether the Watch is currently reachable.
    /// Updated from the WCSession delegate queue, read from any thread.
    /// Protected by `OSAllocatedUnfairLock` to prevent data races.
    private let _isWatchReachable = OSAllocatedUnfairLock(initialState: false)
    public var isWatchReachable: Bool {
        get { _isWatchReachable.withLock { $0 } }
        set { _isWatchReachable.withLock { $0 = newValue } }
    }

    /// Whether the iPhone is paired with an Apple Watch.
    public var isPaired: Bool {
        session.isPaired
    }

    /// Whether the BioNaural Watch app is installed on the paired Watch.
    public var isWatchAppInstalled: Bool {
        session.isWatchAppInstalled
    }

    // MARK: - Message Keys

    private enum MessageKey {
        static let type = "type"
        static let heartRate = "heartRate"
        static let samples = "samples"
        static let payload = "payload"
    }

    // MARK: - Initialization

    /// Creates and activates the Watch connectivity service.
    ///
    /// - Parameter session: The `WCSession` to use. Defaults to `.default`.
    ///   Injectable for testing.
    public init(session: WCSession = .default) {
        self.session = session
        self.logger = Logger(subsystem: "com.bionaural.app", category: "WatchConnectivity")

        // Build the AsyncStream and capture the continuation.
        // The closure executes synchronously in AsyncStream.init, so
        // capturedContinuation is guaranteed to be set before use.
        var capturedContinuation: AsyncStream<BiometricSample>.Continuation?
        self.heartRateSamples = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation!

        super.init()

        self.isWatchReachable = session.isReachable

        guard WCSession.isSupported() else {
            logger.info("WCSession not supported on this device.")
            return
        }

        session.delegate = self
        session.activate()
        logger.info("WCSession activation requested.")
    }

    deinit {
        continuation.finish()
    }

    // MARK: - Send Commands (Swift 6 Safe)

    /// Sends a session command to the Watch.
    ///
    /// Uses `sendMessage` when the Watch is reachable; falls back to
    /// `updateApplicationContext` for guaranteed eventual delivery.
    ///
    /// All dictionaries are serialized to `Data` before crossing
    /// isolation boundaries to satisfy Swift 6 Sendable requirements.
    ///
    /// - Parameter command: The `WatchMessage` to send.
    public func sendMessage(_ message: WatchMessage) {
        guard let payload = message.toDictionary() else {
            logger.warning("Failed to serialize WatchMessage to dictionary.")
            return
        }

        guard session.activationState == .activated else {
            logger.warning("Cannot send message — WCSession not activated.")
            return
        }

        if session.isReachable {
            // Serialize to Data for Swift 6 Sendable safety
            guard let data = serializeDictionary(payload) else {
                logger.warning("Failed to serialize payload to Data for sendMessage.")
                return
            }

            // Deserialize back on the WCSession queue
            guard let restoredPayload = deserializeDictionary(data) else {
                logger.warning("Failed to deserialize payload from Data for sendMessage.")
                return
            }

            session.sendMessage(restoredPayload, replyHandler: nil) { [weak self] error in
                self?.logger.warning("sendMessage failed: \(error.localizedDescription)")
                // Fall back to application context for eventual delivery.
                if let data = self?.serializeDictionary(payload),
                   let fallbackPayload = self?.deserializeDictionary(data) {
                    self?.updateApplicationContext(with: fallbackPayload)
                }
            }
            logger.debug("Sent message via sendMessage.")
        } else {
            updateApplicationContext(with: payload)
            logger.debug("Watch not reachable — sent via applicationContext.")
        }
    }

    /// Sends raw biometric data to the Watch via `transferUserInfo` for
    /// batch/offline delivery.
    ///
    /// - Parameter samples: Array of `BiometricSample` to transfer.
    public func transferBiometricBatch(_ samples: [BiometricSample]) {
        guard !samples.isEmpty else { return }

        // Encode samples to Data for Sendable safety
        guard let data = try? JSONEncoder().encode(samples) else {
            logger.warning("Failed to encode biometric batch.")
            return
        }

        let userInfo: [String: Any] = [
            MessageKey.type: MessageKey.samples,
            MessageKey.payload: data
        ]

        session.transferUserInfo(userInfo)
        logger.info("Transferred batch of \(samples.count) samples via transferUserInfo.")
    }

    // MARK: - Private Helpers

    /// Wraps `updateApplicationContext` with error handling.
    private func updateApplicationContext(with payload: [String: Any]) {
        do {
            try session.updateApplicationContext(payload)
        } catch {
            logger.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    /// Parses a single `BiometricSample` from a message dictionary and yields
    /// it to the stream.
    private func handleSingleSample(from message: [String: Any]) {
        // Try WatchMessage envelope first
        if let watchMessage = WatchMessage.fromDictionary(message) {
            switch watchMessage {
            case .heartRate(let sample):
                continuation.yield(sample)
                return
            default:
                break
            }
        }

        // Fall back to raw BiometricSample dictionary
        guard let sample = BiometricSample(from: message) else {
            logger.debug("Received message that is not a BiometricSample — ignoring.")
            return
        }
        continuation.yield(sample)
    }

    /// Parses a batch of `BiometricSample` from a userInfo dictionary
    /// (used for Watch disconnect recovery via `transferUserInfo`).
    private func handleBufferedSamples(from userInfo: [String: Any]) {
        // Try Data-encoded batch first (Swift 6 safe path)
        if let data = userInfo[MessageKey.payload] as? Data,
           let samples = try? JSONDecoder().decode([BiometricSample].self, from: data) {
            for sample in samples {
                continuation.yield(sample)
            }
            if !samples.isEmpty {
                logger.info("Recovered \(samples.count) buffered samples from Data payload.")
            }
            return
        }

        // Fall back to legacy dictionary array
        if let rawSamples = userInfo[MessageKey.samples] as? [[String: Any]] {
            var parsedCount = 0
            for rawSample in rawSamples {
                if let sample = BiometricSample(from: rawSample) {
                    continuation.yield(sample)
                    parsedCount += 1
                }
            }
            if parsedCount > 0 {
                logger.info("Recovered \(parsedCount) buffered samples from dictionary array.")
            }
            return
        }

        // Not a batch payload — try as a single sample
        handleSingleSample(from: userInfo)
    }

    // MARK: - Serialization Helpers (Swift 6 Sendable Bridge)

    /// Serializes a `[String: Any]` dictionary to `Data` using `NSKeyedArchiver`.
    /// This allows dictionaries to cross actor/isolation boundaries safely.
    private func serializeDictionary(_ dict: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: dict, options: [])
    }

    /// Deserializes `Data` back to a `[String: Any]` dictionary.
    private func deserializeDictionary(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    // MARK: Activation

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        }

        isWatchReachable = session.isReachable

        switch activationState {
        case .activated:
            logger.info("WCSession activated. Paired: \(session.isPaired), reachable: \(session.isReachable)")
        case .inactive:
            logger.info("WCSession inactive.")
        case .notActivated:
            logger.info("WCSession not activated.")
        @unknown default:
            logger.info("WCSession unknown activation state.")
        }
    }

    // MARK: Reachability

    public func sessionReachabilityDidChange(_ session: WCSession) {
        isWatchReachable = session.isReachable
        logger.info("Watch reachability changed: \(session.isReachable)")
    }

    // MARK: Real-Time Messages

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleSingleSample(from: message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleSingleSample(from: message)
        replyHandler([:])
    }

    // MARK: Buffered Data (Disconnect Recovery)

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleBufferedSamples(from: userInfo)
    }

    // MARK: Session Lifecycle (iPhone-Only Delegate Methods)

    public func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive.")
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        // On iPhone, reactivate the session after deactivation
        // (required for multi-Watch switching support).
        logger.info("WCSession deactivated — reactivating.")
        session.activate()
    }
}

// MARK: - Logger (Lightweight Wrapper)

/// Lightweight logging wrapper that delegates to `os.Logger` when available.
/// Avoids importing `os` at the file level to keep the service testable.
private struct Logger: Sendable {
    private let subsystem: String
    private let category: String

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    func info(_ message: String) {
        #if DEBUG
        print("[\(category)] \(message)")
        #endif
    }

    func debug(_ message: String) {
        #if DEBUG
        print("[\(category)] DEBUG: \(message)")
        #endif
    }

    func warning(_ message: String) {
        #if DEBUG
        print("[\(category)] WARNING: \(message)")
        #endif
    }

    func error(_ message: String) {
        #if DEBUG
        print("[\(category)] ERROR: \(message)")
        #endif
    }
}
