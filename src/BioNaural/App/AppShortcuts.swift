// AppShortcuts.swift
// BioNaural
//
// Registers BioNaural's App Intents with the system so they appear
// automatically in the Shortcuts app and Siri suggestions.
// Uses the AppShortcutsProvider protocol (iOS 16+).

import AppIntents

/// Provides pre-built shortcuts that appear in the Shortcuts app
/// without any user configuration. Each shortcut maps to an App Intent
/// and includes Siri phrases for voice activation.
struct BioNauralShortcuts: AppShortcutsProvider {

    /// The shortcuts surfaced to the system. Each entry defines a phrase
    /// set, a short title for the Shortcuts gallery, and a system image.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start a session in \(.applicationName)",
                "Start a focus session in \(.applicationName)",
                "Begin \(.applicationName) session",
                "Start relaxation in \(.applicationName)",
                "Start sleep in \(.applicationName)"
            ],
            shortTitle: "Start Session",
            systemImageName: "waveform.circle.fill"
        )

        AppShortcut(
            intent: StopSessionIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "End my \(.applicationName) session",
                "Stop my session in \(.applicationName)"
            ],
            shortTitle: "Stop Session",
            systemImageName: "stop.circle.fill"
        )
    }
}
