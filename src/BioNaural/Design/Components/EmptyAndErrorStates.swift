// EmptyAndErrorStates.swift
// BioNaural
//
// Polished empty states, error states, and interruption views.
// Each state is informative, never a dead end, and includes
// VoiceOver labels. All values from Theme tokens.

import SwiftUI

// MARK: - EmptySessionsView

/// Shown when the user has no session history yet.
/// Features a gentle animated mini-orb to invite exploration.
struct EmptySessionsView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbScale: CGFloat = Theme.Animation.OrbScale.breathingMin

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Mini Orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.Colors.accent,
                            Theme.Colors.accent.opacity(Theme.Opacity.dim)
                        ],
                        center: .center,
                        startRadius: .zero,
                        endRadius: Theme.Spacing.jumbo / 2
                    )
                )
                .frame(
                    width: Theme.Spacing.jumbo,
                    height: Theme.Spacing.jumbo
                )
                .scaleEffect(orbScale)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Theme.Animation.orbBreathing) {
                        orbScale = Theme.Animation.OrbScale.breathingMax
                    }
                }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Your first session awaits")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Choose a mode above to begin. Each session helps BioNaural learn what works best for you.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.mega)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("No sessions yet. Choose a mode to begin your first session."))
    }
}

// MARK: - EmptyTrendsView

/// Shown when analytics/trends don't have enough data to display.
/// Shows progress toward unlocking trend insights.
struct EmptyTrendsView: View {

    /// Number of completed sessions so far.
    let completedSessions: Int

    /// Sessions required before trends are meaningful.
    var sessionsRequired: Int = 5

    private var progress: Double {
        min(Double(completedSessions) / Double(max(sessionsRequired, 1)), 1.0)
    }

    private var sessionsRemaining: Int {
        max(sessionsRequired - completedSessions, .zero)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Dashed chart placeholder
            dashedChartPlaceholder

            VStack(spacing: Theme.Spacing.sm) {
                Text("Not enough data yet")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if sessionsRemaining > .zero {
                    Text("\(sessionsRemaining) more session\(sessionsRemaining == 1 ? "" : "s") to unlock trends")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    Text("Trends are ready to view")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                        .frame(height: Theme.Spacing.xs)

                    Capsule()
                        .fill(Theme.Colors.accent)
                        .frame(
                            width: geo.size.width * progress,
                            height: Theme.Spacing.xs
                        )
                }
            }
            .frame(height: Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.mega)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("Trends need \(sessionsRemaining) more sessions. \(completedSessions) of \(sessionsRequired) completed.")
        )
    }

    @ViewBuilder
    private var dashedChartPlaceholder: some View {
        ZStack {
            // Dashed axes
            Path { path in
                // Y axis
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: Theme.Spacing.mega))
                // X axis
                path.move(to: CGPoint(x: 0, y: Theme.Spacing.mega))
                path.addLine(to: CGPoint(x: Theme.Spacing.mega * 2, y: Theme.Spacing.mega))
            }
            .stroke(
                Theme.Colors.textTertiary,
                style: StrokeStyle(
                    lineWidth: Theme.Radius.glassStroke,
                    dash: [Theme.Spacing.xs, Theme.Spacing.xs]
                )
            )

            // Placeholder wave
            Path { path in
                let width = Theme.Spacing.mega * 2
                let height = Theme.Spacing.mega
                path.move(to: CGPoint(x: .zero, y: height * 0.7))
                path.addCurve(
                    to: CGPoint(x: width, y: height * 0.3),
                    control1: CGPoint(x: width * 0.3, y: height * 0.9),
                    control2: CGPoint(x: width * 0.7, y: height * 0.1)
                )
            }
            .stroke(
                Theme.Colors.accent.opacity(Theme.Opacity.dim),
                style: StrokeStyle(
                    lineWidth: Theme.Radius.glassStroke,
                    dash: [Theme.Spacing.md, Theme.Spacing.sm]
                )
            )
        }
        .frame(
            width: Theme.Spacing.mega * 2,
            height: Theme.Spacing.mega
        )
        .accessibilityHidden(true)
    }
}

// MARK: - NoWatchView

/// Shown when no Apple Watch is paired. This is NOT a dead end.
/// Emphasizes that manual mode is a first-class experience.
struct NoWatchView: View {

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "applewatch.slash")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Manual mode works great")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("BioNaural's time-based arcs adapt to your check-in responses and get smarter every session. Pair an Apple Watch anytime to add real-time biometric adaptation.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("No Apple Watch paired. Manual mode provides a great experience with time-based arcs that improve every session."))
    }
}

// MARK: - NoHeadphonesView

