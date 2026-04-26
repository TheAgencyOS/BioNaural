// ExportTrackSheet.swift
// BioNaural
//
// Sheet that walks the user through exporting a saved composition
// to disk. Drives an `ExportCoordinator` and swaps content based on
// its phase (idle → rendering → completed | failed | cancelled).
//
// All visual values from Theme tokens. Native NavigationStack +
// SwiftUI sheets — no third-party UI.

import OSLog
import SwiftUI

struct ExportTrackSheet: View {

    @State private var coordinator: ExportCoordinator?
    @State private var durationMinutes: Int
    @State private var binauralVolume: Double
    @State private var ambientVolume: Double
    @State private var melodicVolume: Double
    @State private var bassVolume: Double
    @State private var drumsVolume: Double
    @State private var pathCopiedToast: Bool = false
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    init(composition: CustomComposition) {
        let coord = ExportCoordinator(composition: composition)
        _coordinator = State(initialValue: coord)
        _durationMinutes = State(
            initialValue: coord?.suggestedDurationMinutes ?? Theme.Compose.Defaults.durationMinutes
        )
        // Pre-fill mix sliders with the composition's stored values.
        // `task` below will overwrite these with the live engine's
        // current parameters when the sheet appears, so the export
        // matches what the user was just hearing.
        _binauralVolume = State(initialValue: composition.binauralVolume)
        _ambientVolume = State(initialValue: composition.ambientVolume)
        _melodicVolume = State(initialValue: composition.melodicVolume)
        // Bass and drums aren't on the composition; defaults from the
        // live engine via `task`. Until then a sensible neutral.
        _bassVolume = State(initialValue: 0.55)
        _drumsVolume = State(initialValue: 0.45)
    }

