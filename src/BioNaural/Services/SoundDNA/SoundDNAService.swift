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
import os
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
    /// Delegates to ``AudioCapturer`` which is non-isolated to avoid
    /// @MainActor assertions in the realtime audio tap closure.
    private func performCapture() async -> Bool {
        let capturer = AudioCapturer()
        let result = await capturer.capture(
            durationSeconds: Theme.SoundDNA.captureDurationSeconds,
            bufferSize: AVAudioFrameCount(Theme.SoundDNA.fftSize)
        )

        guard let result else { return false }

        capturedSamples = result.samples
        capturedSampleRate = result.sampleRate
        return true
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

// MARK: - Audio Capturer (Non-Isolated)

/// Handles microphone capture entirely outside @MainActor isolation.
/// The `installTap` closure runs on the realtime audio thread — this
/// class is deliberately NOT actor-isolated so the closure doesn't
/// trigger Swift 6 strict concurrency assertions.
final class AudioCapturer: @unchecked Sendable {

    struct CaptureResult {
        let samples: [Float]
        let sampleRate: Double
    }

    private var engine: AVAudioEngine?
    private nonisolated let lock = OSAllocatedUnfairLock(initialState: [Float]())

    /// Appends samples to the lock-protected buffer (sync context).
    private nonisolated func appendSamples(_ samples: [Float]) {
        lock.withLock { $0.append(contentsOf: samples) }
    }

    /// Drains and returns all accumulated samples (sync context).
    private nonisolated func drainSamples() -> [Float] {
        lock.withLock { state in
            let drained = state
            state = []
            return drained
        }
    }

    /// Capture audio from the microphone for the given duration.
    /// Returns nil if the microphone is unavailable or the format is invalid.
    func capture(
        durationSeconds: Double,
        bufferSize: AVAudioFrameCount
    ) async -> CaptureResult? {
        let engine = AVAudioEngine()
        self.engine = engine

        // Configure audio session before accessing inputNode.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            return nil
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Validate format — simulator or denied mic returns 0 Hz / 0 channels.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            return nil
        }

        let sampleRate = format.sampleRate
        let targetCount = Int(durationSeconds * sampleRate)

        // Install tap — this closure runs on the realtime audio thread.
        // Because AudioCapturer is NOT @MainActor, there's no isolation assertion.
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: format
        ) { [weak self] pcmBuffer, _ in
            guard let self,
                  let channelData = pcmBuffer.floatChannelData?[0] else { return }
            let frameCount = Int(pcmBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: frameCount
            ))
            self.appendSamples(samples)
        }

        // Start the engine.
        do {
            try engine.start()
        } catch {
            stop()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            return nil
        }

        // Wait for capture duration.
        try? await Task.sleep(for: .seconds(durationSeconds))

        stop()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        // Drain accumulated samples.
        let result = drainSamples()

        guard result.count >= targetCount / 2 else { return nil }

        return CaptureResult(samples: result, sampleRate: sampleRate)
    }

    private func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
