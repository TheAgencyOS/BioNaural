// ContextTrackManager.swift
// BioNaural
//
// Manages the lifecycle of Context Tracks — purpose-built audio tracks
// tied to life events (study sessions, pre-performance routines, recovery).
// Handles creation, querying, session recording, archival, and deletion.
// All SwiftData access is @MainActor-isolated.

import Foundation
import OSLog
import SwiftData
import BioNauralShared

// MARK: - Configuration

/// All tunable constants for context track management.
/// No hardcoded values — every threshold and default lives here.
public enum TrackManagerConfig {

    /// Maximum number of active Flow State tracks a user can maintain simultaneously.
    static let maxActiveFlowStateTracks: Int = 5

    /// Days after an event's `activeUntil` date before auto-archival runs.
    static let autoArchiveDaysAfterEvent: Int = 7

    /// Minimum sessions required before a track's `averageSuccessScore` is meaningful.
    static let minimumSessionsForScoring: Int = 3

    /// How locked the sonic signature should be for Flow State consistency (0-1).
    static let flowStateConsistencyThreshold: Double = 0.8

    /// Default Flow State session duration in minutes.
    static let defaultFlowStateDurationMinutes: Int = 60

    /// Default pre-performance prep duration in minutes.
    static let defaultPrepDurationMinutes: Int = 15

    /// Default recovery session duration in minutes.
    static let defaultRecoveryDurationMinutes: Int = 10
}

// MARK: - Protocol

/// Persistence and lifecycle interface for context-specific audio tracks.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
@MainActor
public protocol ContextTrackManagerProtocol: AnyObject {

    /// Creates a Flow State track with locked audio parameters for sonic
    /// anchoring — consistent environments that train the brain to enter
    /// the target state faster.
    func createFlowStateTrack(
        name: String,
        eventKeywords: [String],
        mode: FocusMode,
        ambientBedID: String?,
        carrierFrequency: Double?,
        melodicTags: [String],
        sonicMemoryID: UUID?,
        activeUntil: Date?
    ) async -> ContextTrack

    /// Creates a pre-performance track optimized for short, high-focus prep sessions.
    func createPrePerformanceTrack(
        name: String,
        eventKeywords: [String],
        activeUntil: Date?
    ) async -> ContextTrack

    /// Creates a recovery track with adaptive carrier frequency for relaxation.
    func createRecoveryTrack(
        name: String,
        eventKeywords: [String]
    ) async -> ContextTrack

    /// Returns all non-archived tracks that have not expired.
    func activeTracks() async -> [ContextTrack]

    /// Returns all archived tracks.
    func archivedTracks() async -> [ContextTrack]

    /// Finds the first active track whose keywords match the given event title.
    func track(for eventTitle: String) async -> ContextTrack?

    /// Records a session against a track, updating usage count and running
    /// average success score.
    func recordSessionUsage(
        trackID: UUID,
        sessionID: UUID,
        successScore: Double
    ) async

    /// Manually archives a track by its identifier.
    func archiveTrack(_ trackID: UUID) async

    /// Archives all tracks whose `activeUntil` date has passed.
    /// - Returns: The number of tracks archived.
    @discardableResult
    func archiveExpiredTracks() async -> Int

    /// Permanently deletes a track by its identifier.
    func deleteTrack(_ trackID: UUID) async
}

// MARK: - Logger

extension Logger {

    /// Context track creation, archival, matching, and session recording.
    static let contextTracks = Logger(
        subsystem: "com.bionaural",
        category: "contextTracks"
    )
}

// MARK: - Implementation

/// Production `ContextTrackManagerProtocol` implementation backed by SwiftData.
///
/// `@MainActor`-isolated because `ModelContext` is not `Sendable`. All access
/// happens on the main actor, aligning with the app's MVVM architecture where
/// ViewModels are `@MainActor`.
@MainActor
public final class ContextTrackManager: ContextTrackManagerProtocol {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Creates a context track manager backed by the given model context.
    ///
    /// - Parameter modelContext: The SwiftData context for all persistence
    ///   operations. Typically the shared container's main context, injected
    ///   via the SwiftUI environment.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Creation

