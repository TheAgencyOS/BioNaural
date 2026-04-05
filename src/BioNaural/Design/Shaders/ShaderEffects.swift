// ShaderEffects.swift
// BioNaural
//
// SwiftUI view modifiers wrapping BioNauralShaders.metal.
// Each modifier exposes the shader through a clean API that accepts
// Theme tokens and biometric-driven parameters. All values flow
// through Theme — no hardcoded numbers.

import SwiftUI

// MARK: - Water Ripple Modifier

extension View {

    /// Applies a ripple distortion effect driven by elapsed time and audio amplitude.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since session start (drives animation).
    ///   - speed: Ripple propagation speed from Theme tokens.
    ///   - strength: Distortion amplitude — tie to audio amplitude or biometric state.
    ///   - frequency: Ring density from Theme tokens.
    @available(iOS 17.0, *)
    func waterRipple(
        elapsed: Double,
        speed: Double = Theme.Shader.WaterRipple.speed,
        strength: Double = Theme.Shader.WaterRipple.strength,
        frequency: Double = Theme.Shader.WaterRipple.frequency
    ) -> some View {
        self.visualEffect { content, proxy in
            content.distortionEffect(
                ShaderLibrary.waterRipple(
                    .float2(proxy.size),
                    .float(elapsed),
                    .float(speed),
                    .float(strength),
                    .float(frequency)
                ),
                maxSampleOffset: CGSize(
                    width: Theme.Shader.WaterRipple.maxSampleOffset,
                    height: Theme.Shader.WaterRipple.maxSampleOffset
                )
            )
        }
    }
}

// MARK: - Organic Noise Background Modifier

extension View {

    /// Overlays animated organic noise — a living background texture.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since session start.
    ///   - color: Tint color (typically the mode color).
    ///   - intensity: Brightness level from Theme tokens.
    @available(iOS 17.0, *)
    func organicNoiseOverlay(
        elapsed: Double,
        color: Color,
        intensity: Double = Theme.Shader.OrganicNoise.intensity
    ) -> some View {
        self.overlay {
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.organicNoise(
                            .float2(proxy.size),
                            .float(elapsed),
                            .color(color),
                            .float(intensity)
                        )
                    )
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Circle Glow Pulse Modifier

extension View {

    /// Adds concentric pulsing glow rings radiating from center.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since session start.
    ///   - brightness: Ring peak brightness — tie to biometric intensity.
    ///   - speed: Ring expansion speed from Theme tokens.
    ///   - density: Ring count from Theme tokens.
    ///   - color: Ring color (typically the mode color).
    @available(iOS 17.0, *)
    func circleGlowPulse(
        elapsed: Double,
        brightness: Double = Theme.Shader.CircleGlow.brightness,
        speed: Double = Theme.Shader.CircleGlow.speed,
        density: Double = Theme.Shader.CircleGlow.density,
        color: Color
    ) -> some View {
        self.visualEffect { content, proxy in
            content.colorEffect(
                ShaderLibrary.circleGlowPulse(
                    .float2(proxy.size),
                    .float(elapsed),
                    .float(brightness),
                    .float(speed),
                    .float(density),
                    .color(color)
                )
            )
        }
    }
}

// MARK: - Shimmer Sweep Modifier

extension View {

    /// Adds a sweeping shimmer highlight across the view surface.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since session start.
    ///   - speed: Sweep speed from Theme tokens.
    ///   - width: Band width from Theme tokens.
    ///   - intensity: Peak brightness from Theme tokens.
    @available(iOS 17.0, *)
    func shimmerSweep(
        elapsed: Double,
        speed: Double = Theme.Shader.Shimmer.speed,
        width: Double = Theme.Shader.Shimmer.width,
        intensity: Double = Theme.Shader.Shimmer.intensity
    ) -> some View {
        self.visualEffect { content, proxy in
            content.colorEffect(
                ShaderLibrary.shimmerSweep(
                    .float(elapsed),
                    .float2(proxy.size),
                    .float(speed),
                    .float(width),
                    .float(intensity)
                )
            )
        }
    }
}
