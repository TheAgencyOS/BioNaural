// WavelengthView.swift
// BioNaural
//
// The live biometric signal line — a smooth sinusoidal path that
// scrolls edge-to-edge through the center of the session screen.
// Uses SwiftUI Canvas with Catmull-Rom to Bezier interpolation for
// a fluid, organic feel. Gaussian blur applied for soft-light look.
// Reduce Motion: static horizontal line at center.

import SwiftUI
import BioNauralShared

// MARK: - WavelengthView

struct WavelengthView: View {

    // MARK: - Inputs

    /// Current biometric state (drives amplitude, color, opacity).
    let biometricState: BiometricState

    /// Current session mode (Energize uses bolder treatment).
    let sessionMode: FocusMode

    /// Current binaural beat frequency (Hz) — drives visible cycle count.
    /// When > 0, the wave cycle count is derived mathematically from the
    /// live beat frequency. When 0, falls back to biometric-state defaults.
    let beatFrequency: Double

    /// Whether audio is playing (paused = frozen wave).
    let isPlaying: Bool

    /// Optional color override. When set, this color is used instead of
    /// the biometric-state-derived color. Used to give each audio layer
    /// (Ambient, Melodic, Binaural) its own distinct color.
    var layerColor: Color? = nil

    /// Compact mode — uses reduced amplitude and stroke for mini player rendering.
    var isCompact: Bool = false

    // MARK: - Internal State

    @State private var scrollOffset: CGFloat = 0
    @State private var displayLink: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2

