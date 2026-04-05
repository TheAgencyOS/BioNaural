// MockSoundDNAService.swift
// BioNaural
//
// Mock implementation of SoundDNAServiceProtocol for SwiftUI previews
// and unit tests. Returns configurable results without audio hardware.

import Foundation
import Observation

// MARK: - MockSoundDNAService

@Observable
@MainActor
public final class MockSoundDNAService: SoundDNAServiceProtocol {

    // MARK: - State

    public private(set) var state: SoundDNAState = .idle

    // MARK: - Configuration

    /// The result to return when capture completes. Set this before
    /// calling `startCapture()` to control the mock output.
    public var mockResult: SoundDNAAnalysisResult

    /// Simulated delay for each pipeline stage (seconds).
    public var simulatedDelay: Double

    /// If true, the capture will fail with an error.
    public var shouldFail: Bool

    // MARK: - Init

    public init(
        mockResult: SoundDNAAnalysisResult = MockSoundDNAService.defaultResult,
        simulatedDelay: Double = 0.5,
        shouldFail: Bool = false
    ) {
        self.mockResult = mockResult
        self.simulatedDelay = simulatedDelay
        self.shouldFail = shouldFail
    }

    // MARK: - Protocol Conformance

    public func startCapture() async {
        state = .listening
        try? await Task.sleep(for: .seconds(simulatedDelay))

        guard !shouldFail else {
            state = .error("Mock capture error")
            return
        }

        state = .identifying
        try? await Task.sleep(for: .seconds(simulatedDelay))

        state = .analyzing
        try? await Task.sleep(for: .seconds(simulatedDelay))

        state = .complete(mockResult)
    }

    public func cancelCapture() {
        state = .idle
    }

    public func reset() {
        state = .idle
    }

    // MARK: - Default Mock Data

    public static let defaultResult = SoundDNAAnalysisResult(
        songTitle: "Midnight City",
        artistName: "M83",
        shazamID: "mock-shazam-id",
        appleMusicID: nil,
        genre: "Electronic",
        bpm: 105,
        key: "A",
        scale: .minor,
        brightness: 0.65,
        warmth: 0.55,
        energy: 0.7,
        density: 0.6,
        spectralCentroidHz: 2800,
        source: .shazamMic,
        confidence: 0.75,
        analyzedDuration: 15.0
    )
}