    /// Creates a Flow State track with locked audio parameters for sonic
    /// anchoring — consistent environments that train the brain to enter
    /// the target state faster.
    ///
    /// Flow State tracks lock the ambient bed, carrier frequency, beat frequency
    /// range, and melodic tags so that repeated sessions trigger the same sonic
    /// environment — reinforcing context-dependent state encoding.
    ///
    /// - Parameters:
    ///   - name: User-given track name (e.g., "Deep Work Monday").
    ///   - eventKeywords: Calendar keywords for auto-selection.
    ///   - mode: The focus mode for the track.
    ///   - ambientBedID: Locked ambient bed identifier, or `nil` for adaptive.
    ///   - carrierFrequency: Locked carrier frequency (Hz), or `nil` for mode default.
    ///   - melodicTags: Locked melodic palette tags for consistent timbre.
    ///   - sonicMemoryID: Linked `SonicMemory` UUID, or `nil`.
    ///   - activeUntil: Auto-archive date, or `nil` for permanent.
    /// - Returns: The newly created and persisted `ContextTrack`.
    public func createFlowStateTrack(
        name: String,
        eventKeywords: [String],
        mode: FocusMode,
        ambientBedID: String?,
        carrierFrequency: Double?,
        melodicTags: [String],
        sonicMemoryID: UUID?,
        activeUntil: Date?
    ) async -> ContextTrack {
        let frequencyRange = mode.frequencyRange
        let beatRange = [frequencyRange.lowerBound, frequencyRange.upperBound]

        let track = ContextTrack(
            name: name,
            purpose: TrackPurpose.flowState.rawValue,
            linkedEventKeywords: eventKeywords,
            lockedAmbientBedID: ambientBedID,
            lockedCarrierFrequency: carrierFrequency,
            lockedBeatFrequencyRange: beatRange,
            lockedMelodicTags: melodicTags,
            sonicMemoryID: sonicMemoryID,
            mode: mode.rawValue,
            activeUntil: activeUntil
        )

        modelContext.insert(track)
        save(context: "createFlowStateTrack")

        Logger.contextTracks.info(
            "Created Flow State track '\(name)' with mode \(mode.rawValue)"
        )

        return track
    }

    /// Creates a pre-performance track optimized for short, high-focus prep.
    ///
    /// Pre-performance tracks default to `.focus` mode and use the user's
    /// best-performing carrier frequency and ambient bed from their
    /// `SoundProfile` if available. Otherwise, mode defaults apply.
    ///
    /// - Parameters:
    ///   - name: User-given track name (e.g., "Piano Recital Prep").
    ///   - eventKeywords: Calendar keywords for auto-selection.
    ///   - activeUntil: Auto-archive date (typically the event date +
    ///     `TrackManagerConfig.autoArchiveDaysAfterEvent`), or `nil`.
    /// - Returns: The newly created and persisted `ContextTrack`.
    public func createPrePerformanceTrack(
        name: String,
        eventKeywords: [String],
        activeUntil: Date?
    ) async -> ContextTrack {
        let mode = FocusMode.focus
        let soundProfile = fetchSoundProfile()

        // Use best-performing carrier from the sound profile if available,
        // otherwise fall back to the mode's default carrier frequency.
        let carrierFrequency = soundProfile.flatMap { bestCarrier(from: $0, mode: mode) }
            ?? mode.defaultCarrierFrequency

        let frequencyRange = mode.frequencyRange
        let beatRange = [frequencyRange.lowerBound, frequencyRange.upperBound]

        let track = ContextTrack(
            name: name,
            purpose: TrackPurpose.prePerformance.rawValue,
            linkedEventKeywords: eventKeywords,
            lockedCarrierFrequency: carrierFrequency,
            lockedBeatFrequencyRange: beatRange,
            mode: mode.rawValue,
            activeUntil: activeUntil
        )

        modelContext.insert(track)
        save(context: "createPrePerformanceTrack")

        Logger.contextTracks.info(
            "Created pre-performance track '\(name)' with carrier \(carrierFrequency) Hz"
        )

        return track
    }

