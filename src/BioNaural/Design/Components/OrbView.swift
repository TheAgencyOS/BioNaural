// OrbView.swift
// BioNaural
//
// The breathing Orb — a Canvas-based radial gradient bloom that serves as the
// central visual element during sessions. Color shifts per BiometricState,
// breathing animation synced to beat frequency, and an Energize mode with
// rising particles, warm corona, and amber-gold shimmer.
// Reduce Motion: static gradient, no animation.

import SwiftUI
import BioNauralShared
import Vortex
#if canImport(GlowGetter)
import GlowGetter
#endif

// MARK: - OrbView

struct OrbView: View {

    // MARK: - Inputs

    /// Current biometric activation state (drives color and pulse speed).
    let biometricState: BiometricState

    /// Current session mode (determines Energize visual treatment).
    let sessionMode: FocusMode

    /// Current binaural beat frequency — modulates breathing speed.
    let beatFrequency: Double

    /// Whether audio is actively playing (paused orb holds still).
    let isPlaying: Bool

    // MARK: - Internal State

    @State private var breathingPhase: Bool = false
    @State private var shimmerPhase: Bool = false
    @State private var coronaPhase: Bool = false
    @State private var sessionStart: Date = .now
    @State private var pendingRestartWork: DispatchWorkItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let orbDiameter = size * orbSizeFraction

