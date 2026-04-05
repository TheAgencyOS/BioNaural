// BioNauralFocusFilter.swift
// BioNaural
//
// SetFocusFilterIntent integration that enables BioNaural to respond to
// iOS Focus mode changes. When the user maps an iOS Focus (Work, Sleep,
// Personal, etc.) to a BioNaural session mode, activating that Focus
// writes the mapping to the shared app-group UserDefaults and posts a
// Darwin notification so the running app can show a suggestion card.
//
// This file is separate from the existing FocusFilterIntent.swift (which
// handles auto-start) — this focuses on *suggestion* and *mapping* for
// the Focus Filter settings UI.

import AppIntents
import BioNauralShared
import OSLog

// MARK: - FocusFilterConstants

/// Centralizes all string keys used by the Focus Filter system.
/// Prevents typos and provides a single place to audit persistence keys.
enum FocusFilterConstants {

    /// App group suite name for cross-process UserDefaults access.
    static let appGroupSuite = "group.com.bionaural.shared"

    /// Darwin notification name posted when a Focus filter activates,
    /// allowing the running app to react without polling.
    static let darwinNotificationName = "com.bionaural.focusFilter.activated"

    // MARK: - UserDefaults Keys

    /// The raw value of the suggested `FocusMode` written by the Focus filter.
    static let activeModeKey = "focusFilter.activeMode"

    /// Whether the Focus filter that just activated had auto-start enabled.
    static let autoStartKey = "focusFilter.autoStart"

    /// The suggested session duration in minutes from the Focus filter.
    static let durationMinutesKey = "focusFilter.durationMinutes"

    /// Timestamp of the last Focus filter activation (for staleness checks).
    static let activationTimestampKey = "focusFilter.activationTimestamp"

    // MARK: - Settings Keys (used by FocusFilterSettingsView)

    static let mappingKeyPrefix = "focusFilter.mapping."
    static let autoSuggestEnabledKey = "focusFilter.autoSuggestEnabled"
    static let autoStartEnabledKey = "focusFilter.autoStartEnabled"

    // MARK: - Thresholds

    /// How long (in seconds) before a Focus filter suggestion is considered stale.
    static let suggestionStalenessSeconds: TimeInterval = 300

    // MARK: - iOS Focus Mapping Keys

    static let workMappingKey = "focusFilter.mapping.work"
    static let personalMappingKey = "focusFilter.mapping.personal"
    static let sleepMappingKey = "focusFilter.mapping.sleep"
    static let doNotDisturbMappingKey = "focusFilter.mapping.doNotDisturb"
    static let fitnessMappingKey = "focusFilter.mapping.fitness"
}

// MARK: - FocusModeEntity (Focus Filter Variant)

/// AppEntity wrapping `FocusMode` for the Focus Filter Intents system.
///
/// This mirrors the existing `FocusModeEntity` in AppIntents.swift but
/// adds `systemImageName` to the display representation for richer
/// rendering in the Settings > Focus > BioNaural configuration sheet.
///
/// Note: Because the AppIntents framework requires unique `AppEntity`
/// types per intent context, and the existing `FocusModeEntity` is
/// already registered for Shortcuts, we reuse the same type here.
/// The `BioNauralFocusFilter` references `FocusModeEntity` from
/// AppIntents.swift directly.

// MARK: - BioNauralFocusFilter

/// A Focus Filter that maps an iOS Focus mode to a BioNaural session mode.
///
/// Users configure this in Settings > Focus > [Mode] > Focus Filters > BioNaural.
/// When the associated iOS Focus activates, the filter:
/// 1. Writes the selected mode to the shared app-group UserDefaults.
/// 2. Posts a Darwin notification so the app can show a suggestion card.
/// 3. Optionally auto-starts a session if the user enabled that option.
///
/// This extends the existing `BioNauralFocusFilter` in FocusFilterIntent.swift
/// by adding suggestion-card support alongside the existing auto-start path.
/// To avoid duplicate type definitions, the additional logic is provided as
/// an extension to the existing intent.
extension BioNauralFocusFilter {

    // MARK: - Suggestion Writing

    /// Writes the current Focus filter configuration to the shared app-group
    /// UserDefaults so the main app can read and display a suggestion card.
    ///
    /// - Parameters:
    ///   - mode: The `FocusMode` to suggest.
    ///   - duration: The suggested session duration in minutes.
    ///   - autoStart: Whether the session should start automatically.
    static func writeSuggestion(
        mode: FocusMode,
        duration: Int,
        autoStart: Bool
    ) {
        guard let defaults = UserDefaults(suiteName: FocusFilterConstants.appGroupSuite) else {
            Logger.focusFilter.error("Failed to access app group UserDefaults")
            return
        }

        defaults.set(mode.rawValue, forKey: FocusFilterConstants.activeModeKey)
        defaults.set(autoStart, forKey: FocusFilterConstants.autoStartKey)
        defaults.set(duration, forKey: FocusFilterConstants.durationMinutesKey)
        defaults.set(Date().timeIntervalSince1970, forKey: FocusFilterConstants.activationTimestampKey)

        Logger.focusFilter.info(
            "Focus filter wrote suggestion: mode=\(mode.rawValue), duration=\(duration)min, autoStart=\(autoStart)"
        )
    }