/// Prompts the user to connect headphones for the binaural effect.
/// Auto-detects when headphones connect and calls the dismiss closure.
struct NoHeadphonesView: View {

    /// Called when headphones are detected. The parent should dismiss this view.
    var onHeadphonesConnected: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = Theme.Animation.OrbScale.breathingMin

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "headphones")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.accent)
                .scaleEffect(iconScale)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Theme.Animation.orbBreathing) {
                        iconScale = Theme.Animation.OrbScale.breathingMax
                    }
                }
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Connect headphones")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Binaural beats require separate audio channels — one frequency per ear. Connect any wired or wireless headphones to continue.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .onReceive(
            NotificationCenter.default.publisher(
                for: AVAudioSession.routeChangeNotification
            )
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .newDeviceAvailable else { return }

            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
            let hasHeadphones = outputs.contains {
                $0.portType == .headphones ||
                $0.portType == .bluetoothA2DP ||
                $0.portType == .bluetoothLE ||
                $0.portType == .bluetoothHFP
            }
            if hasHeadphones {
                onHeadphonesConnected?()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Please connect headphones. Binaural beats need separate audio channels, one frequency per ear."))
    }
}

// MARK: - SessionInterruptedView

/// Shown when a session is paused due to an interruption (phone call,
/// Siri, another audio app). Auto-resumes when the interruption clears.
struct SessionInterruptedView: View {

    /// Called when the audio interruption ends. The parent should resume.
    var onInterruptionEnded: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseOpacity: Double = Theme.Opacity.dim

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.accent)
                .opacity(pulseOpacity)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Theme.Animation.orbBreathing) {
                        pulseOpacity = Theme.Opacity.accentStrong
                    }
                }
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Session paused")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Another app interrupted audio playback. Your session will resume automatically when the interruption ends.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .onReceive(
            NotificationCenter.default.publisher(
                for: AVAudioSession.interruptionNotification
            )
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .ended else { return }
            onInterruptionEnded?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Session paused due to an audio interruption. It will resume automatically."))
    }
}

// MARK: - HealthKitDeniedView

/// Gentle nudge when HealthKit access has been denied. Links to Settings.
struct HealthKitDeniedView: View {

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.signalCalm)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Health data access")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("BioNaural uses heart rate and HRV to personalize your sessions in real time. All data stays on your device — it is never shared or sold.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            Button {
                openHealthSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent, in: Capsule())
            }
            .accessibilityHint(Text("Opens iOS Settings where you can grant Health access"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .accessibilityElement(children: .contain)
    }

    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - NetworkErrorView

/// Calm, reassuring network error state with automatic retry.
/// Does not alarm the user — the app works fully offline.
struct NetworkErrorView: View {

    /// Called when the user taps "Try Again" or auto-retry fires.
    var onRetry: (() -> Void)?

    @State private var retryCountdown: Int = Int(Theme.Animation.Duration.autoRetryDelay)
    @State private var timerActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Timer that ticks down the auto-retry countdown.
    private let timer = Timer.publish(
        every: 1.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Connection issue")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("No worries — BioNaural works fully offline. This only affects syncing. Retrying in \(retryCountdown)s.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            Button {
                triggerRetry()
            } label: {
                Text("Try again")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                        in: Capsule()
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .onAppear { timerActive = true }
        .onReceive(timer) { _ in
            guard timerActive else { return }
            if retryCountdown > 1 {
                retryCountdown -= 1
            } else {
                triggerRetry()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Network connection issue. BioNaural works offline. Retrying in \(retryCountdown) seconds."))
    }

    private func triggerRetry() {
        retryCountdown = Int(Theme.Animation.Duration.autoRetryDelay)
        onRetry?()
    }
}

// MARK: - AVAudioSession Import

import AVFoundation

// MARK: - Previews

#if DEBUG
#Preview("EmptySessionsView") {
    EmptySessionsView()
        .background(Theme.Colors.canvas)
}

#Preview("EmptyTrendsView") {
    EmptyTrendsView(completedSessions: 2)
        .background(Theme.Colors.canvas)
}

#Preview("NoWatchView") {
    NoWatchView()
        .background(Theme.Colors.canvas)
}

#Preview("NoHeadphonesView") {
    NoHeadphonesView()
        .background(Theme.Colors.canvas)
}

#Preview("SessionInterruptedView") {
    SessionInterruptedView()
        .background(Theme.Colors.canvas)
}

#Preview("HealthKitDeniedView") {
    HealthKitDeniedView()
        .background(Theme.Colors.canvas)
}

#Preview("NetworkErrorView") {
    NetworkErrorView()
        .background(Theme.Colors.canvas)
}
#endif
