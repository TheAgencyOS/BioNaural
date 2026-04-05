// SonicMemoryInputView.swift
// BioNaural
//
// Sheet modal for describing a meaningful sound memory. The user
// progresses through three vertical steps: describe, feel, preview.
// Extracted sonic parameters drive personalized session audio.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SonicMemoryInputView

struct SonicMemoryInputView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var description: String = ""
    @State private var selectedEmotion: EmotionalTag? = nil
    @State private var selectedMode: FocusMode? = nil
    @State private var extractedParameters: SonicParameters? = nil
    @State private var isExtracting = false

    let onSave: (SonicMemory) -> Void

    // MARK: - Extractor

    private let extractor = SonicParameterExtractor()

    // MARK: - Step Progression

    private var showStep2: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showStep3: Bool {
        selectedEmotion != nil && extractedParameters != nil
    }

    private var canSave: Bool {
        showStep3
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxl) {
                    describeStep

                    if showStep2 {
                        feelStep
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if showStep3 {
                        previewStep
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if canSave {
                        saveButton
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.vertical, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.Colors.canvas)
            .navigationTitle("New Sonic Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .animation(Theme.Animation.sheet, value: showStep2)
            .animation(Theme.Animation.sheet, value: showStep3)
            .animation(Theme.Animation.sheet, value: canSave)
        }
    }

    // MARK: - Step 1: Describe

    @ViewBuilder
    private var describeStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Describe your sound")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("A place, a song, a memory \u{2014} anything with a sound you connect to")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)

            TextEditor(text: $description)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Theme.Spacing.mega + Theme.Spacing.xxxl)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(Theme.Colors.divider, lineWidth: Theme.Radius.glassStroke)
                )
                .onChange(of: description) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        runExtraction(for: newValue)
                    } else {
                        extractedParameters = nil
                    }
                }
                .accessibilityLabel(Text("Sound description"))
                .accessibilityHint(Text("Describe a sound that means something to you"))

            exampleChips
        }
    }

    @ViewBuilder
    private var exampleChips: some View {
        let examples = [
            "Rain on a tin roof",
            "Lo-fi beats in a coffee shop",
            "The hum of a quiet library"
        ]

        FlowLayout(spacing: Theme.Spacing.sm) {
            ForEach(examples, id: \.self) { example in
                Button {
                    description = example
                    runExtraction(for: example)
                } label: {
                    Text(example)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            Theme.Colors.surface,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(Theme.Colors.divider, lineWidth: Theme.Radius.glassStroke)
                        )
                }
                .accessibilityLabel(Text("Example: \(example)"))
                .accessibilityHint(Text("Tap to use this as your description"))
            }
        }
    }

    // MARK: - Step 2: Feel

    @ViewBuilder
    private var feelStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("How does it make you feel?")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            emotionGrid

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Best for...")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(Theme.Typography.Tracking.uppercase)

                modeRow
            }
        }
    }

    @ViewBuilder
    private var emotionGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: Theme.Spacing.sm),
            GridItem(.flexible(), spacing: Theme.Spacing.sm),
            GridItem(.flexible(), spacing: Theme.Spacing.sm)
        ]

        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(EmotionalTag.allCases, id: \.self) { tag in
                emotionCapsule(tag)
            }
        }
    }

    @ViewBuilder
    private func emotionCapsule(_ tag: EmotionalTag) -> some View {
        let isSelected = selectedEmotion == tag

        Button {
            withAnimation(Theme.Animation.standard) {
                selectedEmotion = tag
            }
        } label: {
            Text(tag.displayName)
                .font(Theme.Typography.callout)
                .foregroundStyle(
                    isSelected
                        ? Theme.Colors.textOnAccent
                        : Theme.Colors.textPrimary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    isSelected ? Theme.Colors.accent : Theme.Colors.surface,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Theme.Colors.divider,
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(tag.displayName))
    }

    @ViewBuilder
    private var modeRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(FocusMode.allCases) { mode in
                modeCapsule(mode)
            }
        }
    }

    @ViewBuilder
    private func modeCapsule(_ mode: FocusMode) -> some View {
        let isSelected = selectedMode == mode

        Button {
            withAnimation(Theme.Animation.standard) {
                selectedMode = isSelected ? nil : mode
            }
        } label: {
            Text(mode.displayName)
                .font(Theme.Typography.caption)
                .foregroundStyle(
                    isSelected
                        ? Theme.Colors.textOnAccent
                        : Theme.Colors.textSecondary
                )
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    isSelected
                        ? Color.modeColor(for: mode)
                        : Theme.Colors.surface,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Theme.Colors.divider,
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(mode.displayName))
        .accessibilityHint(Text(isSelected ? "Tap to deselect" : "Tap to associate with \(mode.displayName) mode"))
    }

    // MARK: - Step 3: Preview

    @ViewBuilder
    private var previewStep: some View {
        if let params = extractedParameters {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("What we heard")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                SonicParametersCard(parameters: params)

                Text("This is what we heard in your description")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Save Button

    @ViewBuilder
    private var saveButton: some View {
        Button {
            saveMemory()
        } label: {
            Text("Save Memory")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
        .padding(.top, Theme.Spacing.lg)
        .accessibilityLabel(Text("Save sonic memory"))
    }

    // MARK: - Extraction

    private func runExtraction(for text: String) {
        guard !isExtracting else { return }
        isExtracting = true

        Task {
            let params = await extractor.extract(from: text)
            await MainActor.run {
                withAnimation(Theme.Animation.sheet) {
                    extractedParameters = params
                    // Auto-select the emotion from extraction if user hasn't chosen yet
                    if selectedEmotion == nil {
                        selectedEmotion = params.emotionalAssociation
                    }
                }
                isExtracting = false
            }
        }
    }

    // MARK: - Save

    private func saveMemory() {
        guard let params = extractedParameters,
              let emotion = selectedEmotion else { return }

        let memory = SonicMemory(
            userDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            extractedWarmth: params.warmth,
            extractedRhythm: params.rhythm,
            extractedDensity: params.density,
            extractedBrightness: params.brightness,
            extractedTempo: params.tempo,
            preferredInstruments: params.preferredInstruments,
            preferredAmbientTags: params.preferredAmbientTags,
            emotionalAssociation: emotion.rawValue,
            associatedMode: selectedMode?.rawValue
        )

        modelContext.insert(memory)
        onSave(memory)
        dismiss()
    }
}

// MARK: - SonicParametersCard

/// Reusable card showing extracted sonic parameters as horizontal bars
/// plus matched instrument and ambient tags. Used in both the input
/// preview (Step 3) and the detail view.
struct SonicParametersCard: View {

    let parameters: SonicParameters

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            parameterBars

            if !parameters.preferredInstruments.isEmpty {
                tagSection(title: "Instruments", tags: parameters.preferredInstruments)
            }

            if !parameters.preferredAmbientTags.isEmpty {
                tagSection(title: "Ambient", tags: parameters.preferredAmbientTags)
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var parameterBars: some View {
        let dimensions: [(String, Double)] = [
            ("Warmth", parameters.warmth),
            ("Rhythm", parameters.rhythm),
            ("Density", parameters.density),
            ("Brightness", parameters.brightness)
        ]

        VStack(spacing: Theme.Spacing.md) {
            ForEach(Array(dimensions.enumerated()), id: \.offset) { index, dimension in
                ParameterBarRow(label: dimension.0, value: dimension.1)
                    .animation(
                        Theme.Animation.staggeredFadeIn(index: index),
                        value: dimension.1
                    )
            }
        }
    }

    @ViewBuilder
    private func tagSection(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(Theme.Typography.Tracking.uppercase)

            FlowLayout(spacing: Theme.Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            Theme.Colors.surfaceRaised,
                            in: Capsule()
                        )
                }
            }
        }
    }
}

// MARK: - ParameterBarRow

/// Single horizontal bar showing a labeled 0-1 value with accent fill.
private struct ParameterBarRow: View {

    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                        .frame(height: Theme.Spacing.xxs)

                    Capsule()
                        .fill(Theme.Colors.accent)
                        .frame(
                            width: geometry.size.width * value,
                            height: Theme.Spacing.xxs
                        )
                }
            }
            .frame(height: Theme.Spacing.xxs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(Int(value * 100)) percent"))
    }
}

// MARK: - FlowLayout

/// Simple horizontal wrapping layout for tags and chips.
/// Items flow left-to-right and wrap to the next line when they
/// exceed the available width.
private struct FlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = arrange(
            proposal: proposal,
            subviews: subviews
        )
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(
            proposal: proposal,
            subviews: subviews
        )

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { continue }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = .zero
        var currentY: CGFloat = .zero
        var lineHeight: CGFloat = .zero
        var totalWidth: CGFloat = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > .zero {
                currentX = .zero
                currentY += lineHeight + spacing
                lineHeight = .zero
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SonicMemoryInputView") {
    SonicMemoryInputView { _ in }
        .preferredColorScheme(.dark)
}
#endif
