// AdaptationMapView.swift
// BioNaural
//
// Canvas visualization of a session's adaptation history. Renders a horizontal
// bar showing beat frequency changes over time, with a smooth color gradient
// flowing from cool (calm) through warm (peak) using the biometric signal
// palette. Used in post-session review and shareable maps.

import SwiftUI
import BioNauralShared

// MARK: - AdaptationMapView

struct AdaptationMapView: View {

    // MARK: - Inputs

    /// Ordered adaptation events from the session.
    let events: [AdaptationEventRecord]

    /// Total session duration in seconds.
    let sessionDuration: TimeInterval

    /// The session mode (determines frequency range for normalization).
    let mode: FocusMode

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            guard !events.isEmpty, sessionDuration > 0 else {
                drawEmptyBar(context: &context, size: size)
                return
            }

            drawAdaptationBar(context: &context, size: size)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .accessibilityLabel("Adaptation map showing \(events.count) frequency changes over \(formattedDuration)")
    }

    // MARK: - Drawing

    private func drawAdaptationBar(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let barHeight = size.height
        let barWidth = size.width
        let freqRange = mode.frequencyRange

        // Draw each segment as a smooth gradient between its frequency
        // and the next event's frequency. This creates a continuous
        // color flow rather than hard-edged blocks.
        for i in 0..<events.count {
            let event = events[i]
            let nextTimestamp: TimeInterval
            let nextFrequency: Double

            if i + 1 < events.count {
                nextTimestamp = events[i + 1].timestamp
                nextFrequency = events[i + 1].newBeatFrequency
            } else {
                nextTimestamp = sessionDuration
                nextFrequency = event.newBeatFrequency
            }

            let xStart = CGFloat(event.timestamp / sessionDuration) * barWidth
            let xEnd = CGFloat(nextTimestamp / sessionDuration) * barWidth
            let segmentWidth = max(xEnd - xStart, 1)

            // Normalize both endpoints for gradient interpolation.
            let normalizedStart = normalizeFrequency(
                event.newBeatFrequency,
                range: freqRange
            )
            let normalizedEnd = normalizeFrequency(
                nextFrequency,
                range: freqRange
            )

            let startColor = colorForNormalizedValue(normalizedStart)
            let endColor = colorForNormalizedValue(normalizedEnd)

            let segmentRect = CGRect(
                x: xStart,
                y: 0,
                width: segmentWidth,
                height: barHeight
            )

            // Draw a horizontal gradient for smooth inter-segment transitions.
            context.fill(
                Rectangle().path(in: segmentRect),
                with: .linearGradient(
                    Gradient(colors: [startColor, endColor]),
                    startPoint: CGPoint(x: segmentRect.minX, y: barHeight * Theme.Opacity.half),
                    endPoint: CGPoint(x: segmentRect.maxX, y: barHeight * Theme.Opacity.half)
                )
            )

            // Top highlight — a subtle lighter line along the top edge
            // for depth and polish.
            let highlightRect = CGRect(
                x: xStart,
                y: 0,
                width: segmentWidth,
                height: highlightHeight
            )
            context.fill(
                Rectangle().path(in: highlightRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(Theme.Opacity.light),
                        Color.white.opacity(Theme.Opacity.transparent)
                    ]),
                    startPoint: CGPoint(x: highlightRect.midX, y: 0),
                    endPoint: CGPoint(x: highlightRect.midX, y: highlightRect.maxY)
                )
            )
        }
    }

    private func drawEmptyBar(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .path(in: rect),
            with: .color(Theme.Colors.surface.opacity(Theme.Opacity.half))
        )
    }

    // MARK: - Helpers

    /// Normalizes a beat frequency to [0, 1] within the mode's frequency range.
    private func normalizeFrequency(
        _ frequency: Double,
        range: ClosedRange<Double>
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((frequency - range.lowerBound) / span, 0), 1)
    }

    /// Maps a normalized [0, 1] value through the biometric signal colors
    /// using smooth interpolation. The four signal colors represent:
    /// 0.0 = calm (teal), 0.33 = focus (periwinkle), 0.66 = elevated (amber),
    /// 1.0 = peak (coral).
    ///
    /// Values between stops are linearly interpolated for a continuous
    /// gradient rather than hard color bands.
    private func colorForNormalizedValue(_ value: Double) -> Color {
        // Define color stops using Theme biometric signal colors.
        let stops: [(position: Double, color: Color)] = [
            (0.0, Theme.Colors.signalCalm),
            (0.33, Theme.Colors.signalFocus),
            (0.66, Theme.Colors.signalElevated),
            (1.0, Theme.Colors.signalPeak)
        ]

        // Clamp value.
        let clamped = min(max(value, 0), 1)

        // Find the two surrounding stops.
        guard let firstStop = stops.first, let lastStop = stops.last else {
            return Theme.Colors.signalCalm
        }
        var lower = firstStop
        var upper = lastStop

        for j in 0..<(stops.count - 1) {
            if clamped >= stops[j].position && clamped <= stops[j + 1].position {
                lower = stops[j]
                upper = stops[j + 1]
                break
            }
        }

        // Interpolation factor within the segment.
        let span = upper.position - lower.position
        let t = span > 0 ? (clamped - lower.position) / span : 0

        // Blend between the two stop colors.
        return blendColors(lower.color, upper.color, t: t)
    }

    /// Linearly blends two SwiftUI Colors by factor `t` (0 = from, 1 = to).
    private func blendColors(_ from: Color, _ to: Color, t: Double) -> Color {
        let clamped = min(max(t, 0), 1)

        // Resolve both colors in the standard sRGB space.
        let fromResolved = UIColor(from).cgColor.components ?? [0, 0, 0, 1]
        let toResolved = UIColor(to).cgColor.components ?? [0, 0, 0, 1]

        // Ensure we have at least 4 components (RGBA).
        guard fromResolved.count >= 4, toResolved.count >= 4 else {
            return clamped < 0.5 ? from : to
        }

        let r = fromResolved[0] + (toResolved[0] - fromResolved[0]) * clamped
        let g = fromResolved[1] + (toResolved[1] - fromResolved[1]) * clamped
        let b = fromResolved[2] + (toResolved[2] - fromResolved[2]) * clamped
        let a = fromResolved[3] + (toResolved[3] - fromResolved[3]) * clamped

        return Color(red: r, green: g, blue: b, opacity: a)
    }

    /// Formatted session duration for the accessibility label.
    private var formattedDuration: String {
        let minutes = Int(sessionDuration / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    // MARK: - Layout Constants

    /// Height of the top-edge highlight gradient for subtle depth.
    private var highlightHeight: CGFloat {
        Theme.Spacing.xxs
    }
}

// MARK: - AdaptationMapView + Glass Card Wrapper

extension AdaptationMapView {

    /// Wraps the adaptation map in a glass card container suitable for
    /// use in PostSessionView or any elevated context.
    func glassCardWrapped(height: CGFloat = defaultMapHeight) -> some View {
        self
            .frame(height: height)
            .padding(Theme.Spacing.md)
            .glassCard()
    }

    /// Default map bar height when displayed in a card.
    private static var defaultMapHeight: CGFloat {
        Theme.Spacing.xxxl + Theme.Spacing.sm
    }
}

// MARK: - Preview

#Preview("AdaptationMapView") {
    let sampleEvents: [AdaptationEventRecord] = [
        .init(timestamp: 0, reason: "Start", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 72),
        .init(timestamp: 300, reason: "HR rising", oldBeatFrequency: 14, newBeatFrequency: 12, heartRateAtTime: 82),
        .init(timestamp: 600, reason: "HR stable", oldBeatFrequency: 12, newBeatFrequency: 15, heartRateAtTime: 75),
        .init(timestamp: 900, reason: "HR calm", oldBeatFrequency: 15, newBeatFrequency: 16, heartRateAtTime: 68),
    ]

    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        VStack(spacing: Theme.Spacing.xxl) {
            // Standalone usage.
            AdaptationMapView(
                events: sampleEvents,
                sessionDuration: 1500,
                mode: .focus
            )
            .frame(height: 40)
            .padding(.horizontal, Theme.Spacing.pageMargin)

            // Glass card wrapped usage (PostSessionView style).
            AdaptationMapView(
                events: sampleEvents,
                sessionDuration: 1500,
                mode: .focus
            )
            .glassCardWrapped()
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }
}
