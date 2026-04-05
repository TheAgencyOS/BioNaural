// StudyTrackSetupView.swift
// BioNaural
//
// Three-step sheet flow for creating a new study-focused context track.
// Step 1: Name, calendar keywords, optional event date.
// Step 2: Mode, ambient sound, optional Sonic Memory link, duration.
// Step 3: Review summary and create.
// All values from Theme tokens. Native SwiftUI. Dark-first.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - Ambient Option

/// Descriptor for an ambient sound bed shown in the picker grid.
private struct AmbientOption: Identifiable {
    let id: String
    let label: String
    let systemImage: String
}

/// The available ambient options for the study track setup.
private let ambientOptions: [AmbientOption] = [
    AmbientOption(id: "rain", label: "Rain", systemImage: "cloud.rain.fill"),
    AmbientOption(id: "ocean", label: "Ocean", systemImage: "water.waves"),
    AmbientOption(id: "forest", label: "Forest", systemImage: "tree.fill"),
    AmbientOption(id: "fire", label: "Fire", systemImage: "flame.fill"),
    AmbientOption(id: "wind", label: "Wind", systemImage: "wind"),
    AmbientOption(id: "silence", label: "Silence", systemImage: "speaker.slash.fill")
]

/// The selectable session durations in minutes.
private let durationOptions: [Int] = [30, 60, 90, 120]

// MARK: - StudyTrackSetupView

