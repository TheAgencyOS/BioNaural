// ContentPackManager.swift
// BioNaural
//
// Downloads, caches, indexes, and manages AI-generated content packs
// on device. Each pack is a directory containing stem audio files
// (pads, texture, bass, optional rhythm) plus a metadata.json.
//
// Storage is bounded by Theme.Audio.StemMix.maxStorageMB with LRU
// eviction. At least one pack per mode is always retained.

import BioNauralShared
import Foundation
import OSLog
import SwiftData

// MARK: - Protocol

/// Contract for content pack management. Enables mock for testing.
public protocol ContentPackManagerProtocol {
    func packs(for mode: FocusMode) -> [ContentPack]
    func activePack(for mode: FocusMode) -> ContentPack?
    func loadMetadata(for pack: ContentPack) -> StemPackMetadata?
    @discardableResult
    func install(from sourceURL: URL, metadata: StemPackMetadata) throws -> ContentPack
    func totalStorageUsed() -> Int64
}

// MARK: - Implementation

/// Manages the local content pack library.
///
/// **Responsibilities:**
/// - Maintain `Documents/ContentPacks/` directory structure
/// - Index packs by mode for fast lookup
/// - Load `StemPackMetadata` from disk
/// - Track storage usage and evict LRU packs when over budget
/// - Provide pack URLs to `StemAudioLayer`
public final class ContentPackManager: ContentPackManagerProtocol {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let fileManager: FileManager

    // MARK: - Constants

    /// Root directory for all content packs.
    private var rootURL: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return documents.appendingPathComponent("ContentPacks")
    }

    // MARK: - Initializer

    public init(modelContext: ModelContext, fileManager: FileManager = .default) {
        self.modelContext = modelContext
        self.fileManager = fileManager
        ensureDirectoryExists()
    }

    // MARK: - Pack Discovery

    /// Returns all downloaded packs for a given mode, sorted by most recently played.
    public func packs(for mode: FocusMode) -> [ContentPack] {
        let modeRaw = mode.rawValue
        let descriptor = FetchDescriptor<ContentPack>(
            predicate: #Predicate { $0.mode == modeRaw },
            sortBy: [SortDescriptor(\.lastPlayedDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Returns the most recently played pack for a mode, or the newest download
    /// if nothing has been played yet.
    public func activePack(for mode: FocusMode) -> ContentPack? {
        packs(for: mode).first
    }

    /// Loads the `StemPackMetadata` from a content pack's directory.
    public func loadMetadata(for pack: ContentPack) -> StemPackMetadata? {
        let metadataURL = pack.directoryURL.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL) else {
            Logger.audio.warning("Missing metadata.json for pack '\(pack.id)'")
            return nil
        }
        return try? JSONDecoder().decode(StemPackMetadata.self, from: data)
    }

    // MARK: - Pack Installation

    /// Install a content pack from a downloaded directory.
    ///
    /// Moves the directory into `ContentPacks/`, loads metadata,
    /// creates a SwiftData record, and runs storage eviction if needed.
    ///
    /// - Parameters:
    ///   - sourceURL: Temporary directory containing the extracted pack files.
    ///   - metadata: The pack's metadata (already parsed from the download).
    /// - Returns: The created `ContentPack` record.
    @discardableResult
    public func install(from sourceURL: URL, metadata: StemPackMetadata) throws -> ContentPack {
        let destURL = rootURL.appendingPathComponent(metadata.id)

        // Remove existing pack with same ID if present.
        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destURL)

        // Calculate storage size.
        let size = directorySize(at: destURL)

        let relativePath = "ContentPacks/\(metadata.id)"
        let record = ContentPack(
            id: metadata.id,
            name: metadata.name,
            mode: metadata.modeAffinity.first?.rawValue ?? FocusMode.focus.rawValue,
            energy: metadata.energy,
            brightness: metadata.brightness,
            warmth: metadata.warmth,
            generationPrompt: metadata.generationPrompt,
            sizeBytes: size,
            localPath: relativePath
        )

        modelContext.insert(record)
        try modelContext.save()

        // Evict old packs if over budget.
        evictIfNeeded()

        return record
    }

    // MARK: - Storage Management

    /// Total storage used by all content packs (bytes).
    public func totalStorageUsed() -> Int64 {
        let descriptor = FetchDescriptor<ContentPack>()
        let packs = (try? modelContext.fetch(descriptor)) ?? []
        return packs.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Evict least-recently-played packs until storage is under budget.
    /// Always retains at least `Theme.Audio.StemMix.minPacksPerMode` per mode.
    private func evictIfNeeded() {
        let maxBytes = Int64(Theme.Audio.StemMix.maxStorageMB) * Theme.Audio.StemMix.bytesPerMB
        guard totalStorageUsed() > maxBytes else { return }

        // Fetch all packs sorted by oldest play date first (LRU).
        let descriptor = FetchDescriptor<ContentPack>(
            sortBy: [SortDescriptor(\.lastPlayedDate, order: .forward)]
        )
        guard let allPacks = try? modelContext.fetch(descriptor) else { return }

        // Count packs per mode.
        var modeCount: [String: Int] = [:]
        for pack in allPacks {
            modeCount[pack.mode, default: 0] += 1
        }

        let minPerMode = Theme.Audio.StemMix.minPacksPerMode

        for pack in allPacks {
            guard totalStorageUsed() > maxBytes else { break }

            // Don't evict if this mode would go below minimum.
            let count = modeCount[pack.mode, default: 0]
            if count <= minPerMode { continue }

            // Delete from disk and SwiftData.
            try? fileManager.removeItem(at: pack.directoryURL)
            modeCount[pack.mode, default: 0] -= 1
            modelContext.delete(pack)
        }

        try? modelContext.save()
    }

    // MARK: - Helpers

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: rootURL.path) {
            try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
