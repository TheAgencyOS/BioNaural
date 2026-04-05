// SpotlightIndexer.swift
// BioNaural
//
// Indexes BioNaural sessions, calendar-health patterns, and health insights
// into CoreSpotlight so users can find them via Siri and system Spotlight
// search. All indexing is fire-and-forget — errors are logged but never
// propagated to callers.

import Foundation
import CoreSpotlight
import MobileCoreServices
import UniformTypeIdentifiers
import OSLog
import BioNauralShared

// MARK: - SpotlightConfig

/// All tuning constants for Spotlight indexing. No hardcoded values at call sites.
public enum SpotlightConfig {

    /// Domain identifier for all BioNaural indexed items.
    static let domainIdentifier = "com.bionaural.spotlight"

    /// Content type identifier for session items.
    static let sessionContentType = "com.bionaural.session"

    /// Content type identifier for insight items.
    static let insightContentType = "com.bionaural.insight"

    /// Content type identifier for calendar-health pattern items.
    static let patternContentType = "com.bionaural.pattern"

    /// Maximum number of recent sessions to keep indexed.
    static let maxIndexedSessions: Int = 50

    /// Maximum number of insights to keep indexed.
    static let maxIndexedInsights: Int = 20

    /// Number of days before an indexed item expires from Spotlight.
    static let indexExpirationDays: Int = 30

    /// Prefix for session unique identifiers.
    static let sessionPrefix = "session_"

    /// Prefix for pattern unique identifiers.
    static let patternPrefix = "pattern_"

    /// Prefix for insight unique identifiers.
    static let insightPrefix = "insight_"

    /// Base keywords applied to every indexed item.
    static let baseKeywords = ["BioNaural", "binaural beats", "focus"]
}

// MARK: - SpotlightIndexerProtocol

/// Service interface for indexing BioNaural content into CoreSpotlight.
///
/// Protocol-based to support mock implementations in tests and previews,
/// per the project's DI architecture.
public protocol SpotlightIndexerProtocol: AnyObject, Sendable {

    /// Indexes a completed session for Spotlight search.
    ///
    /// - Parameters:
    ///   - id: The session's unique identifier.
    ///   - mode: The focus mode used during the session.
    ///   - date: When the session occurred.
    ///   - durationMinutes: Session length in minutes.
    ///   - score: Optional biometric success score (0-1).
    func indexSession(
        id: UUID,
        mode: FocusMode,
        date: Date,
        durationMinutes: Int,
        score: Double?
    ) async

    /// Indexes a discovered calendar-health pattern.
    ///
    /// - Parameter pattern: The pattern to index.
    func indexPattern(_ pattern: CalendarPattern) async

    /// Indexes a health insight (e.g., "Your best focus day is Wednesday").
    ///
    /// - Parameters:
    ///   - id: A stable identifier for this insight.
    ///   - title: Human-readable insight title.
    ///   - description: Detailed insight description.
    ///   - relatedMode: Optional focus mode this insight relates to.
    func indexInsight(
        id: String,
        title: String,
        description: String,
        relatedMode: FocusMode?
    ) async

    /// Removes all BioNaural items from the Spotlight index.
    ///
    /// Called when the user requests data deletion (GDPR compliance).
    func deleteAllIndexedItems() async

    /// Re-indexes recent session history, replacing any stale session items.
    ///
    /// - Parameter sessions: The most recent sessions to index.
    func reindexRecentSessions(_ sessions: [FocusSession]) async
}

// MARK: - SpotlightIndexer