struct StudyTrackSetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var step: Int = 0
    @State private var trackName: String = ""
    @State private var eventKeywords: String = ""
    @State private var selectedMode: FocusMode = .focus
    @State private var selectedAmbient: String?
    @State private var sessionDuration: Int = 60
    @State private var activeUntilDate: Date?
    @State private var showDatePicker: Bool = false
    @State private var useExistingSonicMemory: Bool = false
    @State private var selectedSonicMemoryID: UUID?

    @Query(sort: \SonicMemory.dateCreated, order: .reverse)
    private var sonicMemories: [SonicMemory]

    let onCreated: (ContextTrack) -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator

                ZStack {
                    switch step {
                    case 0:
                        stepOne
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    case 1:
                        stepTwo
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    default:
                        stepThree
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .leading)
                            ))
                    }
                }
                .animation(Theme.Animation.sheet, value: step)
            }
            .background(Theme.Colors.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(Theme.Animation.sheet) { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { Theme.Colors.canvas }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        index <= step
                            ? Theme.Colors.accent
                            : Theme.Colors.divider.opacity(Theme.Opacity.half)
                    )
                    .frame(
                        width: index == step
                            ? Theme.Spacing.sm
                            : Theme.Spacing.xs,
                        height: index == step
                            ? Theme.Spacing.sm
                            : Theme.Spacing.xs
                    )
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .animation(Theme.Animation.standard, value: step)
        .accessibilityHidden(true)
    }

    // MARK: - Step 1: What Are You Studying?

    private var stepOne: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                Text("What are you studying?")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Track name")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    TextField(
                        "Organic Chemistry, Bar Exam, Spanish Vocab",
                        text: $trackName
                    )
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Calendar keywords")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    TextField(
                        "exam, final, organic chemistry",
                        text: $eventKeywords
                    )
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

                    Text("We'll match these keywords against your calendar to suggest this track automatically.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                // Event date toggle + picker
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Toggle(isOn: $showDatePicker) {
                        Text("Set an event date")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .tint(Theme.Colors.accent)

                    if showDatePicker {
                        DatePicker(
                            "Event date",
                            selection: Binding(
                                get: { activeUntilDate ?? Date() },
                                set: { activeUntilDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .font(Theme.Typography.body)
                        .tint(Theme.Colors.accent)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(Theme.Animation.standard, value: showDatePicker)

                Spacer(minLength: Theme.Spacing.jumbo)

                nextButton(enabled: !trackName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Choose Your Sound

    private var stepTwo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                Text("Choose your sound")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Mode picker
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Mode")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(FocusMode.allCases) { mode in
                            modeCapsule(mode)
                        }
                    }
                }

                // Ambient picker
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Ambient sound")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(ambientOptions) { option in
                                ambientCard(option)
                            }
                        }
                    }
                }

                // Sonic Memory link
                if !sonicMemories.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Toggle(isOn: $useExistingSonicMemory) {
                            Text("Or use a Sonic Memory")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .tint(Theme.Colors.accent)

                        if useExistingSonicMemory {
                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(sonicMemories) { memory in
                                    sonicMemoryRow(memory)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(Theme.Animation.standard, value: useExistingSonicMemory)
                }

                // Duration picker
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Session duration")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Picker("Duration", selection: $sessionDuration) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text("This sonic signature stays consistent across all study sessions for maximum recall anchoring.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer(minLength: Theme.Spacing.jumbo)

                nextButton(enabled: true)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 3: Review & Create

    private var stepThree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                Text("Review & Create")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Summary card
                summaryCard

                // Science callout
                scienceCallout

                Spacer(minLength: Theme.Spacing.jumbo)

                createButton
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xl)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            summaryRow(label: "Track name", value: trackName)

            summaryRow(
                label: "Mode",
                value: selectedMode.displayName,
                color: Color.modeColor(for: selectedMode)
            )

            if let ambient = selectedAmbient {
                summaryRow(label: "Ambient", value: ambient.capitalized)
            }

            summaryRow(label: "Duration", value: "\(sessionDuration) min")

            if !parsedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Keywords")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    flowLayout(items: parsedKeywords)
                }
            }

            if let date = activeUntilDate, showDatePicker {
                summaryRow(
                    label: "Event date",
                    value: date.formatted(date: .abbreviated, time: .omitted)
                )
            }

            if useExistingSonicMemory, let memoryID = selectedSonicMemoryID,
               let memory = sonicMemories.first(where: { $0.id == memoryID }) {
                summaryRow(label: "Sonic Memory", value: memory.userDescription)
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Science Callout

    private var scienceCallout: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.accent)

                Text("State-Dependent Learning")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text("Studying in a consistent auditory environment improves recall by 15\u{2013}20%. " +
                "Your brain will associate this sound with the material.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Subviews

    private func modeCapsule(_ mode: FocusMode) -> some View {
        let isSelected = selectedMode == mode
        let modeColor = Color.modeColor(for: mode)
        let isRecommended = mode == .focus

        return Button {
            selectedMode = mode
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: mode.systemImageName)
                        .font(Theme.Typography.small)

                    Text(mode.displayName)
                        .font(Theme.Typography.caption)
                }

                if isRecommended {
                    Text("Recommended")
                        .font(Theme.Typography.small)
                        .foregroundStyle(modeColor.opacity(Theme.Opacity.accentStrong))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(isSelected ? modeColor : Theme.Colors.textSecondary)
            .background(
                isSelected
                    ? modeColor.opacity(Theme.Opacity.accentLight)
                    : Theme.Colors.surface
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? modeColor.opacity(Theme.Opacity.medium)
                            : Color.clear,
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) mode\(isRecommended ? ", recommended" : "")")
    }

    private func ambientCard(_ option: AmbientOption) -> some View {
        let isSelected = selectedAmbient == option.id

        return Button {
            withAnimation(Theme.Animation.standard) {
                selectedAmbient = isSelected ? nil : option.id
            }
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: option.systemImage)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.accent
                            : Theme.Colors.textSecondary
                    )

                Text(option.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.textPrimary
                            : Theme.Colors.textTertiary
                    )
            }
            .frame(width: Theme.Spacing.mega, height: Theme.Spacing.mega)
            .background(
                isSelected
                    ? Theme.Colors.accent.opacity(Theme.Opacity.accentLight)
                    : Theme.Colors.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .strokeBorder(
                        isSelected
                            ? Theme.Colors.accent.opacity(Theme.Opacity.medium)
                            : Color.clear,
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label)\(isSelected ? ", selected" : "")")
    }

    private func sonicMemoryRow(_ memory: SonicMemory) -> some View {
        let isSelected = selectedSonicMemoryID == memory.id

        return Button {
            withAnimation(Theme.Animation.standard) {
                selectedSonicMemoryID = isSelected ? nil : memory.id
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: memory.emotion?.systemImageName ?? "waveform")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(
                        isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary
                    )
                    .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                    .background(
                        isSelected
                            ? Theme.Colors.accent.opacity(Theme.Opacity.accentLight)
                            : Theme.Colors.surfaceRaised
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(memory.userDescription)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    if let emotion = memory.emotion {
                        Text(emotion.displayName)
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(memory.userDescription)\(isSelected ? ", selected" : "")")
    }

    private func summaryRow(
        label: String,
        value: String,
        color: Color = Theme.Colors.textPrimary
    ) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)

            Spacer()

            Text(value)
                .font(Theme.Typography.callout)
                .foregroundStyle(color)
        }
    }

    /// Simple horizontal wrap layout for keyword pills.
    private func flowLayout(items: [String]) -> some View {
        let rows = buildRows(items: items)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(rows[rowIndex], id: \.self) { item in
                        keywordPill(item)
                    }
                }
            }
        }
    }

    private func keywordPill(_ keyword: String) -> some View {
        Text(keyword)
            .font(Theme.Typography.small)
            .foregroundStyle(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.Colors.accent.opacity(Theme.Opacity.accentLight))
            .clipShape(Capsule())
    }

    // MARK: - Buttons

    private func nextButton(enabled: Bool) -> some View {
        Button {
            withAnimation(Theme.Animation.sheet) { step += 1 }
        } label: {
            Text("Next")
                .font(Theme.Typography.headline)
                .foregroundStyle(
                    enabled ? Theme.Colors.textOnAccent : Theme.Colors.textTertiary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(
                    enabled
                        ? Theme.Colors.accent
                        : Theme.Colors.surface
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
        .disabled(!enabled)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private var createButton: some View {
        Button(action: createTrack) {
            Text("Create Study Track")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Helpers

    private var parsedKeywords: [String] {
        eventKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Partition keywords into rows (simple heuristic: max 4 per row).
    private func buildRows(items: [String], maxPerRow: Int = 4) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count >= maxPerRow {
                rows.append(current)
                current = []
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    // MARK: - Create Track

    private func createTrack() {
        // Compute activeUntil: 7 days after event date if set
        var computedActiveUntil: Date?
        if showDatePicker, let eventDate = activeUntilDate {
            computedActiveUntil = Calendar.current.date(
                byAdding: .day,
                value: TrackManagerConfig.autoArchiveDaysAfterEvent,
                to: eventDate
            )
        }

        let track = ContextTrack(
            name: trackName.trimmingCharacters(in: .whitespaces),
            purpose: TrackPurpose.study.rawValue,
            linkedEventKeywords: parsedKeywords,
            lockedAmbientBedID: selectedAmbient,
            sonicMemoryID: useExistingSonicMemory ? selectedSonicMemoryID : nil,
            mode: selectedMode.rawValue,
            activeUntil: computedActiveUntil
        )

        modelContext.insert(track)
        onCreated(track)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Study Track Setup") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StudyTrackSetupView { _ in }
        }
        .preferredColorScheme(.dark)
}
