// HeadMotionServiceProtocol.swift
// BioNaural
//
// Protocol defining the public surface of the head motion tracking service.
// Uses AirPods Pro/Max gyroscope data to compute a "stillness score" that
// serves as a secondary biometric signal — stillness correlates with deeper
// focus and relaxation states.

import Foundation

/// Contract for head motion tracking via AirPods.
///
/// The stillness score is a continuous value from 0.0 (very still, deep focus)
/// to 1.0 (significant movement, distracted). Implementations must degrade
/// gracefully when AirPods are not connected or do not support motion tracking.
///
/// Conforming types must be `@MainActor` for SwiftUI observation compatibility.
@MainActor
public protocol HeadMotionServiceProtocol: AnyObject {

    /// Whether the device supports headphone motion tracking
    /// (requires AirPods Pro, AirPods Max, or AirPods Pro 2nd gen+).
    var isAvailable: Bool { get }

    /// Whether motion tracking is currently active and receiving data.
    var isTracking: Bool { get }

    /// Head stillness score derived from a rolling window of rotation rate data.
    /// - `0.0` = very still (deep focus/relaxation)
    /// - `1.0` = significant movement (distracted/restless)
    /// - `nil` = no data available (AirPods disconnected or unsupported)
    var stillnessScore: Double? { get }

    /// Starts head motion tracking. Call at session start.
    ///
    /// If AirPods are not connected or do not support motion, this method
    /// returns silently without error. Check `isTracking` after calling.
    func startTracking()

    /// Stops head motion tracking. Call at session end.
    func stopTracking()
}
