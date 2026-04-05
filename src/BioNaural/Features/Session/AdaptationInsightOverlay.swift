// AdaptationInsightOverlay.swift
// BioNaural
//
// A dismissible, non-blocking insight card shown during a session when
// the adaptive engine makes its first visible frequency adjustment.
//
// Features a live waveform morph animation showing old → new frequency,
// concentric pulse rings on the status dot, and rich mode-specific copy.
//
// Shown ONCE per session (first adaptation event). Auto-dismisses.
// All values from Theme tokens. No hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - AdaptationInsightOverlay

struct AdaptationInsightOverlay: View {

    // MARK: - Input

    let mode: FocusMode
    let adaptationCount: Int
    let oldFrequency: Double
    let newFrequency: Double
    let onDismiss: () -> Void

    // MARK: - State

    @State private var appeared = false
    @State private var wavePhase: CGFloat = 0
    @State private var morphProgress: CGFloat = 0
    @State private var pulseRingScale: CGFloat = 1.0
    @State private var pulseRingOpacity: Double = 0.6
    @State private var autoDismissTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {

            // Header: pulse dot + label + frequency delta
            HStack(spacing: Theme.Spacing.sm) {
                // Concentric pulse rings
                ZStack {
                    // Outer ring (expands and fades)
                    Circle()
                        .stroke(modeColor.opacity(pulseRingOpacity * 0.3), lineWidth: Theme.Radius.glassStroke)
                        .frame(width: Theme.Spacing.lg, height: Theme.Spacing.lg)
                        .scaleEffect(pulseRingScale)
                        .opacity(2.0 - pulseRingScale) // fades as it grows

                    // Middle ring
                    Circle()
                        .stroke(modeColor.opacity(pulseRingOpacity * 0.5), lineWidth: Theme.Radius.glassStroke)
                        .frame(width: Theme.Spacing.md, height: Theme.Spacing.md)
                        .scaleEffect(pulseRingScale * 0.8)

                    // Core dot
                    Circle()
                        .fill(modeColor)
                        .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                }
                .frame(width: Theme.Spacing.xl, height: Theme.Spacing.xl)

                Text("Session adapted")
                    .font(Theme.Typography.small)
                    .foregroundStyle(modeColor)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .textCase(.uppercase)

                Spacer()

                // Frequency delta badge
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(String(format: "%.1f", oldFrequency))
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    Image(systemName: frequencyDirection)
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(modeColor)

                    Text(String(format: "%.1f Hz", newFrequency))
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(modeColor)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(modeColor.opacity(Theme.Opacity.subtle))
                )
            }

