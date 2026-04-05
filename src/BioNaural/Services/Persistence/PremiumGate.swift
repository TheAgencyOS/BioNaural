// PremiumGate.swift
// BioNaural
//
// Utility for checking premium access and gating features behind the paywall.
// Provides static convenience methods, a SwiftUI ViewModifier for locked
// states, and session-limit enforcement for the free tier.

import SwiftUI
import StoreKit
import BioNauralShared

// MARK: - Free Tier Limits

enum FreeTierLimits {
    /// Maximum sessions per day for free-tier users.
    static let maxSessionsPerDay: Int = Constants.freeSessionsPerDay

    /// Modes available on the free tier.
    static let availableModes: Set<FocusMode> = [.focus, .relaxation]

    /// UserDefaults key for the daily session counter.
    static let dailyCountKey = "com.bionaural.dailySessionCount"

    /// UserDefaults key for the date of the last session count reset.
    static let dailyCountDateKey = "com.bionaural.dailySessionCountDate"
}

// MARK: - PremiumGate

enum PremiumGate {

    // MARK: - Premium Status

    /// Returns `true` if the user currently has premium access.
    /// Reads from `SubscriptionManager.shared` (cached for offline).
    @MainActor
    static func isPremium() -> Bool {
        SubscriptionManager.shared.isPremium
    }

    // MARK: - Session Gating

    /// Determines whether the user can start a session with the given mode.
    ///
    /// Free-tier constraints:
    /// - Only Focus and Relaxation modes are available.
    /// - Maximum sessions per calendar day (from Constants).
    /// Premium users always return `true`.
    ///
    /// - Parameters:
    ///   - mode: The `FocusMode` the user wants to start.
    ///   - sessionCount: The number of sessions completed today.
    /// - Returns: `true` if the session is allowed.
    @MainActor
    static func canStartSession(mode: FocusMode, sessionCount: Int) -> Bool {
        guard !isPremium() else { return true }

        guard FreeTierLimits.availableModes.contains(mode) else {
            return false
        }

        return sessionCount < FreeTierLimits.maxSessionsPerDay
    }

    /// Returns `true` if the free-tier daily session limit has been reached.
    /// Premium users always return `false`.
    ///
    /// - Parameter sessionCount: The number of sessions completed today.
    @MainActor
    static func sessionLimitReached(sessionCount: Int) -> Bool {
        guard !isPremium() else { return false }
        return sessionCount >= FreeTierLimits.maxSessionsPerDay
    }

    // MARK: - Daily Session Counter

    /// Returns the number of sessions completed today, auto-resetting on day change.
    static func todaySessionCount() -> Int {
        let defaults = UserDefaults.standard
        let lastDate = defaults.object(forKey: FreeTierLimits.dailyCountDateKey) as? Date

        if let lastDate, !Calendar.current.isDateInToday(lastDate) {
            defaults.set(0, forKey: FreeTierLimits.dailyCountKey)
            defaults.set(Date(), forKey: FreeTierLimits.dailyCountDateKey)
            return 0
        }

        return defaults.integer(forKey: FreeTierLimits.dailyCountKey)
    }

    /// Increments the daily session counter. Called after a session completes.
    static func incrementSessionCount() {
        let currentCount = todaySessionCount()
        let defaults = UserDefaults.standard
        defaults.set(currentCount + 1, forKey: FreeTierLimits.dailyCountKey)
        defaults.set(Date(), forKey: FreeTierLimits.dailyCountDateKey)
    }

    // MARK: - Feature Check

    /// Returns `true` if a specific premium feature is available.
    /// - Parameter feature: The feature to check.
    @MainActor
    static func isFeatureAvailable(_ feature: PremiumFeature) -> Bool {
        if isPremium() { return true }

        switch feature {
        case .focusMode, .relaxationMode, .timeBasedArcs:
            return true
        case .sleepMode, .energizeMode, .biometricAdaptation,
             .unlimitedSessions, .fullSoundLibrary, .trends, .offlineAccess:
            return false
        }
    }
}

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case focusMode
    case relaxationMode
    case sleepMode
    case energizeMode
    case biometricAdaptation
    case unlimitedSessions
    case fullSoundLibrary
    case trends
    case offlineAccess
    case timeBasedArcs

    /// Human-readable label for display in locked-state UI.
    var displayName: String {
        switch self {
        case .focusMode:             return "Focus Mode"
        case .relaxationMode:        return "Relaxation Mode"
        case .sleepMode:             return "Sleep Mode"
        case .energizeMode:          return "Energize Mode"
        case .biometricAdaptation:   return "Biometric Adaptation"
        case .unlimitedSessions:     return "Unlimited Sessions"
        case .fullSoundLibrary:      return "Full Sound Library"
        case .trends:                return "Trends & Insights"
        case .offlineAccess:         return "Offline Access"
        case .timeBasedArcs:         return "Time-Based Arcs"
        }
    }
}

// MARK: - PremiumGated ViewModifier

/// A ViewModifier that overlays a locked state on non-premium content.
///
/// When the user is not premium, the wrapped view is dimmed and overlaid
/// with a lock icon and "Upgrade" tap target that presents the paywall.
///
/// Usage:
/// ```swift
/// SleepModeCard()
///     .premiumGated(feature: .sleepMode)
/// ```
struct PremiumGatedModifier: ViewModifier {
    let feature: PremiumFeature

    @State private var showPaywall = false
    @State private var subscriptionManager = SubscriptionManager.shared

    func body(content: Content) -> some View {
        let locked = !subscriptionManager.isPremium
            && !PremiumGate.isFeatureAvailable(feature)

        content
            .opacity(locked ? Theme.Opacity.medium : Theme.Opacity.full)
            .allowsHitTesting(!locked)
            .overlay {
                if locked {
                    lockedOverlay
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
    }

    private var lockedOverlay: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.accent)

                Text("Upgrade")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)

                Text(feature.displayName)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Theme.Colors.canvas.opacity(Theme.Opacity.half)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(feature.displayName) requires premium. Tap to upgrade.")
    }
}

// MARK: - View Extension

extension View {
    /// Gates this view behind a premium check for the specified feature.
    /// If the user is not premium and the feature requires premium, the view
    /// is dimmed with a lock overlay. Tapping the overlay presents the paywall.
    ///
    /// - Parameter feature: The premium feature this view requires.
    func premiumGated(feature: PremiumFeature) -> some View {
        modifier(PremiumGatedModifier(feature: feature))
    }
}

// MARK: - Session Limit Banner

/// A small banner shown when the free-tier daily session limit is reached.
/// Intended for use in ModeSelectionView or similar entry points.
struct SessionLimitBanner: View {
    @State private var showPaywall = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.signalElevated)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Daily limit reached")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Upgrade for unlimited sessions")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily session limit reached. Tap to upgrade for unlimited sessions.")
    }
}

// MARK: - Preview

#Preview("Premium Gate - Locked") {
    VStack(spacing: Theme.Spacing.lg) {
        Text("Sleep Mode Card")
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.xxl)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
            .premiumGated(feature: .sleepMode)

        SessionLimitBanner()
    }
    .padding(Theme.Spacing.pageMargin)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
