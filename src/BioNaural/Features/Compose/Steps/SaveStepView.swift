// SaveStepView.swift
// BioNaural
//
// Step 5: Name the composition, choose duration, toggle adaptive mode,
// review summary, and save. Auto-generates a default name from the
// user's selections.
// All values from Theme tokens. No hardcoding.

import SwiftUI
import BioNauralShared

// MARK: - SaveStepView

struct SaveStepView: View {

    @Bindable var viewModel: ComposerViewModel
    let onSave: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                composerStepHeader(title: "Save", subtitle: "Name and configure your composition")

                if viewModel.isPreviewPlaying {
                    composerPreviewBadge
                }

                // Name
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Name")

                    TextField("Composition name", text: $viewModel.compositionName)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(Theme.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .fill(Theme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                        .strokeBorder(
                                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                            lineWidth: Theme.Radius.glassStroke
                                        )
                                )
                        )
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                }

                // Duration
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Duration")

                    VStack(spacing: Theme.Spacing.xs) {
                        Picker("Duration", selection: $viewModel.durationMinutes) {
                            ForEach(durationOptions, id: \.self) { minutes in
                                Text("\(minutes)")
                                    .tag(minutes)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.Spacing.pageMargin)

                        Text("minutes")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Adaptive toggle
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Adaptive")
                            .font(Theme.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Responds to biometrics via Watch")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    Spacer()
                    Toggle("Adaptive mode", isOn: $viewModel.isAdaptive)
                        .labelsHidden()
                        .tint(Theme.Colors.accent)
                }
                .padding(Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .strokeBorder(
                                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                    lineWidth: Theme.Radius.glassStroke
                                )
                        )
                )
                .padding(.horizontal, Theme.Spacing.pageMargin)

                // Summary
                summaryCard

                Spacer(minLength: Theme.Spacing.xl)

                // Save button row
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        viewModel.goBack()
                    } label: {
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

                    Button(action: onSave) {
                        Text("Save")
                            .font(Theme.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .background(Capsule().fill(Theme.Colors.accent))
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("SUMMARY")
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: Theme.Spacing.sm) {
                summaryRow("Brain State", value: viewModel.selectedBrainState?.displayName ?? "--")
                summaryRow("Soundscape", value: soundscapeSummary)
                summaryRow("Melodic", value: melodicSummary)
                summaryRow("Space", value: spaceSummary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    @ViewBuilder
    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
            Text(value)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    // MARK: - Helpers

    private var durationOptions: [Int] {
        viewModel.selectedBrainState?.durationOptions ?? FocusMode.focus.durationOptions
    }

    private var soundscapeSummary: String {
        var parts: [String] = []
        if let bed = viewModel.selectedAmbientBed { parts.append(bed.capitalized) }
        if let detail = viewModel.selectedDetailTexture { parts.append(detail.capitalized) }
        return parts.isEmpty ? "Silence" : parts.joined(separator: " + ")
    }

    private var melodicSummary: String {
        let names = viewModel.selectedInstruments
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.rawValue.capitalized }
        return names.isEmpty ? "--" : names.joined(separator: ", ")
    }

    private var spaceSummary: String {
        Theme.Compose.SpaceLabel.label(for: viewModel.reverbWetDry)
    }
}
