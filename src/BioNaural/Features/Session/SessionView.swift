// SessionView.swift
// BioNaural
//
// The session experience — v2 design.
//
// Three layered wave lines (ambient/melodic/binaural) behind the Orb.
// Bare biometric numbers floating above the wave zone.
// Native iOS nav bar with overflow menu for sound selection + settings.
// Transport bar at bottom: AirPlay · expand · pause · stop · lock.
// Mode-specific variants: Sleep near-blackout, Energize phase bar + safety.
//
// All values from Theme tokens. No hardcoded values.

import AVKit
import BioNauralShared
import SwiftUI

// MARK: - Layout Constants

private enum Layout {
    /// Center point for the session background radial gradient (slightly above midpoint).
    static let backgroundGradientCenter: UnitPoint = .init(x: 0.5, y: 0.4)
}

// MARK: - SessionView

struct SessionView: View {

    @Bindable var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies

    // MARK: - Adaptation Insight State

    /// Whether the full first-time insight card has been shown.
    @State private var hasShownFirstInsight = false
    /// Controls visibility of the adaptation overlay (full card or toast).
    @State private var showAdaptationInsight = false
    /// Frequencies for the currently displayed adaptation event.
    @State private var adaptationOldFrequency: Double = 0
    @State private var adaptationNewFrequency: Double = 0

    // MARK: - Menu Action State

    /// Index of the currently selected soundscape preset (0 = Rain, 1 = Wind, 2 = Pink Noise).
    @State private var selectedSoundscapeIndex: Int = 0
    /// Controls presentation of the mix levels sheet.
    @State private var showMixLevels = false
    /// Controls presentation of the session settings sheet.
    @State private var showSessionSettings = false
    /// Controls presentation of the science sheet.
    @State private var showScience = false
    /// Whether the expanded biometric view is active.
    @State private var isExpandedView = false
    /// Whether the screen is locked to prevent accidental touches.
    @State private var isScreenLocked = false

    // MARK: - Body

    var body: some View {
        if viewModel.isSessionComplete {
            postSessionView
        } else {
            sessionContent
        }
    }

    // MARK: - Post Session

    private var postSessionView: some View {
        let session = FocusSession(
            startDate: Date().addingTimeInterval(-viewModel.elapsedTime),
            endDate: Date(),
            mode: viewModel.sessionMode.rawValue,
            durationSeconds: Int(viewModel.elapsedTime),
            averageHeartRate: viewModel.currentHR > 0 ? viewModel.currentHR : nil,
            averageHRV: viewModel.currentHRV > 0 ? viewModel.currentHRV : nil,
            beatFrequencyStart: viewModel.sessionMode.defaultBeatFrequency,
            beatFrequencyEnd: viewModel.currentBeatFrequency,
            carrierFrequency: viewModel.sessionMode.defaultCarrierFrequency,
            adaptationEvents: viewModel.adaptationEvents,
            wasCompleted: true
        )
        return PostSessionView(session: session) {
            dismiss()
        }
    }

    // MARK: - Session Content

