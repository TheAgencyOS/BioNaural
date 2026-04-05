// PremiumInteractions.swift
// BioNaural
//
// Premium interaction components: rolling numbers, custom slider,
// shimmer loading, and breathing glow. Every value sourced from
// Theme tokens. Every animation gated by Reduce Motion.

import SwiftUI

// MARK: - RollingNumberView

/// Odometer-style number display that smoothly transitions between
/// values using `.contentTransition(.numericText())`. Ideal for
/// heart rate, HRV, and timer readouts.
struct RollingNumberView: View {

    // MARK: - Inputs

    /// The integer value to display. Changes trigger the rolling animation.
    let value: Int

    /// Font for the number. Defaults to `Theme.Typography.data`.
    var font: Font = Theme.Typography.data

    /// Text color. Defaults to `Theme.Colors.textPrimary`.
    var color: Color = Theme.Colors.textPrimary

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        Text(verbatim: "\(value)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(
                reduceMotion ? .identity : Theme.Animation.rollingNumber,
                value: value
            )
            .accessibilityLabel(Text("\(value)"))
    }
}

// MARK: - PremiumSlider

/// Custom slider with a thin gradient track, themed thumb, and
/// haptic ticks at quarter increments. All dimensions and colors
/// from Theme tokens.
struct PremiumSlider: View {

    // MARK: - Inputs

    @Binding var value: Double

    /// The allowed range for the slider value.
    let range: ClosedRange<Double>

    /// Accent color for the filled portion of the track.
    var accentColor: Color = Theme.Colors.accent

    /// Optional callback fired on every drag change.
    var onChanged: ((Double) -> Void)?

    // MARK: - Constants

    /// Height of the track line.
    private var trackHeight: CGFloat { Theme.Spacing.xxs }

    /// Diameter of the draggable thumb.
    private var thumbDiameter: CGFloat { Theme.Spacing.xxl }

    /// Haptic tick positions as fractions of the range.
    private let hapticFractions: [Double] = [0.0, 0.25, 0.50, 0.75, 1.0]

    /// Tolerance within which a haptic fires (fraction of range).
    private var hapticTolerance: Double {
        Theme.Opacity.subtle // 0.05 — reuse the token as a numeric threshold
    }

    // MARK: - State

    @State private var lastHapticFraction: Double?
    @GestureState private var isDragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    /// Normalized position of the thumb in [0, 1].
    private var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return .zero }
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width - thumbDiameter
            let thumbX = thumbDiameter / 2 + trackWidth * normalizedValue

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Theme.Colors.surfaceRaised)
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbDiameter / 2)

                // Filled track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(Theme.Opacity.medium),
                                accentColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(.zero, thumbX), height: trackHeight)
                    .padding(.leading, thumbDiameter / 2)

                // Thumb
                Circle()
                    .fill(accentColor)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(
                        color: accentColor.opacity(Theme.Opacity.dim),
                        radius: Theme.Radius.sm,
                        y: Theme.Spacing.xxs / 2
                    )
                    .scaleEffect(isDragging ? Theme.Animation.OrbScale.breathingMax : Theme.Animation.OrbScale.breathingMin + Theme.Opacity.subtle)
                    .animation(Theme.Animation.press, value: isDragging)
                    .position(x: thumbX, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: .zero)
                            .updating($isDragging) { _, state, _ in
                                state = true
                            }
                            .onChanged { drag in
                                let fraction = (drag.location.x - thumbDiameter / 2) / trackWidth
                                let clamped = min(max(fraction, .zero), 1.0)
                                let newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                                value = newValue
                                onChanged?(newValue)
                                fireHapticIfNeeded(fraction: clamped)
                            }
                    )
            }
            .frame(height: thumbDiameter)
        }
        .frame(height: thumbDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(normalizedValue * 100)) percent"))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) * hapticTolerance
            switch direction {
            case .increment:
                value = min(value + step, range.upperBound)
            case .decrement:
                value = max(value - step, range.lowerBound)
            @unknown default:
                break
            }
            onChanged?(value)
        }
        .accessibilityLabel(Text("Volume slider"))
    }

    // MARK: - Haptic

    /// Fires a light haptic tick when the thumb crosses a quarter-mark.
    private func fireHapticIfNeeded(fraction: Double) {
        for tick in hapticFractions where abs(fraction - tick) < hapticTolerance {
            guard lastHapticFraction != tick else { return }
            lastHapticFraction = tick
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }
        // Reset when between ticks so the next crossing fires
        if let last = lastHapticFraction,
           hapticFractions.allSatisfy({ abs(fraction - $0) >= hapticTolerance }) {
            if abs(fraction - last) > hapticTolerance {
                lastHapticFraction = nil
            }
        }
    }
}

