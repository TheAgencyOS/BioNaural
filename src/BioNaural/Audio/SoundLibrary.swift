// SoundLibrary.swift
// BioNaural
//
// Tagged catalog of all bundled melodic loops and textures.
// Metadata is loaded from a bundled JSON file (sounds.json) at init.
// Provides filtering by mode affinity, energy, brightness, density,
// and instrument — used by SoundSelector to pick appropriate sounds.

import AVFoundation
import BioNauralShared
import Foundation
// MARK: - Type Aliases
/// Unique identifier for a sound in the library catalog.
public typealias SoundID = String
// MARK: - Instrument
/// Primary instrument family for a melodic loop.
public enum Instrument: String, Codable, CaseIterable, Sendable {
    case pad
    case piano
    case strings
    case guitar
    case bass
    case percussion
    case texture
}
// MARK: - SoundMetadata
/// Describes a single sound in the library. Every field maps to the
/// tagging system defined in Tech-MelodicLayer.md.
///
/// **No hardcoded values.** Ranges and thresholds that govern how
/// sounds are selected live in `Theme.Audio` and `SoundSelector`,
/// not here. This struct is pure data.
public struct SoundMetadata: Codable, Identifiable, Sendable {
    /// Unique identifier (matches the filename stem in the bundle).
    public let id: SoundID
    /// Filename in the app bundle (without path, with extension).
    public let fileName: String
    /// How activating vs. calming the sound is. `0` = deep sleep,
    /// `1` = high focus energy.
    public let energy: Double
    /// BPM if rhythmic, `nil` if arrhythmic / free-time.
    public let tempo: Double?
    /// Musical key (e.g., `"C"`, `"Eb"`, `"F#"`). `nil` for atonal sounds.
    public let key: String?
    /// Scale type (e.g., `"pentatonic"`, `"whole_tone"`, `"major"`,
    /// `"minor"`, `"dorian"`, `"modal"`). `nil` for atonal sounds.
    public let scale: String?
    /// Primary instrument family.
    public let instrument: Instrument
    /// Spectral brightness. `0` = very dark / filtered, `1` = bright / present.
    public let brightness: Double
    /// Note/event density. `0` = sparse single sustains, `1` = dense.
    public let density: Double
    /// Which focus modes this sound is appropriate for.
    public let modeAffinity: [FocusMode]
    /// Duration of the loop in seconds.
    public let duration: TimeInterval
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case energy
        case tempo
        case key
        case scale
        case instrument
        case brightness
        case density
        case modeAffinity
        case duration
    }
}
// MARK: - SoundLibrary
/// Loads and indexes the complete catalog of bundled melodic sounds.
/// Initialized from `sounds.json` in the app bundle. Provides
/// filtering methods that `SoundSelector` uses to narrow candidates.
public final class SoundLibrary {
    // MARK: - Storage
    /// All sounds in the catalog, keyed by SoundID for O(1) lookup.
    private let catalog: [SoundID: SoundMetadata]
    /// Ordered list for iteration.
    public let allSounds: [SoundMetadata]
    // MARK: - Initializer
    /// Loads the sound catalog from the bundled `sounds.json`.
    ///
    /// If the file is missing or corrupt, the library initializes empty
    /// and logs the error — the app degrades gracefully (melodic layer
    /// simply has nothing to play).
    /// Wrapper for the top-level JSON structure: `{"version": ..., "catalog": [...]}`
    private struct SoundCatalogFile: Decodable {
        let catalog: [SoundMetadata]
    }

    public init() {
        guard let url = Bundle.main.url(forResource: Theme.Audio.soundCatalogFileName,
                                         withExtension: Theme.Audio.soundCatalogFileExtension) else {
            self.catalog = [:]
            self.allSounds = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let file = try decoder.decode(SoundCatalogFile.self, from: data)
            self.allSounds = file.catalog
            self.catalog = Dictionary(uniqueKeysWithValues: file.catalog.map { ($0.id, $0) })
        } catch {
            self.catalog = [:]
            self.allSounds = []
        }
    }
    /// Initializer for testing — accepts metadata directly instead of loading from disk.
    internal init(sounds: [SoundMetadata]) {
        self.allSounds = sounds
        self.catalog = Dictionary(uniqueKeysWithValues: sounds.map { ($0.id, $0) })
    }
    // MARK: - Lookup
    /// Returns metadata for a specific sound, or `nil` if the ID is unknown.
    public func metadata(for soundID: SoundID) -> SoundMetadata? {
        catalog[soundID]
    }
    /// Returns the bundle URL for a sound's audio file, or `nil` if not found.
    /// Searches the app bundle using the `fileName` from the sound's metadata.
    public func audioFileURL(for soundID: SoundID) -> URL? {
        guard let meta = catalog[soundID] else { return nil }
        let name = (meta.fileName as NSString).deletingPathExtension
        let ext = (meta.fileName as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
    // MARK: - Filtering
    /// Filters the catalog by the given criteria. All parameters are optional —
    /// pass `nil` to skip a filter dimension.
    /// - Parameters:
    ///   - mode: Only sounds whose `modeAffinity` contains this mode.
    ///   - energyRange: Closed range for the `energy` tag.
    ///   - brightnessRange: Closed range for the `brightness` tag.
    ///   - densityRange: Closed range for the `density` tag.
    ///   - instruments: Allowed instrument families. `nil` = all instruments.
    /// - Returns: Sounds matching all non-nil criteria.
    public func filter(
        mode: FocusMode? = nil,
        energyRange: ClosedRange<Double>? = nil,
        brightnessRange: ClosedRange<Double>? = nil,
        densityRange: ClosedRange<Double>? = nil,
        instruments: Set<Instrument>? = nil
    ) -> [SoundMetadata] {
        allSounds.filter { sound in
            if let mode, !sound.modeAffinity.contains(mode) {
                return false
            }
            if let range = energyRange, !range.contains(sound.energy) {
                return false
            }
            if let range = brightnessRange, !range.contains(sound.brightness) {
                return false
            }
            if let range = densityRange, !range.contains(sound.density) {
                return false
            }
            if let allowed = instruments, !allowed.contains(sound.instrument) {
                return false
            }
            return true
        }
    }
}
