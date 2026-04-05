// NebulaBokehBackground.swift
// BioNaural
//
// Full-screen background layer with four large out-of-focus color orbs
// representing each mode (Sleep, Relaxation, Focus, Energize) plus film
// grain texture. Creates depth and brand presence — all four modes are
// always subtly present behind the UI.
// Reduce Motion: static canvas with no grain animation.

import SwiftUI
import BioNauralShared

// MARK: - NebulaBokehBackground

struct NebulaBokehBackground: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Base canvas
            Theme.Colors.canvas

            // Deep bokeh — furthest layer, most blurred, largest
            // Sleep — upper left
            bokehOrb(
                color: Theme.Colors.sleep,
                size: Theme.Nebula.deepSize,
                blur: Theme.Nebula.deepBlur,
                opacity: Theme.Nebula.deepOpacity,
                x: Theme.Nebula.Sleep.x,
                y: Theme.Nebula.Sleep.y
            )

            // Energize — lower right
            bokehOrb(
                color: Theme.Colors.energize,
                size: Theme.Nebula.deepSize * Theme.Nebula.Energize.sizeRatio,
                blur: Theme.Nebula.deepBlur * 0.9,
                opacity: Theme.Nebula.deepOpacity * 0.8,
                x: Theme.Nebula.Energize.x,
                y: Theme.Nebula.Energize.y
            )

            // Mid bokeh — middle depth
            // Focus — center-left
            bokehOrb(
                color: Theme.Colors.focus,
                size: Theme.Nebula.midSize,
                blur: Theme.Nebula.midBlur,
                opacity: Theme.Nebula.midOpacity,
                x: Theme.Nebula.Focus.x,
                y: Theme.Nebula.Focus.y
            )

            // Relaxation — upper right
            bokehOrb(
                color: Theme.Colors.relaxation,
                size: Theme.Nebula.midSize * Theme.Nebula.Relaxation.sizeRatio,
                blur: Theme.Nebula.midBlur * 0.85,
                opacity: Theme.Nebula.midOpacity * 0.9,
                x: Theme.Nebula.Relaxation.x,
                y: Theme.Nebula.Relaxation.y
            )

            // Near bokeh — closest, sharpest, smallest
            // Accent convergence — center
            bokehOrb(
                color: Theme.Colors.accent,
                size: Theme.Nebula.nearSize,
                blur: Theme.Nebula.nearBlur,
                opacity: Theme.Nebula.nearOpacity,
                x: Theme.Nebula.Accent.x,
                y: Theme.Nebula.Accent.y
            )

            // Film grain
            if !reduceMotion {
                grainOverlay
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bokeh Orb

    private func bokehOrb(
        color: Color,
        size: CGFloat,
        blur: CGFloat,
        opacity: Double,
        x: CGFloat,
        y: CGFloat
    ) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: blur)
                .opacity(opacity)
                .position(
                    x: geo.size.width * x,
                    y: geo.size.height * y
                )
        }
    }

    // MARK: - Grain Overlay

    private var grainOverlay: some View {
        Canvas { context, size in
            // Render a subtle noise pattern using randomized small rects.
            // This is a static grain — not animated — for minimal CPU cost.
            let step: CGFloat = 4
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    // Deterministic pseudo-random based on position
                    let hash = (x * 374761393 + y * 668265263).truncatingRemainder(dividingBy: 1000) / 1000
                    let brightness = hash * 0.08
                    let rect = CGRect(x: x, y: y, width: step, height: step)
                    context.opacity = brightness
                    context.fill(
                        Path(rect),
                        with: .color(.white)
                    )
                }
            }
        }
        .blendMode(.overlay)
        .opacity(Theme.Nebula.grainOpacity)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("Nebula Bokeh Background") {
    ZStack {
        NebulaBokehBackground()
        Text("BioNaural")
            .font(.largeTitle)
            .foregroundStyle(.white)
    }
}
