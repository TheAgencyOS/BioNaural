// AnimationConstants.swift
// BioNaural
//
// Reduce Motion gate for every animation in the app.
// All animation access flows through `resolve(_:)` which returns
// `.identity` (instant, zero-duration) when the user has enabled
// Reduce Motion in iOS Accessibility settings.
//
// Usage:
//   let anim = AnimationConstants.resolve(.spring(duration: 0.25, bounce: 0))
//   withAnimation(anim) { ... }
//
// Theme.Animation presets already call `resolve` internally, so
// consumers using Theme.Animation.standard etc. get Reduce Motion
// support for free.

import SwiftUI
import UIKit

enum AnimationConstants {

    // MARK: - Reduce Motion Gate

    /// Returns the provided animation when Reduce Motion is off,
    /// or an instant (zero-duration) animation when it is on.
    /// This is the single chokepoint — every animation in the app
    /// must pass through here.
    static func resolve(_ animation: Animation) -> Animation {
        UIAccessibility.isReduceMotionEnabled ? .identity : animation
    }

    /// Boolean convenience for conditional branches that need to know
    /// whether to show animated vs. static content (e.g., the Orb
    /// breathing vs. a static gradient).
    static var reduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Identity Animation

    /// An animation with zero visual duration — used as the Reduce Motion
    /// replacement. SwiftUI's `.default` with duration 0 produces an
    /// instantaneous state change with no interpolation frames.
    ///
    /// Note: `Animation.identity` is a private extension below that
    /// maps to `.linear(duration: 0)`.
}

// MARK: - Animation + Identity

extension Animation {

    /// Zero-duration animation. Produces an instant state change
    /// with no visible interpolation — the Reduce Motion replacement
    /// for every animated transition.
    static let identity: Animation = .linear(duration: 0)
}

// MARK: - View Convenience

extension View {

    /// Wraps `withAnimation` through the Reduce Motion gate.
    /// Prefer this over calling `withAnimation` directly.
    ///
    ///     body.animateThemed(.spring(duration: 0.25)) { value = newValue }
    ///
    func animateThemed<Result>(
        _ animation: Animation,
        _ body: () throws -> Result
    ) rethrows -> Result {
        try withAnimation(AnimationConstants.resolve(animation), body)
    }
}

// MARK: - Reduce Motion Reactive Publisher

#if canImport(Combine)
import Combine

extension AnimationConstants {

    /// A publisher that emits whenever the Reduce Motion setting changes.
    /// Useful for SwiftUI views that need to swap between animated and
    /// static content (Orb breathing vs. static gradient).
    static var reduceMotionPublisher: AnyPublisher<Bool, Never> {
        NotificationCenter.default
            .publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .map { _ in UIAccessibility.isReduceMotionEnabled }
            .prepend(UIAccessibility.isReduceMotionEnabled)
            .eraseToAnyPublisher()
    }
}
#endif
