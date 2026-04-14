// CompositionWaveShape.swift
// BioNaural
//
// Renders a sinusoidal wave path whose visual frequency and amplitude
// are derived from the composition's actual binaural beat frequency
// and carrier frequency. Each composition card shows a unique wave
// signature that reflects the real sound inside.
//
// The beat frequency controls the number of visible wave cycles
// (higher Hz = tighter, faster-looking waves). The carrier frequency
// modulates the amplitude (higher carrier = slightly brighter/taller).
// A secondary, slower wave is drawn underneath at lower opacity to
// add depth — its frequency is derived from the mode's frequency
// range lower bound.

import SwiftUI
import BioNauralShared

// MARK: - CompositionWaveShape

/// A `Shape` that draws a sine wave whose visual properties map to
/// real audio frequencies from a `CustomComposition`.
struct CompositionWaveShape: Shape {

    /// Binaural beat frequency in Hz. Controls the number of visible
    /// wave cycles across the shape width.
    var beatFrequency: Double

    /// Carrier frequency in Hz. Modulates wave amplitude — higher
    /// carriers produce a slightly taller wave.
    var carrierFrequency: Double

    /// Phase offset in radians. Animatable for scroll effects;
    /// defaults to 0 for static rendering on cards.
    var phaseOffset: Double = 0

