// SessionBackgroundView.swift
// BioNaural
//
// Living background layer for the session screen. Uses Metal shaders
// to render organic noise texture and optional water ripple distortion
// on the dark canvas. Driven by elapsed time and biometric state.
// Falls back to a static gradient when Reduce Motion is enabled.

import SwiftUI
import BioNauralShared

// MARK: - SessionBackgroundView

struct SessionBackgroundView: View {

    // MARK: - Inputs

    /// Current session mode (determines color palette).
    let sessionMode: FocusMode

    /// Current biometric state (drives intensity modulation).
    let biometricState: BiometricState

    /// Whether audio is actively playing.
    let isPlaying: Bool

    // MARK: - Internal State

    @State private var sessionStart: Date = .now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            staticBackground
        } else {
            shaderBackground
        }
    }

    // MARK: - Shader Background (iOS 17+)

    @ViewBuilder
    private var shaderBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = isPlaying
                ? sessionStart.distance(to: timeline.date)
                : 0

            Canvas { context, size in
                // Base canvas fill.
                context.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .color(Theme.Colors.canvas)
                )
            }
            .organicNoiseOverlay(
                elapsed: elapsed,
                color: modeColor,
                intensity: noiseIntensity
            )
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear { sessionStart = .now }
    }

    // MARK: - Static Fallback

    private var staticBackground: some View {
        Theme.Colors.canvas
            .ignoresSafeArea()
    }

    // MARK: - Computed Properties

    private var modeColor: Color {
        switch sessionMode {
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleepTint
        case .energize:    return Theme.Colors.energize
        }
    }

    /// Noise intensity scales with biometric activation.
    private var noiseIntensity: Double {
        let base = Theme.Shader.OrganicNoise.intensity
        switch biometricState {
        case .calm:     return base * 0.6
        case .focused:  return base
        case .elevated: return base * 1.3
        case .peak:     return base * 1.6
        }
    }
}

// MARK: - Preview

#Preview("Session Background - Focus") {
    ZStack {
        SessionBackgroundView(
            sessionMode: .focus,
            biometricState: .focused,
            isPlaying: true
        )
        Text("Focus Session")
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}

#Preview("Session Background - Sleep") {
    ZStack {
        SessionBackgroundView(
            sessionMode: .sleep,
            biometricState: .calm,
            isPlaying: true
        )
        Text("Sleep Session")
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}
