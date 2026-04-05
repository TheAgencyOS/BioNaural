// MelodicStepView.swift
// BioNaural
//
// Step 3: Choose instruments (multi-select) and adjust sound character
// with Warm/Bright and Sparse/Dense sliders. Instruments are presented
// as square glass tiles. Sliders use accent tint.
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - MelodicStepView

struct MelodicStepView: View {

    @Bindable var viewModel: ComposerViewModel

    private var availableInstruments: [Instrument] {
        if viewModel.selectedBrainState == .energize {
            return Instrument.allCases
        }
        return [.piano, .pad, .strings, .guitar, .texture]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                composerStepHeader(title: "Melodic Layer", subtitle: "Instruments and character")

                if viewModel.isPreviewPlaying {
                    composerPreviewBadge
                }

                // Instruments — scrollable tiles
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Instruments")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(availableInstruments, id: \.self) { instrument in
                                instrumentTile(instrument)
                            }
                        }
                        .adaptiveGlassContainer(spacing: Theme.Spacing.md)
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                    }
                }

                // Character sliders
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    composerSectionLabel("Character")

                    VStack(spacing: Theme.Spacing.xxl) {
                        composerSlider(
                            leftLabel: "Warm",
                            rightLabel: "Bright",
                            value: Binding(
                                get: { viewModel.brightness },
                                set: { viewModel.updateBrightness($0) }
                            ),
                            tint: Theme.Colors.accent
                        )

                        composerSlider(
                            leftLabel: "Sparse",
                            rightLabel: "Dense",
                            value: Binding(
                                get: { viewModel.density },
                                set: { viewModel.updateDensity($0) }
                            ),
                            tint: Theme.Colors.accent
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

    // MARK: - Instrument Tile

    private func instrumentTile(_ instrument: Instrument) -> some View {
        let isSelected = viewModel.selectedInstruments.contains(instrument)

        return Button {
            viewModel.toggleInstrument(instrument)
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: instrumentIcon(instrument))
                    .font(.system(size: Theme.Typography.Size.body, weight: .light))
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textTertiary)

                Text(instrument.rawValue.capitalized)
                    .font(Theme.Typography.small)
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            }
            .frame(
                width: Theme.Spacing.mega + Theme.Spacing.sm,
                height: Theme.Spacing.mega + Theme.Spacing.sm
            )
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.Colors.accent.opacity(Theme.Opacity.accentStrong) : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Animation.standard, value: isSelected)
    }

    // MARK: - Helpers

    private func instrumentIcon(_ instrument: Instrument) -> String {
        switch instrument {
        case .piano:      return "pianokeys"
        case .pad:        return "waveform"
        case .strings:    return "guitars"
        case .guitar:     return "guitars.fill"
        case .bass:       return "speaker.wave.2.fill"
        case .percussion: return "drum.fill"
        case .texture:    return "waveform.path"
        }
    }
}

// MARK: - Composer Slider

extension View {

    func composerSlider(
        leftLabel: String,
        rightLabel: String,
        value: Binding<Double>,
        tint: Color
    ) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text(leftLabel)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Text(rightLabel)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Slider(value: value, in: 0...1)
                .tint(tint)
                .accessibilityLabel(rightLabel)
        }
    }
}
