// FocusFilterSettingsView.swift
// BioNaural
//
// Settings screen where users configure which iOS Focus modes map to
// which BioNaural session modes. Uses @AppStorage for persistence with
// keys from FocusFilterConstants. All values from Theme tokens.

import SwiftUI
import BioNauralShared

// MARK: - FocusFilterSettingsView

struct FocusFilterSettingsView: View {

    // MARK: - Focus Mode Mappings (persisted via @AppStorage)

    @AppStorage(FocusFilterConstants.workMappingKey)
    private var workMapping: String = FocusMode.focus.rawValue

    @AppStorage(FocusFilterConstants.personalMappingKey)
    private var personalMapping: String = FocusMode.relaxation.rawValue

    @AppStorage(FocusFilterConstants.sleepMappingKey)
    private var sleepMapping: String = FocusMode.sleep.rawValue

    @AppStorage(FocusFilterConstants.doNotDisturbMappingKey)
    private var doNotDisturbMapping: String = FocusMode.relaxation.rawValue

    @AppStorage(FocusFilterConstants.fitnessMappingKey)
    private var fitnessMapping: String = FocusMode.energize.rawValue

    // MARK: - Behavior Toggles

    @AppStorage(FocusFilterConstants.autoSuggestEnabledKey)
    private var autoSuggestEnabled: Bool = true

    @AppStorage(FocusFilterConstants.autoStartEnabledKey)
    private var autoStartEnabled: Bool = false

    // MARK: - iOS Focus Definitions

    private let iosFocusModes: [IOSFocusDefinition] = [
        IOSFocusDefinition(name: "Work", systemImage: "briefcase.fill", defaultMode: .focus),
        IOSFocusDefinition(name: "Personal", systemImage: "person.fill", defaultMode: .relaxation),
        IOSFocusDefinition(name: "Sleep", systemImage: "bed.double.fill", defaultMode: .sleep),
        IOSFocusDefinition(name: "Do Not Disturb", systemImage: "moon.fill", defaultMode: .relaxation),
        IOSFocusDefinition(name: "Fitness", systemImage: "figure.run", defaultMode: .energize)
    ]

    // MARK: - Body

    var body: some View {
        List {
            mappingsSection
            behaviorSection
            aboutSection
        }
        .navigationTitle("Focus Filters")
        .navigationBarTitleDisplayMode(.large)
        .font(Theme.Typography.body)
        .foregroundStyle(Theme.Colors.textPrimary)
    }

    // MARK: - Mappings Section

    /// Pairs each iOS Focus definition with its corresponding @AppStorage binding,
    /// avoiding hardcoded array indices.
    private var mappingBindings: [(definition: IOSFocusDefinition, selection: Binding<String>)] {
        [
            (iosFocusModes[IOSFocusIndex.work], $workMapping),
            (iosFocusModes[IOSFocusIndex.personal], $personalMapping),
            (iosFocusModes[IOSFocusIndex.sleep], $sleepMapping),
            (iosFocusModes[IOSFocusIndex.doNotDisturb], $doNotDisturbMapping),
            (iosFocusModes[IOSFocusIndex.fitness], $fitnessMapping)
        ]
    }

    private var mappingsSection: some View {
        Section {
            ForEach(Array(mappingBindings.enumerated()), id: \.offset) { _, pair in
                mappingRow(
                    definition: pair.definition,
                    selection: pair.selection
                )
            }
        } header: {
            Text("Focus Mode Mappings")
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)
        } footer: {
            Text("When an iOS Focus activates, BioNaural suggests the mapped session mode.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        Section {
            Toggle(
                "Auto-suggest session",
                isOn: $autoSuggestEnabled
            )
            .accessibilityLabel("Automatically suggest a session when a Focus mode activates")

            Toggle(
                "Auto-start session",
                isOn: $autoStartEnabled
            )
            .accessibilityLabel("Automatically start a session when a Focus mode activates")

            if autoStartEnabled {
                Text("Sessions will begin immediately when a mapped Focus mode activates. You can always stop from the Lock Screen or notification.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        } header: {
            Text("Behavior")
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            Label {
                Text("Focus Filter runs on-device. BioNaural only sees which Focus mode is active, not your notification settings.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .accessibilityLabel(
                "Privacy: Focus Filter runs on-device. BioNaural only sees which Focus mode is active, not your notification settings."
            )
        } header: {
            Text("Privacy")
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Mapping Row

extension FocusFilterSettingsView {

    /// A single row mapping an iOS Focus mode to a BioNaural session mode.
    /// Shows the iOS Focus icon, name, and a picker for the BioNaural mode.
    private func mappingRow(
        definition: IOSFocusDefinition,
        selection: Binding<String>
    ) -> some View {
        let resolvedMode = FocusMode(rawValue: selection.wrappedValue)
        let tintColor = resolvedMode.map { Color.modeColor(for: $0) } ?? Theme.Colors.textTertiary

        return HStack(spacing: Theme.Spacing.md) {
            // iOS Focus icon
            Circle()
                .fill(tintColor.opacity(Theme.Opacity.dim))
                .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                .overlay(
                    Image(systemName: definition.systemImage)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(tintColor)
                )

            // iOS Focus name
            Text(definition.name)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer(minLength: 0)

            // BioNaural mode picker
            Picker("", selection: selection) {
                Text("None")
                    .tag("")

                ForEach(FocusMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImageName)
                        .tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .tint(tintColor)
            .accessibilityLabel("\(definition.name) Focus maps to")
            .accessibilityValue(resolvedMode?.displayName ?? "None")
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.name) Focus mode mapped to \(resolvedMode?.displayName ?? "None")")
    }
}

// MARK: - iOS Focus Definition

/// Defines an iOS Focus mode for display in the settings list.
/// Each definition carries the Focus name, its SF Symbol, and the
/// default BioNaural mode suggestion.
struct IOSFocusDefinition {

    /// Display name of the iOS Focus mode (e.g. "Work", "Sleep").
    let name: String

    /// SF Symbol name for the iOS Focus mode icon.
    let systemImage: String

    /// The default BioNaural mode to suggest for this iOS Focus.
    let defaultMode: FocusMode
}

// MARK: - iOS Focus Index Constants

/// Named indices into the `iosFocusModes` array, replacing magic-number subscripts.
enum IOSFocusIndex {
    static let work = 0
    static let personal = 1
    static let sleep = 2
    static let doNotDisturb = 3
    static let fitness = 4
}

// MARK: - Preview

#Preview("Focus Filter Settings") {
    NavigationStack {
        FocusFilterSettingsView()
    }
    .preferredColorScheme(.dark)
}
