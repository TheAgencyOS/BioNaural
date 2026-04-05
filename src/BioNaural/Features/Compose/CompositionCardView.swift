// CompositionCardView.swift
// BioNaural
//
// A refined, square composition card for the Compose hub. Uses the
// same Liquid Glass treatment as the rest of the app (iOS 26+) with
// a fallback to the standard surface + divider stroke pattern. The
// wave signature rendered in the background reflects the real binaural
// frequencies of the composition.
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - CompositionCardView

struct CompositionCardView: View {

    let composition: CustomComposition
    var glassNamespace: Namespace.ID?

    var body: some View {
        let mode = composition.focusMode ?? .focus
        let color = Color.modeColor(for: mode)

        ZStack(alignment: .bottomLeading) {
            // Radial glow from top-leading corner (matches Health cards)
            RadialGradient(
                colors: [
                    color.opacity(Theme.Opacity.accentLight),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 2
            )

            // Wave signature from real frequencies
            CompositionWaveView(composition: composition)
                .accessibilityHidden(true)

            // Text at bottom with gradient fade
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Spacer()

                Text(composition.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Text(formattedDuration)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.surface.opacity(Theme.Opacity.half),
                        Theme.Colors.surface.opacity(Theme.Opacity.translucent)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .aspectRatio(1, contentMode: .fill)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(composition.name), \(composition.durationMinutes) minutes")
        .compositionCardGlass()
        .modifier(CompositionGlassIDModifier(
            id: composition.persistentModelID.hashValue.description,
            namespace: glassNamespace
        ))
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        "\(composition.durationMinutes) min"
    }
}

// MARK: - Glass Card Modifier

/// Applies iOS 26 Liquid Glass on supported versions, falls back to
/// the standard surface + divider stroke pattern on iOS 17-25.
/// Square cards with `Theme.Radius.card` corners.
private struct CompositionCardGlassModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .glassEffect(
                    .regular.tint(
                        Theme.Colors.surface.opacity(Theme.Opacity.glassFill)
                    ),
                    in: .rect(cornerRadius: Theme.Radius.card, style: .continuous)
                )
        } else {
            content
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        }
    }
}

private extension View {
    func compositionCardGlass() -> some View {
        modifier(CompositionCardGlassModifier())
    }
}

// MARK: - Glass ID Modifier

/// Applies `glassEffectID` on iOS 26+ when a namespace is provided,
/// enabling morphing transitions between composition cards and session views.
private struct CompositionGlassIDModifier: ViewModifier {

    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), let namespace {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Composition Card") {
    HStack(spacing: Theme.Spacing.md) {
        CompositionCardView(
            composition: CustomComposition(
                name: "Rain Focus",
                brainState: FocusMode.focus.rawValue,
                beatFrequency: FocusMode.focus.defaultBeatFrequency,
                carrierFrequency: FocusMode.focus.defaultCarrierFrequency,
                ambientBedName: "rain",
                instruments: ["piano"],
                durationMinutes: 25
            )
        )

        CompositionCardView(
            composition: CustomComposition(
                name: "Night Drift",
                brainState: FocusMode.sleep.rawValue,
                beatFrequency: FocusMode.sleep.defaultBeatFrequency,
                carrierFrequency: FocusMode.sleep.defaultCarrierFrequency,
                ambientBedName: "night",
                instruments: ["pad"],
                durationMinutes: 45
            )
        )
    }
    .padding(Theme.Spacing.pageMargin)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
