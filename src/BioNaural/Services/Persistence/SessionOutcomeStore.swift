// SessionOutcomeStore.swift
// BioNaural
//
// Concrete `SessionStoreProtocol` implementation backed by SwiftData.
// Maps between `SessionOutcome` structs (used by the learning system)
// and `FocusSession` SwiftData models (used for persistence).
//
// @MainActor-isolated because `ModelContext` is not Sendable.

import Foundation
import SwiftData
import BioNauralShared

// MARK: - SessionOutcomeStore

/// Persists and queries `SessionOutcome` records by bridging to the
/// `FocusSession` SwiftData model.
///
/// All methods run on `@MainActor` because SwiftData's `ModelContext`
/// requires main-actor isolation. The same pattern is used by
/// `ContextTrackManager` and `SessionStore` elsewhere in the codebase.
@MainActor
public final class SessionOutcomeStore: SessionStoreProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Creates a session outcome store backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for all persistence
    ///   operations. Typically the shared container's main context.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - SessionStoreProtocol

    /// Saves a session outcome by converting it to a `FocusSession` and
    /// inserting into the SwiftData store.
    ///
    /// - Parameter outcome: The session outcome to persist.
    /// - Throws: SwiftData persistence errors.
    public func save(outcome: SessionOutcome) async throws {
        let session = mapOutcomeToFocusSession(outcome)
        modelContext.insert(session)
        try modelContext.save()
    }

    /// Retrieves all session outcomes, optionally filtered by focus mode.
    ///
    /// - Parameter mode: When non-nil, only outcomes matching this mode
    ///   are returned. Pass `nil` for all modes.
    /// - Returns: An array of `SessionOutcome` values sorted by start
    ///   date descending (most recent first).
    /// - Throws: SwiftData fetch errors.
    public func outcomes(mode: FocusMode?) async throws -> [SessionOutcome] {
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        if let mode {
            let modeRawValue = mode.rawValue
            descriptor.predicate = #Predicate<FocusSession> { session in
                session.mode == modeRawValue
            }
        }

        let sessions = try modelContext.fetch(descriptor)
        return sessions.compactMap { mapFocusSessionToOutcome($0) }
    }

    /// Retrieves outcomes within an inclusive date range.
    ///
    /// - Parameters:
    ///   - start: The earliest start date to include.
    ///   - end: The latest start date to include.
    /// - Returns: Matching outcomes sorted by start date descending.
    /// - Throws: SwiftData fetch errors.
    public func outcomes(from start: Date, to end: Date) async throws -> [SessionOutcome] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate<FocusSession> { session in
                session.startDate >= start && session.startDate <= end
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let sessions = try modelContext.fetch(descriptor)
        return sessions.compactMap { mapFocusSessionToOutcome($0) }
    }

    /// Returns the total number of persisted session outcomes.
    ///
    /// - Returns: The count of all `FocusSession` records.
    /// - Throws: SwiftData fetch errors.
    public func outcomeCount() async throws -> Int {
        let descriptor = FetchDescriptor<FocusSession>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Mapping: SessionOutcome -> FocusSession

    /// Converts a `SessionOutcome` to a `FocusSession` for SwiftData storage.
    ///
    /// Fields that exist on `SessionOutcome` but not on `FocusSession`
    /// (e.g., `hrSamples`, `activeSoundTags`) are not stored — they are
    /// transient analysis data that the learning system does not need after
    /// initial recording.
    private func mapOutcomeToFocusSession(_ outcome: SessionOutcome) -> FocusSession {
        // Derive thumbsRating Int from the Bool? representation.
        let thumbsRatingInt: Int? = {
            switch outcome.thumbsUp {
            case .some(true): return 1
            case .some(false): return -1
            case .none: return nil
            }
        }()

        return FocusSession(
            id: outcome.sessionID,
            startDate: outcome.startDate,
            endDate: outcome.endDate,
            mode: outcome.mode.rawValue,
            durationSeconds: Int(outcome.durationSeconds),
            averageHeartRate: computeAverageHR(
                startingHR: outcome.startingHR,
                endingHR: outcome.endingHR
            ),
            averageHRV: nil,
            minHeartRate: nil,
            maxHeartRate: nil,
            beatFrequencyStart: 0,
            beatFrequencyEnd: 0,
            carrierFrequency: 0,
            adaptationEvents: outcome.adaptationEvents,
            ambientBedID: nil,
            melodicLayerIDs: [],
            wasCompleted: outcome.completed,
            thumbsRating: thumbsRatingInt,
            feedbackTags: nil,
            checkInMood: outcome.checkInMood,
            checkInGoal: outcome.checkInIntent?.rawValue,
            biometricSuccessScore: outcome.biometricSuccessScore
        )
    }

    // MARK: - Mapping: FocusSession -> SessionOutcome

    /// Converts a `FocusSession` SwiftData model back to a `SessionOutcome`.
    ///
    /// Returns `nil` if the stored mode string does not match any known
    /// `FocusMode` case (defensive against future mode additions).
    private func mapFocusSessionToOutcome(_ session: FocusSession) -> SessionOutcome? {
        guard let focusMode = FocusMode(rawValue: session.mode) else {
            return nil
        }

        let endDate = session.endDate ?? session.startDate.addingTimeInterval(
            TimeInterval(session.durationSeconds)
        )

        // Derive thumbsUp Bool? from the Int? representation.
        let thumbsUp: Bool? = {
            switch session.thumbsRating {
            case 1: return true
            case -1: return false
            default: return nil
            }
        }()

        // Derive HR start/end from averageHeartRate when individual
        // start/end values are not stored separately.
        let avgHR = session.averageHeartRate
        let startingHR = avgHR
        let endingHR = avgHR
        let hrDelta: Double? = nil

        let calendar = Calendar.current
        let timeOfDay = calendar.component(.hour, from: session.startDate)
        let dayOfWeek = calendar.component(.weekday, from: session.startDate)

        return SessionOutcome(
            sessionID: session.id,
            mode: focusMode,
            startDate: session.startDate,
            endDate: endDate,
            durationSeconds: TimeInterval(session.durationSeconds),
            completed: session.wasCompleted,
            hrSamples: [],
            adaptationEvents: session.adaptationEvents,
            activeSoundTags: [],
            checkInMood: session.checkInMood,
            checkInIntent: session.checkInGoal.flatMap { FocusMode(rawValue: $0) },
            thumbsUp: thumbsUp,
            biometricSuccessScore: session.biometricSuccessScore ?? 0.0,
            overallScore: computeOverallScore(
                biometricScore: session.biometricSuccessScore ?? 0.0,
                thumbsUp: thumbsUp
            ),
            checkInBiometricAlignment: nil,
            startingHR: startingHR,
            endingHR: endingHR,
            hrDelta: hrDelta,
            timeToCalmSeconds: nil,
            sleepOnsetSeconds: nil
        )
    }

    // MARK: - Helpers

    /// Computes a simple average from session start and end heart rates.
    ///
    /// - Parameters:
    ///   - startingHR: Heart rate at session start (BPM), or `nil`.
    ///   - endingHR: Heart rate at session end (BPM), or `nil`.
    /// - Returns: The average of available values, or `nil` if both are absent.
    private func computeAverageHR(startingHR: Double?, endingHR: Double?) -> Double? {
        switch (startingHR, endingHR) {
        case let (.some(start), .some(end)):
            return (start + end) / 2.0
        case let (.some(value), .none), let (.none, .some(value)):
            return value
        case (.none, .none):
            return nil
        }
    }

    /// Re-derives the overall score from stored components using the same
    /// weights defined in `OutcomeScoring`.
    ///
    /// - Parameters:
    ///   - biometricScore: The biometric success score (0.0 - 1.0).
    ///   - thumbsUp: Post-session thumbs rating.
    /// - Returns: Blended overall score.
    private func computeOverallScore(biometricScore: Double, thumbsUp: Bool?) -> Double {
        let thumbsValue: Double = {
            switch thumbsUp {
            case .some(true): return 1.0
            case .some(false): return 0.0
            case .none: return OutcomeScoring.thumbsNeutral
            }
        }()

        return biometricScore * OutcomeScoring.biometricWeight
            + thumbsValue * OutcomeScoring.thumbsWeight
    }
}
