// HapticService.swift
// BioNaural
//
// Thin wrapper around UIKit haptic feedback generators.
// Respects the system haptic setting — UIFeedbackGenerator automatically
// suppresses output when the user has disabled haptics.

import UIKit

/// Protocol for haptic feedback, enabling mock injection in tests.
@MainActor
public protocol HapticServiceProtocol: AnyObject {

    /// Soft haptic played when a session begins.
    func sessionStart()

    /// Success notification played when a session ends.
    func sessionEnd()

    /// Light haptic played when the adaptive engine makes a parameter change.
    func adaptationEvent()

    /// Light impact haptic for standard button presses.
    func buttonPress()
}

/// Production haptic service using `UIImpactFeedbackGenerator` and
/// `UINotificationFeedbackGenerator`.
///
/// All generators are lazily prepared on first use. The system automatically
/// respects the user's haptic preferences — no manual check is needed.
@MainActor
public final class HapticService: HapticServiceProtocol {

    // MARK: - Generators

    /// Soft impact for session start — gentle, non-intrusive.
    private lazy var softGenerator = UIImpactFeedbackGenerator(style: .soft)

    /// Light impact for button presses and adaptation events.
    private lazy var lightGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Notification generator for success feedback on session completion.
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    public init() {}

    // MARK: - HapticServiceProtocol

    public func sessionStart() {
        softGenerator.prepare()
        softGenerator.impactOccurred()
    }

    public func sessionEnd() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    public func adaptationEvent() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.5)
    }

    public func buttonPress() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }
}

// MARK: - Sendable Conformance

// HapticService is @MainActor-isolated, so all mutable state is
// accessed exclusively on the main thread. The Sendable conformance
// on the protocol is satisfied by this isolation.
extension HapticService: @unchecked Sendable {}