    /// Creates a recovery track with adaptive carrier frequency.
    ///
    /// Recovery tracks use `.relaxation` mode with no locked carrier
    /// frequency, allowing the adaptive engine to select freely based on
    /// real-time biometrics. Beat frequency range is set to the relaxation
    /// alpha range.
    ///
    /// - Parameters:
    ///   - name: User-given track name (e.g., "Post-Workout Recovery").
    ///   - eventKeywords: Calendar keywords for auto-selection.
    /// - Returns: The newly created and persisted `ContextTrack`.
    public func createRecoveryTrack(
        name: String,
        eventKeywords: [String]
    ) async -> ContextTrack {
        let mode = FocusMode.relaxation
        let frequencyRange = mode.frequencyRange
        let beatRange = [frequencyRange.lowerBound, frequencyRange.upperBound]

        let track = ContextTrack(
            name: name,
            purpose: TrackPurpose.recovery.rawValue,
            linkedEventKeywords: eventKeywords,
            lockedCarrierFrequency: nil,
            lockedBeatFrequencyRange: beatRange,
            mode: mode.rawValue
        )

        modelContext.insert(track)
        save(context: "createRecoveryTrack")

        Logger.contextTracks.info(
            "Created recovery track '\(name)'"
        )

        return track
    }

    // MARK: - Queries

