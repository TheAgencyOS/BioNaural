// SoundscapeStepView.swift
// BioNaural
//
// Step 2: Build an ambient environment by selecting a base layer
// and an optional detail texture. Environment options are presented
// as a scrollable row of glass cards. Detail textures as smaller pills.
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - Ambient Catalog

enum AmbientBed: String, CaseIterable, Identifiable {
    case rain, ocean, forest, river, wind, night

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .rain:   return "cloud.rain.fill"
        case .ocean:  return "water.waves"
        case .forest: return "tree.fill"
        case .river:  return "drop.fill"
        case .wind:   return "wind"
        case .night:  return "moon.stars.fill"
        }
    }
}

enum DetailTexture: String, CaseIterable, Identifiable {
    case thunder, birdsong, crickets, fire, chimes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thunder:  return "Thunder"
        case .birdsong: return "Birdsong"
        case .crickets: return "Crickets"
        case .fire:     return "Fire"
        case .chimes:   return "Chimes"
        }
    }

    var iconName: String {
        switch self {
        case .thunder:  return "cloud.bolt.fill"
        case .birdsong: return "bird.fill"
        case .crickets: return "ant.fill"
        case .fire:     return "flame.fill"
        case .chimes:   return "bell.fill"
        }
    }
}

// MARK: - SoundscapeStepView

struct SoundscapeStepView: View {

    @Bindable var viewModel: ComposerViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                composerStepHeader(title: "Soundscape", subtitle: "Build your ambient environment")

                if viewModel.isPreviewPlaying {
                    composerPreviewBadge
                }

                // Environment — visual cards
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Environment")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            environmentCard(
                                name: "Silence",
                                icon: "speaker.slash.fill",
                                color: Theme.Colors.textTertiary,
                                isSelected: viewModel.selectedAmbientBed == nil
                            ) {
                                viewModel.selectAmbientBed(nil)
                            }

                            ForEach(AmbientBed.allCases) { bed in
                                environmentCard(
                                    name: bed.displayName,
                                    icon: bed.iconName,
                                    color: Theme.Colors.accent,
                                    isSelected: viewModel.selectedAmbientBed == bed.rawValue
                                ) {
                                    viewModel.selectAmbientBed(bed.rawValue)
                                }
                            }
                        }
                        .adaptiveGlassContainer(spacing: Theme.Spacing.md)
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                    }
                }

                // Detail Texture — compact pills
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Detail Texture")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            composerPill(
                                label: "None",
                                icon: "minus",
                                isSelected: viewModel.selectedDetailTexture == nil
                            ) {
                                viewModel.selectDetailTexture(nil)
                            }

                            ForEach(DetailTexture.allCases) { texture in
                                composerPill(
                                    label: texture.displayName,
                                    icon: texture.iconName,
                                    isSelected: viewModel.selectedDetailTexture == texture.rawValue
                                ) {
                                    viewModel.selectDetailTexture(texture.rawValue)
                                }
                            }
                        }
                        .adaptiveGlassContainer(spacing: Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                    }
                }

                Spacer(minLength: Theme.Spacing.xl)

                composerNavButtons(
                    onBack: { viewModel.goBack() },
                    onNext: { viewModel.advance() }
                )
            }
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
    }

    // MARK: - Environment Card

    private func environmentCard(
        name: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.headline, weight: .light))
                    .foregroundStyle(isSelected ? color : Theme.Colors.textTertiary)

                Text(name)
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            }
            .frame(width: Theme.Spacing.mega + Theme.Spacing.lg, height: Theme.Spacing.mega + Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .strokeBorder(
                        isSelected ? color.opacity(Theme.Opacity.accentStrong) : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Animation.standard, value: isSelected)
    }
}

// MARK: - Shared Composer Components

/// Reusable step header for all composer steps.
struct ComposerStepHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
}

extension View {

    func composerStepHeader(title: String, subtitle: String) -> some View {
        ComposerStepHeaderView(title: title, subtitle: subtitle)
    }

    var composerPreviewBadge: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Compose.PreviewBadge.barSpacing) {
                ForEach(0..<Theme.Compose.PreviewBadge.barHeights.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: Theme.Compose.PreviewBadge.barCornerRadius)
                        .fill(Theme.Colors.accent)
                        .frame(width: Theme.Compose.PreviewBadge.barWidth, height: Theme.Compose.PreviewBadge.barHeights[i])
                }
            }
            .frame(height: Theme.Spacing.lg)

            Text("Preview playing")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            Capsule()
                .fill(Theme.Colors.accent.opacity(Theme.Opacity.subtle))
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.Colors.accent.opacity(Theme.Opacity.light), lineWidth: Theme.Radius.glassStroke)
                )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func composerSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    func composerPill(
        label: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.small))
                Text(label)
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.Colors.accent.opacity(Theme.Opacity.accentLight) : Theme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Theme.Colors.accent.opacity(Theme.Opacity.medium) : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Animation.standard, value: isSelected)
    }

    func composerNavButtons(onBack: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            if #available(iOS 26.0, *) {
                Button(action: onBack) {
                    Text("Back")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button(action: onNext) {
                    Text("Next")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Colors.accent)
            } else {
                Button(action: onBack) {
                    Text("Back")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.surface)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.glassStroke), lineWidth: Theme.Radius.glassStroke)
                                )
                        )
                }

                Button(action: onNext) {
                    Text("Next")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(
                            Capsule().fill(Theme.Colors.accent)
                        )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    private func composerBarHeight(for index: Int) -> CGFloat {
        guard index < Theme.Compose.PreviewBadge.barHeights.count else { return Theme.Compose.PreviewBadge.barHeights[0] }
        return Theme.Compose.PreviewBadge.barHeights[index]
    }
}
