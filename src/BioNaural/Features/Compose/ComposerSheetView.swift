// ComposerSheetView.swift
// BioNaural
//
// Container for the 5-step sound creation flow. Presented as a sheet
// from the Compose hub. Uses a direct step switch with slide transitions
// instead of TabView for reliable programmatic navigation. Step dots
// use an animated capsule indicator. Audio preview plays continuously
// across steps. Dismissing without saving stops the preview cleanly.
// All values from Theme tokens. Native SwiftUI.

import SwiftUI
import BioNauralShared

// MARK: - ComposerSheetView

struct ComposerSheetView: View {

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ComposerViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                sheetContent(viewModel: viewModel)
            } else {
                Color.clear
                    .onAppear { createViewModel() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { NebulaBokehBackground() }
        .interactiveDismissDisabled(viewModel?.isPreviewPlaying ?? false)
        .onDisappear {
            viewModel?.stopPreview()
        }
    }

    private func createViewModel() {
        viewModel = ComposerViewModel(audioEngine: dependencies.audioEngine)
    }

    @ViewBuilder
    private func sheetContent(viewModel: ComposerViewModel) -> some View {
        VStack(spacing: 0) {
            // Step indicator bar
            stepIndicator(viewModel: viewModel)

            // Step content — direct switch with slide transitions
            ZStack {
                switch viewModel.currentStep {
                case 0:
                    BrainStateStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                case 1:
                    SoundscapeStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                case 2:
                    MelodicStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                case 3:
                    SpaceMixStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                default:
                    SaveStepView(viewModel: viewModel) {
                        _ = viewModel.save(in: modelContext)
                        dismiss()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                }
            }
            .animation(Theme.Animation.sheet, value: viewModel.currentStep)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.stopPreview()
                    dismiss()
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Step Indicator

    private func stepIndicator(viewModel: ComposerViewModel) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                Capsule()
                    .fill(
                        index <= viewModel.currentStep
                            ? Theme.Colors.accent
                            : Theme.Colors.divider.opacity(Theme.Opacity.half)
                    )
                    .frame(
                        width: index == viewModel.currentStep
                            ? Theme.Spacing.xxl
                            : Theme.Spacing.sm,
                        height: Theme.Spacing.xxs
                    )
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .animation(Theme.Animation.standard, value: viewModel.currentStep)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Composer Sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ComposerSheetView()
                .environment(AppDependencies())
        }
        .preferredColorScheme(.dark)
}
