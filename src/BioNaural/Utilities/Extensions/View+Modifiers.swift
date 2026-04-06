// View+Modifiers.swift
// BioNaural
//
// Reusable SwiftUI view modifiers built on Theme tokens. Every modifier
// references the design token system — no inline magic numbers.

import SwiftUI

// MARK: - Layout Modifiers

extension View {

    /// Applies the standard horizontal page margin from `Theme.Spacing`.
    func pageMargin() -> some View {
        padding(.horizontal, Theme.Spacing.pageMargin)
    }

    /// Applies the standard card style: surface background, rounded corners,
    /// and inner padding from Theme tokens.
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }

    /// Applies a glass-effect card on iOS 26+. Falls back to `cardStyle()`
    /// on earlier versions.
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}

// MARK: - Badge Modifiers

extension View {

    /// Overlays a small "PRO" badge in the top-trailing corner.
    ///
    /// Use on feature tiles or controls that require a premium subscription.
    func premiumBadge() -> some View {
        overlay(alignment: .topTrailing) {
            Text("PRO")
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xxs)
                .background(Theme.Colors.accent, in: Capsule())
                .padding(Theme.Spacing.sm)
        }
    }
}

// MARK: - Accessibility Modifiers

extension View {

    /// Hides animated content when Reduce Motion is enabled, showing an
    /// optional static replacement instead.
    ///
    /// - Parameter replacement: A static view to display when Reduce Motion
    ///   is on. Defaults to an empty view.
    func hideWhenReduceMotion<Replacement: View>(
        @ViewBuilder replacement: () -> Replacement
    ) -> some View {
        modifier(ReduceMotionModifier(replacement: replacement()))
    }

    /// Hides animated content when Reduce Motion is enabled. Shows nothing
    /// in its place.
    func hideWhenReduceMotion() -> some View {
        modifier(ReduceMotionModifier(replacement: EmptyView()))
    }
}

// MARK: - Adaptive Glass Modifiers

extension View {

    /// Applies iOS 26 Liquid Glass `.regular` effect, falling back to
    /// a themed surface + corner radius on iOS 17-25.
    func adaptiveGlass() -> some View {
        modifier(AdaptiveGlassModifier())
    }

    /// Applies iOS 26 Liquid Glass interactive variant, falling back to
    /// a themed surface on earlier versions. Use for tappable glass elements.
    func adaptiveInteractiveGlass() -> some View {
        modifier(AdaptiveInteractiveGlassModifier())
    }

    /// Applies iOS 26 Liquid Glass for navigation and tab bars, falling
    /// back to a themed surface on earlier versions.
    func adaptiveBarGlass() -> some View {
        modifier(AdaptiveBarGlassModifier())
    }

    /// Wraps content in a `GlassEffectContainer` on iOS 26+ so adjacent
    /// glass elements merge seamlessly. Falls back to a plain `Group` on
    /// earlier versions.
    func adaptiveGlassContainer(spacing: CGFloat = Theme.Spacing.md) -> some View {
        modifier(AdaptiveGlassContainerModifier(spacing: spacing))
    }

    /// Tags a view with a `glassEffectID` for morphing transitions on
    /// iOS 26+. No-op on earlier versions.
    func adaptiveGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        modifier(AdaptiveGlassIDModifier(id: id, namespace: namespace))
    }
}

// MARK: - Premium Transition Modifiers

extension View {

    /// Bloom transition from a mode-selection card into the session Orb.
    /// Uses `matchedGeometryEffect` with the provided namespace to morph
    /// the card shape into the Orb's circular form.
    ///
    /// - Parameters:
    ///   - isActive: Whether the session is currently active (Orb visible).
    ///   - namespace: The `@Namespace` shared between card and Orb.
    ///   - id: Matched geometry identifier string.
    func sessionStartTransition(
        isActive: Bool,
        namespace: Namespace.ID,
        id: String = "sessionBloom"
    ) -> some View {
        modifier(
            SessionStartTransitionModifier(
                isActive: isActive,
                namespace: namespace,
                id: id
            )
        )
    }

    /// Fades and slides a card upward with a staggered delay based on its
    /// index in a list. Cards appear sequentially for a cascading reveal.
    ///
    /// - Parameters:
    ///   - index: The card's position in the list (0-based).
    ///   - isVisible: Triggers the animation when set to `true`.
    func staggeredFadeIn(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredFadeInModifier(index: index, isVisible: isVisible))
    }

    /// Overlays a shimmer gradient sweep while loading. The gradient
    /// sweeps left-to-right using Theme surface colors.
    ///
    /// - Parameter isLoading: When `true`, the shimmer animates.
    func shimmerLoading(isLoading: Bool) -> some View {
        modifier(ShimmerView(isActive: isLoading))
    }
}

