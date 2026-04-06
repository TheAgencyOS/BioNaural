// WatchBiometricPill.swift
// BioNauralWatch
//
// Inline badge showing the current heart rate and biometric state.
// Used on the confident idle screen to surface real-time biometrics
// at a glance. All visual values from WatchDesign tokens.

import SwiftUI
import BioNauralShared

// MARK: - WatchBiometricPill

struct WatchBiometricPill: View {

    // MARK: - Inputs

    /// Current heart rate in BPM.
    let heartRate: Double

    /// Current biometric activation state.
    let state: BiometricState

    // MARK: - Body

    var body: some View {
        HStack(spacing: WatchDesign.Spacing.xs) {
            Image(systemName: "heart")
                .font(.system(size: WatchDesign.Typography.pillHRSize))
                .foregroundStyle(state.watchSignalColor)
                .accessibilityHidden(true)

            Text("\(Int(heartRate))")
                .font(.system(size: WatchDesign.Typography.pillHRSize))
                .foregroundStyle(state.watchSignalColor)

            Text(" \u{00b7} ")
                .font(.system(size: WatchDesign.Typography.pillHRSize))
                .foregroundStyle(WatchDesign.Colors.textSecondary)

            Text(state.watchDisplayName)
                .font(.system(size: WatchDesign.Typography.pillHRSize))
                .foregroundStyle(WatchDesign.Colors.textSecondary)
        }
        .padding(.horizontal, WatchDesign.Layout.biometricPillHPadding)
        .padding(.vertical, WatchDesign.Layout.biometricPillVPadding)
        .background(
            RoundedRectangle(cornerRadius: WatchDesign.Layout.biometricPillCornerRadius)
                .fill(state.watchSignalColor.opacity(WatchDesign.Opacity.pillBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate \(Int(heartRate)) bpm, \(state.watchDisplayName)")
    }
}

// MARK: - Preview

#Preview("Biometric Pill - Calm") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        WatchBiometricPill(heartRate: 62, state: .calm)
    }
}

#Preview("Biometric Pill - Elevated") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        WatchBiometricPill(heartRate: 88, state: .elevated)
    }
}
