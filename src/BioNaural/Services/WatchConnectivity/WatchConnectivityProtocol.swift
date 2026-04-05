// WatchConnectivityProtocol.swift
// BioNaural
//
// Protocol defining the Watch connectivity surface for the iPhone side.
// Provides an AsyncStream of biometric samples and session commands.

import Foundation
import BioNauralShared

/// A command sent from the iPhone to the Watch to control the
/// workout session or request state changes.
public enum SessionCommand: String, Codable, Sendable {

    /// Start a new workout/HR-streaming session on the Watch.
    case startSession

    /// Stop the active workout session on the Watch.
    case stopSession

    /// Pause the active workout session.
    case pauseSession

    /// Resume a paused workout session.
    case resumeSession

    /// Request the Watch to flush any buffered samples via `transferUserInfo`.
    case flushBuffer

    // MARK: - WCSession Serialization

    /// Dictionary key used for command encoding in WCSession messages.
    private static let messageKey = "command"

    /// Converts this command to a dictionary for `WCSession.sendMessage`.
    public func toDictionary() -> [String: Any] {
        [Self.messageKey: rawValue]
    }

    /// Creates a command from a WCSession message dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing a `"command"` string value.
    /// - Returns: The matching `SessionCommand`, or `nil` if the key is missing
    ///   or the value is not a recognized command.
    public init?(from dictionary: [String: Any]) {
        guard let rawValue = dictionary[Self.messageKey] as? String else { return nil }
        self.init(rawValue: rawValue)
    }
}

/// Contract for Watch connectivity on the iPhone side.
///
/// Provides a stream of biometric samples from the Watch and the ability
/// to send session commands back. Implementations wrap `WCSession`.
public protocol WatchConnectivityProtocol: AnyObject, Sendable {

    /// An asynchronous stream of heart rate samples arriving from the Watch.
    ///
    /// The stream yields values as they arrive via `WCSession.didReceiveMessage`
    /// or `didReceiveUserInfo` (for buffered batch recovery).
    var heartRateSamples: AsyncStream<BiometricSample> { get }

    /// Whether the paired Watch is currently reachable (active WCSession).
    var isWatchReachable: Bool { get }

    /// Whether the iPhone is paired with an Apple Watch.
    var isPaired: Bool { get }

    /// Whether the BioNaural Watch app is installed on the paired Watch.
    var isWatchAppInstalled: Bool { get }

    /// Sends a session command to the Watch.
    ///
    /// Uses `sendMessage` when the Watch is reachable; falls back to
    /// `updateApplicationContext` for guaranteed eventual delivery.
    ///
    /// - Parameter command: The command to send.
    func sendCommand(_ command: SessionCommand)
}
