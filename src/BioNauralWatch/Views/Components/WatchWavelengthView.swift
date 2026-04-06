// WatchWavelengthView.swift
// BioNauralWatch
//
// Dual-layer wavelength matching the iPhone carousel card wave style.
// Renders a bloom layer (soft glow) underneath a crisp layer (sharp line)
// for the signature BioNaural card-wave look. Uses Catmull-Rom spline
// interpolation and sine-based edge envelope fading.

import SwiftUI
import BioNauralShared

// MARK: - WatchWavelengthView

struct WatchWavelengthView: View {

    // MARK: - Inputs

    /// Current biometric state (drives amplitude, opacity, color).
    let biometricState: BiometricState

    /// Current session mode (affects stroke width, cycle count, and color).
    let sessionMode: FocusMode

    /// Live binaural beat frequency (Hz). When > 0, derives visible cycle count.
    /// When 0, uses mode-locked cycle counts from the card wave spec.
    let beatFrequency: Double

    /// Whether audio is playing. Paused = frozen scroll.
    let isPlaying: Bool

    // MARK: - Internal State

    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            // Bloom layer — soft glow behind the crisp line
            Canvas { context, size in
                let midY = size.height / 2
                if reduceMotion {
                    drawStaticLine(context: &context, size: size, midY: midY,
                                   strokeWidth: WatchDesign.Wavelength.Bloom.strokeWidth,
                                   opacity: WatchDesign.Wavelength.Bloom.opacity)
                } else {
                    drawSineWave(context: &context, size: size, midY: midY,
                                 strokeWidth: WatchDesign.Wavelength.Bloom.strokeWidth,
                                 opacity: WatchDesign.Wavelength.Bloom.opacity)
                }
            }
            .blur(radius: WatchDesign.Wavelength.Bloom.blurRadius)

