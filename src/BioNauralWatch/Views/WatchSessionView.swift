// WatchSessionView.swift
// BioNauralWatch
//
// Active session screen. Shows the Wavelength, mode label, transport
// controls, and supports tap-to-reveal HR, Always-On Display, paused
// state, and mode-specific variations. All visual values from
// WatchDesign tokens — no hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - WatchSessionView

struct WatchSessionView: View {

    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showHROverlay = false
    @State private var hideOverlayTask: Task<Void, Never>?
    @State private var crownVolume: Double = 1.0

    // MARK: - Body

    var body: some View {
        Group {
            if isLuminanceReduced {
                alwaysOnDisplay
            } else if sessionManager.isPaused {
                pausedDisplay
            } else {
                activeDisplay
            }
        }
    }

    // MARK: - Active Display

    private var activeDisplay: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: WatchDesign.Spacing.xs) {
                Spacer()

                modeLabelView

                Spacer()

                ZStack {
                    wavelengthView
                        .opacity(showHROverlay ? WatchDesign.Opacity.revealWaveDim : 1.0)

                    if showHROverlay {
                        tapRevealOverlay
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { revealHeartRate() }
                .accessibilityLabel("Session wavelength")
                .accessibilityHint("Tap to reveal heart rate")
                .accessibilityAddTraits(.isButton)

                if showBreathingIndicator {
                    breathingIndicator
                }

                Spacer()

                WatchGlassPill(
                    isPlaying: true,
                    elapsedSeconds: sessionManager.elapsedSeconds,
                    sessionMode: mode,
                    onTogglePlayPause: { sessionManager.pauseSession() },
                    onStop: { sessionManager.stopSession() }
                )
                .opacity(max(sleepDimFactor, WatchDesign.Opacity.sleepTimerFloor))
            }
            .padding(.bottom, WatchDesign.Layout.glassPillBottomOffset)
        }
        .focusable()
        .digitalCrownRotation(
            $crownVolume,
            from: 0.0,
            through: 1.0,
            by: WatchDesign.Animation.crownHapticDetent,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownVolume) { _, newValue in
            sessionManager.setEntrainmentVolume(newValue)
        }
    }

    // MARK: - Paused Display

    private var pausedDisplay: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: WatchDesign.Spacing.xs) {
                Spacer()

                modeLabelView

                Spacer()

                // Dashed horizontal line replaces wavelength
                pausedLine
                    .frame(height: WatchDesign.Wavelength.height)

                if showBreathingIndicator {
                    breathingIndicator
                }

                Spacer()

                WatchGlassPill(
                    isPlaying: false,
                    elapsedSeconds: sessionManager.elapsedSeconds,
                    sessionMode: mode,
                    onTogglePlayPause: { sessionManager.resumeSession() },
                    onStop: { sessionManager.stopSession() }
                )
            }
            .padding(.bottom, WatchDesign.Layout.glassPillBottomOffset)
        }
    }

    // MARK: - Always-On Display

    private var alwaysOnDisplay: some View {
        VStack {
            Spacer()

            Text(mode.displayName.uppercased())
                .font(.system(size: WatchDesign.Typography.aodModeSize, weight: .medium))
                .tracking(WatchDesign.Typography.modeLabelTracking)
                .foregroundStyle(mode.watchColor.opacity(WatchDesign.Opacity.aodModeLabel))

            // Static horizontal line
            Rectangle()
                .fill(mode.watchColor.opacity(WatchDesign.Opacity.aodLine))
                .frame(height: WatchDesign.Wavelength.Stroke.standard)
                .padding(.horizontal, WatchDesign.Spacing.xxl)

            Text(formattedElapsed)
                .font(.system(size: WatchDesign.Typography.aodTimerSize, weight: .light, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.aodTimer))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.displayName) session, \(formattedElapsed)")
    }

    // MARK: - Mode Label

    private var modeLabelView: some View {
        Text(mode.displayName.uppercased())
            .font(.system(size: WatchDesign.Typography.modeLabelSize, weight: .medium))
            .tracking(WatchDesign.Typography.modeLabelTracking)
            .foregroundStyle(mode.watchColor.opacity(modeLabelOpacity))
            .accessibilityLabel("\(mode.displayName) session active")
    }

    private var modeLabelOpacity: Double {
        guard sessionManager.activeMode == .sleep else {
            return WatchDesign.Opacity.modeLabel * sleepDimFactor
        }
        // Sleep mode progressively dims from modeLabel down to sleepDimFloor
        return WatchDesign.Opacity.modeLabel * sleepDimFactor
    }

    // MARK: - Card-Style Background

    /// Linear gradient wash matching the iPhone carousel card design —
    /// mode color bleeds from top-left and fades to canvas at bottom-right.
    /// Includes a left accent stripe (narrow mode-colored gradient on leading edge).
    private var backgroundGradient: some View {
        ZStack(alignment: .leading) {
            // Card-style linear gradient wash (top-left → bottom-right)
            LinearGradient(
                stops: [
                    .init(color: mode.watchColor.opacity(backgroundOpacity), location: 0.0),
                    .init(color: WatchDesign.Colors.surface.opacity(WatchDesign.Card.gradientMidOpacity * sleepDimFactor), location: 0.4),
                    .init(color: WatchDesign.Colors.canvas, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Left accent stripe — mode color fading to transparent
            LinearGradient(
                colors: [
                    mode.watchColor.opacity(backgroundOpacity * 2),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: WatchDesign.Card.accentStripeWidth)
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        let base: Double = mode == .energize ? WatchDesign.Opacity.sessionBackgroundEnergize : WatchDesign.Card.gradientStartOpacity
        return base * sleepDimFactor
    }

    // MARK: - Wavelength

    private var wavelengthView: some View {
        WatchWavelengthView(
            biometricState: sessionManager.currentBiometricState,
            sessionMode: mode,
            beatFrequency: sessionManager.currentBeatFrequency,
            isPlaying: true
        )
        .frame(height: WatchDesign.Wavelength.height)
    }

    // MARK: - Tap-to-Reveal Overlay

    private var revealAccessibilityLabel: String {
        if let hr = sessionManager.currentHeartRate {
            return "Heart rate: \(Int(hr)) bpm, \(sessionManager.currentBiometricState.watchDisplayName)"
        } else {
            return "Heart rate unavailable"
        }
    }

    private var tapRevealOverlay: some View {
        VStack(spacing: WatchDesign.Spacing.xs) {
            if let hr = sessionManager.currentHeartRate {
                Text("\(Int(hr))")
                    .font(.system(size: WatchDesign.Typography.revealHRSize, weight: .light, design: .monospaced))
                    .foregroundStyle(mode.watchColor)

                Text("bpm")
                    .font(.system(size: WatchDesign.Typography.revealUnitSize))
                    .foregroundStyle(mode.watchColor.opacity(WatchDesign.Opacity.bpmUnit))

                HStack(spacing: WatchDesign.Spacing.xs) {
                    Circle()
                        .fill(sessionManager.currentBiometricState.watchSignalColor)
                        .frame(
                            width: WatchDesign.Layout.learningDotSize,
                            height: WatchDesign.Layout.learningDotSize
                        )
                        .accessibilityHidden(true)

                    Text(sessionManager.currentBiometricState.watchDisplayName)
                        .font(.system(size: WatchDesign.Typography.revealStateSize))
                        .foregroundStyle(WatchDesign.Colors.textSecondary)
                }
            } else {
                Text("--")
                    .font(.system(size: WatchDesign.Typography.revealHRSize, weight: .light, design: .monospaced))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)

                Text("bpm")
                    .font(.system(size: WatchDesign.Typography.revealUnitSize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)

                Text("Connecting...")
                    .font(.system(size: WatchDesign.Typography.revealStateSize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(revealAccessibilityLabel)
    }

    // MARK: - Breathing Indicator

    private var showBreathingIndicator: Bool {
        sessionManager.activeMode == .relaxation || sessionManager.activeMode == .sleep
    }

    private var breathingIndicator: some View {
        HStack(spacing: WatchDesign.Spacing.md) {
            Circle()
                .stroke(mode.watchColor, lineWidth: WatchDesign.Wavelength.Stroke.standard)
                .background(
                    Circle()
                        .fill(mode.watchColor.opacity(WatchDesign.Opacity.breatheCircleFill))
                )
                .frame(
                    width: WatchDesign.Layout.breatheCircleSize,
                    height: WatchDesign.Layout.breatheCircleSize
                )

            Text("Breathe")
                .font(.system(size: WatchDesign.Typography.breatheLabelSize))
                .foregroundStyle(mode.watchColor.opacity(WatchDesign.Opacity.breatheText))
        }
        .accessibilityLabel("Breathing guide active")
    }

    // MARK: - Paused Line

    private var pausedLine: some View {
        VStack(spacing: WatchDesign.Spacing.sm) {
            // Dashed horizontal line
            Line()
                .stroke(
                    mode.watchColor.opacity(WatchDesign.Opacity.pausedLine),
                    style: StrokeStyle(
                        lineWidth: WatchDesign.Wavelength.Stroke.paused,
                        dash: [WatchDesign.Spacing.md, WatchDesign.Spacing.sm]
                    )
                )
                .frame(height: WatchDesign.Wavelength.Stroke.paused)

            Text("PAUSED")
                .font(.system(size: WatchDesign.Typography.pausedLabelSize))
                .tracking(WatchDesign.Typography.pausedLabelTracking)
                .foregroundStyle(WatchDesign.Colors.textSecondary)
        }
        .accessibilityLabel("Session paused")
    }

    // MARK: - Sleep Progressive Dimming

    private var sleepDimFactor: Double {
        guard sessionManager.activeMode == .sleep else { return 1.0 }
        let minutes = sessionManager.elapsedSeconds / 60
        let dimStart = WatchDesign.Animation.sleepDimStartMinutes
        guard minutes > dimStart else { return 1.0 }
        let reduction = (minutes - dimStart) * WatchDesign.Animation.sleepDimRatePerMinute
        return max(1.0 - reduction, WatchDesign.Opacity.sleepDimFloor)
    }

    // MARK: - Reveal Heart Rate

    private func revealHeartRate() {
        withAnimation(.spring(bounce: WatchDesign.Animation.pressBounce)) {
            showHROverlay = true
        }

        hideOverlayTask?.cancel()
        hideOverlayTask = Task {
            try? await Task.sleep(for: .seconds(WatchDesign.Animation.revealHold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: WatchDesign.Animation.revealFadeOut)) {
                showHROverlay = false
            }
        }
    }

    // MARK: - Helpers

    private var mode: FocusMode {
        sessionManager.activeMode ?? .focus
    }

    private var formattedElapsed: String {
        let total = Int(sessionManager.elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Line Shape

/// A simple horizontal line shape for the paused state dashed line.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