            ZStack {
                if isEnergize && !reduceMotion {
                    coronaLayer(diameter: orbDiameter)
                }

                // Ambient particle halo (Vortex) — behind the orb
                if isPlaying && !reduceMotion {
                    vortexParticleLayer(diameter: orbDiameter)
                }

                orbCanvas(diameter: orbDiameter)
                    .hdrGlow(intensity: isEnergize
                        ? Theme.HDRGlow.energizeIntensity
                        : Theme.HDRGlow.orbIntensity)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { startAnimations() }
        .onChange(of: isPlaying) { _, playing in
            if playing { startAnimations() }
        }
        .onChange(of: biometricState) { _, _ in restartBreathing() }
        .onChange(of: sessionMode) { _, _ in restartBreathing() }
        .onChange(of: beatFrequency) { _, _ in restartBreathing() }
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Main Orb Canvas

    @ViewBuilder
    private func orbCanvas(diameter: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = diameter / 2

            let gradient = Gradient(colors: [
                orbColor,
                orbColor.opacity(Theme.Opacity.transparent)
            ])
            let shading = GraphicsContext.Shading.radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: radius
            )

            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: diameter,
                height: diameter
            )
            context.fill(Ellipse().path(in: rect), with: shading)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(reduceMotion ? 1.0 : breathingScale)
        .opacity(orbOpacity)
        .animation(reduceMotion ? nil : breathingAnimation, value: breathingPhase)
    }

    // MARK: - Corona Layer (Energize)

    @ViewBuilder
    private func coronaLayer(diameter: CGFloat) -> some View {
        let coronaDiameter = diameter * Theme.Orb.Energize.coronaScaleMax

        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = coronaDiameter / 2

            let gradient = Gradient(colors: [
                Theme.Colors.energize.opacity(Theme.Orb.Energize.coronaOpacityMultiplier),
                Theme.Colors.energize.opacity(Theme.Opacity.transparent)
            ])
            let shading = GraphicsContext.Shading.radialGradient(
                gradient,
                center: center,
                startRadius: diameter / 2 * Theme.Orb.Energize.coronaScaleMin,
                endRadius: radius
            )

            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: coronaDiameter,
                height: coronaDiameter
            )
            context.fill(Ellipse().path(in: rect), with: shading)
        }
        .frame(width: coronaDiameter, height: coronaDiameter)
        .scaleEffect(coronaPhase
            ? Theme.Orb.Energize.coronaScaleMax
            : Theme.Orb.Energize.coronaScaleMin)
        .animation(
            AnimationConstants.resolve(
                .easeInOut(duration: Theme.Orb.Energize.coronaCycleSeconds)
                    .repeatForever(autoreverses: true)
            ),
            value: coronaPhase
        )
    }

    // MARK: - Vortex Particle Layer

    @ViewBuilder
    private func vortexParticleLayer(diameter: CGFloat) -> some View {
        let particleColor = orbColor
        let birthRate = Theme.Particles.ambientBirthRate * particleBirthRateMultiplier

        VortexView(createParticleSystem(birthRate: birthRate)) {
            Circle()
                .fill(particleColor)
                .frame(width: Theme.Particles.sizeMax, height: Theme.Particles.sizeMax)
                .blur(radius: Theme.Particles.blurRadius)
                .blendMode(.plusLighter)
                .tag("ambient")
        }
        .frame(width: diameter * Theme.Particles.haloFrameMultiplier, height: diameter * Theme.Particles.haloFrameMultiplier)
        .allowsHitTesting(false)
    }

    private func createParticleSystem(birthRate: Double) -> VortexSystem {
        var system = VortexSystem(tags: ["ambient"])
        system.position = [0.5, 0.5]
        system.shape = .ellipse(radius: Theme.Particles.emitterShapeRadius)
        system.birthRate = birthRate
        system.lifespan = Theme.Particles.lifetimeMax
        system.speed = Theme.Particles.speed
        system.speedVariation = Theme.Particles.speedVariation
        system.angle = .degrees(270)
        system.angleRange = .degrees(360)
        system.size = Theme.Particles.size
        system.sizeVariation = Theme.Particles.sizeVariation
        system.sizeMultiplierAtDeath = Theme.Particles.sizeMultiplierAtDeath
        system.colors = .ramp(orbColor.toVortexColor(), orbColor.toVortexColor().opacity(Theme.Particles.colorRampTailOpacity), .clear)
        return system
    }

    private var particleBirthRateMultiplier: Double {
        switch biometricState {
        case .calm:     return Theme.Particles.calmMultiplier
        case .focused:  return Theme.Particles.focusedMultiplier
        case .elevated: return Theme.Particles.elevatedMultiplier
        case .peak:     return Theme.Particles.peakMultiplier
        }
    }

    // MARK: - Computed Properties

    private var isEnergize: Bool {
        sessionMode == .energize
    }

    private var orbColor: Color {
        if isEnergize && shimmerPhase {
            return Color(hex: Theme.Orb.Energize.shimmerGoldHex)
        }
        return Color.biometricColor(for: biometricState)
    }

    private var orbOpacity: Double {
        switch biometricState {
        case .calm:     return Theme.Orb.StateOpacity.calm
        case .focused:  return Theme.Orb.StateOpacity.focused
        case .elevated: return Theme.Orb.StateOpacity.elevated
        case .peak:     return Theme.Orb.StateOpacity.peak
        }
    }

    private var breathingScale: CGFloat {
        breathingPhase
            ? (isEnergize ? Theme.Orb.Energize.scaleMax : Theme.Animation.OrbScale.breathingMax)
            : (isEnergize ? Theme.Orb.Energize.scaleMin : Theme.Animation.OrbScale.breathingMin)
    }

    /// Derives the Orb's breathing cycle duration from the live beat frequency.
    /// Inverse-proportional: higher Hz = faster pulse, lower Hz = slower pulse.
    /// Falls back to biometric-state defaults when beatFrequency is zero
    /// (e.g., manual mode with no audio running).
    private var pulseCycleDuration: Double {
        guard beatFrequency > 0 else {
            // Fallback to static defaults when no frequency data
            switch biometricState {
            case .calm:     return Theme.Orb.PulseCycle.calm
            case .focused:  return Theme.Orb.PulseCycle.focused
            case .elevated: return Theme.Orb.PulseCycle.elevated
            case .peak:     return Theme.Orb.PulseCycle.peak
            }
        }

        // cycleDuration = scaleFactor / beatFrequency, clamped to safe range
        let raw = Theme.Animation.FrequencySync.orbScaleFactor / beatFrequency
        return min(
            Theme.Animation.FrequencySync.orbCycleDurationMax,
            max(Theme.Animation.FrequencySync.orbCycleDurationMin, raw)
        )
    }

    private var breathingAnimation: SwiftUI.Animation {
        Theme.Animation.orbBreathing(cycleDuration: pulseCycleDuration)
    }

    private var orbSizeFraction: CGFloat {
        let rest = Theme.Animation.OrbScale.restingFraction
        let peak = Theme.Animation.OrbScale.peakFraction
        let range = peak - rest
        switch biometricState {
        case .calm:     return rest
        case .focused:  return rest + range * Theme.Particles.focusedSizeFraction
        case .elevated: return rest + range * Theme.Particles.elevatedSizeFraction
        case .peak:     return peak
        }
    }

    private var accessibilityDescription: String {
        let stateDesc = biometricState.rawValue
        let modeDesc = sessionMode.displayName
        return "Session orb, \(modeDesc) mode, \(stateDesc) state"
    }

    // MARK: - Animation Control

    private func startAnimations() {
        sessionStart = .now
        breathingPhase = true
        if isEnergize {
            shimmerPhase = true
            coronaPhase = true
        }
    }

    private func restartBreathing() {
        pendingRestartWork?.cancel()
        breathingPhase = false
        let work = DispatchWorkItem { [self] in
            breathingPhase = true
            if isEnergize {
                shimmerPhase = true
                coronaPhase = true
            }
        }
        pendingRestartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Particles.breathingRestartDelay, execute: work)
    }
}

// MARK: - HDR Glow Modifier

private extension View {

    /// Applies GlowGetter HDR glow on supported devices, falls back to
    /// a standard shadow-based glow on unsupported devices or watchOS.
    @ViewBuilder
    func hdrGlow(intensity: Double) -> some View {
        #if canImport(GlowGetter) && !os(watchOS)
        self
            .clipShape(Circle())
            .glow(intensity, Circle())
        #else
        self
        #endif
    }
}

// MARK: - SwiftUI Color → VortexSystem.Color

private extension Color {
    func toVortexColor() -> VortexSystem.Color {
        let resolved = self.resolve(in: EnvironmentValues())
        return VortexSystem.Color(
            red: Double(resolved.red),
            green: Double(resolved.green),
            blue: Double(resolved.blue),
            opacity: Double(resolved.opacity)
        )
    }
}

// MARK: - Preview

#Preview("OrbView - Calm") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        OrbView(
            biometricState: .calm,
            sessionMode: .focus,
            beatFrequency: 14,
            isPlaying: true
        )
        .frame(width: 300, height: 300)
    }
}

#Preview("OrbView - Energize") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        OrbView(
            biometricState: .elevated,
            sessionMode: .energize,
            beatFrequency: 20,
            isPlaying: true
        )
        .frame(width: 300, height: 300)
    }
}