            // Crisp layer — sharp line on top
            Canvas { context, size in
                let midY = size.height / 2
                if reduceMotion {
                    drawStaticLine(context: &context, size: size, midY: midY,
                                   strokeWidth: crispStrokeWidth,
                                   opacity: crispOpacity)
                } else {
                    drawSineWave(context: &context, size: size, midY: midY,
                                 strokeWidth: crispStrokeWidth,
                                 opacity: crispOpacity)
                }
            }
        }
        .frame(height: WatchDesign.Wavelength.height)
        .onAppear { startScrolling() }
        .onDisappear { stopScrolling() }
        .onChange(of: isPlaying) { _, playing in
            if playing { startScrolling() } else { stopScrolling() }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sine Wave Drawing (with edge envelope)

    private func drawSineWave(
        context: inout GraphicsContext,
        size: CGSize,
        midY: CGFloat,
        strokeWidth: CGFloat,
        opacity: Double
    ) {
        let amplitude = waveAmplitude
        let cycleCount = waveCycleCount
        let width = size.width
        let sampleCount = Int(width / WatchDesign.Wavelength.sampleDensity)
        guard sampleCount > 2 else { return }

        var points: [CGPoint] = []
        for i in 0...sampleCount {
            let x = CGFloat(i) / CGFloat(sampleCount) * width
            let normalizedX = (x + scrollOffset) / width * cycleCount * 2 * .pi

            // Sine-based edge envelope: sin(position * pi)^exponent
            let position = CGFloat(i) / CGFloat(sampleCount)
            let envelope = pow(sin(position * .pi), WatchDesign.Wavelength.edgeFadeExponent)

            let y = midY + sin(normalizedX) * amplitude * envelope
            points.append(CGPoint(x: x, y: y))
        }

        let path = catmullRomPath(through: points)

        context.stroke(
            path,
            with: .color(waveColor.opacity(opacity)),
            lineWidth: strokeWidth
        )
    }

    // MARK: - Static Line (Reduce Motion)

    private func drawStaticLine(
        context: inout GraphicsContext,
        size: CGSize,
        midY: CGFloat,
        strokeWidth: CGFloat,
        opacity: Double
    ) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: size.width, y: midY))

        context.stroke(
            path,
            with: .color(waveColor.opacity(opacity)),
            lineWidth: strokeWidth
        )
    }

    // MARK: - Catmull-Rom to Bezier

    private func catmullRomPath(through points: [CGPoint]) -> Path {
        guard points.count >= 4 else {
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

        let alpha = WatchDesign.Wavelength.catmullRomAlpha

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
        let interval: TimeInterval = 1.0 / WatchDesign.Wavelength.frameRate
        scrollTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            MainActor.assumeIsolated { [self] in
                scrollOffset += WatchDesign.Wavelength.scrollSpeed * CGFloat(interval)
            }
        }
    }

    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    // MARK: - Design-Token-Driven Properties

    /// Wave color: mode color, shifting toward signal color when elevated/peak.
    private var waveColor: Color {
        let modeColor = WatchDesign.Colors.modeColor(for: sessionMode)
        let signalColor = WatchDesign.Colors.signalColor(for: biometricState)

        switch biometricState {
        case .calm, .focused:
            return modeColor
        case .elevated:
            return blendColors(modeColor, signalColor, ratio: WatchDesign.Wavelength.BlendRatio.elevated)
        case .peak:
            return blendColors(modeColor, signalColor, ratio: WatchDesign.Wavelength.BlendRatio.peak)
        }
    }

    private func blendColors(_ c1: Color, _ c2: Color, ratio: CGFloat) -> Color {
        let env = EnvironmentValues()
        let r1 = c1.resolve(in: env)
        let r2 = c2.resolve(in: env)
        return Color(
            red: Double(r1.red + (r2.red - r1.red) * Float(ratio)),
            green: Double(r1.green + (r2.green - r1.green) * Float(ratio)),
            blue: Double(r1.blue + (r2.blue - r1.blue) * Float(ratio))
        )
    }

    /// Wave amplitude based on biometric state.
    private var waveAmplitude: CGFloat {
        if sessionMode == .sleep && biometricState == .calm {
            return WatchDesign.Wavelength.Amplitude.sleepDeep
        }
        switch biometricState {
        case .calm:     return WatchDesign.Wavelength.Amplitude.calm
        case .focused:  return WatchDesign.Wavelength.Amplitude.focused
        case .elevated: return WatchDesign.Wavelength.Amplitude.elevated
        case .peak:     return WatchDesign.Wavelength.Amplitude.peak
        }
    }

    /// Visible wave cycle count: mode-locked (card style) when no live frequency,
    /// or derived from beat frequency when available.
    private var waveCycleCount: CGFloat {
        if beatFrequency > 0 {
            let raw = CGFloat(beatFrequency / WatchDesign.Wavelength.BeatToCycle.divisor)
            return min(WatchDesign.Wavelength.BeatToCycle.max, max(WatchDesign.Wavelength.BeatToCycle.min, raw))
        }

        // Mode-locked cycle counts matching carousel card wave densities
        switch sessionMode {
        case .sleep:       return WatchDesign.Wavelength.ModeCycles.sleep
        case .relaxation:  return WatchDesign.Wavelength.ModeCycles.relaxation
        case .focus:       return WatchDesign.Wavelength.ModeCycles.focus
        case .energize:    return WatchDesign.Wavelength.ModeCycles.energize
        }
    }

    /// Crisp layer stroke width varies by mode and biometric state.
    private var crispStrokeWidth: CGFloat {
        if sessionMode == .energize {
            return WatchDesign.Wavelength.Stroke.energize
        }
        if sessionMode == .sleep {
            return WatchDesign.Wavelength.Stroke.sleep
        }
        switch biometricState {
        case .calm, .focused:
            return WatchDesign.Wavelength.Crisp.strokeWidth
        case .elevated, .peak:
            return WatchDesign.Wavelength.Crisp.highlightedStrokeWidth
        }
    }

    /// Crisp layer opacity by biometric state and mode.
    private var crispOpacity: Double {
        if sessionMode == .energize {
            return WatchDesign.Wavelength.WaveOpacity.energize
        }
        if sessionMode == .sleep {
            return WatchDesign.Wavelength.WaveOpacity.sleep
        }
        switch biometricState {
        case .calm:     return WatchDesign.Wavelength.WaveOpacity.calm
        case .focused:  return WatchDesign.Wavelength.WaveOpacity.focused
        case .elevated: return WatchDesign.Wavelength.WaveOpacity.elevated
        case .peak:     return WatchDesign.Wavelength.WaveOpacity.peak
        }
    }
}
