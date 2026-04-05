// ContentPack.swift
// BioNaural
//
// SwiftData model for downloaded AI-generated content packs.
// Each pack contains stem-separated audio files (pads, texture, bass,
// optional rhythm) managed by ContentPackManager. Metadata tracks
// download date, playback frequency, and storage size for LRU eviction.

import Foundation
import SwiftData

/// Persistent metadata for a downloaded content pack.
///
/// Content packs are stored in `Documents/ContentPacks/{id}/` and
/// contain stem audio files plus a `metadata.json` (StemPackMetadata).
/// This SwiftData model tracks the pack's lifecycle — when it was
/// downloaded, how often it's played, and how much storage it uses.
@Model
public final class ContentPack {

    // MARK: - Identity

    /// Unique pack identifier (matches the directory name and StemPackMetadata.id).
    @Attribute(.unique)
    public var id: String

    /// Human-readable name (e.g., "Warm Focus Ambient").
    public var name: String

    // MARK: - Classification

    /// The focus mode this pack is designed for (FocusMode.rawValue).
    public var mode: String

    /// Activating vs. calming — `0.0` = deep sleep, `1.0` = high energy.
    public var energy: Double

    /// Spectral brightness — `0.0` = dark/warm, `1.0` = bright/airy.
    public var brightness: Double

    /// Spectral warmth — `0.0` = cold/clinical, `1.0` = warm/rich.
    public var warmth: Double

    // MARK: - Source

    /// The text prompt used for AI generation. `nil` for manually
    /// produced or Demucs-separated packs.
    public var generationPrompt: String?

    // MARK: - Lifecycle

    /// When this pack was downloaded to the device.
    public var downloadDate: Date

    /// When this pack was last played. Used for LRU eviction.
    public var lastPlayedDate: Date?

    /// Total number of times this pack has been played.
    public var playCount: Int

    // MARK: - Storage

    /// Total size of all files in this pack (bytes).
    public var sizeBytes: Int64

    /// Relative path from the app's Documents directory to the pack folder
    /// (e.g., `"ContentPacks/pack_focus_warm_01"`).
    public var localPath: String

    // MARK: - Initializer

    public init(
        id: String,
        name: String,
        mode: String,
        energy: Double,
        brightness: Double,
        warmth: Double,
        generationPrompt: String? = nil,
        downloadDate: Date = Date(),
        lastPlayedDate: Date? = nil,
        playCount: Int = 0,
        sizeBytes: Int64,
        localPath: String
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.energy = energy
        self.brightness = brightness
        self.warmth = warmth
        self.generationPrompt = generationPrompt
        self.downloadDate = downloadDate
        self.lastPlayedDate = lastPlayedDate
        self.playCount = playCount
        self.sizeBytes = sizeBytes
        self.localPath = localPath
    }

    // MARK: - Convenience

    /// Full URL to the pack directory on disk.
    public var directoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return documents.appendingPathComponent(localPath)
    }

    /// Record a play event — updates `lastPlayedDate` and increments `playCount`.
    public func recordPlay() {
        lastPlayedDate = Date()
        playCount += 1
    }
}
