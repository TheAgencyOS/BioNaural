// WatchMainView.swift
// BioNauralWatch
//
// Root view for the Watch app. Routes between mode selection (idle)
// and the active session view. Shows last session summary when available.

import SwiftUI
import BioNauralShared

struct WatchMainView: View {

    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        Group {
            if sessionManager.isSessionActive {
                WatchSessionView()
            } else {
                idleView
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        ScrollView {
            VStack(spacing: WatchLayout.sectionSpacing) {
                WatchModeSelectionView()

                if let summary = sessionManager.lastSessionSummary {
                    lastSessionCard(summary)
                }
            }
            .padding(.horizontal, WatchLayout.horizontalPadding)
        }
    }

    // MARK: - Last Session Summary

    private func lastSessionCard(_ summary: WatchSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: WatchLayout.innerSpacing) {
            Text("Last Session")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: summary.mode.watchIconName)
                    .foregroundStyle(summary.mode.watchColor)
                    .accessibilityHidden(true)

                Text(summary.mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(summary.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
            }

            Text(summary.formattedTimeAgo)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(WatchLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: WatchLayout.cardCornerRadius)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last session: \(summary.mode.displayName), \(summary.formattedDuration), \(summary.formattedTimeAgo)")
    }
}

// MARK: - WatchSessionSummary

/// Lightweight summary of the last completed session, stored by
/// `WatchSessionManager` for display on the idle screen.
struct WatchSessionSummary: Codable, Sendable {
    let mode: FocusMode
    let durationSeconds: TimeInterval
    let endDate: Date

    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedTimeAgo: String {
        let interval = Date().timeIntervalSince(endDate)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - WatchLayout

/// Centralized layout constants for the Watch interface.
/// All spacing, padding, and sizing values live here — no hardcoded
/// values in view code.
enum WatchLayout {
    static let horizontalPadding: CGFloat = 4
    static let sectionSpacing: CGFloat = 12
    static let innerSpacing: CGFloat = 4
    static let cardPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 12
    static let modeCardCornerRadius: CGFloat = 14
    static let modeCardVerticalPadding: CGFloat = 14
    static let modeCardHorizontalPadding: CGFloat = 12
    static let modeIconSize: CGFloat = 22
    static let hrFontSize: CGFloat = 48
    static let timerFontSize: CGFloat = 18
    static let orbPulseMinScale: CGFloat = 0.92
    static let orbPulseMaxScale: CGFloat = 1.08
    static let orbSize: CGFloat = 60
    static let orbBlurRadius: CGFloat = 12
    static let stopButtonSize: CGFloat = 44
    static let durationPickerRange: ClosedRange<Int> = 5...60
    static let durationPickerDefault: Int = 15
    static let durationPickerStep: Int = 5
    static let heartbeatPingInterval: TimeInterval = 5
    static let connectionHealthTimeout: TimeInterval = 10
}

// MARK: - FocusMode Watch Extensions

extension FocusMode {

    /// SF Symbol icon name for each mode on Watch.
    var watchIconName: String {
        switch self {
        case .focus:       return "brain.head.profile"
        case .relaxation:  return "leaf.fill"
        case .sleep:       return "moon.fill"
        case .energize:    return "bolt.fill"
        }
    }

    /// Mode-specific tint color for Watch UI.
    /// Uses the same hex values as Theme.Colors on iPhone, resolved
    /// directly here since Theme depends on UIKit (unavailable on watchOS).
    var watchColor: Color {
        switch self {
        case .focus:       return Color(hex: FocusModeHex.focus)
        case .relaxation:  return Color(hex: FocusModeHex.relaxation)
        case .sleep:       return Color(hex: FocusModeHex.sleep)
        case .energize:    return Color(hex: FocusModeHex.energize)
        }
    }

    /// Hex values matching Theme.Colors.Hex on the iPhone side.
    private enum FocusModeHex {
        static let focus: UInt = 0x5B6ABF
        static let relaxation: UInt = 0x4EA8A6
        static let sleep: UInt = 0x9080C4
        static let energize: UInt = 0xF5A623
    }
}

// MARK: - Color+Hex (watchOS)

extension Color {

    /// Creates a Color from a hex integer (e.g., 0x6E7CF7).
    /// Mirrors the iPhone-side `Color(hex:)` initializer from Theme.swift.
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
