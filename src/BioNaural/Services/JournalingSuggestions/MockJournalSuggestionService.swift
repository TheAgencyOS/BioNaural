// MockJournalSuggestionService.swift
// BioNaural
//
// Mock implementation of JournalSuggestionServiceProtocol for tests and previews.
// Returns realistic sample data representing a week of user activity.

import Foundation
import BioNauralShared

// MARK: - MockJournalSuggestionService

public final class MockJournalSuggestionService: JournalSuggestionServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// When true, returns sample data. When false, returns empty arrays (simulates no access).
    public var hasAccess: Bool

    /// The sample activities returned by this mock.
    public var sampleActivities: [JournalActivity]

    // MARK: - Init

    /// Creates a mock service.
    /// - Parameters:
    ///   - hasAccess: Whether the mock simulates having journal access. Defaults to `true`.
    ///   - sampleActivities: Custom sample data. Defaults to a realistic week of activities.
    public init(
        hasAccess: Bool = true,
        sampleActivities: [JournalActivity]? = nil
    ) {
        self.hasAccess = hasAccess
        self.sampleActivities = sampleActivities ?? Self.defaultSampleActivities()
    }

    // MARK: - Protocol Conformance

    public func recentActivities() async -> [JournalActivity] {
        guard hasAccess else { return [] }
        return sampleActivities
            .sorted { $0.date > $1.date }
            .prefix(JournalConfig.maxSuggestionsPerFetch)
            .map { $0 }
    }

    public func activitiesOnDate(_ date: Date) async -> [JournalActivity] {
        guard hasAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return sampleActivities
            .filter { $0.date >= startOfDay && $0.date < endOfDay }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Default Sample Data

    /// Generates a realistic week of journal activities for previews.
    private static func defaultSampleActivities() -> [JournalActivity] {
        let calendar = Calendar.current
        let now = Date()

        return [
            // Today
            JournalActivity(
                id: "mock-workout-today",
                title: "Morning Run",
                date: calendar.date(
                    bySettingHour: 7, minute: 15, second: 0, of: now
                ) ?? now,
                activityType: .workout,
                metadata: "Running, 5.2 km"
            ),
            JournalActivity(
                id: "mock-music-today",
                title: "Clair de Lune",
                date: calendar.date(
                    bySettingHour: 9, minute: 30, second: 0, of: now
                ) ?? now,
                activityType: .music,
                metadata: "Debussy"
            ),

            // Yesterday
            JournalActivity(
                id: "mock-location-yesterday",
                title: "Blue Bottle Coffee",
                date: calendar.date(
                    byAdding: .day, value: -1,
                    to: calendar.date(
                        bySettingHour: 10, minute: 0, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .location,
                metadata: "Downtown"
            ),
            JournalActivity(
                id: "mock-social-yesterday",
                title: "Lunch with Alex",
                date: calendar.date(
                    byAdding: .day, value: -1,
                    to: calendar.date(
                        bySettingHour: 12, minute: 30, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .social,
                metadata: nil
            ),

            // 2 days ago
            JournalActivity(
                id: "mock-workout-2d",
                title: "Yoga Flow",
                date: calendar.date(
                    byAdding: .day, value: -2,
                    to: calendar.date(
                        bySettingHour: 18, minute: 0, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .workout,
                metadata: "Yoga, 45 min"
            ),
            JournalActivity(
                id: "mock-photo-2d",
                title: "Sunset at the Park",
                date: calendar.date(
                    byAdding: .day, value: -2,
                    to: calendar.date(
                        bySettingHour: 19, minute: 15, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .photo,
                metadata: nil
            ),

            // 4 days ago
            JournalActivity(
                id: "mock-music-4d",
                title: "Lo-fi Beats Playlist",
                date: calendar.date(
                    byAdding: .day, value: -4,
                    to: calendar.date(
                        bySettingHour: 14, minute: 0, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .music,
                metadata: "Various Artists"
            ),
            JournalActivity(
                id: "mock-location-4d",
                title: "Public Library",
                date: calendar.date(
                    byAdding: .day, value: -4,
                    to: calendar.date(
                        bySettingHour: 10, minute: 30, second: 0, of: now
                    ) ?? now
                ) ?? now,
                activityType: .location,
                metadata: "Midtown"
            )
        ]
    }
}