/// Production implementation that writes to `CSSearchableIndex.default()`.
///
/// Thread safety: `CSSearchableIndex` is documented as thread-safe, so this
/// class uses `@unchecked Sendable` rather than an actor to avoid unnecessary
/// serialization overhead.
public final class SpotlightIndexer: SpotlightIndexerProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let searchableIndex: CSSearchableIndex
    private let logger = Logger(subsystem: "com.bionaural", category: "SpotlightIndexer")
    private let calendar = Calendar.current

    // MARK: - Initialization

    /// Creates a Spotlight indexer backed by the default searchable index.
    public init() {
        self.searchableIndex = CSSearchableIndex.default()
    }

    /// Creates a Spotlight indexer with a custom searchable index (for testing).
    ///
    /// - Parameter searchableIndex: The index to write items to.
    init(searchableIndex: CSSearchableIndex) {
        self.searchableIndex = searchableIndex
    }

    // MARK: - Session Indexing

    public func indexSession(
        id: UUID,
        mode: FocusMode,
        date: Date,
        durationMinutes: Int,
        score: Double?
    ) async {
        let uniqueID = SpotlightConfig.sessionPrefix + id.uuidString
        let title = "\(mode.displayName) Session \u{2014} \(durationMinutes) min"
        let description = buildSessionDescription(date: date, score: score)

        var keywords = SpotlightConfig.baseKeywords
        keywords.append(contentsOf: [
            mode.displayName.lowercased(),
            "session",
            mode.rawValue
        ])

        let attributeSet = buildAttributeSet(
            contentType: SpotlightConfig.sessionContentType,
            title: title,
            description: description,
            keywords: keywords
        )

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueID,
            domainIdentifier: SpotlightConfig.domainIdentifier,
            attributeSet: attributeSet
        )

        await indexItems([item])
    }

    // MARK: - Pattern Indexing

    public func indexPattern(_ pattern: CalendarPattern) async {
        let uniqueID = SpotlightConfig.patternPrefix + pattern.id
        let title = buildPatternTitle(pattern)
        let description = "\(pattern.condition) \u{2192} \(pattern.observation)"

        var keywords = SpotlightConfig.baseKeywords
        keywords.append(contentsOf: [
            "pattern",
            "calendar",
            "health",
            "insight"
        ])

        let attributeSet = buildAttributeSet(
            contentType: SpotlightConfig.patternContentType,
            title: title,
            description: description,
            keywords: keywords
        )

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueID,
            domainIdentifier: SpotlightConfig.domainIdentifier,
            attributeSet: attributeSet
        )

        await indexItems([item])
    }

    // MARK: - Insight Indexing

    public func indexInsight(
        id: String,
        title: String,
        description: String,
        relatedMode: FocusMode?
    ) async {
        let uniqueID = SpotlightConfig.insightPrefix + id

        var keywords = SpotlightConfig.baseKeywords
        keywords.append(contentsOf: ["insight", "health"])
        if let mode = relatedMode {
            keywords.append(mode.displayName.lowercased())
            keywords.append(mode.rawValue)
        }

        let attributeSet = buildAttributeSet(
            contentType: SpotlightConfig.insightContentType,
            title: title,
            description: description,
            keywords: keywords
        )

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueID,
            domainIdentifier: SpotlightConfig.domainIdentifier,
            attributeSet: attributeSet
        )

        await indexItems([item])
    }

    // MARK: - Deletion

    public func deleteAllIndexedItems() async {
        do {
            try await searchableIndex.deleteSearchableItems(
                withDomainIdentifiers: [SpotlightConfig.domainIdentifier]
            )
            logger.info("Deleted all indexed Spotlight items.")
        } catch {
            logger.error("Failed to delete all Spotlight items: \(error.localizedDescription)")
        }
    }

    // MARK: - Batch Re-Index

    public func reindexRecentSessions(_ sessions: [FocusSession]) async {
        // Remove existing session items first.
        let existingIDs = sessions.prefix(SpotlightConfig.maxIndexedSessions).map {
            SpotlightConfig.sessionPrefix + $0.id.uuidString
        }

        do {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: existingIDs)
        } catch {
            logger.error("Failed to remove stale session items: \(error.localizedDescription)")
        }

        // Index the most recent sessions up to the configured limit.
        let recentSessions = sessions
            .sorted { $0.startDate > $1.startDate }
            .prefix(SpotlightConfig.maxIndexedSessions)

        var items: [CSSearchableItem] = []

        for session in recentSessions {
            guard let mode = session.focusMode else { continue }

            let durationMinutes = session.durationSeconds / 60
            let uniqueID = SpotlightConfig.sessionPrefix + session.id.uuidString
            let title = "\(mode.displayName) Session \u{2014} \(durationMinutes) min"
            let description = buildSessionDescription(
                date: session.startDate,
                score: session.biometricSuccessScore
            )

            var keywords = SpotlightConfig.baseKeywords
            keywords.append(contentsOf: [
                mode.displayName.lowercased(),
                "session",
                mode.rawValue
            ])

            let attributeSet = buildAttributeSet(
                contentType: SpotlightConfig.sessionContentType,
                title: title,
                description: description,
                keywords: keywords
            )

            let item = CSSearchableItem(
                uniqueIdentifier: uniqueID,
                domainIdentifier: SpotlightConfig.domainIdentifier,
                attributeSet: attributeSet
            )
            items.append(item)
        }

        guard !items.isEmpty else { return }
        await indexItems(items)
    }

    // MARK: - Private Helpers

    /// Submits items to the searchable index, logging any errors.
    /// Sets the expiration date on a searchable item.
    private func applyExpiration(to item: CSSearchableItem) {
        let calendar = Calendar.current
        if let expirationDate = calendar.date(
            byAdding: .day,
            value: SpotlightConfig.indexExpirationDays,
            to: Date()
        ) {
            item.expirationDate = expirationDate
        }
    }

    private func indexItems(_ items: [CSSearchableItem]) async {
        items.forEach { applyExpiration(to: $0) }
        do {
            try await searchableIndex.indexSearchableItems(items)
            logger.debug("Indexed \(items.count) item(s) in Spotlight.")
        } catch {
            logger.error("Failed to index \(items.count) Spotlight item(s): \(error.localizedDescription)")
        }
    }

    /// Builds a `CSSearchableItemAttributeSet` with common properties.
    ///
    /// - Parameters:
    ///   - contentType: The content type identifier string.
    ///   - title: The item's display title.
    ///   - description: The item's content description.
    ///   - keywords: Search keywords for the item.
    /// - Returns: A configured attribute set.
    private func buildAttributeSet(
        contentType: String,
        title: String,
        description: String,
        keywords: [String]
    ) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType(contentType) ?? .content)
        attributeSet.title = title
        attributeSet.contentDescription = description
        attributeSet.keywords = keywords
        attributeSet.thumbnailData = nil

        return attributeSet
    }

    /// Formats a session description from the date and optional score.
    ///
    /// Example: "Tuesday, April 1 \u{00B7} Score: 78%"
    private func buildSessionDescription(date: Date, score: Double?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        let dateString = dateFormatter.string(from: date)

        if let score {
            let percentage = Int(score * 100)
            return "\(dateString) \u{00B7} Score: \(percentage)%"
        }

        return dateString
    }

    /// Builds a human-readable title from a calendar pattern.
    ///
    /// Converts underscore-separated observation strings into readable text.
    /// Example: "hr_spikes_10bpm_before" -> "HR spikes before meetings"
    private func buildPatternTitle(_ pattern: CalendarPattern) -> String {
        let observation = pattern.observation
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        return observation
    }
}
