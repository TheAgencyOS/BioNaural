// BrainStateStepView.swift
// BioNaural
//
// Step 1 of the composition creation flow. Presents the four brain
// states (Focus, Calm, Sleep, Energy) as a 2x2 grid of glass cards
// with mode-colored wave signatures. Selecting a state starts the
// binaural beat preview immediately.

import SwiftUI
import BioNauralShared

// MARK: - BrainStateStepView

struct BrainStateStepView: View {

    @Bindable var viewModel: ComposerViewModel

    private let modes: [FocusMode] = [.focus, .relaxation, .sleep, .energize]

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                composerStepHeader(title: "Brain State", subtitle: "Choose your target frequency")

                // 2x2 Grid
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(modes) { mode in
                        brainStateCard(mode)
                            .onTapGesture {
                                viewModel.selectBrainState(mode)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(mode.displayName)
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)

                Spacer(minLength: Theme.Spacing.xl)

                // Next button
                Button {
                    viewModel.advance()
                } label: {
                    Text("Next")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Capsule().fill(Theme.Colors.accent))
                }
                .disabled(!viewModel.canAdvance)
                .opacity(viewModel.canAdvance ? 1 : Theme.Opacity.medium)
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
    }

    // MARK: - Brain State Card

    private func brainStateCard(_ mode: FocusMode) -> some View {
        let isSelected = viewModel.selectedBrainState == mode
        let color = Color.modeColor(for: mode)

        return ZStack(alignment: .topLeading) {
            // Radial glow from top-leading
            RadialGradient(
                colors: [
                    color.opacity(isSelected ? Theme.Opacity.accentLight : Theme.Opacity.subtle),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 2
            )

            // Bloom + crisp wave from real mode frequencies
            CompositionWaveView(mode: mode)
                .accessibilityHidden(true)

            // Icon badge — top leading
            Image(systemName: mode.systemImageName)
                .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                .foregroundStyle(color)
                .frame(
                    width: Theme.Spacing.xxl + Theme.Spacing.sm,
                    height: Theme.Spacing.xxl + Theme.Spacing.sm
                )
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(color.opacity(Theme.Opacity.accentLight))
                )
                .padding(Theme.Spacing.lg)

            // Name anchored bottom-left
            VStack {
                Spacer()
                Text(mode.displayName)
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.lg)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    isSelected ? color.opacity(Theme.Opacity.accentStrong) : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
        .animation(Theme.Animation.standard, value: isSelected)
    }
}

// MARK: - Preview

#Preview("Brain State Step") {
    BrainStateStepView(viewModel: ComposerViewModel(audioEngine: AudioEngine()))
        .background(Theme.Colors.canvas)
        .preferredColorScheme(.dark)
}
