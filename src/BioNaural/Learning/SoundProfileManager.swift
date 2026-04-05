// SoundProfileManager.swift
// BioNaural
//
// Manages and updates the user's learned sound preferences.
// Loads from SwiftData, applies learning updates from session outcomes,
// and persists changes immediately. All on-device, no network dependencies.

import Foundation
import SwiftData
import BioNauralShared

// MARK: - Sound Profile Manager Protocol

/// Public contract for managing the user's sound preference profile.
/// Enables dependency injection and test mocking.
@MainActor
public protocol SoundProfileManagerProtocol: AnyObject {
    /// Returns the current sound profile, loading or creating a default if needed.
    func currentProfile() async -> SoundProfile?
    /// Updates the profile based on a session outcome.
    func updateFromOutcome(_ outcome: BioNauralShared.SessionOutcome) async
    /// Integrates a Sound DNA analysis result into the profile.
    func integrateFromSoundDNA(_ result: SoundDNAAnalysisResult) async
    /// Resets all learned preferences to factory defaults.
    func resetToDefaults() async
    /// Force-reloads the profile from persistent storage.
    func reload() async
}

// MARK: - Sound Profile Store Protocol

/// Persistence contract for sound profiles. Backed by SwiftData in production,
/// replaceable with an in-memory store for tests.
@MainActor
public protocol SoundProfileStoreProtocol: AnyObject {
    /// Loads the current sound profile, or nil if none exists.
    func loadProfile() async throws -> SoundProfile?
    /// Saves (upserts) the given sound profile.
    func saveProfile(_ profile: SoundProfile) async throws
    /// Deletes all stored profiles (used by resetToDefaults).
    func deleteAllProfiles() async throws
}

// MARK: - Weight Adjustment Configuration

/// All weight-adjustment constants. These control how session outcomes
/// modify learned sound preferences. Never hardcoded at adjustment sites.
public enum SoundLearningConfig {

    /// Multiplier applied to sound tag weights on thumbs-up feedback.
    /// 1.10 = +10% increase.
    static let thumbsUpFactor: Double = 1.10

    /// Multiplier applied to sound tag weights on thumbs-down feedback.
    /// 0.80 = -20% decrease.
    static let thumbsDownFactor: Double = 0.80

    /// Multiplier applied when biometric success > highSuccessThreshold.
    /// 1.15 = +15% increase.
    static let highBiometricSuccessFactor: Double = 1.15

    /// Multiplier applied when biometric success < lowSuccessThreshold.
    /// 0.90 = -10% decrease.
    static let lowBiometricSuccessFactor: Double = 0.90

    /// Biometric success threshold above which positive reinforcement is applied.
    static let highSuccessThreshold: Double = 0.7

    /// Biometric success threshold below which negative reinforcement is applied.
    static let lowSuccessThreshold: Double = 0.3

    /// Exponential moving average alpha for self-awareness score updates.
    /// Lower values make the running average more stable.
    static let selfAwarenessEMAAlpha: Double = 0.2
}

// MARK: - Sound Profile Manager

/// Manages the user's learned sound preference profile.
///
/// The manager loads the profile from persistent storage on first access,
/// applies learning updates from session outcomes, and writes changes
/// back immediately. All operations are serialized by the actor.
///
/// Usage:
/// ```swift
/// let manager = SoundProfileManager(store: swiftDataStore)
/// let profile = await manager.currentProfile()
/// await manager.updateFromOutcome(outcome)
/// ```
@MainActor
public final class SoundProfileManager: SoundProfileManagerProtocol {

    // MARK: - Dependencies

    private let store: SoundProfileStoreProtocol
    private let dateProvider: DateProviding

    // MARK: - Cached State

    /// The in-memory working copy. Loaded lazily on first access.
    private var cachedProfile: SoundProfile?

    // MARK: - Initialization

    /// Creates a sound profile manager.
    ///
    /// - Parameters:
    ///   - store: Persistence backend for sound profiles.
    ///   - dateProvider: Clock abstraction for testability.
    public init(
        store: SoundProfileStoreProtocol,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.store = store
        self.dateProvider = dateProvider
    }

    // MARK: - Public Interface

    /// Returns the current sound profile, loading from storage or creating
    /// a default if none exists.
    public func currentProfile() async -> SoundProfile? {
        if let cached = cachedProfile {
            return cached
        }
        let loaded = try? await store.loadProfile()
        cachedProfile = loaded
        return loaded
    }

    /// Updates the sound profile based on a session outcome.
    /// Delegates to SoundProfile.updateFromOutcome which implements the learning rules.
    public func updateFromOutcome(_ outcome: BioNauralShared.SessionOutcome) async {
        guard let profile = await currentProfile() else { return }
        profile.updateFromOutcome(outcome)
        cachedProfile = profile
        try? await store.saveProfile(profile)
    }

    /// Integrates a Sound DNA analysis result into the sound profile.
    /// Delegates to SoundProfile.integrateFromSoundDNA which blends new
    /// features with existing preferences using an EMA learning rate.
    public func integrateFromSoundDNA(_ result: SoundDNAAnalysisResult) async {
        guard let profile = await currentProfile() else { return }
        guard result.confidence >= Theme.SoundDNA.minimumIntegrationConfidence else { return }
        profile.integrateFromSoundDNA(result)
        cachedProfile = profile
        try? await store.saveProfile(profile)
    }

    /// Resets the sound profile to factory defaults.
    public func resetToDefaults() async {
        guard let profile = await currentProfile() else { return }
        profile.resetPreferences()
        cachedProfile = profile
        try? await store.saveProfile(profile)
    }

    /// Force-reloads the profile from persistent storage, discarding the cached copy.
    /// Useful after data import or migration.
    public func reload() async {
        cachedProfile = nil
        _ = await currentProfile()
    }
}
