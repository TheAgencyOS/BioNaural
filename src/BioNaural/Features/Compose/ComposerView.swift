// ComposerView.swift
// BioNaural
//
// Hub view for the Compose tab. Shows saved compositions in a
// 2-column grid with an empty state when no compositions exist.
// Floating "+" button opens the creation sheet. Tapping a card
// launches a session; long-press reveals edit/duplicate/delete.
// All values from Theme tokens. Native SwiftUI.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - ComposerView

struct ComposerView: View {

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomComposition.createdDate, order: .reverse)
    private var compositions: [CustomComposition]

    @State private var showCreationSheet = false
    @Namespace private var glassNamespace

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if compositions.isEmpty {
                emptyState
            } else {
                compositionsGrid
            }
        }
        .background { NebulaBokehBackground() }
        .navigationTitle("Compose")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dependencies.hapticService.buttonPress()
                    showCreationSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("Create new composition")
            }
        }
        .sheet(isPresented: $showCreationSheet) {
            ComposerSheetView()
                .environment(dependencies)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()
                .frame(height: Theme.Spacing.mega)

            // Orb with convergence glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                                Theme.Colors.accent.opacity(Theme.Opacity.subtle),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: Theme.Spacing.jumbo
                        )
                    )
                    .frame(
                        width: Theme.Spacing.jumbo * 2,
                        height: Theme.Spacing.jumbo * 2
                    )

                // Mini wave through orb center
                CompositionWaveView(mode: .focus)
                    .frame(width: Theme.Spacing.mega * 2, height: Theme.Spacing.xxl)
            }
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Create your first sound")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("Layer binaural beats, soundscapes, and instruments into a composition that adapts to you.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Theme.Spacing.mega * 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    // MARK: - Compositions Grid

    private var compositionsGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(compositions) { composition in
                NavigationLink(value: AppDestination.composedSession(id: composition.id)) {
                    CompositionCardView(
                        composition: composition,
                        glassNamespace: glassNamespace
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        duplicateComposition(composition)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteComposition(composition)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .adaptiveGlassContainer(spacing: Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.mega + Theme.Spacing.xxxl)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            dependencies.hapticService.buttonPress()
            showCreationSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: Theme.Typography.Size.headline, weight: .medium))
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(
                    width: Theme.Spacing.jumbo + Theme.Spacing.sm,
                    height: Theme.Spacing.jumbo + Theme.Spacing.sm
                )
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.accent, Theme.Colors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Theme.Colors.accent.opacity(Theme.Opacity.medium),
                            radius: Theme.Spacing.lg,
                            y: Theme.Spacing.sm
                        )
                )
        }
        .accessibilityLabel("Create new composition")
        .padding(.trailing, Theme.Spacing.pageMargin)
        .padding(.bottom, Theme.Spacing.mega + Theme.Spacing.jumbo)
    }

    // MARK: - Actions

    private func duplicateComposition(_ source: CustomComposition) {
        let copy = CustomComposition(
            name: source.name + " Copy",
            brainState: source.brainState,
            beatFrequency: source.beatFrequency,
            carrierFrequency: source.carrierFrequency,
            ambientBedName: source.ambientBedName,
            detailTextureName: source.detailTextureName,
            instruments: source.instruments,
            brightness: source.brightness,
            density: source.density,
            reverbWetDry: source.reverbWetDry,
            binauralVolume: source.binauralVolume,
            ambientVolume: source.ambientVolume,
            melodicVolume: source.melodicVolume,
            durationMinutes: source.durationMinutes,
            isAdaptive: source.isAdaptive
        )
        modelContext.insert(copy)
    }

    private func deleteComposition(_ composition: CustomComposition) {
        modelContext.delete(composition)
    }
}

// MARK: - Preview

#Preview("Composer - Empty") {
    NavigationStack {
        ComposerView()
    }
    .environment(AppDependencies())
    .preferredColorScheme(.dark)
}
