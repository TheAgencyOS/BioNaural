// SoundDNAServiceProtocol.swift
// BioNaural
//
// Protocol-based contract for the Sound DNA capture and analysis pipeline.
// Separates the interface from the ShazamKit + vDSP implementation so
// tests and previews can use a mock without audio hardware.

import Foundation

// MARK: - Analysis Result

/// The complete output of a Sound DNA analysis pipeline run.
/// Contains both ShazamKit identification data (if matched) and
/// on-device DSP feature extraction results.
public struct SoundDNAAnalysisResult: Sendable {

    // MARK: Identification

    /// Song title from ShazamKit. `nil` if unidentified.
    public let songTitle: String?

    /// Artist name from ShazamKit. `nil` if unidentified.
    public let artistName: String?

    /// Shazam media item ID. `nil` if unidentified.
    public let shazamID: String?

    /// Apple Music catalog ID. `nil` if unidentified.
    public let appleMusicID: String?

    /// Genre from ShazamKit metadata. `nil` if unavailable.
    public let genre: String?

    // MARK: Extracted Features

    /// Detected BPM. `nil` if no clear beat.
    public let bpm: Double?

    /// Detected key (e.g., "C", "F#"). `nil` if detection failed.
    public let key: String?

    /// Major/minor scale classification.
    public let scale: DetectedScale

    /// Spectral brightness [0.0 - 1.0].
    public let brightness: Double

    /// Warmth [0.0 - 1.0].
    public let warmth: Double

    /// Energy [0.0 - 1.0].
    public let energy: Double

    /// Density [0.0 - 1.0].
    public let density: Double

    /// Raw spectral centroid in Hz.
    public let spectralCentroidHz: Double?

    // MARK: Metadata

    /// How the audio was acquired.
    public let source: SoundDNASource

    /// Confidence in the extracted features [0.0 - 1.0].
    public let confidence: Double

    /// Duration of the analyzed segment in seconds.
    public let analyzedDuration: Double

    public init(
        songTitle: String? = nil,
        artistName: String? = nil,
        shazamID: String? = nil,
        appleMusicID: String? = nil,
        genre: String? = nil,
        bpm: Double? = nil,
        key: String? = nil,
        scale: DetectedScale = .unknown,
        brightness: Double = 0.5,
        warmth: Double = 0.5,
        energy: Double = 0.5,
        density: Double = 0.5,
        spectralCentroidHz: Double? = nil,
        source: SoundDNASource = .micOnly,
        confidence: Double = 0.5,
        analyzedDuration: Double = 0
    ) {
        self.songTitle = songTitle
        self.artistName = artistName
        self.shazamID = shazamID
        self.appleMusicID = appleMusicID
        self.genre = genre
        self.bpm = bpm
        self.key = key
        self.scale = scale
        self.brightness = brightness
        self.warmth = warmth
        self.energy = energy
        self.density = density
        self.spectralCentroidHz = spectralCentroidHz
        self.source = source
        self.confidence = confidence
        self.analyzedDuration = analyzedDuration
    }
}

// MARK: - Analysis State

/// Observable states of the Sound DNA capture pipeline.
public enum SoundDNAState: Sendable, Equatable {
    /// Idle — not capturing.
    case idle
    /// Listening to audio via microphone.
    case listening
    /// Attempting to identify the song via ShazamKit.
    case identifying
    /// Running on-device DSP analysis on captured/downloaded audio.
    case analyzing
    /// Analysis complete with result.
    case complete(SoundDNAAnalysisResult)
    /// An error occurred during capture or analysis.
    case error(String)

    public static func == (lhs: SoundDNAState, rhs: SoundDNAState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.listening, .listening): return true
        case (.identifying, .identifying): return true
        case (.analyzing, .analyzing): return true
        case (.complete, .complete): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Protocol

/// Contract for the Sound DNA capture and analysis service.
///
/// The service orchestrates: mic capture → ShazamKit identification →
/// on-device audio feature extraction → assembled result. Protocol-based
/// for dependency injection and test mocking.
@MainActor
public protocol SoundDNAServiceProtocol: AnyObject {

    /// Current state of the capture pipeline. Observable for UI binding.
    var state: SoundDNAState { get }

    /// Start capturing audio and run the full analysis pipeline.
    /// Updates `state` as it progresses through listening → identifying →
    /// analyzing → complete/error.
    func startCapture() async

    /// Cancel an in-progress capture. Resets state to idle.
    func cancelCapture()

    /// Reset the service to idle state after viewing results.
    func reset()
}