// MARK: - Micro-Interaction Modifiers

extension View {

    /// Adds a breathing glow shadow that expands and contracts on a
    /// `Theme.Animation.Duration.breathingGlowCycle` cycle. Use for
    /// suggested or recommended cards.
    ///
    /// - Parameters:
    ///   - color: The glow color. Defaults to accent.
    ///   - isActive: When `false`, the glow is hidden.
    func pulseGlow(
        color: Color = Theme.Colors.accent,
        isActive: Bool = true
    ) -> some View {
        modifier(BreathingGlow(color: color, isActive: isActive))
    }

    /// Applies `.contentTransition(.numericText())` for smooth
    /// odometer-style number changes on iOS 17+.
    func rollingNumber() -> some View {
        modifier(RollingNumberModifier())
    }
}

// MARK: - Card Style Modifier

private struct CardStyleModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
    }
}

// MARK: - Glass Card Modifier

private struct GlassCardModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(Theme.Spacing.lg)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .glassEffect(
                    .regular.tint(Theme.Colors.surface.opacity(Theme.Opacity.light)),
                    in: .rect(cornerRadius: Theme.Radius.xl)
                )
        } else {
            content.cardStyle()
        }
    }
}

// MARK: - Ambient Glow

extension View {

    /// Adds a subtle color glow beneath the view. Static — rasterized once.
    func ambientGlow(_ color: Color, cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color.opacity(Theme.ModeCard.ambientGlowOpacity))
                .blur(radius: Theme.ModeCard.ambientGlowBlurRadius)
        )
    }

    /// Applies glass card treatment + ambient glow together.
    func premiumCard(glowColor: Color) -> some View {
        self
            .glassCard()
            .ambientGlow(glowColor)
    }
}

// MARK: - Reduce Motion Modifier

private struct ReduceMotionModifier<Replacement: View>: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let replacement: Replacement

    func body(content: Content) -> some View {
        if reduceMotion {
            replacement
        } else {
            content
        }
    }
}

// MARK: - Adaptive Glass Modifier

private struct AdaptiveGlassModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .glassEffect(
                    .regular.tint(
                        Theme.Colors.surface.opacity(Theme.Opacity.glassFill)
                    ),
                    in: .rect(cornerRadius: Theme.Radius.xl)
                )
        } else {
            content
                .background(Theme.Colors.surface.opacity(Theme.Opacity.glassFill))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke // 1pt
                        )
                )
        }
    }
}

// MARK: - Adaptive Interactive Glass Modifier

private struct AdaptiveInteractiveGlassModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .glassEffect(
                    .regular.interactive().tint(
                        Theme.Colors.surface.opacity(Theme.Opacity.glassInteractive)
                    ),
                    in: .rect(cornerRadius: Theme.Radius.xl)
                )
        } else {
            content
                .background(Theme.Colors.surface.opacity(Theme.Opacity.glassInteractive))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        }
    }
}

// MARK: - Adaptive Bar Glass Modifier

private struct AdaptiveBarGlassModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(
                        Theme.Colors.surface.opacity(Theme.Opacity.glassBar)
                    )
                )
        } else {
            content
                .background(
                    Theme.Colors.surface.opacity(Theme.Opacity.glassBar)
                )
        }
    }
}

// MARK: - Adaptive Glass Container Modifier

private struct AdaptiveGlassContainerModifier: ViewModifier {

    let spacing: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Adaptive Glass ID Modifier

private struct AdaptiveGlassIDModifier: ViewModifier {

    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Session Start Transition Modifier

private struct SessionStartTransitionModifier: ViewModifier {

    let isActive: Bool
    let namespace: Namespace.ID
    let id: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: isActive
            )
            .scaleEffect(isActive ? Theme.Animation.OrbScale.breathingMax : Theme.Animation.OrbScale.breathingMin)
            .opacity(isActive ? Theme.Opacity.full : Theme.Opacity.transparent)
            .animation(
                reduceMotion ? .identity : Theme.Animation.sessionTransition,
                value: isActive
            )
            .accessibilityHidden(!isActive)
    }
}

// MARK: - Staggered Fade In Modifier

private struct StaggeredFadeInModifier: ViewModifier {

    let index: Int
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vertical offset for the slide-up entrance.
    private var slideOffset: CGFloat {
        isVisible ? .zero : Theme.Spacing.xl
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
            .offset(y: reduceMotion ? .zero : slideOffset)
            .animation(
                reduceMotion ? .identity : Theme.Animation.staggeredFadeIn(index: index),
                value: isVisible
            )
    }
}

// MARK: - Rolling Number Modifier

private struct RollingNumberModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .contentTransition(.numericText())
        }
    }
}
