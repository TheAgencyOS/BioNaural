// JournalSuggestionService.swift
// BioNaural
//
// Protocol + concrete implementation for reading Apple's JournalingSuggestions.
// Maps real-life moments (workouts, music, locations, contacts, photos)
// into lightweight JournalActivity structs for correlation with session outcomes.
// Requires iOS 17.2+, NSUserActivityTypes, and com.apple.developer.journal entitlement.

import Foundation
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif
import BioNauralShared
import OSLog

// MARK: - JournalConfig

/// Configuration constants for journal suggestion fetching.
public enum JournalConfig {

    /// Maximum number of suggestions to process per fetch cycle.
    static let maxSuggestionsPerFetch: Int = 20

    /// How far back to look for recent activity, in days.
    static let lookbackDays: Int = 7
}

// MARK: - JournalActivityType

/// Classification of a journal activity mapped from JournalingSuggestion content types.
public enum JournalActivityType: String, Sendable, CaseIterable {
    case workout
    case music
    case location
    case social    // contacts / calls
    case photo
    case other

    /// SF Symbol name for this activity type.
    var icon: String {
        switch self {
        case .workout:  return "figure.run"
        case .music:    return "music.note"
        case .location: return "location.fill"
        case .social:   return "person.2.fill"
        case .photo:    return "photo.fill"
        case .other:    return "sparkles"
        }
    }
}

// MARK: - JournalActivity

/// Lightweight, Sendable model representing a single activity from JournalingSuggestions.
/// Used throughout the app for correlation analysis and UI display.
public struct JournalActivity: Identifiable, Sendable {

    /// Unique identifier derived from the suggestion.
    public let id: String

    /// Human-readable title of the activity.
    public let title: String

    /// When the activity occurred.
    public let date: Date

    /// Classified type of the activity.
    public let activityType: JournalActivityType

    /// Optional descriptive metadata (e.g. workout type, song name, location name).
    public let metadata: String?

    public init(
        id: String,
        title: String,
        date: Date,
        activityType: JournalActivityType,
        metadata: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.activityType = activityType
        self.metadata = metadata
    }
}

// MARK: - JournalSuggestionServiceProtocol

/// Contract for reading journal suggestions.
/// Implementations fetch Apple's JournalingSuggestions and map them
/// to lightweight JournalActivity models for session correlation.
@MainActor
public protocol JournalSuggestionServiceProtocol: AnyObject, Sendable {

    /// Fetch recent activities within the configured lookback window.
    /// Returns up to `JournalConfig.maxSuggestionsPerFetch` activities,
    /// sorted by date descending (most recent first).
    func recentActivities() async -> [JournalActivity]

    /// Fetch activities that occurred on a specific date.
    /// Matches activities whose date falls within the same calendar day.
    func activitiesOnDate(_ date: Date) async -> [JournalActivity]
}

// MARK: - JournalSuggestionService

#if canImport(JournalingSuggestions)

