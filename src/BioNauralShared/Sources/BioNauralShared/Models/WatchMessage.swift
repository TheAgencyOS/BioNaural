import Foundation

// MARK: - Session Command

/// Commands sent from iPhone to Watch (or vice versa) to control a session.
public enum SessionCommand: Codable, Sendable, Equatable {
    /// Start a new session in the given mode.
    case start(FocusMode)
    /// Stop the current session.
    case stop
    /// Pause the current session.
    case pause
    /// Resume a paused session.
    case resume

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case mode
    }

    private enum CommandType: String, Codable {
        case start, stop, pause, resume
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CommandType.self, forKey: .type)
        switch type {
        case .start:
            let mode = try container.decode(FocusMode.self, forKey: .mode)
            self = .start(mode)
        case .stop:   self = .stop
        case .pause:  self = .pause
        case .resume: self = .resume
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .start(let mode):
            try container.encode(CommandType.start, forKey: .type)
            try container.encode(mode, forKey: .mode)
        case .stop:
            try container.encode(CommandType.stop, forKey: .type)
        case .pause:
            try container.encode(CommandType.pause, forKey: .type)
        case .resume:
            try container.encode(CommandType.resume, forKey: .type)
        }
    }
}

// MARK: - Session State Update

/// A snapshot of the current session state, sent between devices to keep
/// iPhone and Watch synchronized.
public struct SessionStateUpdate: Codable, Sendable, Equatable {
    /// Whether a session is currently active.
    public let isActive: Bool
    /// Whether the session is paused.
    public let isPaused: Bool
    /// The mode of the active session, if any.
    public let mode: FocusMode?
    /// Elapsed duration of the active session in seconds.
    public let elapsed: TimeInterval

    public init(isActive: Bool, isPaused: Bool, mode: FocusMode?, elapsed: TimeInterval) {
        self.isActive = isActive
        self.isPaused = isPaused
        self.mode = mode
        self.elapsed = elapsed
    }
}

// MARK: - Watch Message

/// Top-level message envelope for all Watch-iPhone communication.
///
/// All messages are serialized to `[String: Any]` dictionaries for
/// `WCSession.sendMessage`. Each case carries a typed payload:
///
/// - `heartRate`: A `BiometricSample` from the Watch HR sensor.
/// - `sessionCommand`: A `SessionCommand` to start/stop/pause/resume.
/// - `sessionState`: A `SessionStateUpdate` snapshot for synchronization.
public enum WatchMessage: Codable, Sendable, Equatable {
    /// A heart-rate sample from the Watch sensor.
    case heartRate(BiometricSample)
    /// A session control command.
    case sessionCommand(SessionCommand)
    /// A session state synchronization update.
    case sessionState(SessionStateUpdate)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case messageType
        case payload
    }

    private enum MessageType: String, Codable {
        case heartRate
        case sessionCommand
        case sessionState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .messageType)
        switch type {
        case .heartRate:
            let sample = try container.decode(BiometricSample.self, forKey: .payload)
            self = .heartRate(sample)
        case .sessionCommand:
            let command = try container.decode(SessionCommand.self, forKey: .payload)
            self = .sessionCommand(command)
        case .sessionState:
            let state = try container.decode(SessionStateUpdate.self, forKey: .payload)
            self = .sessionState(state)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .heartRate(let sample):
            try container.encode(MessageType.heartRate, forKey: .messageType)
            try container.encode(sample, forKey: .payload)
        case .sessionCommand(let command):
            try container.encode(MessageType.sessionCommand, forKey: .messageType)
            try container.encode(command, forKey: .payload)
        case .sessionState(let state):
            try container.encode(MessageType.sessionState, forKey: .messageType)
            try container.encode(state, forKey: .payload)
        }
    }

    // MARK: - WCSession Serialization

    /// Dictionary keys used for the top-level WCSession envelope.
    private enum DictionaryKey {
        static let messageType = "messageType"
        static let payload = "payload"
    }

    /// Converts this message to a dictionary suitable for `WCSession.sendMessage`.
    ///
    /// The payload is JSON-encoded into a `Data` value stored under the
    /// `"payload"` key, ensuring type safety during deserialization.
    ///
    /// - Returns: A `[String: Any]` dictionary, or `nil` if encoding fails.
    public func toDictionary() -> [String: Any]? {
        let encoder = JSONEncoder()
        switch self {
        case .heartRate(let sample):
            guard let data = try? encoder.encode(sample) else { return nil }
            return [
                DictionaryKey.messageType: MessageType.heartRate.rawValue,
                DictionaryKey.payload: data
            ]
        case .sessionCommand(let command):
            guard let data = try? encoder.encode(command) else { return nil }
            return [
                DictionaryKey.messageType: MessageType.sessionCommand.rawValue,
                DictionaryKey.payload: data
            ]
        case .sessionState(let state):
            guard let data = try? encoder.encode(state) else { return nil }
            return [
                DictionaryKey.messageType: MessageType.sessionState.rawValue,
                DictionaryKey.payload: data
            ]
        }
    }

    /// Creates a `WatchMessage` from a WCSession message dictionary.
    ///
    /// - Parameter dictionary: A dictionary with `"messageType"` (String) and
    ///   `"payload"` (Data) keys, as produced by `toDictionary()`.
    /// - Returns: A decoded `WatchMessage`, or `nil` if the dictionary is
    ///   malformed or the payload fails to decode.
    public static func fromDictionary(_ dictionary: [String: Any]) -> WatchMessage? {
        guard let typeString = dictionary[DictionaryKey.messageType] as? String,
              let type = MessageType(rawValue: typeString),
              let payloadData = dictionary[DictionaryKey.payload] as? Data else {
            return nil
        }

        let decoder = JSONDecoder()
        switch type {
        case .heartRate:
            guard let sample = try? decoder.decode(BiometricSample.self, from: payloadData) else { return nil }
            return .heartRate(sample)
        case .sessionCommand:
            guard let command = try? decoder.decode(SessionCommand.self, from: payloadData) else { return nil }
            return .sessionCommand(command)
        case .sessionState:
            guard let state = try? decoder.decode(SessionStateUpdate.self, from: payloadData) else { return nil }
            return .sessionState(state)
        }
    }
}
