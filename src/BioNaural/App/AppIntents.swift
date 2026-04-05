// AppIntents.swift
// BioNaural
//
// App Intents for Siri and Shortcuts integration. Provides StartSessionIntent,
// StopSessionIntent, and FocusModeEntity to allow users to control BioNaural
// sessions via voice commands and the Shortcuts app.

import AppIntents
import BioNauralShared
import OSLog
import SwiftData
import SwiftUI

// MARK: - FocusModeEntity

/// An App Entity representing the four BioNaural session modes.
///
/// Bridges the shared `FocusMode` enum into the AppIntents system so Siri
/// and Shortcuts can present and resolve mode selections.
struct FocusModeEntity: AppEntity {

    // MARK: - Properties

    /// The underlying `FocusMode` raw value string (e.g. "focus", "relaxation", "sleep", "energize").
    var id: String

    /// Human-readable name shown in Siri dialogs and the Shortcuts editor.
    var name: String

    // MARK: - AppEntity Conformance

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Session Mode")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = FocusModeEntityQuery()

    // MARK: - Factory

    /// Creates a `FocusModeEntity` from a `FocusMode` enum value.
    /// All display strings are derived from the shared model — no hardcoded values.
    init(from mode: FocusMode) {
        self.id = mode.rawValue
        self.name = mode.displayName
    }

    /// Memberwise initializer required by the framework.
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - FocusModeEntityQuery

/// Query provider that resolves `FocusModeEntity` values from the `FocusMode` enum.
struct FocusModeEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [FocusModeEntity] {
        FocusMode.allCases
            .filter { identifiers.contains($0.rawValue) }
            .map { FocusModeEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [FocusModeEntity] {
        FocusMode.allCases.map { FocusModeEntity(from: $0) }
    }

    func defaultResult() async -> FocusModeEntity? {
        FocusModeEntity(from: .focus)
    }
}

// MARK: - StartSessionIntent

/// Starts a BioNaural session with the specified mode and optional duration.
/// When duration is omitted, the user's preferred duration from their profile
/// is used. The intent launches the app into the session screen.
struct StartSessionIntent: AppIntent {

    static let title: LocalizedStringResource = "Start BioNaural Session"

    static let description: IntentDescription = IntentDescription(
        "Starts a binaural beats session in BioNaural with the selected mode and duration.",
        categoryName: "Session"
    )

    static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "Session Mode", description: "The type of session to start.")
    var sessionType: FocusModeEntity

    @Parameter(
        title: "Duration (minutes)",
        description: "How long the session should last. Uses your preferred duration if not set.",
        requestValueDialog: "How many minutes should the session last?"
    )
    var duration: Int?

    // MARK: - Phrases

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$sessionType) session") {
            \.$duration
        }
    }

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let focusMode = FocusMode(rawValue: sessionType.id) else {
            throw IntentError.invalidMode
        }

        // Resolve duration: explicit parameter > user profile > mode default.
        let resolvedDuration = try await resolvedDurationMinutes(for: focusMode)

        // Post a notification that the session UI observes to begin playback.
        let userInfo: [String: Any] = [
            SessionLaunchKeys.mode: focusMode.rawValue,
            SessionLaunchKeys.durationMinutes: resolvedDuration,
        ]

        NotificationCenter.default.post(
            name: .startSessionFromIntent,
            object: nil,
            userInfo: userInfo
        )

        let displayName = focusMode.displayName
        return .result(
            dialog: "Starting \(displayName) session for \(resolvedDuration) minutes."
        )
    }

    // MARK: - Duration Resolution

    /// Resolves the session duration by checking the explicit parameter first,
    /// then falling back to the user's profile preference.
    private func resolvedDurationMinutes(for mode: FocusMode) async throws -> Int {
        if let explicitDuration = duration, explicitDuration > 0 {
            return explicitDuration
        }

        // Attempt to read from the user's SwiftData profile.
        if let profileDuration = try? await fetchPreferredDuration() {
            return profileDuration
        }

        // Final fallback: use the default from UserProfile.
        return UserProfile.defaultDurationMinutes
    }

    /// Queries SwiftData for the current user profile's preferred duration.
    @MainActor
    private func fetchPreferredDuration() async throws -> Int? {
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

// MARK: - StopSessionIntent

/// Stops any currently active BioNaural session.
struct StopSessionIntent: AppIntent {

    static let title: LocalizedStringResource = "Stop BioNaural Session"

    static let description: IntentDescription = IntentDescription(
        "Stops the currently running BioNaural session.",
        categoryName: "Session"
    )

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(
            name: .stopSessionFromIntent,
            object: nil
        )
        return .result(dialog: "Session stopped.")
    }
}

// MARK: - Intent Error

/// Errors thrown by BioNaural App Intents.
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidMode

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidMode:
            return "The selected session mode is not recognized."
        }
    }
}

// MARK: - Session Launch Keys

/// Keys used in NotificationCenter userInfo dictionaries for intent-driven
/// session launches. Centralizes key strings to prevent typos.
enum SessionLaunchKeys {
    static let mode = "bionaural.intent.session.mode"
    static let durationMinutes = "bionaural.intent.session.durationMinutes"
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted by `StartSessionIntent` to request the app begin a session.
    static let startSessionFromIntent = Notification.Name("bionaural.startSessionFromIntent")
    /// Posted by `StopSessionIntent` to request the app end the current session.
    static let stopSessionFromIntent = Notification.Name("bionaural.stopSessionFromIntent")
}

// MARK: - Intent Donation

/// Donates a `StartSessionIntent` to Siri so it can learn usage patterns
/// and proactively suggest sessions via Spotlight and Siri Suggestions.
enum IntentDonation {

    static func donateStartSession(mode: FocusMode, durationMinutes: Int) {
        let intent = StartSessionIntent()
        intent.sessionType = FocusModeEntity(from: mode)
        intent.duration = durationMinutes

        Task {
            do {
                try await IntentDonationManager.shared.donate(intent: intent)
                Logger.intents.debug("Donated StartSessionIntent: \(mode.rawValue), \(durationMinutes) min")
            } catch {
                Logger.intents.error("Intent donation failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UserProfile Default Duration

extension UserProfile {
    /// The default session duration in minutes, matching the init parameter default.
    /// Used as a fallback when no profile exists in the database.
    static let defaultDurationMinutes: Int = Theme.Compose.Defaults.durationMinutes
}