    private var sessionContent: some View {
        ZStack {
            backgroundLayer

            // Main content
            VStack(spacing: .zero) {
                navBar

                // Energize: phase bar below nav
                if viewModel.sessionMode == .energize {
                    energizePhaseBar
                }

                Spacer()

                // Biometrics above the wave zone
                biometricStrip
                    .padding(.bottom, Theme.Spacing.lg)

                // Expanded biometric details
                if isExpandedView {
                    expandedBiometricDetails
                        .padding(.bottom, Theme.Spacing.md)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Orb + three wave layers
                waveOrbZone

                // Layer legend
                layerLegend
                    .padding(.top, -Theme.Spacing.xxs)

                Spacer()

                // Timer + frequency
                timerSection

                // Energize: HR ceiling gauge
                if viewModel.sessionMode == .energize {
                    hrCeilingGauge
                        .padding(.top, Theme.Spacing.md)
                }

                Spacer()

                // Transport bar
                transportBar

                // Safe area
                Spacer()
                    .frame(height: Theme.Spacing.xxxl)
            }
            .opacity(screenOpacity)

            // Adaptation insight overlay
            adaptationInsightLayer

            // Safety banner (Energize only)
            if viewModel.sessionMode == .energize {
                safetyBannerOverlay
            }

            // Sleep blanking
            if viewModel.isSleepBlanked {
                sleepBlankingOverlay
            }

            // Screen lock overlay
            if isScreenLocked {
                screenLockOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Ensure shared session state is set for the mini player,
            // covering both HomeTab-initiated and Compose-initiated sessions.
            dependencies.activeSessionMode = viewModel.sessionMode
        }
        .onChange(of: viewModel.adaptationCount) { _, newCount in
            guard newCount > 0 else { return }
            guard let lastEvent = viewModel.adaptationEvents.last else { return }

            adaptationOldFrequency = lastEvent.oldBeatFrequency
            adaptationNewFrequency = lastEvent.newBeatFrequency

            if newCount == 1 {
                // First adaptation: show full insight card
                hasShownFirstInsight = true
            }
            // Haptic feedback for adaptation
            dependencies.hapticService.adaptationEvent()

            // Show overlay for every adaptation (full card on first, auto-dismiss toast on subsequent)
            withAnimation(Theme.Animation.standard) {
                showAdaptationInsight = true
            }
        }
        .onChange(of: viewModel.elapsedTime) { _, newElapsed in
            // Sync elapsed time to shared state so the mini player can display it.
            dependencies.activeSessionElapsed = newElapsed
        }
        .onChange(of: viewModel.isSessionComplete) { _, isComplete in
            // When the session completes, clear active session state so the
            // mini player disappears.
            if isComplete {
                dependencies.activeSessionMode = nil
                dependencies.activeSessionElapsed = 0
            }
        }
        .sheet(isPresented: $showMixLevels) {
            mixLevelsSheet
        }
        .sheet(isPresented: $showSessionSettings) {
            sessionSettingsSheet
        }
        .sheet(isPresented: $showScience) {
            scienceSheet
        }
    }

}

// MARK: - Nav Bar (iOS native style)

extension SessionView {

    fileprivate var navBar: some View {
        HStack {
            // Collapse to mini player
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimize to mini player")

            Spacer()

            // Title
            Text(viewModel.sessionDisplayName)
                .font(.system(size: Theme.Typography.Size.body, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            // Overflow menu
            overflowMenu
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .frame(height: Theme.Spacing.jumbo)
        .padding(.top, Theme.Spacing.md)
    }
}

// MARK: - Overflow Menu

extension SessionView {

    fileprivate var overflowMenu: some View {
        Menu {
            // Sound selection section
            Section("Soundscape") {
                ForEach(Array(Constants.Soundscape.presets.enumerated()), id: \.offset) { index, preset in
                    Button {
                        selectedSoundscapeIndex = index
                        viewModel.selectSoundscape(preset.bedName)
                    } label: {
                        Label(
                            preset.displayName,
                            systemImage: selectedSoundscapeIndex == index ? "checkmark" : "music.note"
                        )
                    }
                }
            }

            Section {
                Button {
                    showMixLevels = true
                } label: {
                    Label("Mix Levels", systemImage: "slider.horizontal.3")
                }

                Button {
                    showSessionSettings = true
                } label: {
                    Label("Session Settings", systemImage: "gearshape")
                }

                Button {
                    showScience = true
                } label: {
                    Label("The Science", systemImage: "book.closed")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Session options")
    }
}

// MARK: - Biometric Strip

extension SessionView {

    /// Bare monospaced numbers floating above the wave zone.
    fileprivate var biometricStrip: some View {
        HStack(spacing: Theme.Spacing.xxxl) {
            if viewModel.currentHR > .zero {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(viewModel.formattedHeartRate)
                        .font(Theme.Typography.data)
                        .foregroundStyle(Color.biometricColor(for: viewModel.currentState))
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            if let hrvText = viewModel.formattedHRV {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(hrvText)
                        .font(Theme.Typography.data)
                        .foregroundStyle(Theme.Colors.accent)
                        .contentTransition(.numericText())
                    Text("HRV")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Wave + Orb Zone

extension SessionView {

    /// The Orb at center with three layered wave lines passing through it.
    /// Ambient = widest/slowest (teal), Melodic = medium (accent), Binaural = tightest (mode color).
    /// Each layer has a distinct color matching the mockup layered-depth design.
    /// All wave frequencies are mathematically derived from the live audio.
    fileprivate var waveOrbZone: some View {
        GeometryReader { geo in
            let orbSize = geo.size.width * orbFraction
            waveOrbContent(orbSize: orbSize)
                .frame(width: geo.size.width, height: orbSize + Theme.Spacing.mega)
        }
        .frame(height: Theme.Spacing.mega * 3)
        .accessibilityHidden(true)
    }

    fileprivate func waveOrbContent(orbSize: CGFloat) -> some View {
        ZStack {
            // Glow behind wave intersection
            RadialGradient(
                colors: [
                    effectiveModeColor.opacity(Theme.Opacity.accentLight),
                    Color.clear
                ],
                center: .center,
                startRadius: Theme.Spacing.xxl,
                endRadius: orbSize * Constants.WaveZone.glowEndRadiusMultiplier
            )
            .frame(width: orbSize * Constants.WaveZone.glowFrameWidthMultiplier, height: orbSize * Constants.WaveZone.glowEndRadiusMultiplier)

            // Layer 1: Ambient wave (widest, slowest — teal)
            WavelengthView(
                biometricState: viewModel.currentState,
                sessionMode: viewModel.sessionMode,
                beatFrequency: max(
                    viewModel.currentBeatFrequency / Constants.WaveZone.ambientFrequencyDivisor,
                    Constants.WaveZone.ambientFrequencyFloor
                ),
                isPlaying: viewModel.isPlaying,
                layerColor: Theme.Colors.signalCalm
            )
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.mega * Constants.WaveZone.ambientHeightMultiplier)
            .mask(waveEdgeFadeMask)

            // Layer 2: Melodic wave (medium — accent)
            WavelengthView(
                biometricState: viewModel.currentState,
                sessionMode: viewModel.sessionMode,
                beatFrequency: max(
                    viewModel.currentBeatFrequency / Constants.WaveZone.melodicFrequencyDivisor,
                    Constants.WaveZone.melodicFrequencyFloor
                ),
                isPlaying: viewModel.isPlaying,
                layerColor: Theme.Colors.accent
            )
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.mega * Constants.WaveZone.melodicHeightMultiplier)
            .mask(waveEdgeFadeMask)

            // Layer 3: Binaural wave (tightest, brightest — mode color)
            WavelengthView(
                biometricState: viewModel.currentState,
                sessionMode: viewModel.sessionMode,
                beatFrequency: viewModel.currentBeatFrequency,
                isPlaying: viewModel.isPlaying,
                layerColor: effectiveModeColor
            )
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.mega * Constants.WaveZone.binauralHeightMultiplier)
            .mask(waveEdgeFadeMask)

            // The Orb
            OrbView(
                biometricState: viewModel.currentState,
                sessionMode: viewModel.sessionMode,
                beatFrequency: viewModel.currentBeatFrequency,
                isPlaying: viewModel.isPlaying
            )
            .frame(width: orbSize, height: orbSize)
        }
    }

    /// Vertical gradient mask that fades wave layers to transparent at top/bottom edges,
    /// eliminating visible rectangular boundaries from the blur effect.
    fileprivate var waveEdgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: .zero),
                .init(color: .white, location: Theme.Opacity.accentLight),
                .init(color: .white, location: 1.0 - Theme.Opacity.accentLight),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Layer Legend

extension SessionView {

    fileprivate var layerLegend: some View {
        HStack(spacing: Theme.Spacing.lg) {
            legendItem(color: Theme.Colors.signalCalm, label: "Ambient", opacity: Theme.Opacity.medium)
            legendItem(color: Theme.Colors.accent, label: "Melodic", opacity: Theme.Opacity.medium)
            legendItem(color: effectiveModeColor, label: "Binaural", opacity: Theme.Opacity.half)
        }
    }

    fileprivate func legendItem(color: Color, label: String, opacity: Double) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .fill(color.opacity(opacity))
                .frame(width: Theme.Spacing.lg, height: Theme.Radius.legendStroke)
            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Timer Section

extension SessionView {

    fileprivate var timerSection: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            // Timer
            if viewModel.isInMandatoryCoolDown,
               let coolDownRemaining = viewModel.formattedCoolDownRemaining {
                Text(coolDownRemaining)
                    .font(Theme.Typography.timer)
                    .tracking(Theme.Typography.Tracking.data)
                    .foregroundStyle(Theme.Colors.signalCalm)
                    .opacity(Theme.Opacity.half)
            } else if let remaining = viewModel.formattedRemainingTime {
                Text(remaining)
                    .font(Theme.Typography.timer)
                    .tracking(Theme.Typography.Tracking.data)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .opacity(Theme.Opacity.half)
            } else {
                Text(viewModel.formattedElapsedTime)
                    .font(Theme.Typography.timer)
                    .tracking(Theme.Typography.Tracking.data)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .opacity(Theme.Opacity.half)
            }

            // Frequency + band label
            HStack(spacing: Theme.Spacing.xxs) {
                Text(viewModel.formattedBeatFrequency)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(effectiveModeColor)
                    .opacity(Theme.Opacity.half)

                Text(bandLabel)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            // Pomodoro break indicator
            if viewModel.isPomodoroBreak {
                Text("BREAK")
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .foregroundStyle(Theme.Colors.relaxation)
                    .opacity(Theme.Opacity.half)
            }
        }
    }
}

// MARK: - Transport Bar

extension SessionView {

    /// Bottom transport: AirPlay · expand · pause/play · stop · lock
    fileprivate var transportBar: some View {
        HStack {
            // AirPlay (native route picker — tapping opens the system picker directly)
            AirPlayRoutePickerRepresentable()
                .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                .accessibilityLabel("AirPlay audio output")

            Spacer()

            // Center controls
            HStack(spacing: Theme.Spacing.xxl) {
                // Expand (fullscreen toggle)
                Button {
                    withAnimation(Theme.Animation.standard) {
                        isExpandedView.toggle()
                    }
                } label: {
                    Image(systemName: isExpandedView ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpandedView ? "Collapse view" : "Expand view")

                // Play/Pause (primary)
                Button { viewModel.togglePlayPause() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: Theme.Typography.Size.headline))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(
                            width: Theme.Spacing.jumbo + Theme.Spacing.xs,
                            height: Theme.Spacing.jumbo + Theme.Spacing.xs
                        )
                        .background(
                            Circle()
                                .fill(Theme.Colors.surfaceRaised)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            Theme.Colors.textOnAccent.opacity(Theme.Opacity.light),
                                            lineWidth: Theme.Radius.glassStroke
                                        )
                                )
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(PremiumSessionButtonStyle())
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                // Stop
                Button { viewModel.stopSession() } label: {
                    Image(systemName: "square.fill")
                        .font(.system(size: Theme.Typography.Size.small, weight: .regular))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop session")
            }

            Spacer()

            // Lock
            Button {
                withAnimation(Theme.Animation.standard) {
                    isScreenLocked = true
                }
            } label: {
                Image(systemName: "lock")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lock screen")
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }
}

// MARK: - Energize Phase Bar

extension SessionView {

    fileprivate var energizePhaseBar: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Radius.segmentHeight) {
                // Warm-up
                phaseSegment(filled: viewModel.energizePhase != .warmUp, flex: 1, color: Theme.Colors.energize)
                // Ramp
                phaseSegment(
                    filled: viewModel.energizePhase == .sustain
                        || viewModel.energizePhase == .coolDown
                        || viewModel.energizePhase == .completed,
                    flex: 1,
                    color: Theme.Colors.energize
                )
                // Sustain
                phaseSegment(
                    filled: viewModel.energizePhase == .coolDown
                        || viewModel.energizePhase == .completed,
                    flex: 2,
                    color: Theme.Colors.energize
                )
                // Cool-down
                phaseSegment(filled: viewModel.energizePhase == .completed, flex: 1, color: Theme.Colors.signalCalm)
            }
            .padding(.horizontal, Theme.Spacing.xxxl)

            if let phaseLabel = viewModel.energizePhaseLabel {
                Text(phaseLabel)
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.energize)
                    .opacity(Theme.Opacity.half)
            }
        }
        .padding(.top, Theme.Spacing.xxs)
    }

    fileprivate func phaseSegment(filled: Bool, flex: Int, color: Color) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.xs)
            .fill(color.opacity(filled ? Theme.Opacity.accentStrong : Theme.Opacity.accentLight))
            .frame(height: Theme.Radius.segmentHeight)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - HR Ceiling Gauge

extension SessionView {

    fileprivate var hrCeilingGauge: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack {
                Text("HR Ceiling")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Text("\(Int(viewModel.currentHR)) / \(Int(Theme.Audio.Safety.hrHardStopBPM))")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.signalElevated)
            }

            GeometryReader { geo in
                let fraction = min(viewModel.currentHR / Theme.Audio.Safety.hrHardStopBPM, 1.0)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.xs)
                        .fill(Theme.Colors.surfaceRaised)
                    RoundedRectangle(cornerRadius: Theme.Radius.xs)
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.signalCalm, Theme.Colors.signalElevated],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: Theme.Radius.segmentHeight)
        }
        .padding(.horizontal, Theme.Spacing.jumbo)
    }
}

// MARK: - Sleep Blanking

extension SessionView {

    fileprivate var sleepBlankingOverlay: some View {
        Theme.Colors.canvas
            .ignoresSafeArea()
            .overlay(
                VStack {
                    Spacer()
                    Text("Tap to peek")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.sleepTint)
                        .opacity(Theme.Opacity.subtle)
                        .padding(.bottom, Theme.Spacing.mega)
                }
            )
            .onTapGesture { viewModel.revealData() }
            .accessibilityLabel("Screen blanked during sleep mode")
            .accessibilityHint("Tap to reveal session data")
    }
}

// MARK: - Adaptation Insight Layer

extension SessionView {

    @ViewBuilder
    fileprivate var adaptationInsightLayer: some View {
        if showAdaptationInsight {
            VStack {
                Spacer()
                AdaptationInsightOverlay(
                    mode: viewModel.sessionMode,
                    adaptationCount: viewModel.adaptationCount,
                    oldFrequency: adaptationOldFrequency,
                    newFrequency: adaptationNewFrequency,
                    onDismiss: {
                        withAnimation(Theme.Animation.standard) {
                            showAdaptationInsight = false
                        }
                    }
                )
                .padding(.bottom, Theme.Spacing.jumbo + Theme.Spacing.md)
            }
            .opacity(viewModel.isSleepBlanked ? Theme.Opacity.transparent : Theme.Opacity.full)
        }
    }
}

// MARK: - Safety Banner (Energize)

extension SessionView {

    @ViewBuilder
    fileprivate var safetyBannerOverlay: some View {
        if let alert = viewModel.safetyAlert {
            VStack {
                if alert.severity == .caution {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(Theme.Typography.caption)
                        Text(alert.message)
                            .font(Theme.Typography.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.Colors.canvas)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Capsule().fill(Theme.Colors.energize.opacity(Theme.Opacity.accentStrong)))
                    .padding(.top, Theme.Spacing.jumbo + Theme.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "heart.slash.fill")
                                .font(Theme.Typography.headline)
                            Text("Safety Alert")
                                .font(Theme.Typography.headline)
                        }
                        Text(alert.message)
                            .font(Theme.Typography.body)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.Colors.canvas)
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(LinearGradient(colors: [Theme.Colors.signalPeak, Theme.Colors.energize], startPoint: .leading, endPoint: .trailing))
                    )
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.jumbo + Theme.Spacing.md)
                    .onTapGesture { viewModel.dismissSafetyAlert() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(Theme.Animation.standard, value: viewModel.safetyAlert?.id)
        }
    }
}

