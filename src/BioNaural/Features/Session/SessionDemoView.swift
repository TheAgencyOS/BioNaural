// SessionDemoView.swift
// BioNaural
//
// A standalone demo view for testing Orb + Wavelength frequency sync
// WITHOUT audio, Watch, or HealthKit. Simulates the adaptive engine
// by letting you:
//
//   1. Drag a slider to manually set beat frequency (1–30 Hz)
//   2. Tap mode buttons to switch between Focus/Relaxation/Sleep/Energize
//   3. Tap biometric state buttons to simulate HR changes
//   4. Toggle "Auto Demo" to watch a scripted frequency sweep
//
// The Orb breathing cycle and Wavelength cycle count respond in real time
// to the beat frequency — you can see the math driving the visuals.
//
// HOW TO TEST:
//   - Open this file in Xcode
//   - Use the SwiftUI Preview canvas (Cmd+Option+P)
//   - OR run the app and navigate to Settings > Developer > Session Demo
//   - No audio files, Watch, or HealthKit needed
//
// All values from Theme tokens. No hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - SessionDemoView

struct SessionDemoView: View {

    // MARK: - State

    @State private var beatFrequency: Double = 15.0
    @State private var sessionMode: FocusMode = .focus
    @State private var biometricState: BiometricState = .focused
    @State private var isPlaying: Bool = true
    @State private var autoDemoActive: Bool = false
    @State private var autoDemoTask: Task<Void, Never>?
    @State private var elapsedTime: TimeInterval = 0
    @State private var sessionTimer: Timer?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                RadialGradient(
                    colors: [
                        modeColor.opacity(Theme.Opacity.accentWash),
                        Theme.Colors.canvas.opacity(Theme.Opacity.transparent)
                    ],
                    center: .center,
                    startRadius: .zero,
                    endRadius: Theme.Layout.screenEstimate
                )
                .ignoresSafeArea()
            }

            // Wavelength (behind orb)
            WavelengthView(
                biometricState: biometricState,
                sessionMode: sessionMode,
                beatFrequency: beatFrequency,
                isPlaying: isPlaying
            )
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.mega)

            VStack(spacing: Theme.Spacing.lg) {

                // Mode label
                Text(sessionMode.displayName.uppercased())
                    .font(Theme.Typography.display)
                    .tracking(Theme.Typography.Tracking.display)
                    .foregroundStyle(modeColor)
                    .opacity(Theme.Opacity.medium)

                Spacer()

                // The Orb
                OrbView(
                    biometricState: biometricState,
                    sessionMode: sessionMode,
                    beatFrequency: beatFrequency,
                    isPlaying: isPlaying
                )
                .frame(width: orbSize, height: orbSize)

                Spacer()

                // Live data readout
                dataReadout

                // Frequency slider
                frequencySlider

                // Mode selector
                modeSelector

                // Biometric state selector
                stateSelector

                // Controls
                controlRow
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .onAppear { startTimer() }
        .onDisappear { stopAll() }
        .navigationTitle("Session Demo")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data Readout

    private var dataReadout: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.xxs) {
                Text(String(format: "%.1f", beatFrequency))
                    .font(Theme.Typography.data)
                    .foregroundStyle(modeColor)
                    .contentTransition(.numericText())
                Text("Hz")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(modeColor.opacity(Theme.Opacity.accentStrong))
            }

            VStack(spacing: Theme.Spacing.xxs) {
                Text(String(format: "%.1f", orbCycleDuration))
                    .font(Theme.Typography.data)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("Orb sec")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            VStack(spacing: Theme.Spacing.xxs) {
                Text(String(format: "%.1f", waveCycles))
                    .font(Theme.Typography.data)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("Waves")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Frequency Slider

    private var frequencySlider: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Slider(value: $beatFrequency, in: 1...30, step: 0.5)
                .tint(modeColor)

            HStack {
                Text("1 Hz")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Text("Delta")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.signalCalm)
                Spacer()
                Text("Theta")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.sleep)
                Spacer()
                Text("Alpha")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.relaxation)
                Spacer()
                Text("Beta")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.focus)
                Spacer()
                Text("30 Hz")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(FocusMode.allCases) { mode in
                Button {
                    withAnimation(Theme.Animation.standard) {
                        sessionMode = mode
                        beatFrequency = mode.defaultBeatFrequency
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: mode.systemImageName)
                            .font(.system(size: Theme.Typography.Size.body))
                        Text(mode.displayName)
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(
                        sessionMode == mode
                            ? Color.modeColor(for: mode)
                            : Theme.Colors.textTertiary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(
                                sessionMode == mode
                                    ? Color.modeColor(for: mode).opacity(Theme.Opacity.accentLight)
                                    : Theme.Colors.surface
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - State Selector

    private var stateSelector: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach([BiometricState.calm, .focused, .elevated, .peak], id: \.rawValue) { state in
                Button {
                    withAnimation(Theme.Animation.standard) {
                        biometricState = state
                    }
                } label: {
                    Text(stateLabel(state))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(
                            biometricState == state
                                ? Color.biometricColor(for: state)
                                : Theme.Colors.textTertiary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(
                                    biometricState == state
                                        ? Color.biometricColor(for: state).opacity(Theme.Opacity.accentLight)
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Play/pause
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                    .background(
                        Circle().fill(Theme.Colors.surface)
                    )
            }
            .buttonStyle(.plain)

            // Auto demo toggle
            Button {
                if autoDemoActive {
                    stopAutoDemo()
                } else {
                    startAutoDemo()
                }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(autoDemoActive ? Theme.Colors.signalPeak : Theme.Colors.textTertiary)
                        .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                    Text(autoDemoActive ? "Stop Auto" : "Auto Demo")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule().fill(Theme.Colors.surface)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Computed

    private var modeColor: Color {
        Color.modeColor(for: sessionMode)
    }

    private func stateLabel(_ state: BiometricState) -> String {
        switch state {
        case .calm:     return "Calm"
        case .focused:  return "Focused"
        case .elevated: return "Elevated"
        case .peak:     return "Peak"
        }
    }

    private var orbSize: CGFloat {
        Theme.Layout.screenEstimate * Theme.Animation.OrbScale.restingFraction * 1.5
    }

    /// Mirrors the Orb's internal calculation so the readout is accurate.
    private var orbCycleDuration: Double {
        guard beatFrequency > 0 else { return Theme.Orb.PulseCycle.focused }
        let raw = Theme.Animation.FrequencySync.orbScaleFactor / beatFrequency
        return min(
            Theme.Animation.FrequencySync.orbCycleDurationMax,
            max(Theme.Animation.FrequencySync.orbCycleDurationMin, raw)
        )
    }

    /// Mirrors the Wavelength's internal calculation.
    private var waveCycles: Double {
        guard beatFrequency > 0 else { return 2.0 }
        let raw = beatFrequency / Theme.Animation.FrequencySync.waveScaleFactor
        return min(
            Double(Theme.Animation.FrequencySync.waveCycleCountMax),
            max(Double(Theme.Animation.FrequencySync.waveCycleCountMin), raw)
        )
    }

    // MARK: - Timer

    private func startTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    // MARK: - Auto Demo

    /// Runs a scripted frequency sweep: cycles through all 4 modes,
    /// sweeping their frequency range over ~8 seconds each.
    private func startAutoDemo() {
        autoDemoActive = true
        autoDemoTask = Task { @MainActor in
            let modes: [FocusMode] = [.focus, .relaxation, .sleep, .energize]
            let stepsPerMode = 40
            let stepInterval: Duration = .milliseconds(200)

            while !Task.isCancelled {
                for mode in modes {
                    guard !Task.isCancelled else { return }
                    withAnimation(Theme.Animation.standard) {
                        sessionMode = mode
                    }

                    let range = mode.frequencyRange
                    let rangeSpan = range.upperBound - range.lowerBound

                    // Sweep up
                    for step in 0..<stepsPerMode {
                        guard !Task.isCancelled else { return }
                        let progress = Double(step) / Double(stepsPerMode)
                        withAnimation(Theme.Animation.press) {
                            beatFrequency = range.lowerBound + rangeSpan * progress
                        }

                        // Update biometric state based on progress
                        let newState: BiometricState
                        switch progress {
                        case 0..<0.25: newState = .calm
                        case 0.25..<0.5: newState = .focused
                        case 0.5..<0.75: newState = .elevated
                        default: newState = .peak
                        }
                        if biometricState != newState {
                            withAnimation(Theme.Animation.standard) {
                                biometricState = newState
                            }
                        }

                        try? await Task.sleep(for: stepInterval)
                    }

                    // Sweep back down
                    for step in 0..<stepsPerMode {
                        guard !Task.isCancelled else { return }
                        let progress = 1.0 - Double(step) / Double(stepsPerMode)
                        withAnimation(Theme.Animation.press) {
                            beatFrequency = range.lowerBound + rangeSpan * progress
                        }
                        try? await Task.sleep(for: stepInterval)
                    }
                }
            }
        }
    }

    private func stopAutoDemo() {
        autoDemoActive = false
        autoDemoTask?.cancel()
        autoDemoTask = nil
    }

    private func stopAll() {
        sessionTimer?.invalidate()
        stopAutoDemo()
    }
}

// MARK: - Preview

#Preview("Session Demo") {
    SessionDemoView()
        .preferredColorScheme(.dark)
}

#Preview("Session Demo — Sleep") {
    SessionDemoView()
        .preferredColorScheme(.dark)
        .onAppear {}
}
