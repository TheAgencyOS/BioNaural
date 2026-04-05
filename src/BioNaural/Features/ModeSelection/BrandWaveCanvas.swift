// BrandWaveCanvas.swift
// BioNaural
//
// Animated rendering of the brand wave signature — four converging
// sine waves (Sleep, Relaxation, Focus, Energize) with a center
// convergence glow. Mirrors the app icon SVG exactly, but alive.
// The recommended mode's wave glows brighter than the others.
// Uses TimelineView + Canvas for smooth 30 FPS animation.
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - BrandWaveCanvas

struct BrandWaveCanvas: View {

    /// The recommended mode — its wave renders brighter.
    let highlightedMode: FocusMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawStaticWaves(context: context, size: size)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time * Theme.CardWave.AuroraDrift.phaseSpeed
                    drawAnimatedWaves(context: context, size: size, phase: phase)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Animated Waves

    private func drawAnimatedWaves(context: GraphicsContext, size: CGSize, phase: Double) {
        let midY = size.height * Theme.BrandWave.verticalCenter
        let width = size.width

        // Center convergence glow
        drawConvergenceGlow(context: context, size: size)

        // Draw each mode's wave — order matches SVG: Sleep (back), Relaxation, Focus, Energize (front)
        for mode in [FocusMode.sleep, .relaxation, .focus, .energize] {
            let isHighlighted = mode == highlightedMode
            let color = Color.modeColor(for: mode)
            let cycles = waveCycles(for: mode)

            let path = buildWavePath(
                width: width,
                midY: midY,
                amplitude: size.height * Theme.BrandWave.amplitudeFraction,
                cycles: cycles,
                phase: phase
            )

            // Bloom layer (soft glow)
            var bloomCtx = context
            bloomCtx.addFilter(.blur(radius: Theme.CardWave.Bloom.blurRadius))
            bloomCtx.stroke(
                path,
                with: .color(color.opacity(
                    isHighlighted
                        ? Theme.BrandWave.highlightBloomOpacity
                        : Theme.BrandWave.dimBloomOpacity
                )),
                style: StrokeStyle(
                    lineWidth: Theme.CardWave.Bloom.strokeWidth,
                    lineCap: .round
                )
            )

            // Crisp layer (sharp visible line)
            context.stroke(
                path,
                with: .color(color.opacity(
                    isHighlighted
                        ? Theme.BrandWave.highlightCrispOpacity
                        : Theme.BrandWave.dimCrispOpacity
                )),
                style: StrokeStyle(
                    lineWidth: isHighlighted
                        ? Theme.BrandWave.highlightStrokeWidth
                        : Theme.CardWave.Crisp.strokeWidth,
                    lineCap: .round
                )
            )
        }
    }

    // MARK: - Static Waves (Reduce Motion)

    private func drawStaticWaves(context: GraphicsContext, size: CGSize) {
        let midY = size.height * Theme.BrandWave.verticalCenter
        let width = size.width

        drawConvergenceGlow(context: context, size: size)

        for mode in [FocusMode.sleep, .relaxation, .focus, .energize] {
            let isHighlighted = mode == highlightedMode
            let color = Color.modeColor(for: mode)
            let cycles = waveCycles(for: mode)

            let path = buildWavePath(
                width: width,
                midY: midY,
                amplitude: size.height * Theme.BrandWave.amplitudeFraction,
                cycles: cycles,
                phase: 0
            )

            context.stroke(
                path,
                with: .color(color.opacity(
                    isHighlighted
                        ? Theme.BrandWave.highlightCrispOpacity
                        : Theme.BrandWave.dimCrispOpacity
                )),
                style: StrokeStyle(
                    lineWidth: isHighlighted
                        ? Theme.BrandWave.highlightStrokeWidth
                        : Theme.CardWave.Crisp.strokeWidth,
                    lineCap: .round
                )
            )
        }
    }

    // MARK: - Convergence Glow

    private func drawConvergenceGlow(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * Theme.BrandWave.verticalCenter)
        let radius = size.width * Theme.BrandWave.convergenceRadiusFraction

        let gradient = Gradient(colors: [
            Color(hex: Theme.BrandWave.convergenceColorHex).opacity(Theme.BrandWave.convergenceOpacity),
            Color.clear,
        ])

        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.fill(
            Ellipse().path(in: rect),
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
        )
    }

    // MARK: - Wave Path

    /// Builds a sine wave path with edge-envelope fade matching the brand SVG.
    private func buildWavePath(
        width: CGFloat,
        midY: CGFloat,
        amplitude: CGFloat,
        cycles: Double,
        phase: Double
    ) -> Path {
        let freq = cycles * 2.0 * .pi
        let fadeExp = Theme.BrandWave.fadeExponent
        let step = Theme.Compose.Wave.pathStep

        var path = Path()
        var x: CGFloat = 0
        var isFirst = true

        while x <= width {
            let normalizedX = x / width
            let envelope = pow(sin(normalizedX * .pi), fadeExp)
            let y = midY + amplitude * envelope * sin(normalizedX * freq + phase)

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        return path
    }

    // MARK: - Wave Cycles

    /// Maps mode to visible cycle count — matches the SVG's relative frequencies.
    private func waveCycles(for mode: FocusMode) -> Double {
        switch mode {
        case .sleep:      return Theme.BrandWave.Cycles.sleep
        case .relaxation: return Theme.BrandWave.Cycles.relaxation
        case .focus:      return Theme.BrandWave.Cycles.focus
        case .energize:   return Theme.BrandWave.Cycles.energize
        }
    }
}

// MARK: - Theme.BrandWave Tokens

extension Theme {

    enum BrandWave {

        /// Vertical center as fraction of view height.
        static let verticalCenter: Double = 0.5

        /// Wave amplitude as fraction of view height.
        static let amplitudeFraction: CGFloat = 0.15

        /// Edge-fade exponent (higher = sharper dissolve at edges).
        static let fadeExponent: Double = 1.2

        /// Highlighted mode — bloom opacity (brighter).
        static let highlightBloomOpacity: Double = 0.45

        /// Dim modes — bloom opacity.
        static let dimBloomOpacity: Double = 0.15

        /// Highlighted mode — crisp line opacity.
        static let highlightCrispOpacity: Double = 0.70

        /// Dim modes — crisp line opacity.
        static let dimCrispOpacity: Double = 0.30

        /// Highlighted mode — stroke width (thicker).
        static let highlightStrokeWidth: CGFloat = 2.5

        /// Center convergence glow radius as fraction of width.
        static let convergenceRadiusFraction: CGFloat = 0.25

        /// Center convergence glow color (near-white with blue tint, from SVG).
        static let convergenceColorHex: String = "E8EAFF"

        /// Center convergence glow opacity.
        static let convergenceOpacity: Double = 0.08

        /// Wave cycle counts matching the SVG's relative frequencies.
        /// Sleep = slowest/widest, Energize = tightest/fastest.
        enum Cycles {
            static let sleep: Double = 1.0
            static let relaxation: Double = 1.5
            static let focus: Double = 2.5
            static let energize: Double = 5.0
        }
    }
}