    var animatableData: Double {
        get { phaseOffset }
        set { phaseOffset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let midY = height * Theme.Compose.Wave.verticalCenter

        // Map beat frequency to visible cycles.
        // Sleep (1-8 Hz) -> ~0.5-2 cycles = slow, wide waves
        // Focus (12-20 Hz) -> ~3-5 cycles = medium waves
        // Energize (14-30 Hz) -> ~3.5-7 cycles = tight, fast waves
        let cycles = beatFrequency * Theme.Compose.Wave.frequencyToVisualCycles

        // Map carrier frequency to amplitude.
        // Sleep 150 Hz -> lower amplitude, Energize 500 Hz -> higher amplitude.
        // Normalized to a 100-600 Hz range.
        let normalizedCarrier = (carrierFrequency - Theme.Compose.Wave.carrierFloor)
            / (Theme.Compose.Wave.carrierCeiling - Theme.Compose.Wave.carrierFloor)
        let clampedCarrier = min(max(normalizedCarrier, 0), 1)
        let amplitude = height * (Theme.Compose.Wave.amplitudeMin
            + clampedCarrier * (Theme.Compose.Wave.amplitudeMax - Theme.Compose.Wave.amplitudeMin))

        let step = Theme.Compose.Wave.pathStep
        var isFirst = true

        for x in stride(from: 0, through: width, by: step) {
            let normalizedX = x / width
            let angle = normalizedX * cycles * 2 * .pi + phaseOffset
            let y = midY + sin(angle) * amplitude

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - CompositionWaveView

/// Renders a dual-layer wave (bloom + crisp) with edge envelope fade,
/// matching the premium quality of ModeCardWaveCanvas. The primary wave
/// uses the composition's beat frequency; a secondary slower wave adds
/// depth underneath.
struct CompositionWaveView: View {

    let beatFrequency: Double
    let carrierFrequency: Double
    let color: Color
    let secondaryBeat: Double

    /// Initialize from a saved composition.
    init(composition: CustomComposition) {
        let mode = composition.focusMode ?? .focus
        self.beatFrequency = composition.beatFrequency
        self.carrierFrequency = composition.carrierFrequency
        self.color = Color.modeColor(for: mode)
        self.secondaryBeat = mode.frequencyRange.lowerBound
    }

    /// Initialize from raw frequency values and a mode.
    init(mode: FocusMode) {
        self.beatFrequency = mode.defaultBeatFrequency
        self.carrierFrequency = mode.defaultCarrierFrequency
        self.color = Color.modeColor(for: mode)
        self.secondaryBeat = mode.frequencyRange.lowerBound
    }

    var body: some View {

        Canvas { context, size in
            // Build primary path with edge envelope
            let primaryPath = buildEnvelopedPath(
                size: size,
                beatFrequency: beatFrequency,
                carrierFrequency: carrierFrequency
            )

            // Build secondary path (slower, gentler)
            let secondaryPath = buildEnvelopedPath(
                size: size,
                beatFrequency: secondaryBeat,
                carrierFrequency: carrierFrequency * Theme.Compose.Wave.secondaryCarrierRatio
            )

            // Secondary — bloom only (soft background depth)
            var secBloom = context
            secBloom.addFilter(.blur(radius: Theme.Compose.Wave.bloomBlurRadius))
            secBloom.stroke(
                secondaryPath,
                with: .color(color.opacity(Theme.Compose.Wave.secondaryOpacity)),
                style: StrokeStyle(
                    lineWidth: Theme.Compose.Wave.bloomStrokeWidth,
                    lineCap: .round
                )
            )

            // Primary — Layer 1: Bloom (soft glow)
            var bloomCtx = context
            bloomCtx.addFilter(.blur(radius: Theme.Compose.Wave.bloomBlurRadius))
            bloomCtx.stroke(
                primaryPath,
                with: .color(color.opacity(Theme.Compose.Wave.bloomOpacity)),
                style: StrokeStyle(
                    lineWidth: Theme.Compose.Wave.bloomStrokeWidth,
                    lineCap: .round
                )
            )

            // Primary — Layer 2: Crisp (sharp visible line)
            context.stroke(
                primaryPath,
                with: .color(color.opacity(Theme.Compose.Wave.crispOpacity)),
                style: StrokeStyle(
                    lineWidth: Theme.Compose.Wave.crispStrokeWidth,
                    lineCap: .round
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Enveloped Path

    /// Builds a sine wave path with `pow(sin, exponent)` edge envelope,
    /// matching the edge-dissolve technique from ModeCardWaveCanvas.
    private func buildEnvelopedPath(
        size: CGSize,
        beatFrequency: Double,
        carrierFrequency: Double
    ) -> Path {
        let width = size.width
        let midY = size.height * Theme.Compose.Wave.verticalCenter

        let cycles = beatFrequency * Theme.Compose.Wave.frequencyToVisualCycles
        let normalizedCarrier = (carrierFrequency - Theme.Compose.Wave.carrierFloor)
            / (Theme.Compose.Wave.carrierCeiling - Theme.Compose.Wave.carrierFloor)
        let clampedCarrier = min(max(normalizedCarrier, 0), 1)
        let amplitude = size.height * (Theme.Compose.Wave.amplitudeMin
            + clampedCarrier * (Theme.Compose.Wave.amplitudeMax - Theme.Compose.Wave.amplitudeMin))

        let freq = cycles * 2.0 * .pi
        let fadeExp = Theme.Compose.Wave.fadeExponent
        let step = Theme.Compose.Wave.pathStep

        var path = Path()
        var x: CGFloat = 0
        var isFirst = true

        while x <= width {
            let normalizedX = x / width
            let envelope = pow(sin(normalizedX * .pi), fadeExp)
            let y = midY + amplitude * envelope * sin(normalizedX * freq)

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
}

// MARK: - Theme.Compose Tokens

extension Theme {

    enum Compose {

        enum Wave {
            /// How many visible sine cycles per Hz of beat frequency.
            /// At 15 Hz (Focus default), this yields ~3.75 cycles.
            static let frequencyToVisualCycles: Double = 0.25

            /// Vertical center of the wave as a fraction of the view height.
            static let verticalCenter: Double = 0.55

            /// Carrier frequency normalization floor (Hz).
            static let carrierFloor: Double = 100.0

            /// Carrier frequency normalization ceiling (Hz).
            static let carrierCeiling: Double = 600.0

            /// Minimum wave amplitude as a fraction of view height.
            static let amplitudeMin: Double = 0.08

            /// Maximum wave amplitude as a fraction of view height.
            static let amplitudeMax: Double = 0.22

            /// Path drawing step size in points.
            static let pathStep: CGFloat = 2.0

            /// Edge envelope exponent — higher = sharper fade at edges.
            /// Matches ModeCardWaveCanvas.fadeExponent.
            static let fadeExponent: Double = Theme.CardWave.fadeExponent

            /// Bloom layer — soft glow underneath the crisp line.
            static let bloomStrokeWidth: CGFloat = Theme.CardWave.Bloom.strokeWidth
            static let bloomOpacity: Double = Theme.CardWave.Bloom.opacity
            static let bloomBlurRadius: CGFloat = Theme.CardWave.Bloom.blurRadius

            /// Crisp layer — the visible sharp line.
            static let crispStrokeWidth: CGFloat = Theme.CardWave.Crisp.strokeWidth
            static let crispOpacity: Double = Theme.CardWave.Crisp.opacity

            /// Secondary wave opacity (background depth layer).
            static let secondaryOpacity: Double = 0.18

            /// Secondary wave carrier ratio (lower = gentler secondary).
            static let secondaryCarrierRatio: Double = 0.6
        }

        // Card styling uses standard Theme tokens (Radius.card, Opacity.glassFill, etc.)
        // and the .glassEffect modifier via CompositionCardGlassModifier.

        enum Defaults {
            static let brightness: Double = 0.5
            static let density: Double = 0.3
            static let reverbWetDry: Float = 15.0
            static let binauralVolume: Double = 0.0    // opt-in — user raises slider to enable
            static let ambientVolume: Double = 0.20
            static let melodicVolume: Double = 0.79
            static let durationMinutes: Int = 25
            static let filterTolerance: Double = 0.15
            static let reverbMax: Float = 75.0
            static let volumeLabelWidth: CGFloat = 85.0
        }

        enum SpaceLabel {
            static let intimateThreshold: Float = 12.0
            static let roomThreshold: Float = 25.0
            static let hallThreshold: Float = 45.0
            static let cathedralThreshold: Float = 60.0

            static func label(for wetDry: Float) -> String {
                switch wetDry {
                case ..<intimateThreshold: return "Intimate"
                case ..<roomThreshold: return "Room"
                case ..<hallThreshold: return "Hall"
                case ..<cathedralThreshold: return "Cathedral"
                default: return "Vast"
                }
            }
        }

        enum PreviewBadge {
            static let barWidth: CGFloat = 3.0
            static let barSpacing: CGFloat = 2.0
            static let barCornerRadius: CGFloat = 1.0
            static let barHeights: [CGFloat] = [5, 12, 4, 9]
        }

        enum ModeDefaults {
            static func brightness(for mode: FocusMode) -> Double {
                switch mode {
                case .sleep: return 0.15
                case .relaxation: return 0.30
                case .focus: return 0.40
                case .energize: return 0.65
                }
            }
            static func density(for mode: FocusMode) -> Double {
                switch mode {
                case .sleep: return 0.05
                case .relaxation: return 0.20
                case .focus: return 0.30
                case .energize: return 0.45
                }
            }
        }
    }
}
