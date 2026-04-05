// OnboardingWaveCanvas.swift
// BioNaural
//
// Subtle animated sine wave background for onboarding screens.
// Uses the same dual-layer rendering (bloom + crisp) and edge-envelope
// fade as ModeCardWaveCanvas, creating visual continuity with the
// home screen cards. Positioned as a full-bleed background layer.
// Reduce Motion: renders a single static horizontal line.

import SwiftUI

// MARK: - OnboardingWaveCanvas

struct OnboardingWaveCanvas: View {

    /// Wave color — defaults to accent. Pass a mode color for themed screens.
    var color: Color = Theme.Colors.accent

    /// Vertical position as fraction of view height (0 = top, 1 = bottom).
    var verticalCenter: Double = Theme.Onboarding.Wave.verticalCenter

    /// Number of visible sine cycles across the width.
    var cycleCount: Double = Theme.Onboarding.Wave.cycleCount

    /// Wave amplitude as fraction of view height.
    var amplitudeFraction: CGFloat = Theme.Onboarding.Wave.amplitudeFraction

    /// Overall opacity multiplier — use lower values for background subtlety.
    var intensity: Double = Theme.Onboarding.Wave.intensity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawStaticLine(context: context, size: size)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time * Theme.Onboarding.Wave.scrollSpeed
                    drawWave(context: context, size: size, phase: phase)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Wave Renderer

