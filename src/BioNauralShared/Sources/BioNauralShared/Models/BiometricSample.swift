import Foundation

/// A single heart-rate reading transmitted between Watch and iPhone.
///
/// `BiometricSample` is the atomic unit of biometric data flowing through the
/// WatchConnectivity pipeline. It carries the BPM value, a UNIX timestamp, and
/// a confidence indicator derived from sensor quality.
///
/// The struct provides `toDictionary()` and `init(from:)` for WCSession message
/// serialization, since `WCSession.sendMessage` requires `[String: Any]`.
public struct BiometricSample: Codable, Sendable, Equatable {

    // MARK: - Properties

    /// Heart rate in beats per minute.
    public let bpm: Double

    /// UNIX timestamp (`Date().timeIntervalSince1970`) of the sample.
    public let timestamp: TimeInterval

    /// Sensor confidence level.
    ///
    /// Mirrors `HKHeartRateMotionContext` quality tiers:
    /// - `0` — low confidence (significant motion artifact).
    /// - `1` — medium confidence (some motion).
    /// - `2` — high confidence (stationary, clean signal).
    public let confidence: Int

    // MARK: - Initialization

    /// Creates a new biometric sample.
    ///
    /// - Parameters:
    ///   - bpm: Heart rate in beats per minute.
    ///   - timestamp: UNIX epoch timestamp of the reading.
    ///   - confidence: Sensor confidence (0 = low, 1 = medium, 2 = high).
    ///     Clamped to the valid range 0...2.
    public init(bpm: Double, timestamp: TimeInterval, confidence: Int) {
        self.bpm = bpm
        self.timestamp = timestamp
        self.confidence = min(max(confidence, 0), 2)
    }

    // MARK: - WCSession Serialization

    /// Dictionary keys used for WCSession message encoding.
    private enum DictionaryKey {
        static let bpm = "bpm"
        static let timestamp = "timestamp"
        static let confidence = "confidence"
    }

    /// Converts this sample to a dictionary suitable for `WCSession.sendMessage`.
    ///
    /// - Returns: A `[String: Any]` dictionary containing `bpm`, `timestamp`,
    ///   and `confidence`.
    public func toDictionary() -> [String: Any] {
        [
            DictionaryKey.bpm: bpm,
            DictionaryKey.timestamp: timestamp,
            DictionaryKey.confidence: confidence
        ]
    }

    /// Creates a biometric sample from a WCSession message dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing `bpm` (Double),
    ///   `timestamp` (TimeInterval), and `confidence` (Int).
    /// - Returns: A `BiometricSample` if all required keys are present and
    ///   correctly typed; `nil` otherwise.
    public init?(from dictionary: [String: Any]) {
        guard let bpm = dictionary[DictionaryKey.bpm] as? Double,
              let timestamp = dictionary[DictionaryKey.timestamp] as? TimeInterval,
              let confidence = dictionary[DictionaryKey.confidence] as? Int else {
            return nil
        }
        self.init(bpm: bpm, timestamp: timestamp, confidence: confidence)
    }
}