            // Live waveform morph — shows old frequency morphing into new
            Canvas { context, size in
                drawWaveMorph(context: context, size: size)
            }
            .frame(height: Theme.Spacing.xxl)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))

            // Insight text
            Text(insightText)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)

            // First-time explanation
            if isFirstAdaptation {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(modeColor.opacity(Theme.Opacity.accentLight))
                        .frame(width: 3)

                    Text(firstAdaptationExplanation)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(Theme.Opacity.minimal),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            modeColor.opacity(Theme.Opacity.light),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
                .shadow(
                    color: Color.black.opacity(Theme.Opacity.dim),
                    radius: Theme.Spacing.sm,
                    y: Theme.Spacing.xxs
                )
                .shadow(
                    color: modeColor.opacity(Theme.Opacity.subtle),
                    radius: Theme.Spacing.lg,
                    y: Theme.Spacing.sm
                )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: appeared ? .zero : Theme.Spacing.xxl)
        .onAppear {
            withAnimation(Theme.Animation.sheet) {
                appeared = true
            }

            // Wave animation
            withAnimation(
                .linear(duration: Theme.Animation.Duration.orbBreathingDefault)
                .repeatForever(autoreverses: false)
            ) {
                wavePhase = .pi * 2
            }

            // Morph old frequency → new frequency
            withAnimation(.easeInOut(duration: Theme.Animation.Duration.orbAdaptation)) {
                morphProgress = 1.0
            }

            // Pulse ring animation
            withAnimation(
                .easeOut(duration: Theme.Orb.PulseCycle.focused)
                .repeatForever(autoreverses: false)
            ) {
                pulseRingScale = 2.0
                pulseRingOpacity = 0
            }

            // Auto-dismiss
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(Theme.Animation.Duration.safetyBannerDismiss + 2))
                guard !Task.isCancelled else { return }
                withAnimation(Theme.Animation.standard) {
                    onDismiss()
                }
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
        .onTapGesture {
            autoDismissTask?.cancel()
            withAnimation(Theme.Animation.press) {
                onDismiss()
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                removal: .opacity.combined(with: .scale(scale: 0.98))
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session adapted from \(String(format: "%.1f", oldFrequency)) to \(String(format: "%.1f", newFrequency)) Hz. \(insightText)")
        .accessibilityHint("Tap to dismiss")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Waveform Morph

    /// Draws a sine wave that morphs from the old frequency to the new frequency
    /// based on morphProgress. Creates a visual representation of the adaptation.
    private func drawWaveMorph(context: GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let amplitude = size.height * 0.35

        // Interpolate frequency
        let currentFreq = oldFrequency + (newFrequency - oldFrequency) * Double(morphProgress)
        // Map beat frequency to visual cycles (higher Hz = more cycles)
        let visualCycles = currentFreq / 5.0

        var path = Path()
        let steps = Int(size.width)
        for x in 0...steps {
            let xPos = CGFloat(x)
            let normalizedX = xPos / size.width
            let envelope = sin(normalizedX * .pi)
            let yPos = midY + sin(normalizedX * visualCycles * .pi * 2 + wavePhase) * amplitude * envelope

            if x == 0 {
                path.move(to: CGPoint(x: xPos, y: yPos))
            } else {
                path.addLine(to: CGPoint(x: xPos, y: yPos))
            }
        }

        // Glow
        var glowCtx = context
        glowCtx.addFilter(.blur(radius: Theme.Wavelength.blurRadius * 2))
        glowCtx.stroke(
            path,
            with: .color(modeColor.opacity(Theme.Opacity.medium)),
            lineWidth: Theme.Wavelength.Stroke.elevated
        )

        // Primary
        context.stroke(
            path,
            with: .color(modeColor.opacity(Theme.Opacity.accentStrong)),
            lineWidth: Theme.Wavelength.Stroke.standard
        )
    }

    // MARK: - Content

    private var isFirstAdaptation: Bool { adaptationCount <= 1 }

    private var frequencyDirection: String {
        newFrequency > oldFrequency ? "arrow.up.right" : "arrow.down.right"
    }

    private var insightText: String {
        switch mode {
        case .focus:
            if newFrequency < oldFrequency {
                return "Your heart rate rose \u{2014} BioNaural lowered the beat frequency to help you settle back into focus."
            }
            return "Your biometrics stabilized \u{2014} the beat frequency adjusted to deepen your focus state."
        case .relaxation:
            if newFrequency < oldFrequency {
                return "You\u{2019}re calming down. The session is progressing deeper into alpha range."
            }
            return "Your nervous system is still settling \u{2014} the audio is holding steady to support the transition."
        case .sleep:
            return "The session is descending through the brainwave bands \u{2014} theta toward delta, matching your brain\u{2019}s natural sleep onset."
        case .energize:
            if newFrequency > oldFrequency {
                return "Your body is responding \u{2014} the beat frequency is rising into the high-beta activation range."
            }
            return "The engine adjusted to keep your energy level in the sweet spot without overdriving."
        }
    }

    private var firstAdaptationExplanation: String {
        "This is a closed-loop system \u{2014} it responds to your physiology in real time. Static beats can\u{2019}t do this."
    }

    private var modeColor: Color { Color.modeColor(for: mode) }
}

// MARK: - Preview

#Preview("First Adaptation — Focus") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            Spacer()
            AdaptationInsightOverlay(
                mode: .focus,
                adaptationCount: 1,
                oldFrequency: 14.0,
                newFrequency: 13.2,
                onDismiss: {}
            )
            .padding(.bottom, Theme.Spacing.mega)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Energize Adaptation") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            Spacer()
            AdaptationInsightOverlay(
                mode: .energize,
                adaptationCount: 1,
                oldFrequency: 18.0,
                newFrequency: 22.5,
                onDismiss: {}
            )
            .padding(.bottom, Theme.Spacing.mega)
        }
    }
    .preferredColorScheme(.dark)
}