// MARK: - Background

extension SessionView {

    fileprivate var backgroundLayer: some View {
        GeometryReader { geo in
            ZStack {
                Theme.Colors.canvas

                RadialGradient(
                    colors: [
                        effectiveBackgroundColor.opacity(effectiveAccentWashOpacity),
                        Theme.Colors.canvas.opacity(Theme.Opacity.transparent)
                    ],
                    center: Layout.backgroundGradientCenter,
                    startRadius: .zero,
                    endRadius: geo.size.width
                )
                .animation(Theme.Animation.orbAdaptation, value: viewModel.isInMandatoryCoolDown)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Expanded Biometric Details

extension SessionView {

    fileprivate var expandedBiometricDetails: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(viewModel.formattedBeatFrequency)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(effectiveModeColor)
                    Text("Beat Freq")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                VStack(spacing: Theme.Spacing.xxs) {
                    Text(bandLabel)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.accent)
                    Text("Band")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                VStack(spacing: Theme.Spacing.xxs) {
                    Text(viewModel.currentState.displayName)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Color.biometricColor(for: viewModel.currentState))
                    Text("State")
                        .font(Theme.Typography.small)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                if viewModel.adaptationCount > 0 {
                    VStack(spacing: Theme.Spacing.xxs) {
                        Text("\(viewModel.adaptationCount)")
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Adapts")
                            .font(Theme.Typography.small)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Mix Levels Sheet

extension SessionView {

    fileprivate var mixLevelsSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                    .frame(height: Theme.Spacing.md)

                mixSlider(
                    label: "Binaural",
                    value: Binding(
                        get: { viewModel.audioEngine.parameters.binauralVolume },
                        set: { viewModel.audioEngine.parameters.binauralVolume = $0 }
                    ),
                    color: effectiveModeColor
                )

                mixSlider(
                    label: "Ambient",
                    value: Binding(
                        get: { viewModel.audioEngine.parameters.ambientVolume },
                        set: { viewModel.audioEngine.parameters.ambientVolume = $0 }
                    ),
                    color: Theme.Colors.signalCalm
                )

                mixSlider(
                    label: "Melodic",
                    value: Binding(
                        get: { viewModel.audioEngine.parameters.melodicVolume },
                        set: { viewModel.audioEngine.parameters.melodicVolume = $0 }
                    ),
                    color: Theme.Colors.accent
                )

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Mix Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMixLevels = false }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    fileprivate func mixSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Slider(value: value, in: 0...1)
                .accessibilityLabel(label)
                .tint(color)
        }
    }
}

// MARK: - Session Settings Sheet

extension SessionView {

    fileprivate var sessionSettingsSheet: some View {
        NavigationStack {
            List {
                Section("Duration") {
                    Stepper(
                        "\(Int(viewModel.targetDurationMinutes)) min",
                        value: Binding(
                            get: { viewModel.targetDurationMinutes },
                            set: { viewModel.adjustDuration(minutes: $0) }
                        ),
                        in: Double(Constants.minimumSessionMinutes)...Double(Constants.maxSessionMinutes),
                        step: Constants.durationStepMinutes
                    )
                }

                Section("Adaptation") {
                    HStack {
                        Text("Mode")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(viewModel.isAdaptiveMode ? "Adaptive" : "Manual")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Session Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSessionSettings = false }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Science Sheet

extension SessionView {

    fileprivate var scienceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                    // Current session context
                    scienceContextCard

                    // Core science cards
                    scienceCard(
                        icon: "waveform.path",
                        title: "Binaural Beats",
                        // swiftlint:disable:next line_length
                        body: "When each ear receives a slightly different frequency, your brain perceives a third tone — the binaural beat — at the difference frequency. Research suggests this can gently encourage your brainwaves toward that target frequency, a process called auditory entrainment."
                    )

                    scienceCard(
                        icon: "brain.head.profile",
                        title: "Brainwave Bands",
                        // swiftlint:disable:next line_length
                        body: "Delta (1–4 Hz) for deep sleep, Theta (4–8 Hz) for drowsiness and meditation, Alpha (8–13 Hz) for relaxed awareness, Beta (13–30 Hz) for active focus, and Gamma (30+ Hz) for peak concentration. Your session targets the band that matches your goal."
                    )

                    scienceCard(
                        icon: "heart.text.clipboard",
                        title: "Adaptive Advantage",
                        // swiftlint:disable:next line_length
                        body: "Your heart rate and HRV reveal your real-time autonomic state. BioNaural reads these signals and adjusts the beat frequency to meet you where you are — not where a static preset assumes you should be. The result is a session that adapts to your body."
                    )

                    scienceCard(
                        icon: "person.2",
                        title: "Individual Differences",
                        // swiftlint:disable:next line_length
                        body: "Brainwave entrainment affects people differently. Factors like baseline anxiety, caffeine intake, and even genetics influence responsiveness. BioNaural learns your patterns over time, personalizing each session to what actually works for you."
                    )

                    scienceCard(
                        icon: "checkmark.shield",
                        title: "The Honest Truth",
                        // swiftlint:disable:next line_length
                        body: "The effects of binaural beats are real but modest. Studies show small-to-medium effect sizes for focus and relaxation. The adaptive biometric engine is where the real science lives — closing the loop between what you hear and how your body responds."
                    )

                    scienceCard(
                        icon: "ear",
                        title: "Best Practices",
                        // swiftlint:disable:next line_length
                        body: "Use stereo headphones — binaural beats require separate left/right channels. Keep volume comfortable, not loud. Sessions of 15–30 minutes are most studied. Consistency matters more than duration."
                    )
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("The Science")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showScience = false }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Contextual card showing the science behind the current session mode.
    fileprivate var scienceContextCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: viewModel.sessionMode.systemImageName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(effectiveModeColor)
                Text("Your \(viewModel.sessionDisplayName) Session")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text(scienceContextDescription)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(viewModel.formattedBeatFrequency)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(effectiveModeColor)
                    Text("Current")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(bandLabel)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.accent)
                    Text("Band")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                if viewModel.adaptationCount > 0 {
                    VStack(spacing: Theme.Spacing.xxs) {
                        Text("\(viewModel.adaptationCount)")
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Adaptations")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(.top, Theme.Spacing.xxs)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
    }

    fileprivate var scienceContextDescription: String {
        switch viewModel.sessionMode {
        case .focus:
            // swiftlint:disable:next line_length
            return "Targeting the Beta band (13–30 Hz) to promote sustained attention. The adaptive engine uses negative feedback — if your heart rate rises, the frequency lowers to maintain calm focus."
        case .relaxation:
            // swiftlint:disable:next line_length
            return "Guiding your brainwaves toward Alpha (8–13 Hz) — the band associated with relaxed awareness and recovery. A gentle downward bias nudges you toward your alpha peak."
        case .sleep:
            // swiftlint:disable:next line_length
            return "Transitioning from Theta (4–8 Hz) down to Delta (1–4 Hz) over the session. This mimics the natural descent into deep sleep, with the rate guided by your biometrics."
        case .energize:
            // swiftlint:disable:next line_length
            return "Driving toward high Beta and low Gamma (18–30 Hz) to boost alertness and energy. Safety guardrails monitor your heart rate and enforce a mandatory cool-down."
        }
    }

    fileprivate func scienceCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: Theme.Spacing.xl)
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Text(body)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surface)
        )
    }
}

// MARK: - Screen Lock Overlay

extension SessionView {

    fileprivate var screenLockOverlay: some View {
        Theme.Colors.canvas.opacity(Theme.Opacity.minimal)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: Theme.Typography.Size.headline))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("Screen Locked")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("Long press to unlock")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .opacity(Theme.Opacity.half)
                }
            )
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: Constants.screenLockPressDuration) {
                withAnimation(Theme.Animation.standard) {
                    isScreenLocked = false
                }
                dependencies.hapticService.adaptationEvent()
            }
            .accessibilityLabel("Screen is locked")
            .accessibilityHint("Long press to unlock")
    }
}

