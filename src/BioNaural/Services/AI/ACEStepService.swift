// ACEStepService.swift
// BioNaural
//
// Protocol and placeholder for AI music generation via ACE-STEP 1.5.
// When the API or local model becomes available, implement
// ACEStepMusicService.generateLoop() and flip isAvailable to true.
// The MelodicLayer treats generated loops identically to bundled ones —
// both are local .m4a file URLs fed to AVAudioPlayerNode.
//
// Until then, BioNaural uses its curated, tagged sound library for all
// melodic content. This placeholder ensures the architecture is ready
// with zero refactoring when generative audio ships.

import Foundation
import os.log

// MARK: - Protocol

/// Contract for AI-powered music generation. Implementations produce
/// short audio loops from a structured prompt, returning a local file URL
/// that the MelodicLayer can play through AVAudioPlayerNode.
public protocol MusicGenerationServiceProtocol: AnyObject, Sendable {

    /// Generates an audio loop matching the given prompt.
    ///
    /// - Parameter prompt: Structured description of the desired audio.
    /// - Returns: A file URL pointing to the generated audio on disk (.m4a).
    /// - Throws: `MusicGenerationError` if generation fails or the service
    ///   is not configured.
    func generateLoop(prompt: MusicPrompt) async throws -> URL

    /// Whether the service is configured and ready to generate audio.
    var isAvailable: Bool { get }
}

// MARK: - Music Prompt

/// Structured prompt describing the audio loop to generate. All fields
/// map to musical concepts that ACE-STEP 1.5 (or a similar model) can
/// interpret to produce coherent, mode-appropriate audio.
public struct MusicPrompt: Codable, Sendable, Equatable {

    /// The BioNaural session mode driving this generation.
    /// One of: "focus", "relaxation", "sleep", "energize".
    public let mode: String

    /// Energy level on a 0.0 (minimal) to 1.0 (maximum) scale.
    /// Derived from the adaptive engine's current biometric state.
    public let energy: Double

    /// Target tempo in BPM. Nil allows the model to choose freely
    /// based on mode and energy.
    public let tempo: Int?

    /// Musical key (e.g., "C", "F#", "Bb").
    public let key: String

    /// Scale type for tonal content.
    /// Examples: "pentatonic", "major", "minor", "lydian", "dorian", "mixolydian".
    public let scale: String

    /// Primary instrument or timbre.
    /// Examples: "pad", "piano", "strings", "guitar", "bells", "synth".
    public let instrument: String

    /// Target loop duration in seconds.
    public let durationSeconds: Int

    /// Overall stylistic direction.
    /// Examples: "ambient", "minimal", "rhythmic", "textural", "melodic".
    public let style: String

    public init(
        mode: String,
        energy: Double,
        tempo: Int?,
        key: String,
        scale: String,
        instrument: String,
        durationSeconds: Int,
        style: String
    ) {
        self.mode = mode
        self.energy = max(0, min(1, energy))
        self.tempo = tempo
        self.key = key
        self.scale = scale
        self.instrument = instrument
        self.durationSeconds = durationSeconds
        self.style = style
    }
}

// MARK: - Errors

/// Errors specific to AI music generation.
public enum MusicGenerationError: Error, LocalizedError {
    /// The service is not yet configured (no API key or local model).
    case notConfigured

    /// The generation request failed.
    case generationFailed(underlying: Error?)

    /// The model produced output that could not be converted to valid audio.
    case invalidOutput

    /// The output file could not be written to disk.
    case fileWriteFailed

    /// The requested duration exceeds the service's maximum.
    case durationExceedsLimit(maxSeconds: Int)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI music generation is not configured."
        case .generationFailed(let error):
            if let error {
                return "Music generation failed: \(error.localizedDescription)"
            }
            return "Music generation failed."
        case .invalidOutput:
            return "The generated audio was invalid."
        case .fileWriteFailed:
            return "Failed to save generated audio to disk."
        case .durationExceedsLimit(let max):
            return "Requested duration exceeds the \(max)-second limit."
        }
    }
}

// MARK: - ACE-STEP Placeholder

/// Placeholder implementation for ACE-STEP 1.5 music generation.
///
/// Currently returns `isAvailable = false` and throws `.notConfigured`
/// on all generation calls. When the ACE-STEP API or on-device model
/// becomes available:
///
/// 1. Add the API endpoint / Core ML model to this class.
/// 2. Implement `generateLoop()` to call the model and write the output
///    to the app's caches directory as .m4a.
/// 3. Set `isAvailable` to check for API key / model presence.
/// 4. The MelodicLayer picks up generated loops automatically — it only
///    cares about the file URL, not the source.
public final class ACEStepMusicService: MusicGenerationServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.bionaural", category: "MusicGeneration")

    /// Directory where generated loops are cached.
    private let cacheDirectory: URL

    public init() {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            self.cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratedLoops", isDirectory: true)
            return
        }
        self.cacheDirectory = caches.appendingPathComponent("GeneratedLoops", isDirectory: true)
    }

    // MARK: - MusicGenerationServiceProtocol

    /// Not available until ACE-STEP API or local model is configured.
    public var isAvailable: Bool { false }

    public func generateLoop(prompt: MusicPrompt) async throws -> URL {
        // ACE-STEP 1.5 integration point — enable by configuring the server endpoint.
        //
        // Expected flow:
        // 1. Validate prompt (duration within limits, valid key/scale).
        // 2. Encode prompt to ACE-STEP API format.
        // 3. POST to API endpoint (or run Core ML inference).
        // 4. Receive raw audio data (WAV or PCM).
        // 5. Convert to .m4a using AVAssetWriter for AAC compression.
        // 6. Write to cacheDirectory with a content-hash filename.
        // 7. Return the file URL.
        //
        // The MelodicLayer loads this URL identically to bundled loops:
        //   let file = try AVAudioFile(forReading: url)
        //   playerNode.scheduleFile(file, at: nil)

        logger.info("Music generation requested but ACE-STEP is not configured.")
        throw MusicGenerationError.notConfigured
    }

    // MARK: - Cache Management

    /// Removes all cached generated loops. Called when the user clears
    /// app caches from Settings.
    public func clearCache() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cacheDirectory.path) else { return }
        try fm.removeItem(at: cacheDirectory)
        logger.info("Cleared generated loop cache.")
    }

    /// Total size of cached generated loops in bytes.
    public func cacheSize() -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += size
        }
        return total
    }
}