    /// Returns all active tracks — not archived and not past their expiry.
    ///
    /// A track is active when `isArchived == false` AND either `activeUntil`
    /// is `nil` (permanent) or `activeUntil > now`.
    ///
    /// - Returns: Active tracks sorted by creation date (newest first).
    public func activeTracks() async -> [ContextTrack] {
        let now = Date()

        let descriptor = FetchDescriptor<ContextTrack>(
            predicate: #Predicate<ContextTrack> { track in
                track.isArchived == false
                && (track.activeUntil == nil || track.activeUntil! > now)
            },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.contextTracks.error(
                "Failed to fetch active tracks: \(error.localizedDescription)"
            )
            return []
        }
    }

    /// Returns all archived tracks sorted by creation date (newest first).
    public func archivedTracks() async -> [ContextTrack] {
        let descriptor = FetchDescriptor<ContextTrack>(
            predicate: #Predicate<ContextTrack> { track in
                track.isArchived == true
            },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.contextTracks.error(
                "Failed to fetch archived tracks: \(error.localizedDescription)"
            )
            return []
        }
    }

    /// Finds the first active track whose linked keywords match the event title.
    ///
    /// Performs a case-insensitive substring match: lowercases the event title
    /// and checks each active track's `linkedEventKeywords` for any keyword
    /// that appears within the title.
    ///
    /// - Parameter eventTitle: The calendar event title to match against.
    /// - Returns: The first matching active track, or `nil` if none match.
    public func track(for eventTitle: String) async -> ContextTrack? {
        let active = await activeTracks()
        let lowercasedTitle = eventTitle.lowercased()

        return active.first { track in
            track.linkedEventKeywords.contains { keyword in
                lowercasedTitle.contains(keyword.lowercased())
            }
        }
    }

    // MARK: - Session Recording

    /// Records a session against a track, updating usage statistics.
    ///
    /// Appends the session ID, increments `totalSessionCount`, and updates
    /// the running `averageSuccessScore` using an incremental mean formula.
    ///
    /// - Parameters:
    ///   - trackID: The UUID of the track to update.
    ///   - sessionID: The UUID of the completed session.
    ///   - successScore: The biometric success score for the session (0-1).
    public func recordSessionUsage(
        trackID: UUID,
        sessionID: UUID,
        successScore: Double
    ) async {
        guard let track = fetchTrack(by: trackID) else {
            Logger.contextTracks.warning(
                "recordSessionUsage: track not found for id \(trackID)"
            )
            return
        }

        let sessionIDString = sessionID.uuidString
        track.sessionIDs.append(sessionIDString)
        track.totalSessionCount += 1

        // Incremental running average: new_avg = old_avg + (score - old_avg) / count
        if let currentAverage = track.averageSuccessScore {
            let count = Double(track.totalSessionCount)
            track.averageSuccessScore = currentAverage + (successScore - currentAverage) / count
        } else {
            track.averageSuccessScore = successScore
        }

        save(context: "recordSessionUsage")

        let avgScore = track.averageSuccessScore ?? 0.0
        Logger.contextTracks.info(
            "Recorded session \(sessionIDString) on track '\(track.name)' (count: \(track.totalSessionCount), avg: \(avgScore))"
        )
    }

    // MARK: - Archival

    /// Manually archives a track by its identifier.
    ///
    /// - Parameter trackID: The UUID of the track to archive.
    public func archiveTrack(_ trackID: UUID) async {
        guard let track = fetchTrack(by: trackID) else {
            Logger.contextTracks.warning(
                "archiveTrack: track not found for id \(trackID)"
            )
            return
        }

        track.isArchived = true
        save(context: "archiveTrack")

        Logger.contextTracks.info("Archived track '\(track.name)'")
    }

    /// Archives all tracks whose `activeUntil` date has passed.
    ///
    /// Finds tracks where `activeUntil < now` and `isArchived == false`,
    /// then sets `isArchived = true` on each.
    ///
    /// - Returns: The number of tracks that were archived.
    @discardableResult
    public func archiveExpiredTracks() async -> Int {
        let now = Date()

        let descriptor = FetchDescriptor<ContextTrack>(
            predicate: #Predicate<ContextTrack> { track in
                track.isArchived == false
                && track.activeUntil != nil
                && track.activeUntil! < now
            }
        )

        do {
            let expired = try modelContext.fetch(descriptor)

            for track in expired {
                track.isArchived = true
            }

            if !expired.isEmpty {
                save(context: "archiveExpiredTracks")
                Logger.contextTracks.info(
                    "Auto-archived \(expired.count) expired track(s)"
                )
            }

            return expired.count
        } catch {
            Logger.contextTracks.error(
                "Failed to fetch expired tracks: \(error.localizedDescription)"
            )
            return 0
        }
    }

    // MARK: - Deletion

    /// Permanently deletes a track by its identifier.
    ///
    /// - Parameter trackID: The UUID of the track to delete.
    public func deleteTrack(_ trackID: UUID) async {
        guard let track = fetchTrack(by: trackID) else {
            Logger.contextTracks.warning(
                "deleteTrack: track not found for id \(trackID)"
            )
            return
        }

        let name = track.name
        modelContext.delete(track)
        save(context: "deleteTrack")

        Logger.contextTracks.info("Deleted track '\(name)'")
    }

    // MARK: - Private Helpers

    /// Fetches a single track by UUID.
    private func fetchTrack(by id: UUID) -> ContextTrack? {
        let descriptor = FetchDescriptor<ContextTrack>(
            predicate: #Predicate<ContextTrack> { track in
                track.id == id
            }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Logger.contextTracks.error(
                "Failed to fetch track \(id): \(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Fetches the user's sound profile for pre-performance track defaults.
    private func fetchSoundProfile() -> SoundProfile? {
        var descriptor = FetchDescriptor<SoundProfile>()
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Logger.contextTracks.error(
                "Failed to fetch sound profile: \(error.localizedDescription)"
            )
            return nil
        }
    }

    /// Derives the best carrier frequency from a sound profile for a given mode.
    ///
    /// Uses the mode's `carrierFrequencyRange` and the profile's energy
    /// preference to interpolate within the range. Returns `nil` if no
    /// meaningful preference exists for the mode.
    private func bestCarrier(from profile: SoundProfile, mode: FocusMode) -> Double? {
        guard let energy = profile.energyPreference[mode.rawValue] else {
            return nil
        }

        let range = mode.carrierFrequencyRange
        // Map energy preference (0-1) to carrier frequency range.
        // Higher energy preference = higher carrier frequency.
        return range.lowerBound + energy * (range.upperBound - range.lowerBound)
    }

    /// Saves the model context, logging errors without throwing.
    private func save(context label: String) {
        do {
            try modelContext.save()
        } catch {
            Logger.contextTracks.error(
                "Save failed (\(label)): \(error.localizedDescription)"
            )
        }
    }
}