// MARK: - Computed Helpers

extension SessionView {

    fileprivate var isSleepMode: Bool { viewModel.sessionMode == .sleep }

    fileprivate var effectiveModeColor: Color {
        if isSleepMode { return Theme.Colors.sleepTint }
        if viewModel.sessionMode == .energize, viewModel.isInMandatoryCoolDown { return coolDownInterpolatedColor }
        return viewModel.modeColor
    }

    fileprivate var effectiveBackgroundColor: Color {
        if viewModel.sessionMode == .energize, viewModel.isInMandatoryCoolDown { return coolDownInterpolatedColor }
        if isSleepMode { return Theme.Colors.sleepTint }
        return viewModel.modeColor
    }

    fileprivate var effectiveAccentWashOpacity: Double {
        if isSleepMode { return Theme.Opacity.minimal }
        if viewModel.sessionMode == .energize { return Theme.Opacity.accentWash + Theme.Opacity.minimal }
        return Theme.Opacity.accentWash
    }

    fileprivate var coolDownInterpolatedColor: Color {
        let progress = viewModel.coolDownProgress
        if progress <= .zero { return Theme.Colors.energize }
        if progress >= 1.0 { return Theme.Colors.signalCalm }
        return Color(UIColor(Theme.Colors.energize).blended(with: UIColor(Theme.Colors.signalCalm), fraction: progress))
    }