    private var modeAllowsRhythm: Bool {
        guard let mode = coordinator?.mode else { return false }
        return Theme.ModeInstrumentation.allowsRhythmStem(for: mode)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let coordinator {
                    content(coordinator: coordinator)
                } else {
                    invalidCompositionView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        coordinator?.cancel()
                        dismiss()
                    }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isRendering)
        .task {
            // Snapshot the live engine's current parameters once on
            // appear so the export sheet's mix defaults match what the
            // user was just hearing in the session. Mix Levels writes
            // straight to these atomics; nothing persists them back to
            // the composition, so this is the only source of truth.
            let p = dependencies.audioEngine.parameters
            binauralVolume = p.binauralVolume
            ambientVolume = p.ambientVolume
            melodicVolume = p.melodicVolume
            bassVolume = p.bassVolume
            drumsVolume = p.drumsVolume
            Logger.audio.info(
                "[Export Sheet] task snapshot — binaural=\(p.binauralVolume, format: .fixed(precision: 3)) ambient=\(p.ambientVolume, format: .fixed(precision: 3)) melodic=\(p.melodicVolume, format: .fixed(precision: 3)) bass=\(p.bassVolume, format: .fixed(precision: 3)) drums=\(p.drumsVolume, format: .fixed(precision: 3)) isPlaying=\(p.isPlaying ? "true" : "false", privacy: .public)"
            )
        }
    }

    private var invalidCompositionView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.Spacing.jumbo))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("This composition is missing a brain state and cannot be exported.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.pageMargin)
            Spacer()
        }
    }

    @ViewBuilder
    private func content(coordinator: ExportCoordinator) -> some View {
        switch coordinator.phase {
        case .idle:
            idleContent(coordinator: coordinator)
        case .rendering:
            ExportProgressView(progress: coordinator.progress) {
                coordinator.cancel()
                dismiss()
            }
        case .completed(let url):
            completedContent(url: url)
        case .failed(let error):
            failedContent(error: error)
        case .cancelled:
            // Coordinator only enters .cancelled when the user backs
            // out. The Cancel button already dismisses, so this branch
            // is effectively unreachable in normal flow — render an
            // empty state defensively.
            Color.clear.onAppear { dismiss() }
        }
    }

    private var isRendering: Bool {
        guard let coordinator else { return false }
        if case .rendering = coordinator.phase { return true }
        return false
    }

    // MARK: - Idle

    private func idleContent(coordinator: ExportCoordinator) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                Text(coordinator.compositionName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.lg)

                if coordinator.isAdaptive {
                    adaptiveNote
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Format")

                    HStack {
                        Text("WAV")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("Lossless")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(surfaceBackground)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    composerSectionLabel("Duration")

                    HStack {
                        Text("\(durationMinutes) min")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Stepper(
                            "Duration",
                            value: $durationMinutes,
                            in: 1...coordinator.maxDurationMinutes
                        )
                        .labelsHidden()
                    }
                    .padding(Theme.Spacing.lg)
                    .background(surfaceBackground)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                }

                mixSection

                Spacer(minLength: Theme.Spacing.xl)

                Button {
                    Logger.audio.info(
                        "[Export Sheet] Render tapped — sliders: binaural=\(binauralVolume, format: .fixed(precision: 3)) ambient=\(ambientVolume, format: .fixed(precision: 3)) melodic=\(melodicVolume, format: .fixed(precision: 3)) bass=\(bassVolume, format: .fixed(precision: 3)) drums=\(drumsVolume, format: .fixed(precision: 3))"
                    )
                    coordinator.start(
                        format: .wav,
                        durationMinutes: durationMinutes,
                        mix: RenderMix(
                            binauralVolume: binauralVolume,
                            ambientVolume: ambientVolume,
                            melodicVolume: melodicVolume,
                            bassVolume: bassVolume,
                            drumsVolume: drumsVolume
                        )
                    )
                } label: {
                    Text("Render")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Capsule().fill(Theme.Colors.accent))
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
    }

    private var adaptiveNote: some View {
        Text("Adaptive sessions export as a fixed-frequency version. Live sessions still adapt.")
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surfaceBackground)
            .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    // MARK: - Mix Section

    private var mixSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            composerSectionLabel("Mix")

            VStack(spacing: Theme.Spacing.lg) {
                mixSliderRow(label: "Binaural", value: $binauralVolume)
                mixSliderRow(label: "Ambient",  value: $ambientVolume)
                mixSliderRow(label: "Melodic",  value: $melodicVolume)
                if modeAllowsRhythm {
                    mixSliderRow(label: "Bass",  value: $bassVolume)
                    mixSliderRow(label: "Drums", value: $drumsVolume)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(surfaceBackground)
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }

    private func mixSliderRow(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Theme.Compose.Defaults.volumeLabelWidth, alignment: .leading)

            Slider(value: value, in: 0...1)
                .tint(Theme.Colors.accent)

            Text("\(Int((value.wrappedValue * 100).rounded()))")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .monospacedDigit()
                .frame(width: Theme.Spacing.xxxl, alignment: .trailing)
        }
    }

    // MARK: - Completed

    private func completedContent(url: URL) -> some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Theme.Spacing.jumbo))
                .foregroundStyle(Theme.Colors.accent)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Export ready")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(url.lastPathComponent)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
            }

            Spacer()

            ShareLink(item: url) {
                Text("Share or Save…")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(Capsule().fill(Theme.Colors.accent))
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            #if targetEnvironment(simulator)
            revealInFinderButton(url: url)
            #endif

            Button("Done") {
                dismiss()
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    // MARK: - Reveal in Finder (Simulator-only debug helper)

    #if targetEnvironment(simulator)
    @ViewBuilder
    private func revealInFinderButton(url: URL) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                copyPathForFinder(url)
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.surface)
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Theme.Colors.accent.opacity(Theme.Opacity.glassStroke),
                                        lineWidth: Theme.Radius.glassStroke
                                    )
                            )
                    )
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            if pathCopiedToast {
                Text("Path copied. In Finder, press ⇧⌘G then ⌘V.")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.accent)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Animation.standard, value: pathCopiedToast)
    }

    private func copyPathForFinder(_ url: URL) {
        UIPasteboard.general.string = url.path
        print("[Export] Reveal in Finder → \(url.path)")
        pathCopiedToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            pathCopiedToast = false
        }
    }
    #endif

    // MARK: - Failed

    private func failedContent(error: Error) -> some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.Spacing.jumbo))
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Export failed")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(error.localizedDescription)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(Theme.Typography.callout)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .background(Capsule().fill(Theme.Colors.accent))
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    // MARK: - Surface

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(
                        Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
    }
}
