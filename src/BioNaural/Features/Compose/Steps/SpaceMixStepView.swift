// SpaceMixStepView.swift
// BioNaural
//
// Step 4: Adjust reverb depth (Intimate to Vast) and volume balance
// across the three audio layers (Beats, Soundscape, Melodic).
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - SpaceMixStepView

struct SpaceMixStepView: View {

    @Bindable var viewModel: ComposerViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                composerStepHeader(title: "Space & Mix", subtitle: "Shape the depth and balance")

                if viewModel.isPreviewPlaying {
                    composerPreviewBadge
                }

                // Space
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Space")

                    VStack(spacing: Theme.Spacing.md) {
                        composerSlider(
                            leftLabel: "Intimate",
                            rightLabel: "Vast",
                            value: Binding(
                                get: { Double(viewModel.reverbWetDry) / Double(Theme.Compose.Defaults.reverbMax) },
                                set: { viewModel.updateReverbWetDry(Float($0) * Theme.Compose.Defaults.reverbMax) }
                            ),
                            tint: Theme.Colors.sleep
                        )

                        Text(spaceLabel)
                            .font(.system(size: Theme.Typography.Size.small, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                }

                // Volume Balance
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    composerSectionLabel("Volume Balance")

                    VStack(spacing: Theme.Spacing.xl) {
                        volumeRow(
                            label: "Beats",
                            tint: Theme.Colors.accent,
                            value: Binding(
                                get: { viewModel.binauralVolume },
                                set: { viewModel.updateBinauralVolume($0) }
                            )
                        )

                        volumeRow(
                            label: "Soundscape",
                            tint: Theme.Colors.relaxation,
                            value: Binding(
                                get: { viewModel.ambientVolume },
                                set: { viewModel.updateAmbientVolume($0) }
                            )
                        )

                        volumeRow(
                            label: "Melodic",
                            tint: Theme.Colors.sleep,
                            value: Binding(
                                get: { viewModel.melodicVolume },
                                set: { viewModel.updateMelodicVolume($0) }
                            )
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
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

    // MARK: - Volume Row

    private func volumeRow(
        label: String,
        tint: Color,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(label)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Theme.Compose.Defaults.volumeLabelWidth, alignment: .leading)

            Slider(value: value, in: 0...1)
                .tint(tint)
                .accessibilityLabel(label)
        }
    }

    // MARK: - Space Label

    private var spaceLabel: String {
        Theme.Compose.SpaceLabel.label(for: viewModel.reverbWetDry)
    }
}
