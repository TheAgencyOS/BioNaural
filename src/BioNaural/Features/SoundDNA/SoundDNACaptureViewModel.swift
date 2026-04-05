// SoundDNACaptureViewModel.swift
// BioNaural
//
// ViewModel for the Sound DNA capture flow. Coordinates between the
// SoundDNAService (capture + analysis) and SoundProfileManager
// (persistence + profile integration). Also persists analyzed samples
// as SoundDNASample records in SwiftData.

import Foundation
import Observation
import SwiftData

// MARK: - SoundDNACaptureViewModel

@Observable
@MainActor
final class SoundDNACaptureViewModel {

    // MARK: - Published State

    /// Current pipeline state — drives the UI.
    var captureState: SoundDNAState { service.state }

    /// The most recent analysis result, for display in the result view.
    private(set) var lastResult: SoundDNAAnalysisResult?

    /// Whether the result has been saved to the profile.
    private(set) var isSavedToProfile: Bool = false

    // MARK: - Dependencies

    private let service: SoundDNAServiceProtocol
    private let profileManager: SoundProfileManagerProtocol
    private let modelContext: ModelContext

    // MARK: - Init

    init(
        service: SoundDNAServiceProtocol,
        profileManager: SoundProfileManagerProtocol,
        modelContext: ModelContext
    ) {
        self.service = service
        self.profileManager = profileManager
        self.modelContext = modelContext
    }

    // MARK: - Actions

    /// Start the capture and analysis pipeline.
    func startCapture() async {
        isSavedToProfile = false
        lastResult = nil
        await service.startCapture()

        // Extract result if complete
        if case .complete(let result) = service.state {
            lastResult = result
        }
    }

    /// Cancel an in-progress capture.
    func cancel() {
        service.cancelCapture()
    }

    /// Save the analysis result to SwiftData and integrate into the SoundProfile.
    func saveToProfile() async {
        guard let result = lastResult else { return }

        // Persist as SoundDNASample
        let sample = SoundDNASample(
            songTitle: result.songTitle,
            artistName: result.artistName,
            shazamID: result.shazamID,
            appleMusicID: result.appleMusicID,
            genre: result.genre,
            extractedBPM: result.bpm,
            extractedKey: result.key,
            extractedScale: result.scale.rawValue,
            extractedBrightness: result.brightness,
            extractedWarmth: result.warmth,
            extractedEnergy: result.energy,
            extractedDensity: result.density,
            spectralCentroidHz: result.spectralCentroidHz,
            source: result.source.rawValue,
            analysisConfidence: result.confidence,
            analyzedDurationSeconds: result.analyzedDuration,
            isIntegratedIntoProfile: true
        )
        modelContext.insert(sample)
        try? modelContext.save()

        // Integrate into SoundProfile
        await profileManager.integrateFromSoundDNA(result)

        isSavedToProfile = true
    }

    /// Reset to idle for another capture.
    func reset() {
        service.reset()
        lastResult = nil
        isSavedToProfile = false
    }
}