// MARK: - ShimmerView

/// Loading placeholder that sweeps a gradient left-to-right over the
/// content. Uses Theme surface colors for the gradient stops.
struct ShimmerView: ViewModifier {

    /// When `true`, the shimmer animates. When `false`, content is shown normally.
    let isActive: Bool

    @State private var phase: CGFloat = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    shimmerOverlay
                        .allowsHitTesting(false)
                )
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Theme.Animation.shimmerCycle) {
                        phase = 1.0
                    }
                }
                .accessibilityLabel(Text("Loading"))
        } else {
            content
        }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if reduceMotion {
            // Static subtle overlay for Reduce Motion
            Theme.Colors.surface.opacity(Theme.Opacity.light)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
        } else {
            GeometryReader { geo in
                let gradientWidth = geo.size.width * 2
                LinearGradient(
                    colors: [
                        Theme.Colors.surface.opacity(Theme.Opacity.transparent),
                        Theme.Colors.surfaceRaised.opacity(Theme.Opacity.medium),
                        Theme.Colors.surface.opacity(Theme.Opacity.transparent)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: gradientWidth)
                .offset(x: -gradientWidth + phase * (geo.size.width + gradientWidth))
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
        }
    }
}

// MARK: - BreathingGlow

/// Adds a pulsing shadow that expands and contracts over a
/// `Theme.Animation.Duration.breathingGlowCycle` period. Designed for
/// "suggested" or "recommended" mode cards.
struct BreathingGlow: ViewModifier {

    /// The glow color (typically the mode color).
    let color: Color

    /// When `false`, the glow is hidden instantly.
    let isActive: Bool

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shadow radius range for the breathing animation.
    private var glowRadiusMin: CGFloat { Theme.Radius.sm }
    private var glowRadiusMax: CGFloat { Theme.Radius.xxl }

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(shadowOpacity) : .clear,
                radius: isActive ? currentRadius : .zero
            )
            .onAppear {
                guard isActive, !reduceMotion else { return }
                withAnimation(Theme.Animation.breathingGlow) {
                    isExpanded = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                guard !reduceMotion else { return }
                if newValue {
                    withAnimation(Theme.Animation.breathingGlow) {
                        isExpanded = true
                    }
                } else {
                    withAnimation(Theme.Animation.press) {
                        isExpanded = false
                    }
                }
            }
            .accessibilityElement(children: .contain)
    }

    private var currentRadius: CGFloat {
        reduceMotion ? glowRadiusMin : (isExpanded ? glowRadiusMax : glowRadiusMin)
    }

    private var shadowOpacity: Double {
        isExpanded ? Theme.Opacity.medium : Theme.Opacity.light
    }
}

// MARK: - PremiumSessionButtonStyle

/// A premium button style with scale + opacity feedback on press.
/// Respects Reduce Motion — falls back to .identity animation when enabled.
/// Used across session controls and the session player transport bar.
struct PremiumSessionButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Interaction.pressScale : 1.0)
            .opacity(configuration.isPressed ? Theme.Opacity.medium : Theme.Opacity.full)
            .animation(
                reduceMotion ? .identity : (configuration.isPressed ? Theme.Animation.press : Theme.Animation.standard),
                value: configuration.isPressed
            )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("RollingNumberView") {
    struct PreviewWrapper: View {
        @State private var heartRate = 72

        var body: some View {
            VStack(spacing: Theme.Spacing.xl) {
                RollingNumberView(
                    value: heartRate,
                    font: Theme.Typography.display,
                    color: Theme.Colors.accent
                )
                Button("Randomize") {
                    heartRate = Int.random(in: 55...120)
                }
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.canvas)
        }
    }
    return PreviewWrapper()
}

#Preview("PremiumSlider") {
    struct PreviewWrapper: View {
        @State private var volume = 0.5

        var body: some View {
            VStack(spacing: Theme.Spacing.xl) {
                PremiumSlider(
                    value: $volume,
                    range: 0...1,
                    accentColor: Theme.Colors.accent
                )
                .padding(.horizontal, Theme.Spacing.pageMargin)

                Text(verbatim: "\(Int(volume * 100))%")
                    .font(Theme.Typography.data)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.canvas)
        }
    }
    return PreviewWrapper()
}
#endif