    private func drawWave(context: GraphicsContext, size: CGSize, phase: Double) {
        let path = buildWavePath(size: size, phase: phase)

        // Layer 1 — Bloom (soft glow)
        var bloomCtx = context
        bloomCtx.addFilter(.blur(radius: Theme.CardWave.Bloom.blurRadius))
        bloomCtx.stroke(
            path,
            with: .color(color.opacity(Theme.CardWave.Bloom.opacity * intensity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Bloom.strokeWidth,
                lineCap: .round
            )
        )

        // Layer 2 — Crisp (visible line)
        context.stroke(
            path,
            with: .color(color.opacity(Theme.CardWave.Crisp.opacity * intensity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Crisp.strokeWidth,
                lineCap: .round
            )
        )
    }

    // MARK: - Path Builder

    private func buildWavePath(size: CGSize, phase: Double) -> Path {
        let width = size.width
        let midY = size.height * verticalCenter
        let amplitude = size.height * amplitudeFraction
        let freq = cycleCount * 2.0 * .pi
        let fadeExp = Theme.CardWave.fadeExponent

        var path = Path()
        let step: CGFloat = 2.0

        var x: CGFloat = 0
        while x <= width {
            let normalizedX = x / width
            let envelope = pow(sin(normalizedX * .pi), fadeExp)
            let y = midY + amplitude * envelope * sin(normalizedX * freq + phase)

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        return path
    }

    // MARK: - Static Line (Reduce Motion)

    private func drawStaticLine(context: GraphicsContext, size: CGSize) {
        let midY = size.height * verticalCenter
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: size.width, y: midY))

        context.stroke(
            path,
            with: .color(color.opacity(Theme.CardWave.Crisp.opacity * intensity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Crisp.strokeWidth,
                lineCap: .round
            )
        )
    }
}

// MARK: - Binaural Wave Merge Canvas

/// Dual-layer animation showing two sine waves (left ear / right ear)
/// at slightly different frequencies, with a third "perceived" beat wave
/// emerging between them. Used on the HowItWorks onboarding screen.
struct BinauralWaveMergeCanvas: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawStaticMerge(context: context, size: size)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    drawAnimatedMerge(context: context, size: size, time: time)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Animated Merge

    private func drawAnimatedMerge(context: GraphicsContext, size: CGSize, time: Double) {
        let width = size.width
        let midY = size.height * 0.5
        let spacing = size.height * Theme.Onboarding.BinauralMerge.waveSpacing
        let amplitude = size.height * Theme.Onboarding.BinauralMerge.amplitudeFraction
        let fadeExp = Theme.CardWave.fadeExponent
        let phase = time * Theme.Onboarding.Wave.scrollSpeed

        // Left ear wave — accent color, slightly higher frequency
        let leftPath = buildWavePath(
            width: width,
            midY: midY - spacing,
            amplitude: amplitude,
            cycles: Theme.Onboarding.BinauralMerge.leftCycles,
            phase: phase,
            fadeExp: fadeExp
        )

        // Right ear wave — relaxation color, slightly lower frequency
        let rightPath = buildWavePath(
            width: width,
            midY: midY + spacing,
            amplitude: amplitude,
            cycles: Theme.Onboarding.BinauralMerge.rightCycles,
            phase: phase * Theme.Onboarding.BinauralMerge.rightPhaseMultiplier,
            fadeExp: fadeExp
        )

        // Perceived beat wave — emerges at center, wider/slower
        let beatPath = buildWavePath(
            width: width,
            midY: midY,
            amplitude: amplitude * Theme.Onboarding.BinauralMerge.beatAmplitudeScale,
            cycles: Theme.Onboarding.BinauralMerge.beatCycles,
            phase: phase * Theme.Onboarding.BinauralMerge.beatPhaseMultiplier,
            fadeExp: fadeExp
        )

        // Draw each wave with dual-layer rendering

        // Left ear — bloom + crisp
        drawDualLayer(
            context: context,
            path: leftPath,
            color: Theme.Colors.accent,
            intensity: Theme.Onboarding.BinauralMerge.earWaveIntensity
        )

        // Right ear — bloom + crisp
        drawDualLayer(
            context: context,
            path: rightPath,
            color: Theme.Colors.relaxation,
            intensity: Theme.Onboarding.BinauralMerge.earWaveIntensity
        )

        // Perceived beat — bloom + crisp, brighter
        drawDualLayer(
            context: context,
            path: beatPath,
            color: Theme.Colors.textPrimary,
            intensity: Theme.Onboarding.BinauralMerge.beatWaveIntensity
        )
    }

    // MARK: - Static Merge (Reduce Motion)

    private func drawStaticMerge(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let midY = size.height * 0.5
        let spacing = size.height * Theme.Onboarding.BinauralMerge.waveSpacing
        let amplitude = size.height * Theme.Onboarding.BinauralMerge.amplitudeFraction
        let fadeExp = Theme.CardWave.fadeExponent

        let leftPath = buildWavePath(
            width: width, midY: midY - spacing,
            amplitude: amplitude,
            cycles: Theme.Onboarding.BinauralMerge.leftCycles,
            phase: 0, fadeExp: fadeExp
        )
        let rightPath = buildWavePath(
            width: width, midY: midY + spacing,
            amplitude: amplitude,
            cycles: Theme.Onboarding.BinauralMerge.rightCycles,
            phase: 0, fadeExp: fadeExp
        )
        let beatPath = buildWavePath(
            width: width, midY: midY,
            amplitude: amplitude * Theme.Onboarding.BinauralMerge.beatAmplitudeScale,
            cycles: Theme.Onboarding.BinauralMerge.beatCycles,
            phase: 0, fadeExp: fadeExp
        )

        drawDualLayer(context: context, path: leftPath, color: Theme.Colors.accent,
                       intensity: Theme.Onboarding.BinauralMerge.earWaveIntensity)
        drawDualLayer(context: context, path: rightPath, color: Theme.Colors.relaxation,
                       intensity: Theme.Onboarding.BinauralMerge.earWaveIntensity)
        drawDualLayer(context: context, path: beatPath, color: Theme.Colors.textPrimary,
                       intensity: Theme.Onboarding.BinauralMerge.beatWaveIntensity)
    }

    // MARK: - Shared Helpers

    private func drawDualLayer(
        context: GraphicsContext,
        path: Path,
        color: Color,
        intensity: Double
    ) {
        // Bloom
        var bloomCtx = context
        bloomCtx.addFilter(.blur(radius: Theme.CardWave.Bloom.blurRadius))
        bloomCtx.stroke(
            path,
            with: .color(color.opacity(Theme.CardWave.Bloom.opacity * intensity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Bloom.strokeWidth,
                lineCap: .round
            )
        )

        // Crisp
        context.stroke(
            path,
            with: .color(color.opacity(Theme.CardWave.Crisp.opacity * intensity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Crisp.strokeWidth,
                lineCap: .round
            )
        )
    }

    private func buildWavePath(
        width: CGFloat,
        midY: CGFloat,
        amplitude: CGFloat,
        cycles: Double,
        phase: Double,
        fadeExp: Double
    ) -> Path {
        let freq = cycles * 2.0 * .pi
        let step: CGFloat = 2.0

        var path = Path()
        var x: CGFloat = 0

        while x <= width {
            let normalizedX = x / width
            let envelope = pow(sin(normalizedX * .pi), fadeExp)
            let y = midY + amplitude * envelope * sin(normalizedX * freq + phase)

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        return path
    }
}

// MARK: - Adaptive Wavelength Canvas

/// Dual-layer wavelength that morphs between calm and elevated states,
/// demonstrating real-time biometric adaptation. Color interpolates
/// from signalCalm → signalElevated. Used on AdaptiveDifference screen.
struct AdaptiveWavelengthCanvas: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawWave(context: context, size: size, progress: 0.5, phase: 0)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time * Theme.Onboarding.Wave.scrollSpeed
                    drawWave(context: context, size: size, progress: progress, phase: phase)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Theme.Animation.Duration.orbAdaptation)
                    .repeatForever(autoreverses: true)
                ) {
                    progress = 1.0
                }
            }
        }
    }

    private func drawWave(
        context: GraphicsContext,
        size: CGSize,
        progress: CGFloat,
        phase: Double
    ) {
        let width = size.width
        let midY = size.height * 0.5
        let fadeExp = Theme.CardWave.fadeExponent

        // Interpolate frequency and amplitude between calm and elevated
        let frequency = lerp(
            from: Theme.Wavelength.Frequency.calm,
            to: Theme.Wavelength.Frequency.elevated,
            t: progress
        )
        let amplitude = lerp(
            from: Theme.Wavelength.Amplitude.calm,
            to: Theme.Wavelength.Amplitude.elevated,
            t: progress
        )

        // Interpolate color from calm → elevated
        let calmHex = Theme.Colors.Hex.signalCalm
        let elevatedHex = Theme.Colors.Hex.signalElevated
        let r = lerp(
            from: CGFloat((calmHex >> 16) & 0xFF) / 255.0,
            to: CGFloat((elevatedHex >> 16) & 0xFF) / 255.0,
            t: progress
        )
        let g = lerp(
            from: CGFloat((calmHex >> 8) & 0xFF) / 255.0,
            to: CGFloat((elevatedHex >> 8) & 0xFF) / 255.0,
            t: progress
        )
        let b = lerp(
            from: CGFloat(calmHex & 0xFF) / 255.0,
            to: CGFloat(elevatedHex & 0xFF) / 255.0,
            t: progress
        )
        let waveColor = Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b))

        // Build the path with edge envelope
        let freq = Double(frequency) * 2.0 * .pi * 0.25
        let step: CGFloat = 2.0
        var path = Path()
        var x: CGFloat = 0

        while x <= width {
            let normalizedX = x / width
            let envelope = pow(sin(normalizedX * .pi), fadeExp)
            let y = midY + CGFloat(amplitude) * envelope * sin(normalizedX * freq + phase)

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        // Bloom layer
        var bloomCtx = context
        bloomCtx.addFilter(.blur(radius: Theme.CardWave.Bloom.blurRadius))
        bloomCtx.stroke(
            path,
            with: .color(waveColor.opacity(Theme.CardWave.Bloom.opacity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Bloom.strokeWidth,
                lineCap: .round
            )
        )

        // Crisp layer
        context.stroke(
            path,
            with: .color(waveColor.opacity(Theme.CardWave.Crisp.opacity)),
            style: StrokeStyle(
                lineWidth: Theme.Wavelength.Stroke.standard,
                lineCap: .round
            )
        )
    }

    private func lerp(from a: CGFloat, to b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

// MARK: - Theme.Onboarding Tokens

extension Theme {

    enum Onboarding {

        enum Wave {
            /// Vertical center as fraction of view height.
            static let verticalCenter: Double = 0.5

            /// Visible sine cycles across the width.
            static let cycleCount: Double = 2.0

            /// Wave amplitude as fraction of view height.
            static let amplitudeFraction: CGFloat = 0.08

            /// Phase scroll speed (radians/second) — slower than home cards for subtlety.
            static let scrollSpeed: Double = 0.25

            /// Overall opacity multiplier for background waves.
            static let intensity: Double = 0.6
        }

        enum BinauralMerge {
            /// Vertical spacing between the two ear waves, as fraction of height.
            static let waveSpacing: CGFloat = 0.15

            /// Wave amplitude as fraction of view height.
            static let amplitudeFraction: CGFloat = 0.10

            /// Left ear cycle count (slightly higher frequency).
            static let leftCycles: Double = 2.5

            /// Right ear cycle count (slightly lower frequency).
            static let rightCycles: Double = 3.0

            /// Right ear phase multiplier for visual offset.
            static let rightPhaseMultiplier: Double = 1.1

            /// Perceived beat wave cycle count (much lower — the "difference").
            static let beatCycles: Double = 0.5

            /// Perceived beat amplitude scale relative to ear waves.
            static let beatAmplitudeScale: CGFloat = 1.3

            /// Perceived beat phase speed multiplier.
            static let beatPhaseMultiplier: Double = 0.3

            /// Ear wave intensity (slightly dimmer).
            static let earWaveIntensity: Double = 0.7

            /// Perceived beat wave intensity (brighter — the star).
            static let beatWaveIntensity: Double = 0.5
        }
    }
}

// MARK: - Preview

#Preview("Onboarding Wave Background") {
    ZStack {
        Theme.Colors.canvas
            .ignoresSafeArea()

        OnboardingWaveCanvas()
    }
    .preferredColorScheme(.dark)
}

#Preview("Binaural Wave Merge") {
    ZStack {
        Theme.Colors.canvas
            .ignoresSafeArea()

        BinauralWaveMergeCanvas()
            .frame(height: 200)
    }
    .preferredColorScheme(.dark)
}

#Preview("Adaptive Wavelength") {
    ZStack {
        Theme.Colors.canvas
            .ignoresSafeArea()

        AdaptiveWavelengthCanvas()
            .frame(height: 200)
    }
    .preferredColorScheme(.dark)
}
