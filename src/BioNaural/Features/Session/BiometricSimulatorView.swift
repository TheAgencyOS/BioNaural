// BiometricSimulatorView.swift
// BioNaural
//
// Simulates Apple Watch biometric readings for testing adaptive audio.
// Provides preset scenarios (restless sleep, deep focus, workout) and
// manual controls (HR slider, HRV slider) that feed into BiometricProcessor
// as if they were real wearable data.
//
// Accessible from the session overflow menu during debug builds.

import BioNauralShared
import SwiftUI

// MARK: - Simulator Scenarios

/// Pre-built biometric scenarios for testing adaptive audio responses.
enum BiometricScenario: String, CaseIterable, Identifiable {
    case restlessSleep = "Restless Sleep"
    case deepSleep = "Deep Sleep"
    case anxiousRelaxation = "Anxious → Calm"
    case deepFocus = "Deep Focus"
    case focusDistracted = "Focus → Distracted"
    case workoutWarmup = "Workout Warmup"
    case workoutPeak = "Workout Peak"
    case workoutCooldown = "Cooldown"
    case manual = "Manual Control"

    var id: String { rawValue }

    /// Returns (time_offset_seconds, heart_rate, hrv) keyframes.
    /// The simulator interpolates between keyframes.
    var keyframes: [(time: Double, hr: Double, hrv: Double)] {
        switch self {
        case .restlessSleep:
            // HR spikes every ~3 minutes (restless), then settles
            return [
                (0,   58, 45),   // Start: light sleep
                (60,  55, 50),   // Settling
                (120, 52, 55),   // Deeper
                (180, 72, 25),   // RESTLESS — HR spike, HRV drops
                (210, 65, 30),   // Calming down
                (270, 54, 50),   // Back to sleep
                (360, 70, 28),   // Another restless episode
                (390, 62, 35),   // Calming
                (450, 52, 55),   // Deep again
                (540, 50, 60),   // Deepest
                (600, 48, 65),   // Very deep sleep
                (720, 50, 58),   // Sustained deep
                (900, 52, 55),   // End: stable sleep
            ]
        case .deepSleep:
            return [
                (0,   60, 40),
                (120, 55, 50),
                (300, 50, 60),
                (600, 48, 65),
                (900, 47, 68),
            ]
        case .anxiousRelaxation:
            return [
                (0,   85, 20),   // Start: anxious
                (60,  80, 25),
                (180, 72, 32),   // Starting to calm
                (300, 65, 40),
                (450, 60, 48),   // Noticeably calmer
                (600, 55, 55),   // Relaxed
                (900, 52, 60),   // Deep relaxation
            ]
        case .deepFocus:
            return [
                (0,   70, 40),
                (120, 68, 45),
                (300, 65, 50),
                (600, 63, 55),
                (900, 62, 55),
            ]
        case .focusDistracted:
            return [
                (0,   65, 50),   // Focused
                (180, 63, 52),   // Deep focus
                (300, 75, 35),   // Distracted! HR up, HRV down
                (360, 80, 28),   // More distracted
                (420, 72, 35),   // Recovering
                (600, 65, 48),   // Refocused
                (900, 63, 52),   // Stable focus
            ]
        case .workoutWarmup:
            return [
                (0,   72, 40),
                (60,  80, 35),
                (120, 90, 30),
                (180, 100, 25),
                (300, 110, 22),
                (450, 120, 18),
            ]
        case .workoutPeak:
            return [
                (0,   120, 18),
                (60,  135, 15),
                (120, 145, 12),
                (180, 150, 10),
                (300, 148, 11),
                (450, 145, 12),
            ]
        case .workoutCooldown:
            return [
                (0,   140, 12),
                (60,  125, 18),
                (120, 110, 25),
                (180, 95, 32),
                (300, 80, 40),
                (450, 72, 45),
            ]
        case .manual:
            return [(0, 70, 45)]
        }
    }
}

// MARK: - BiometricSimulatorView

struct BiometricSimulatorView: View {