    /// Posts a Darwin notification to signal the running app that a Focus
    /// filter has activated. Darwin notifications cross process boundaries,
    /// so the app receives this even if it was backgrounded.
    static func postDarwinNotification() {
        let name = FocusFilterConstants.darwinNotificationName as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name), nil, nil, true)

        Logger.focusFilter.debug("Posted Darwin notification: \(FocusFilterConstants.darwinNotificationName)")
    }

    // MARK: - Suggestion Reading

    /// Reads the most recent Focus filter suggestion from shared UserDefaults.
    ///
    /// Returns `nil` if no suggestion exists or the suggestion is stale
    /// (older than 5 minutes).
    ///
    /// - Returns: A tuple of `(FocusMode, durationMinutes, autoStart)` or `nil`.
    static func readSuggestion() -> (mode: FocusMode, duration: Int, autoStart: Bool)? {
        guard let defaults = UserDefaults(suiteName: FocusFilterConstants.appGroupSuite) else {
            return nil
        }

        guard let modeRaw = defaults.string(forKey: FocusFilterConstants.activeModeKey),
              let mode = FocusMode(rawValue: modeRaw)
        else {
            return nil
        }

        // Check staleness — ignore suggestions older than 5 minutes.
        let timestamp = defaults.double(forKey: FocusFilterConstants.activationTimestampKey)
        guard Date().timeIntervalSince1970 - timestamp < FocusFilterConstants.suggestionStalenessSeconds else {
            Logger.focusFilter.debug("Focus filter suggestion is stale, ignoring")
            return nil
        }

        let duration = defaults.integer(forKey: FocusFilterConstants.durationMinutesKey)
        let autoStart = defaults.bool(forKey: FocusFilterConstants.autoStartKey)

        return (mode: mode, duration: duration > 0 ? duration : UserProfile.defaultDurationMinutes, autoStart: autoStart)
    }

    /// Clears the stored suggestion after it has been consumed or dismissed.
    static func clearSuggestion() {
        guard let defaults = UserDefaults(suiteName: FocusFilterConstants.appGroupSuite) else {
            return
        }

        defaults.removeObject(forKey: FocusFilterConstants.activeModeKey)
        defaults.removeObject(forKey: FocusFilterConstants.autoStartKey)
        defaults.removeObject(forKey: FocusFilterConstants.durationMinutesKey)
        defaults.removeObject(forKey: FocusFilterConstants.activationTimestampKey)

        Logger.focusFilter.debug("Cleared Focus filter suggestion")
    }
}

// MARK: - FocusModeMapping

/// Maps an iOS Focus mode name to a BioNaural session mode with a
/// suggested duration. Used by `FocusFilterSettingsView` and the
/// suggestion card.
struct FocusModeMapping: Sendable, Equatable {

    /// The iOS Focus mode name (e.g. "Work", "Sleep", "Do Not Disturb").
    let iosFocusName: String

    /// The BioNaural mode to suggest when this iOS Focus activates.
    /// `nil` means no mapping (the user selected "None").
    let bioNauralMode: FocusMode?

    /// Suggested session duration in minutes.
    let suggestedDurationMinutes: Int
}

// MARK: - Default Mappings

extension FocusModeMapping {

    /// Sensible default mappings from iOS Focus modes to BioNaural modes.
    /// Users can override these in the Focus Filter settings.
    static let defaults: [FocusModeMapping] = [
        FocusModeMapping(iosFocusName: "Work", bioNauralMode: .focus, suggestedDurationMinutes: 25),
        FocusModeMapping(iosFocusName: "Personal", bioNauralMode: .relaxation, suggestedDurationMinutes: 20),
        FocusModeMapping(iosFocusName: "Sleep", bioNauralMode: .sleep, suggestedDurationMinutes: 30),
        FocusModeMapping(iosFocusName: "Do Not Disturb", bioNauralMode: .relaxation, suggestedDurationMinutes: 15),
        FocusModeMapping(iosFocusName: "Fitness", bioNauralMode: .energize, suggestedDurationMinutes: 20)
    ]
}

// MARK: - Logger Extension

extension Logger {

    /// Focus Filter activation, suggestion writing, and mapping changes.
    static let focusFilter = Logger(subsystem: "com.bionaural", category: "focusFilter")
}
