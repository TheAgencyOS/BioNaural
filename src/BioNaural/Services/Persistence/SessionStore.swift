// SessionStore.swift
// BioNaural
//
// CRUD operations for FocusSession records backed by SwiftData.
// Injected via SwiftUI Environment as a protocol-based service.

import Foundation
import SwiftData
import BioNauralShared

// MARK: - Protocol

/// Persistence interface for session history.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
@MainActor public protocol SessionStoring: Sendable {
    /// Persists a session record.
    func save(session: FocusSession) throws

    /// Fetches session records with optional filtering and limiting.
    func fetchAll(limit: Int?, mode: FocusMode?) throws -> [FocusSession]

    /// Fetches sessions from the last N days.
    func fetchRecent(days: Int) throws -> [FocusSession]

    /// Deletes all session records (GDPR "delete my data").
    func deleteAll() throws

    /// Exports all session records as GDPR-compliant JSON.
    func exportAsJSON() throws -> Data
}

// MARK: - Implementation

/// Production `SessionStoring` implementation backed by a SwiftData
/// `ModelContext`.
///
/// This store is ``-isolated because `ModelContext` is not
/// `Sendable`. All access must happen on the main actor — which aligns
/// with the app's MVVM architecture where ViewModels are ``.

public final class SessionStore: SessionStoring {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Creates a session store backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context to use for all
    ///   persistence operations. Typically the shared container's main
    ///   context, injected via the SwiftUI environment.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    /// Persists a session record.
    ///
    /// If a session with the same `id` already exists, SwiftData merges
    /// the changes (upsert behavior from the `@Attribute(.unique)` on `id`).
    ///
    /// - Parameter session: The session to save.
    /// - Throws: SwiftData persistence errors.
    public func save(session: FocusSession) throws {
        modelContext.insert(session)
        try modelContext.save()
    }

    /// Fetches session records with optional filtering and limiting.
    /// Results are sorted by `startDate` descending (most recent first).
    ///
    /// - Parameters:
    ///   - limit: Maximum number of sessions to return. `nil` for all.
    ///   - mode: Filter to a specific `FocusMode`. `nil` for all modes.
    /// - Returns: An array of matching sessions, newest first.
    /// - Throws: SwiftData fetch errors.
    public func fetchAll(limit: Int? = nil, mode: FocusMode? = nil) throws -> [FocusSession] {
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        if let mode {
            let modeRawValue = mode.rawValue
            descriptor.predicate = #Predicate<FocusSession> { session in
                session.mode == modeRawValue
            }
        }

        if let limit {
            descriptor.fetchLimit = limit
        }

        return try modelContext.fetch(descriptor)
    }

    /// Fetches sessions from the last N days.
    ///
    /// - Parameter days: Number of days to look back from now.
    /// - Returns: Sessions within the date range, newest first.
    /// - Throws: SwiftData fetch errors.
    public func fetchRecent(days: Int) throws -> [FocusSession] {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) else {
            return []
        }

        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.startDate >= cutoffDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    /// Deletes all session records.
    /// Used for the GDPR "delete my data" flow and during development.
    ///
    /// - Throws: SwiftData deletion errors.
    public func deleteAll() throws {
        try modelContext.delete(model: FocusSession.self)
        try modelContext.save()
    }

    /// Exports all session records as GDPR-compliant JSON.
    ///
    /// The export includes every field on every session, serialized as
    /// a JSON array. Suitable for the "Export My Data" flow in Settings.
    ///
    /// - Returns: UTF-8 encoded JSON data.
    /// - Throws: SwiftData fetch errors or JSON encoding errors.
    public func exportAsJSON() throws -> Data {
        let sessions = try fetchAll(limit: nil, mode: nil)

        let exportRecords = sessions.map { session in
            SessionExportRecord(
                id: session.id,
                startDate: session.startDate,
                endDate: session.endDate,
                mode: session.mode,
                durationSeconds: session.durationSeconds,
                averageHeartRate: session.averageHeartRate,
                averageHRV: session.averageHRV,
                minHeartRate: session.minHeartRate,
                maxHeartRate: session.maxHeartRate,
                beatFrequencyStart: session.beatFrequencyStart,
                beatFrequencyEnd: session.beatFrequencyEnd,
                carrierFrequency: session.carrierFrequency,
                adaptationEvents: session.adaptationEvents,
                ambientBedID: session.ambientBedID,
                melodicLayerIDs: session.melodicLayerIDs,
                wasCompleted: session.wasCompleted,
                thumbsRating: session.thumbsRating,
                feedbackTags: session.feedbackTags,
                checkInMood: session.checkInMood,
                checkInGoal: session.checkInGoal,
                biometricSuccessScore: session.biometricSuccessScore
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportRecords)
    }
}

// MARK: - Export DTO

/// Codable mirror of `FocusSession` used exclusively for JSON export.
/// SwiftData `@Model` classes are not directly `Encodable`, so we map
/// to this plain struct for serialization.
private struct SessionExportRecord: Encodable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let mode: String
    let durationSeconds: Int
    let averageHeartRate: Double?
    let averageHRV: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let beatFrequencyStart: Double
    let beatFrequencyEnd: Double
    let carrierFrequency: Double
    let adaptationEvents: [AdaptationEventRecord]
    let ambientBedID: String?
    let melodicLayerIDs: [String]
    let wasCompleted: Bool
    let thumbsRating: Int?
    let feedbackTags: [String]?
    let checkInMood: Double?
    let checkInGoal: String?
    let biometricSuccessScore: Double?
}
