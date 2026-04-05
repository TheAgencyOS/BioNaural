// SwiftDataSoundProfileStore.swift
// BioNaural
//
// Concrete SwiftData-backed implementation of SoundProfileStoreProtocol.
// Loads, saves, and deletes SoundProfile records from the local store.
// Used by SoundProfileManager for production persistence.

import Foundation
import SwiftData

// MARK: - SwiftDataSoundProfileStore

@MainActor
public final class SwiftDataSoundProfileStore: SoundProfileStoreProtocol {

    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func loadProfile() async throws -> SoundProfile? {
        let descriptor = FetchDescriptor<SoundProfile>()
        return try modelContext.fetch(descriptor).first
    }

    public func saveProfile(_ profile: SoundProfile) async throws {
        modelContext.insert(profile)
        try modelContext.save()
    }

    public func deleteAllProfiles() async throws {
        try modelContext.delete(model: SoundProfile.self)
    }
}