            if reduceMotion {
                drawStaticLine(context: &context, size: size, midY: midY)
            } else {
                drawSineWave(context: &context, size: size, midY: midY)
            }
        }
        .blur(radius: isCompact ? Theme.Wavelength.compactBlurRadius : Theme.Wavelength.blurRadius)
        .onAppear { startScrolling() }
        .onDisappear { stopScrolling() }
        .onChange(of: isPlaying) { _, playing in
            if playing { startScrolling() } else { stopScrolling() }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sine Wave Drawing

    private func drawSineWave(
        context: inout GraphicsContext,
        size: CGSize,
        midY: CGFloat
    ) {
        let amplitude = waveAmplitude
        let cycleCount = waveCycleCount
        let width = size.width

        // Generate sample points along the width.
        let sampleCount = Int(width / 2)
        guard sampleCount > 2 else { return }

        var points: [CGPoint] = []
        for i in 0...sampleCount {
            let x = CGFloat(i) / CGFloat(sampleCount) * width
            let normalizedX = (x + scrollOffset) / width * cycleCount * 2 * .pi
            let y = midY + sin(normalizedX) * amplitude
            points.append(CGPoint(x: x, y: y))
        }

        // Build a smooth path using Catmull-Rom to Bezier conversion.
        let path = catmullRomPath(through: points)

        context.stroke(
            path,
            with: .color(waveColor.opacity(waveOpacity)),
            lineWidth: waveStrokeWidth
        )
    }

    // MARK: - Static Line (Reduce Motion)

    private func drawStaticLine(
        context: inout GraphicsContext,
        size: CGSize,
        midY: CGFloat
    ) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: size.width, y: midY))

        context.stroke(
            path,
            with: .color(waveColor.opacity(waveOpacity)),
            lineWidth: waveStrokeWidth
        )
    }

    // MARK: - Catmull-Rom to Bezier

    /// Converts a sequence of points into a smooth Bezier path using
    /// Catmull-Rom spline interpolation.
    private func catmullRomPath(through points: [CGPoint]) -> Path {
        guard points.count >= 4 else {
            // Fallback: simple line through all points.
            var path = Path()
            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            return path
        }

        var path = Path()
        path.move(to: points[0])

        let alpha: CGFloat = 0.5 // Centripetal Catmull-Rom

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            let d1 = distance(p0, p1)
            let d2 = distance(p1, p2)
            let d3 = distance(p2, p3)

            let safeD1 = max(d1, 0.001)
            let safeD2 = max(d2, 0.001)
            let safeD3 = max(d3, 0.001)

            let b1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / (6 * pow(safeD1, alpha) / pow(safeD2, alpha) + 3),
                y: p1.y + (p2.y - p0.y) / (6 * pow(safeD1, alpha) / pow(safeD2, alpha) + 3)
            )
            let b2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / (6 * pow(safeD3, alpha) / pow(safeD2, alpha) + 3),
                y: p2.y - (p3.y - p1.y) / (6 * pow(safeD3, alpha) / pow(safeD2, alpha) + 3)
            )

            path.addCurve(to: p2, control1: b1, control2: b2)
        }

        return path
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Scroll Control

    private func startScrolling() {
        guard !reduceMotion else { return }
        stopScrolling()
        let interval: TimeInterval = 1.0 / Theme.Wavelength.frameRate
        displayLink = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            scrollOffset += Theme.Animation.Duration.waveScrollSpeed * CGFloat(interval)
        }
    }

    private func stopScrolling() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Theme-Driven Properties

    private var waveColor: Color {
        layerColor ?? Color.biometricColor(for: biometricState)
    }

    private var waveAmplitude: CGFloat {
        if isCompact {
            if sessionMode == .energize {
                return Theme.Wavelength.Amplitude.Compact.energize
            }
            switch biometricState {
            case .calm:     return Theme.Wavelength.Amplitude.Compact.calm
            case .focused:  return Theme.Wavelength.Amplitude.Compact.focused
            case .elevated: return Theme.Wavelength.Amplitude.Compact.elevated
            case .peak:     return Theme.Wavelength.Amplitude.Compact.peak
            }
        }
        if sessionMode == .energize {
            return Theme.Wavelength.Amplitude.energize
        }
        switch biometricState {
        case .calm:     return Theme.Wavelength.Amplitude.calm
        case .focused:  return Theme.Wavelength.Amplitude.focused
        case .elevated: return Theme.Wavelength.Amplitude.elevated
        case .peak:     return Theme.Wavelength.Amplitude.peak
        }
    }

    /// Derives visible wave cycle count from the live beat frequency.
    /// `cycleCount = beatFrequency / scaleFactor`, clamped to visible range.
    /// Falls back to biometric-state defaults when no frequency data.
    private var waveCycleCount: CGFloat {
        guard beatFrequency > 0 else {
            // Fallback to static defaults
            if sessionMode == .energize {
                return Theme.Wavelength.Frequency.energize
            }
            switch biometricState {
            case .calm:     return Theme.Wavelength.Frequency.calm
            case .focused:  return Theme.Wavelength.Frequency.focused
            case .elevated: return Theme.Wavelength.Frequency.elevated
            case .peak:     return Theme.Wavelength.Frequency.peak
            }
        }

        let raw = CGFloat(beatFrequency / Theme.Animation.FrequencySync.waveScaleFactor)
        return min(
            Theme.Animation.FrequencySync.waveCycleCountMax,
            max(Theme.Animation.FrequencySync.waveCycleCountMin, raw)
        )
    }

    private var waveOpacity: Double {
        if sessionMode == .energize {
            return Theme.Wavelength.StateOpacity.energize
        }
        switch biometricState {
        case .calm:     return Theme.Wavelength.StateOpacity.calm
        case .focused:  return Theme.Wavelength.StateOpacity.focused
        case .elevated: return Theme.Wavelength.StateOpacity.elevated
        case .peak:     return Theme.Wavelength.StateOpacity.peak
        }
    }

    private var waveStrokeWidth: CGFloat {
        if isCompact {
            return Theme.Wavelength.Stroke.compact
        }
        if sessionMode == .energize {
            return Theme.Wavelength.Stroke.energize
        }
        switch biometricState {
        case .calm, .focused:     return Theme.Wavelength.Stroke.standard
        case .elevated, .peak:    return Theme.Wavelength.Stroke.elevated
        }
    }
}

// MARK: - Preview

#Preview("WavelengthView - Focus 15 Hz") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        WavelengthView(
            biometricState: .focused,
            sessionMode: .focus,
            beatFrequency: 15.0,
            isPlaying: true
        )
        .frame(height: 100)
    }
}

#Preview("WavelengthView - Sleep 4 Hz") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        WavelengthView(
            biometricState: .calm,
            sessionMode: .sleep,
            beatFrequency: 4.0,
            isPlaying: true
        )
        .frame(height: 100)
    }
}

#Preview("WavelengthView - Energize 22 Hz") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        WavelengthView(
            biometricState: .elevated,
            sessionMode: .energize,
            beatFrequency: 22.0,
            isPlaying: true
        )
        .frame(height: 100)
    }
}
