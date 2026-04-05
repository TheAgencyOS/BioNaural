// ModeCardWaveCanvas.swift
// BioNaural
//
// Animated sine wave for home screen mode cards. Mirrors the brand identity
// SVG — dual-layer rendering (bloom + crisp), sine-envelope edge fade, and
// mathematically correct cycle counts derived from each mode's Hz range.
// Uses TimelineView + Canvas for butter-smooth animation at 30 FPS.
// Reduce Motion: renders a single static horizontal line at center.

import SwiftUI
import BioNauralShared

// MARK: - ModeCardWaveCanvas

struct ModeCardWaveCanvas: View {

    /// The mode determines cycle count and color.
    let mode: FocusMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived Properties

    private var modeColor: Color { Color.modeColor(for: mode) }

    private var cycleCount: Double {
        switch mode {
        case .sleep:      return Theme.CardWave.Cycles.sleep
        case .relaxation: return Theme.CardWave.Cycles.relaxation
        case .focus:      return Theme.CardWave.Cycles.focus
        case .energize:   return Theme.CardWave.Cycles.energize
        }
    }

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                drawStaticLine(context: context, size: size)
            }
            .allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = time * Theme.CardWave.scrollSpeed
                    drawWave(context: context, size: size, phase: phase)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Wave Renderer

    /// Draws a dual-layer sine wave with edge envelope fade.
    /// Layer 1: Bloom — blurred, lower opacity (the soft glow).
    /// Layer 2: Crisp — sharp, higher opacity (the visible line).
    /// Edge envelope: `sin(normalizedX * pi)` fades both ends to zero.
    private func drawWave(context: GraphicsContext, size: CGSize, phase: Double) {
        let path = buildWavePath(size: size, phase: phase)

        // Layer 1 — Bloom (matches SVG filter="waveSoft")
        var bloomCtx = context
        bloomCtx.addFilter(.blur(radius: Theme.CardWave.Bloom.blurRadius))
        bloomCtx.stroke(
            path,
            with: .color(modeColor.opacity(Theme.CardWave.Bloom.opacity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Bloom.strokeWidth,
                lineCap: .round
            )
        )

        // Layer 2 — Crisp (matches SVG primary stroke)
        context.stroke(
            path,
            with: .color(modeColor.opacity(Theme.CardWave.Crisp.opacity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Crisp.strokeWidth,
                lineCap: .round
            )
        )
    }

    // MARK: - Path Builder

    /// Generates a smooth sine wave path with edge-fade envelope.
    ///
    /// The sine function: `y = amplitude * envelope * sin(x * cycles * 2pi + phase)`
    /// Envelope: `pow(sin(normalizedX * pi), fadeExponent)` — dissolves at edges,
    /// matching the SVG's linearGradient edgeFade (0% → 12% fade-in, 88% → 100% fade-out).
    ///
    /// Sampled every 2px for performance. Catmull-Rom interpolation is unnecessary
    /// at this density — raw `addLine` produces visually smooth curves.
    private func buildWavePath(size: CGSize, phase: Double) -> Path {
        let width = size.width
        let midY = size.height * 0.5
        let amplitude = size.height * Theme.CardWave.amplitudeFraction
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
        let midY = size.height * 0.5
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: size.width, y: midY))

        context.stroke(
            path,
            with: .color(modeColor.opacity(Theme.CardWave.Crisp.opacity)),
            style: StrokeStyle(
                lineWidth: Theme.CardWave.Crisp.strokeWidth,
                lineCap: .round
            )
        )
    }
}

// MARK: - Preview

#Preview("Card Waves — All Modes") {
    VStack(spacing: Theme.Spacing.md) {
        ForEach([FocusMode.sleep, .relaxation, .focus, .energize], id: \.self) { mode in
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)

                ModeCardWaveCanvas(mode: mode)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            }
            .frame(height: 120)
            .overlay(
                Text(mode.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Color.modeColor(for: mode)),
                alignment: .bottomLeading
            )
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }
    .frame(maxHeight: .infinity)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
