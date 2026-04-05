// WatchSessionView.swift
// BioNauralWatch
//
// Active session display. Shows heart rate, elapsed timer, a simplified
// orb pulse, and a stop button. Supports Always On Display via
// @Environment(\.isLuminanceReduced).

import SwiftUI
import BioNauralShared

struct WatchSessionView: View {

    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// Drives the orb breathing animation.
    @State private var orbPulseActive: Bool = false

    var body: some View {
        if isLuminanceReduced {
            alwaysOnDisplay
        } else {
            activeDisplay
        }
    }

    // MARK: - Always On Display (Luminance Reduced)

    /// Minimal rendering for AOD: HR + timer on black background.
    /// No animations, no gradients — preserves battery.
    private var alwaysOnDisplay: some View {
        VStack(spacing: WatchLayout.innerSpacing) {
            Spacer()

            heartRateLabel
                .foregroundStyle(modeColor.opacity(0.6))

            timerLabel
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Active Display

    private var activeDisplay: some View {
        VStack(spacing: WatchLayout.innerSpacing) {
            Spacer()

            // Simplified Orb — color pulse matching mode
            orbPulse
                .padding(.bottom, WatchLayout.innerSpacing)

            heartRateLabel
                .foregroundStyle(modeColor)

            timerLabel
                .foregroundStyle(.secondary)

            Spacer()

            stopButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(
                colors: [modeColor.opacity(0.08), Color.black],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
        )
    }

    // MARK: - Heart Rate

    private var heartRateLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(heartRateText)
                .font(.system(size: WatchLayout.hrFontSize, weight: .light, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())

            if sessionManager.currentHeartRate != nil {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(modeColor.opacity(0.6))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate: \(heartRateText) beats per minute")
    }

    private var heartRateText: String {
        if let hr = sessionManager.currentHeartRate {
            return "\(Int(hr))"
        }
        return "--"
    }

    // MARK: - Timer

    private var timerLabel: some View {
        Text(formattedElapsed)
            .font(.system(size: WatchLayout.timerFontSize, weight: .regular, design: .monospaced))
            .monospacedDigit()
            .accessibilityLabel("Elapsed time: \(formattedElapsed)")
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

    // MARK: - Orb Pulse

    /// Simplified orb for Watch: a blurred circle that gently pulses
    /// in the mode color. Much lighter than the full Canvas orb on iPhone.
    private var orbPulse: some View {
        Circle()
            .fill(modeColor.opacity(0.3))
            .frame(width: WatchLayout.orbSize, height: WatchLayout.orbSize)
            .blur(radius: WatchLayout.orbBlurRadius)
            .scaleEffect(orbPulseActive ? WatchLayout.orbPulseMaxScale : WatchLayout.orbPulseMinScale)
            .animation(
                .easeInOut(duration: orbCycleDuration)
                    .repeatForever(autoreverses: true),
                value: orbPulseActive
            )
            .onAppear {
                orbPulseActive = true
            }
            .accessibilityHidden(true)
    }

    /// Pulse cycle duration derived from the mode's natural tempo.
    /// Focus: medium pace, Relaxation: slow, Sleep: slowest.
    private var orbCycleDuration: Double {
        guard let mode = sessionManager.activeMode else { return 5.0 }
        switch mode {
        case .focus:       return 4.0
        case .relaxation:  return 5.0
        case .sleep:       return 6.0
        case .energize:    return 0.75
        }
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button {
            sessionManager.stopSession()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: WatchLayout.stopButtonSize, height: WatchLayout.stopButtonSize)
                .background(
                    Circle()
                        .fill(Color.red.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop")
        .accessibilityHint("Ends the current session")
    }

    // MARK: - Helpers

    private var modeColor: Color {
        guard let mode = sessionManager.activeMode else { return .white }
        switch mode {
        case .focus: return Color(hex: 0x5B6ABF)
        case .relaxation: return Color(hex: 0x4EA8A6)
        case .sleep: return Color(hex: 0x9080C4)
        case .energize: return Color(hex: 0xF5A623)
        }
    }
}