/// Concrete implementation using Apple's JournalingSuggestions framework (iOS 17.2+).
/// Fetches suggestion items, maps typed content to `JournalActivity` structs,
/// and filters by date range. Gracefully returns empty arrays on earlier iOS versions.
@available(iOS 17.2, *)
@MainActor
public final class JournalSuggestionService: JournalSuggestionServiceProtocol {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "com.bionaural", category: "JournalSuggestions")

    // MARK: - Init

    public init() {
        Self.logger.info("JournalSuggestionService initialized")
    }

    // MARK: - Recent Activities

    public func recentActivities() async -> [JournalActivity] {
        let calendar = Calendar.current
        let now = Date()

        guard let lookbackDate = calendar.date(
            byAdding: .day,
            value: -JournalConfig.lookbackDays,
            to: now
        ) else {
            Self.logger.error("Failed to compute lookback date")
            return []
        }

        let suggestions = await fetchSuggestions()
        let activities = mapSuggestionsToActivities(suggestions)

        return activities
            .filter { $0.date >= lookbackDate && $0.date <= now }
            .sorted { $0.date > $1.date }
            .prefix(JournalConfig.maxSuggestionsPerFetch)
            .map { $0 }
    }

    // MARK: - Activities On Date

    public func activitiesOnDate(_ date: Date) async -> [JournalActivity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            Self.logger.error("Failed to compute end of day for date filter")
            return []
        }

        let suggestions = await fetchSuggestions()
        let activities = mapSuggestionsToActivities(suggestions)

        return activities
            .filter { $0.date >= startOfDay && $0.date < endOfDay }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Private — Fetch

    /// Fetches raw suggestions from the JournalingSuggestions framework.
    private func fetchSuggestions() async -> [JournalingSuggestion] {
        do {
            let suggestions = try await JournalingSuggestion.suggestions()
            Self.logger.info("Fetched \(suggestions.count) journal suggestions")
            return suggestions
        } catch {
            Self.logger.error("Failed to fetch journal suggestions: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Private — Mapping

    /// Maps an array of `JournalingSuggestion` items into `JournalActivity` models.
    /// Each suggestion may contain multiple content items; each becomes its own activity.
    private func mapSuggestionsToActivities(_ suggestions: [JournalingSuggestion]) -> [JournalActivity] {
        var activities: [JournalActivity] = []

        for suggestion in suggestions {
            for item in suggestion.items {
                if let activity = mapContentItem(item, suggestion: suggestion) {
                    activities.append(activity)
                }
            }

            // If no typed content items were mapped, create a generic activity from the suggestion itself
            if suggestion.items.isEmpty {
                activities.append(
                    JournalActivity(
                        id: suggestion.hashValue.description,
                        title: suggestion.title,
                        date: suggestion.date,
                        activityType: .other,
                        metadata: nil
                    )
                )
            }
        }

        return activities
    }

    /// Maps a single suggestion content item to a `JournalActivity`.
    /// Returns nil if the content type is not recognized.
    private func mapContentItem(
        _ item: JournalingSuggestion.ItemContent,
        suggestion: JournalingSuggestion
    ) -> JournalActivity? {
        let baseID = "\(suggestion.hashValue)-\(item.hashValue)"

        switch item {
        case let workout as JournalingSuggestion.Workout:
            return JournalActivity(
                id: "\(baseID)-workout",
                title: workout.activityType ?? suggestion.title,
                date: workout.date ?? suggestion.date,
                activityType: .workout,
                metadata: workout.details
            )

        case let song as JournalingSuggestion.Song:
            return JournalActivity(
                id: "\(baseID)-song",
                title: song.title ?? suggestion.title,
                date: song.date ?? suggestion.date,
                activityType: .music,
                metadata: song.artist
            )

        case let location as JournalingSuggestion.Location:
            return JournalActivity(
                id: "\(baseID)-location",
                title: location.placeName ?? suggestion.title,
                date: location.date ?? suggestion.date,
                activityType: .location,
                metadata: location.city
            )

        case let contact as JournalingSuggestion.Contact:
            return JournalActivity(
                id: "\(baseID)-contact",
                title: contact.name ?? suggestion.title,
                date: suggestion.date,
                activityType: .social,
                metadata: nil
            )

        case is JournalingSuggestion.Photo:
            return JournalActivity(
                id: "\(baseID)-photo",
                title: suggestion.title,
                date: suggestion.date,
                activityType: .photo,
                metadata: nil
            )

        default:
            Self.logger.debug("Unrecognized content item type in suggestion: \(suggestion.title)")
            return JournalActivity(
                id: "\(baseID)-other",
                title: suggestion.title,
                date: suggestion.date,
                activityType: .other,
                metadata: nil
            )
        }
    }
}

#endif

// MARK: - Fallback Service (iOS < 17.2 or Simulator)

/// Fallback implementation for devices running iOS versions earlier than 17.2.
/// Returns empty arrays for all queries. Ensures the app compiles and runs
/// without conditional compilation guards scattered throughout the codebase.
@MainActor
public final class JournalSuggestionFallbackService: JournalSuggestionServiceProtocol {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "com.bionaural", category: "JournalSuggestions")

    // MARK: - Init

    public init() {
        Self.logger.info("JournalSuggestionFallbackService initialized (iOS < 17.2)")
    }

    // MARK: - Protocol Conformance

    public func recentActivities() async -> [JournalActivity] { [] }

    public func activitiesOnDate(_ date: Date) async -> [JournalActivity] { [] }
}

// MARK: - Factory

/// Creates the appropriate JournalSuggestionService for the current iOS version.
/// Use this at the DI layer to inject the correct implementation.
@MainActor
public enum JournalSuggestionServiceFactory {

    /// Returns a live `JournalSuggestionService` on iOS 17.2+ (device only),
    /// or a `JournalSuggestionFallbackService` on earlier versions / Simulator.
    public static func create() -> any JournalSuggestionServiceProtocol {
        #if canImport(JournalingSuggestions)
        if #available(iOS 17.2, *) {
            return JournalSuggestionService()
        } else {
            return JournalSuggestionFallbackService()
        }
        #else
        return JournalSuggestionFallbackService()
        #endif
    }
}