    fileprivate var screenOpacity: Double {
        if viewModel.isSleepBlanked { return Theme.Opacity.transparent }
        return Theme.Opacity.full
    }

    /// Fraction of available width for the orb at the current biometric state.
    fileprivate var orbFraction: CGFloat {
        switch viewModel.currentState {
        case .calm:     return Theme.Animation.OrbScale.restingFraction
        case .focused:  return (Theme.Animation.OrbScale.restingFraction + Theme.Animation.OrbScale.peakFraction) / 2.0
        case .elevated: return Theme.Animation.OrbScale.peakFraction * Constants.orbElevatedFractionMultiplier
        case .peak:     return Theme.Animation.OrbScale.peakFraction
        }
    }

    fileprivate var bandLabel: String {
        let freq = viewModel.currentBeatFrequency
        switch freq {
        case ..<Constants.BrainwaveBands.deltaCeiling:  return "Delta"
        case Constants.BrainwaveBands.deltaCeiling..<Constants.BrainwaveBands.thetaCeiling:  return "Theta"
        case Constants.BrainwaveBands.thetaCeiling..<Constants.BrainwaveBands.alphaCeiling:  return "Alpha"
        case Constants.BrainwaveBands.alphaCeiling..<Constants.BrainwaveBands.betaCeiling: return "Beta"
        default:      return "High-Beta"
        }
    }
}

// MARK: - UIColor Blending Helper

private extension UIColor {
    func blended(with other: UIColor, fraction: Double) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(fraction)
        return UIColor(red: r1 + (r2 - r1) * f, green: g1 + (g2 - g1) * f, blue: b1 + (b2 - b1) * f, alpha: a1 + (a2 - a1) * f)
    }
}

// MARK: - AirPlay Route Picker (UIViewRepresentable)

private struct AirPlayRoutePickerRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = UIColor(Theme.Colors.accent)
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
