// AIContentService.swift
// BioNaural
//
// Protocol and implementations for requesting AI-generated audio content.
// v2 hits an ACE-Step 1.5 server for personalized stem pack generation.
// MockAIContentService returns bundled demo packs for development and testing.

import BioNauralShared
import Foundation

// MARK: - Generation Result

/// Result of a stem pack generation request.
public struct StemPackGenerationResult: Sendable {
    /// Unique identifier for the generated pack.
    public let packID: String
    /// Download URL for the generated pack archive (.zip).
    public let downloadURL: URL
    /// Metadata for the generated pack.
    public let metadata: StemPackMetadata
}

// MARK: - Content Pack Manifest

/// Describes a content pack available for download from the server.
/// Returned by `checkForUpdates` — the app decides which to download.
public struct ContentPackManifest: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let mode: FocusMode
    public let sizeBytes: Int64
    public let downloadURL: URL
    public let prompt: String?
}

// MARK: - Protocol

/// Contract for requesting AI-generated audio content.
///
/// **v2 implementation:** Hits an ACE-Step 1.5 server endpoint.
/// **Mock implementation:** Returns bundled demo packs from the app bundle.
///
/// The protocol is designed so the entire AI content pipeline can be
/// built and tested before any server infrastructure exists.
public protocol AIContentServiceProtocol: Sendable {

    /// Request generation of a personalized stem pack.
    ///
    /// - Parameters:
    ///   - prompt: Natural language prompt built by `SonicProfilePromptBuilder`.
    ///   - mode: The target focus mode (determines generation parameters).
    /// - Returns: A generation result containing the download URL and metadata.
    func generateStemPack(
        prompt: String,
        mode: FocusMode
    ) async throws -> StemPackGenerationResult

    /// Check if new personalized content is available for download.
    ///
    /// Called periodically (e.g., weekly) to refresh the user's content library.
    ///
    /// - Parameter profileHash: Hash of the user's SoundProfile preferences
    ///   (used to determine if new content should be generated).
    /// - Returns: Manifests for available packs, or empty if up to date.
    func checkForUpdates(
        profileHash: String
    ) async throws -> [ContentPackManifest]

    /// Download a content pack archive to a temporary directory.
    ///
    /// - Parameter manifest: The manifest describing the pack to download.
    /// - Returns: URL of the extracted pack directory (ready for installation).
    func downloadPack(
        manifest: ContentPackManifest
    ) async throws -> URL
}

// MARK: - Mock Implementation (Development + v1.5)

/// Returns bundled demo stem packs from the app bundle.
/// Enables full end-to-end testing of the StemAudioLayer +
/// BiometricStemMixer pipeline without any server infrastructure.
public final class MockAIContentService: AIContentServiceProtocol, @unchecked Sendable {

    public init() {}

    public func generateStemPack(
        prompt: String,
        mode: FocusMode
    ) async throws -> StemPackGenerationResult {
        // Simulate generation delay.
        try await Task.sleep(for: .seconds(Theme.Audio.StemMix.mockGenerationDelaySeconds))

        let packID = "mock_\(mode.rawValue)_\(UUID().uuidString.prefix(8))"

        // Return a mock result pointing to bundled demo content.
        let metadata = StemPackMetadata(
            id: packID,
            name: "Demo \(mode.rawValue.capitalized) Pack",
            padsFileName: "pads.m4a",
            textureFileName: "texture.m4a",
            bassFileName: "bass.m4a",
            rhythmFileName: mode == .sleep ? nil : "rhythm.m4a",
            energy: mockEnergy(for: mode),
            brightness: mode == .sleep
                ? Theme.Audio.StemMix.MockDefaults.sleepBrightness
                : Theme.Audio.StemMix.MockDefaults.focusBrightness,
            warmth: Theme.Audio.StemMix.MockDefaults.defaultWarmth,
            tempo: mode == .sleep ? nil : Theme.Audio.StemMix.MockDefaults.defaultTempo,
            key: "A",
            modeAffinity: [mode],
            generatedBy: .manual,
            generationPrompt: prompt
        )

        return StemPackGenerationResult(
            packID: packID,
            downloadURL: URL(fileURLWithPath: NSTemporaryDirectory()),
            metadata: metadata
        )
    }

    private func mockEnergy(for mode: FocusMode) -> Double {
        switch mode {
        case .focus:      return Theme.Audio.StemMix.MockDefaults.focusEnergy
        case .relaxation: return Theme.Audio.StemMix.MockDefaults.relaxEnergy
        case .sleep:      return Theme.Audio.StemMix.MockDefaults.sleepEnergy
        case .energize:   return Theme.Audio.StemMix.MockDefaults.energizeEnergy
        }
    }

    public func checkForUpdates(
        profileHash: String
    ) async throws -> [ContentPackManifest] {
        // Mock: no updates available.
        []
    }

    public func downloadPack(
        manifest: ContentPackManifest
    ) async throws -> URL {
        // Mock: return temp directory.
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(manifest.id)
    }
}
