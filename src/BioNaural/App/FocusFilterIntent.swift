// FocusFilterIntent.swift
// BioNaural
//
// SetFocusFilterIntent integration that makes BioNaural appear in
// iOS Focus mode settings. When the user configures a Focus filter
// for BioNaural and enables autoStart, the app automatically launches
// a session when that iOS Focus mode activates.

import AppIntents
import BioNauralShared
import SwiftData

/// A Focus Filter that allows BioNaural to respond to iOS Focus mode changes.
///
/// Users configure this in Settings > Focus > [Mode] > Focus Filters > BioNaural.
/// When the associated iOS Focus activates:
/// - If `autoStart` is enabled, a session begins automatically using the
///   configured `sessionType`.
/// - If `autoStart` is disabled, no action is taken (the filter is dormant).
struct BioNauralFocusFilter: SetFocusFilterIntent {

    // MARK: - Display

    static let title: LocalizedStringResource = "BioNaural Session Settings"

    static let description: IntentDescription? = IntentDescription(
        "Configure BioNaural to automatically start a session when this Focus mode activates.",
        categoryName: "Session"
    )

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "BioNaural Session Settings",
            subtitle: autoStart
                ? "Auto-starts \(sessionType?.name ?? "a") session"
                : "No auto-start configured",
            image: .init(systemName: "waveform.circle.fill")
        )
    }

    // MARK: - Parameters

    @Parameter(
        title: "Auto-Start Session",
        description: "Automatically begin a BioNaural session when this Focus activates.",
        default: false
    )
    var autoStart: Bool

    @Parameter(
        title: "Session Mode",
        description: "The type of session to auto-start."
    )
    var sessionType: FocusModeEntity?

    // MARK: - Perform

    /// Called by the system when the associated iOS Focus mode activates or deactivates.
    @MainActor
    func perform() async throws -> some IntentResult {
        guard autoStart else {
            return .result()
        }

        // Resolve the session mode. Fall back to the user's preferred mode
        // if no explicit mode was configured in the Focus filter.
        let resolvedMode: FocusMode
        if let entityID = sessionType?.id, let mode = FocusMode(rawValue: entityID) {
            resolvedMode = mode
        } else {
            resolvedMode = try await preferredModeFromProfile() ?? .focus
        }

        // Resolve duration from the user profile.
        let resolvedDuration = try await preferredDurationFromProfile()
            ?? UserProfile.defaultDurationMinutes

        let userInfo: [String: Any] = [
            SessionLaunchKeys.mode: resolvedMode.rawValue,
            SessionLaunchKeys.durationMinutes: resolvedDuration,
        ]

        NotificationCenter.default.post(
            name: .startSessionFromIntent,
            object: nil,
            userInfo: userInfo
        )

        return .result()
    }

    // MARK: - Profile Resolution

    /// Reads the user's preferred FocusMode from the SwiftData profile.
    @MainActor
    private func preferredModeFromProfile() throws -> FocusMode? {
        let container = try ModelContainer(
            for: UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        return profiles.first?.focusMode
    }

    @MainActor
    private func preferredDurationFromProfile() throws -> Int? {
        let container = try ModelContainer(
            for: UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        return profiles.first?.preferredDurationMinutes
    }
}
