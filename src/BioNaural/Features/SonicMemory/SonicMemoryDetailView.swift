// SonicMemoryDetailView.swift
// BioNaural
//
// Detail view for a single sonic memory. Shows the full description,
// emotional association, extracted parameters visualization, matched
// tags, and usage statistics. Includes destructive delete with
// confirmation.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SonicMemoryDetailView

struct SonicMemoryDetailView: View {

    let memory: SonicMemory

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    // MARK: - Derived Properties

    private var emotion: EmotionalAssociation? {
        EmotionalAssociation(rawValue: memory.emotionalAssociation)
    }

    private var emotionColor: Color {
        guard let emotion else { return Theme.Colors.accent }
        switch emotion {
        case .calm:      return Theme.Colors.relaxation
        case .focused:   return Theme.Colors.focus
        case .energized: return Theme.Colors.energize
        case .nostalgic: return Theme.Colors.sleep
        case .safe:      return Theme.Colors.signalCalm
        case .joyful:    return Theme.Colors.signalElevated
        }
    }

    /// Build a SonicParameters struct from the persisted model for the
    /// shared card component.
    private var parameters: SonicParameters {
        SonicParameters(
            warmth: memory.extractedWarmth,
            rhythm: memory.extractedRhythm,
            density: memory.extractedDensity,
            brightness: memory.extractedBrightness,
            tempo: memory.extractedTempo,
            preferredInstruments: memory.preferredInstruments,
            preferredAmbientTags: memory.preferredAmbientTags,
            emotionalAssociation: EmotionalTag(rawValue: memory.emotionalAssociation) ?? .calm,
            confidence: memory.biometricCorrelation ?? .zero
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                descriptionSection
                associationSection
                parametersSection
                statsSection
                deleteSection
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.canvas)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete Memory?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                deleteMemory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this sonic memory and its associated data. This action cannot be undone.")
        }
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Description")

            Text(memory.userDescription)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
    }

    // MARK: - Associations

    @ViewBuilder
    private var associationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Association")

            HStack(spacing: Theme.Spacing.sm) {
                // Emotion badge
                if let emotion {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: emotion.systemImageName)
                            .font(Theme.Typography.caption)

                        Text(emotion.displayName)
                            .font(Theme.Typography.callout)
                    }
                    .foregroundStyle(emotionColor)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        emotionColor.opacity(Theme.Opacity.light),
                        in: Capsule()
                    )
                }

                // Mode badge
                if let mode = memory.focusMode {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: mode.systemImageName)
                            .font(Theme.Typography.caption)

                        Text(mode.displayName)
                            .font(Theme.Typography.callout)
                    }
                    .foregroundStyle(Color.modeColor(for: mode))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        Color.modeColor(for: mode).opacity(Theme.Opacity.light),
                        in: Capsule()
                    )
                }
            }
        }
    }

    // MARK: - Parameters

    @ViewBuilder
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Sonic Profile")

            SonicParametersCard(parameters: parameters)
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader("Usage")

            HStack(spacing: Theme.Spacing.md) {
                statTile(
                    label: "Sessions",
                    value: "\(memory.sessionCount)"
                )

                statTile(
                    label: "Avg Score",
                    value: formattedScore
                )

                statTile(
                    label: "Last Used",
                    value: formattedLastUsed
                )
            }
        }
    }

    @ViewBuilder
    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(value)"))
    }

    private var formattedScore: String {
        guard let score = memory.averageSuccessScore else { return "\u{2014}" }
        return "\(Int(score * 100))%"
    }

    private var formattedLastUsed: String {
        guard let date = memory.lastUsed else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Delete

    @ViewBuilder
    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete Memory")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.stressCritical)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Theme.Colors.stressCritical.opacity(Theme.Opacity.subtle),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
                )
        }
        .padding(.top, Theme.Spacing.lg)
        .accessibilityLabel(Text("Delete this sonic memory"))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textTertiary)
            .textCase(.uppercase)
            .tracking(Theme.Typography.Tracking.uppercase)
    }

    private func deleteMemory() {
        modelContext.delete(memory)
        dismiss()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SonicMemoryDetailView") {
    NavigationStack {
        SonicMemoryDetailView(
            memory: SonicMemory(
                userDescription: "Rain on a tin roof at my grandmother's cabin in the mountains. " +
                    "The sound of drops hitting the metal, mixed with distant thunder.",
                extractedWarmth: 0.8,
                extractedRhythm: 0.4,
                extractedDensity: 0.6,
                extractedBrightness: 0.3,
                preferredInstruments: ["piano", "strings"],
                preferredAmbientTags: ["rain", "fire"],
                emotionalAssociation: EmotionalAssociation.nostalgic.rawValue,
                associatedMode: FocusMode.relaxation.rawValue,
                sessionCount: 12,
                averageSuccessScore: 0.78,
                lastUsed: Date().addingTimeInterval(-86400)
            )
        )
    }
    .preferredColorScheme(.dark)
}
#endif
