// BioNauralShaders.metal
// BioNaural
//
// Custom Metal fragment shaders for session visuals.
// Water ripple, organic noise background, circular glow pulse,
// and shimmer highlight. All parameters are runtime-driven from
// Swift (biometric state, audio amplitude, elapsed time).
//
// Usage: Apply via SwiftUI's .colorEffect(), .distortionEffect(),
// or .layerEffect() modifiers inside a TimelineView(.animation).

#include <metal_stdlib>
using namespace metal;

// MARK: - Water Ripple (Distortion Effect)

/// Ripple distortion centered on a point, driven by time and strength.
/// Attach to a view via .distortionEffect(ShaderLibrary.waterRipple(...)).
///
/// Parameters:
///   size:     View size in points
///   time:     Elapsed seconds (drives ripple animation)
///   speed:    Ripple propagation speed (1.0 = normal)
///   strength: Distortion amplitude (0.0 = none, 5.0 = dramatic)
///   frequency: Ripple density (higher = more rings)
[[ stitchable ]]
float2 waterRipple(float2 position,
                   float2 size,
                   float time,
                   float speed,
                   float strength,
                   float frequency) {
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float2 delta = uv - center;
    float dist = length(delta);

    float ripple = sin(dist * frequency - time * speed) * strength;
    float falloff = smoothstep(0.5, 0.0, dist);
    float2 offset = normalize(delta + 0.0001) * ripple * falloff;

    return position + offset;
}

// MARK: - Organic Noise Background (Color Effect)

/// Generates animated organic sine-wave lines — a living background texture.
/// Attach via .colorEffect(ShaderLibrary.organicNoise(...)).
///
/// Parameters:
///   position: Fragment position
///   size:     View size
///   time:     Elapsed seconds (drives animation)
///   color:    Base tint color (e.g., periwinkle)
///   intensity: Overall brightness (0.0-1.0)
[[ stitchable ]]
half4 organicNoise(float2 position,
                   half4 currentColor,
                   float2 size,
                   float time,
                   half4 color,
                   float intensity) {
    float2 uv = position / size;

    // Layer multiple sine waves at different frequencies and phases.
    float wave1 = sin(uv.x * 8.0 + time * 0.3 + uv.y * 3.0) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 6.0 - time * 0.2 + uv.x * 4.0) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 10.0 + time * 0.15) * 0.5 + 0.5;
    float wave4 = sin(uv.x * 12.0 - uv.y * 8.0 + time * 0.4) * 0.5 + 0.5;

    // Combine waves with diminishing contribution.
    float combined = wave1 * 0.4 + wave2 * 0.3 + wave3 * 0.2 + wave4 * 0.1;

    // Radial falloff — brighter at center, fades to edges.
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);
    float falloff = smoothstep(0.7, 0.0, dist);

    half alpha = half(combined * falloff * intensity);
    return half4(color.rgb * alpha, alpha);
}

// MARK: - Circle Glow Pulse (Color Effect)

/// Concentric circular waves radiating from center, driven by time.
/// Perfect for orb glow effects. Attach via .colorEffect().
///
/// Parameters:
///   position:   Fragment position
///   size:       View size
///   time:       Elapsed seconds
///   brightness: Peak brightness of rings (0.0-2.0)
///   speed:      Ring expansion speed
///   density:    Number of visible rings
///   ringColor:  Color of the rings
[[ stitchable ]]
half4 circleGlowPulse(float2 position,
                      half4 currentColor,
                      float2 size,
                      float time,
                      float brightness,
                      float speed,
                      float density,
                      half4 ringColor) {
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    // Generate concentric rings that pulse outward.
    float ring = sin(dist * density - time * speed);
    ring = ring * 0.5 + 0.5;            // Normalize to 0-1
    ring = pow(ring, 4.0);              // Sharpen the peaks
    ring *= smoothstep(0.5, 0.0, dist); // Fade at edges

    half alpha = half(ring * brightness);
    half4 result = currentColor + half4(ringColor.rgb * alpha, alpha * 0.5);
    return result;
}

// MARK: - Shimmer Sweep (Color Effect)

/// A sweeping highlight that moves across a view, like light catching a surface.
/// Attach via .colorEffect(ShaderLibrary.shimmerSweep(...)).
///
/// Parameters:
///   position:  Fragment position
///   size:      View size
///   time:      Elapsed seconds
///   speed:     Sweep speed (1.0 = normal, 0.3 = slow ambient)
///   width:     Width of the shimmer band (0.05-0.3)
///   intensity: Peak brightness of shimmer (0.0-1.0)
[[ stitchable ]]
half4 shimmerSweep(float2 position,
                   half4 currentColor,
                   float time,
                   float2 size,
                   float speed,
                   float width,
                   float intensity) {
    float2 uv = position / size;

    // Diagonal sweep: position along a 45-degree line.
    float sweep = fract(time * speed * 0.1);
    float pos = (uv.x + uv.y) * 0.5;
    float dist = abs(pos - sweep);

    // Wrap-around for continuous sweep.
    dist = min(dist, 1.0 - dist);

    // Gaussian-like falloff for soft shimmer band.
    float shimmer = exp(-dist * dist / (width * width * 0.5));
    shimmer *= intensity;

    half4 highlight = half4(half(shimmer), half(shimmer), half(shimmer), half(shimmer * 0.5));
    return currentColor + highlight;
}