    @Bindable var viewModel: SessionViewModel
    @State private var selectedScenario: BiometricScenario = .restlessSleep
    @State private var isRunning = false
    @State private var elapsedTime: Double = 0
    @State private var currentHR: Double = 70
    @State private var currentHRV: Double = 45
    @State private var manualHR: Double = 70
    @State private var manualHRV: Double = 45
    @State private var simulationTimer: Timer?
    @State private var readingLog: [(time: Double, hr: Double, hrv: Double)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {

                    // Current readings display
                    currentReadingsCard

                    // Scenario picker
                    scenarioPicker

                    // Manual controls (when manual mode selected)
                    if selectedScenario == .manual {
                        manualControls
                    }

                    // Transport
                    transportControls

                    // Reading log
                    if !readingLog.isEmpty {
                        readingLogView
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Biometric Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { stopSimulation() }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Current Readings

    private var currentReadingsCard: some View {
        HStack(spacing: Theme.Spacing.xl) {
            VStack {
                Text("\(Int(currentHR))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(heartRateColor)
                Text("BPM")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            VStack {
                Text("\(Int(currentHRV))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.signalCalm)
                Text("HRV (ms)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            VStack {
                Text(biometricStateLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text("State")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface.cornerRadius(Theme.Radius.lg))
    }

    private var heartRateColor: Color {
        if currentHR > 100 { return Theme.Colors.signalPeak }
        if currentHR > 80 { return Theme.Colors.signalElevated }
        if currentHR > 65 { return Theme.Colors.textPrimary }
        return Theme.Colors.signalCalm
    }

    private var biometricStateLabel: String {
        if currentHR > 120 { return "Peak" }
        if currentHR > 90 { return "Elevated" }
        if currentHR > 70 { return "Focused" }
        return "Calm"
    }

    // MARK: - Scenario Picker

    private var scenarioPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Scenario")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: Theme.Spacing.xs) {
                ForEach(BiometricScenario.allCases) { scenario in
                    Button {
                        selectedScenario = scenario
                        if scenario == .manual {
                            currentHR = manualHR
                            currentHRV = manualHRV
                        }
                    } label: {
                        Text(scenario.rawValue)
                            .font(Theme.Typography.caption)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .fill(selectedScenario == scenario
                                          ? Theme.Colors.accent.opacity(0.2)
                                          : Theme.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(selectedScenario == scenario ? Theme.Colors.accent : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(selectedScenario == scenario
                                            ? Theme.Colors.textPrimary
                                            : Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Manual Controls

    private var manualControls: some View {
        VStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text("Heart Rate")
                        .font(Theme.Typography.caption)
                    Spacer()
                    Text("\(Int(manualHR)) BPM")
                        .font(Theme.Typography.dataSmall)
                }
                .foregroundStyle(Theme.Colors.textSecondary)
                Slider(value: $manualHR, in: 40...180, step: 1)
                    .tint(heartRateColor)
                    .onChange(of: manualHR) { _, newValue in
                        currentHR = newValue
                        sendBiometricReading()
                    }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack {
                    Text("HRV")
                        .font(Theme.Typography.caption)
                    Spacer()
                    Text("\(Int(manualHRV)) ms")
                        .font(Theme.Typography.dataSmall)
                }
                .foregroundStyle(Theme.Colors.textSecondary)
                Slider(value: $manualHRV, in: 5...100, step: 1)
                    .tint(Theme.Colors.signalCalm)
                    .onChange(of: manualHRV) { _, newValue in
                        currentHRV = newValue
                        sendBiometricReading()
                    }
            }
        }
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button {
                if isRunning { stopSimulation() } else { startSimulation() }
            } label: {
                Label(isRunning ? "Stop" : "Start Simulation",
                      systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(isRunning ? Theme.Colors.signalPeak : Theme.Colors.accent)
            }

            if isRunning {
                Text(formatTime(elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Button {
                readingLog.removeAll()
                elapsedTime = 0
            } label: {
                Text("Reset")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Reading Log

    private var readingLogView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Readings (\(readingLog.count))")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            ForEach(Array(readingLog.suffix(8).enumerated()), id: \.offset) { _, reading in
                HStack {
                    Text(formatTime(reading.time))
                        .font(.system(.caption2, design: .monospaced))
                    Spacer()
                    Text("HR \(Int(reading.hr))")
                        .foregroundStyle(reading.hr > 90 ? Theme.Colors.signalElevated : Theme.Colors.textSecondary)
                    Text("HRV \(Int(reading.hrv))")
                        .foregroundStyle(Theme.Colors.signalCalm)
                }
                .font(Theme.Typography.caption)
            }
        }
    }

    // MARK: - Simulation Engine

    private func startSimulation() {
        isRunning = true
        elapsedTime = 0
        readingLog.removeAll()

        // Send initial reading
        sendBiometricReading()

        // Timer: tick every 3 seconds (simulates watch reading interval)
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                guard isRunning else { return }
                elapsedTime += 3.0

                if selectedScenario == .manual {
                    currentHR = manualHR
                    currentHRV = manualHRV
                } else {
                    // Interpolate from scenario keyframes
                    let kf = selectedScenario.keyframes
                    let (hr, hrv) = interpolateKeyframes(kf, at: elapsedTime)
                    currentHR = hr
                    currentHRV = hrv
                }

                sendBiometricReading()
                readingLog.append((time: elapsedTime, hr: currentHR, hrv: currentHRV))
            }
        }
    }

    private func stopSimulation() {
        isRunning = false
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func sendBiometricReading() {
        // Feed simulated data into the BiometricProcessor
        // This is the same path real Apple Watch data takes
        viewModel.injectSimulatedBiometric(hr: currentHR, hrv: currentHRV)
    }

    private func interpolateKeyframes(
        _ keyframes: [(time: Double, hr: Double, hrv: Double)],
        at time: Double
    ) -> (hr: Double, hrv: Double) {
        guard keyframes.count >= 2 else {
            return (keyframes.first?.hr ?? 70, keyframes.first?.hrv ?? 45)
        }

        // Find the two keyframes we're between
        let loopDuration = keyframes.last!.time
        let loopedTime = loopDuration > 0 ? time.truncatingRemainder(dividingBy: loopDuration) : 0

        var prev = keyframes[0]
        var next = keyframes.count > 1 ? keyframes[1] : keyframes[0]

        for i in 0..<keyframes.count - 1 {
            if loopedTime >= keyframes[i].time && loopedTime < keyframes[i + 1].time {
                prev = keyframes[i]
                next = keyframes[i + 1]
                break
            }
        }

        let range = next.time - prev.time
        let t = range > 0 ? (loopedTime - prev.time) / range : 0

        // Smooth interpolation (ease-in-out)
        let smooth = t * t * (3 - 2 * t)

        let hr = prev.hr + (next.hr - prev.hr) * smooth
        let hrv = prev.hrv + (next.hrv - prev.hrv) * smooth

        return (hr, hrv)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
