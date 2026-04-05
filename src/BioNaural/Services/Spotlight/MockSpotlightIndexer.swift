// MockSpotlightIndexer.swift
// BioNaural
//
// Mock implementation of SpotlightIndexerProtocol for unit tests and
// SwiftUI previews. Tracks call counts without touching CoreSpotlight.

import Foundation
import BioNauralShared

// MARK: - MockSpotlightIndexer

/// Test double that records indexing calls for verification.
///
/// All counters are incremented on each method call. No actual Spotlight
/// indexing occurs. Uses `@unchecked Sendable` to match the protocol
/// conformance — counters are only read from the test thread after awaiting.
public final class MockSpotlightIndexer: SpotlightIndexerProtocol, @unchecked Sendable {

    // MARK: - Call Tracking

    /// Number of individual sessions indexed via `indexSession(...)`.
    public var indexedSessionCount = 0

    /// Number of patterns indexed via `indexPattern(...)`.
    public var indexedPatternCount = 0

    /// Number of insights indexed via `indexInsight(...)`.
    public var indexedInsightCount = 0

    /// Number of times `deleteAllIndexedItems()` was called.
    public var deleteAllCallCount = 0

    /// Number of times `reindexRecentSessions(...)` was called.
    public var reindexCallCount = 0

    /// The total number of sessions passed to the most recent `reindexRecentSessions` call.
    public var lastReindexSessionCount = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - SpotlightIndexerProtocol

    public func indexSession(
        id: UUID,
        mode: FocusMode,
        date: Date,
        durationMinutes: Int,
        score: Double?
    ) async {
        indexedSessionCount += 1
    }

    public func indexPattern(_ pattern: CalendarPattern) async {
        indexedPatternCount += 1
    }

    public func indexInsight(
        id: String,
        title: String,
        description: String,
        relatedMode: FocusMode?
    ) async {
        indexedInsightCount += 1
    }

    public func deleteAllIndexedItems() async {
        deleteAllCallCount += 1
    }

    public func reindexRecentSessions(_ sessions: [FocusSession]) async {
        reindexCallCount += 1
        lastReindexSessionCount = sessions.count
    }
}
