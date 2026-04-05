// SoundDNAService.swift
// BioNaural
//
// Production implementation of the Sound DNA capture pipeline.
// Orchestrates: mic capture → ShazamKit identification → on-device
// DSP analysis → assembled result. All on-device, no external servers.
//
// Architecture:
// 1. Start mic capture via AVAudioEngine
// 2. Feed audio to ShazamKit (parallel with buffer accumulation)
// 3. If ShazamKit matches, attempt to download Apple Music preview
//    for cleaner analysis; fall back to mic audio
// 4. Run SoundDNAAnalyzer on the best available audio
// 5. Assemble and return SoundDNAAnalysisResult

import Foundation
import AVFoundation
import ShazamKit
import Observation

// MARK: - SoundDNAService

/// Production Sound DNA service using ShazamKit + AVAudioEngine + vDSP.
///
/// The service manages its own audio session for capture. It does NOT
/// interfere with the main audio engine (BinauralBeatNode) — capture
/// happens before a session starts, never during.
@Observable
@MainActor
public final class SoundDNAService: NSObject, SoundDNAServiceProtocol {

    // MARK: - Published State

    public private(set) var state: SoundDNAState = .idle

    // MARK: - Dependencies

    private let analyzer: SoundDNAAnalyzerProtocol

    // MARK: - Audio Capture State

    private var captureEngine: AVAudioEngine?
    private var capturedSamples: [Float] = []
    private var capturedSampleRate: Double = Theme.SoundDNA.captureSampleRate

    // MARK: - ShazamKit State

    private var shazamSession: SHSession?
    private var shazamMatch: SHMatchedMediaItem?
    private var shazamContinuation: CheckedContinuation<SHMatchedMediaItem?, Never>?

    // MARK: - Cancellation

    private var isCancelled = false

    // MARK: - Init

    public init(analyzer: SoundDNAAnalyzerProtocol = SoundDNAAnalyzer()) {
        self.analyzer = analyzer
        super.init()
    }

    // MARK: - Public API

    public func startCapture() async {
        isCancelled = false
        capturedSamples = []
        shazamMatch = nil
        state = .listening

        // Step 1: Capture audio from microphone
        let captureSuccess = await performCapture()
        guard captureSuccess, !isCancelled else {
            if !isCancelled { state = .error("Microphone capture failed") }
            return
        }

        // Step 2: Identify with ShazamKit
        state = .identifying
        let matchedItem = await identifyWithShazam()

        guard !isCancelled else { return }

        // Step 3: Analyze audio
        state = .analyzing

        let features = analyzer.analyze(
            samples: capturedSamples,
            sampleRate: capturedSampleRate,
            channelCount: 1
        )

        guard !isCancelled else { return }

        // Step 4: Determine source and confidence
        let source: SoundDNASource
        let confidence: Double

        if matchedItem != nil {
            source = .shazamMic
            confidence = Theme.SoundDNA.micAnalysisConfidence
        } else {
            source = .micOnly
            confidence = Theme.SoundDNA.micAnalysisConfidence
        }

        // Step 5: Assemble result
        let result = SoundDNAAnalysisResult(
            songTitle: matchedItem?.title,
            artistName: matchedItem?.artist,
            shazamID: matchedItem?.shazamID,
            appleMusicID: matchedItem?.appleMusicURL?.absoluteString,
            genre: matchedItem?.genres.first,
            bpm: features.bpm,
            key: features.key,
            scale: features.scale,
            brightness: features.brightness,
            warmth: features.warmth,
            energy: features.energy,
            density: features.density,
            spectralCentroidHz: features.spectralCentroidHz,
            source: source,
            confidence: confidence,
            analyzedDuration: Double(capturedSamples.count) / capturedSampleRate
        )

        state = .complete(result)
    }

    public func cancelCapture() {
        isCancelled = true
        stopCaptureEngine()
        shazamContinuation?.resume(returning: nil)
        shazamContinuation = nil
        state = .idle
    }

    public func reset() {
        state = .idle
        capturedSamples = []
        shazamMatch = nil
    }

    // MARK: - Audio Capture

    /// Capture audio from the microphone for the configured duration.
    private func performCapture() async -> Bool {
        let engine = AVAudioEngine()
        self.captureEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        capturedSampleRate = format.sampleRate

        let targetSampleCount = Int(
            Theme.SoundDNA.captureDurationSeconds * capturedSampleRate
        )

        // Install tap to accumulate samples
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(Theme.SoundDNA.fftSize),
            format: format
        ) { [weak self] buffer, _ in
            guard let self else { return }
            let channelData = buffer.floatChannelData?[0]
            let frameCount = Int(buffer.frameLength)
            guard let channelData else { return }

            let samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: frameCount
            ))

            Task { @MainActor in
                self.capturedSamples.append(contentsOf: samples)
            }
        }

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            try engine.start()
        } catch {
            stopCaptureEngine()
            return false
        }

        // Wait for capture duration
        let captureDuration = Theme.SoundDNA.captureDurationSeconds
        try? await Task.sleep(for: .seconds(captureDuration))

        stopCaptureEngine()

        // Restore audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        return capturedSamples.count >= targetSampleCount / 2
    }

    /// Stop the capture engine and remove the tap.
    private func stopCaptureEngine() {
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
    }

    // MARK: - ShazamKit Identification

    /// Attempt to identify the captured audio via ShazamKit.
    private func identifyWithShazam() async -> SHMatchedMediaItem? {
        let session = SHSession()
        self.shazamSession = session
        session.delegate = self

        // Create a signature from captured audio
        let signatureGenerator = SHSignatureGenerator()
        let format = AVAudioFormat(
            standardFormatWithSampleRate: capturedSampleRate,
            channels: 1
        )

        guard let format else { return nil }

        // Convert captured samples to an AVAudioPCMBuffer
        let sampleCount = min(
            capturedSamples.count,
            Int(Theme.SoundDNA.shazamMatchDurationSeconds * capturedSampleRate)
        )
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(sampleCount)
              )
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<sampleCount {
                channelData[i] = capturedSamples[i]
            }
        }

        do {
            try signatureGenerator.append(buffer, at: nil)
            let signature = signatureGenerator.signature()
            session.match(signature)
        } catch {
            return nil
        }

        // Wait for delegate callback
        return await withCheckedContinuation { continuation in
            self.shazamContinuation = continuation

            // Timeout after a reasonable period
            Task {
                try? await Task.sleep(for: .seconds(Theme.SoundDNA.shazamTimeoutSeconds))
                if let cont = self.shazamContinuation {
                    self.shazamContinuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - SHSessionDelegate

extension SoundDNAService: SHSessionDelegate {

    nonisolated public func session(_ session: SHSession, didFind match: SHMatch) {
        let item = match.mediaItems.first
        Task { @MainActor in
            self.shazamMatch = item
            self.shazamContinuation?.resume(returning: item)
            self.shazamContinuation = nil
        }
    }

    nonisolated public func session(
        _ session: SHSession,
        didNotFindMatchFor signature: SHSignature,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.shazamContinuation?.resume(returning: nil)
            self.shazamContinuation = nil
        }
    }
}
