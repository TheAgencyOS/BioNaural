// AmbienceLayer.swift
// BioNaural
//
// Manages ambient bed playback (rain, noise, wind) as the second audio layer.
// Uses AVAudioPlayerNode for file-based playback with seamless looping
// and crossfade transitions on bed changes. Volume driven by
// AudioParameters.ambientVolume — never hardcoded.

import AVFoundation
import Foundation
import OSLog

/// Manages a single ambient texture bed (rain, pink noise, wind, etc.)
/// with seamless looping and crossfade transitions when switching beds.
///
/// **Threading:** All public methods must be called from the main thread.
/// The node graph runs on the audio render thread; volume changes flow
/// through the mixer node's `volume` property (thread-safe in AVAudioEngine).
///
/// **No hardcoded values.** All volumes, crossfade durations, and timing
/// come from `Theme.Audio` tokens or `AudioParameters`.
public final class AmbienceLayer {

    // MARK: - Node Graph

    /// The submixer node that downstream consumers (e.g., the master mixer)
    /// connect to. Returned by `outputNode` for engine graph wiring.
    private let submixer = AVAudioMixerNode()

    /// The currently active player — plays the looping ambient bed.
    private var activePlayer: AVAudioPlayerNode?

    /// The outgoing player during a crossfade transition.
    private var fadingPlayer: AVAudioPlayerNode?

    // MARK: - State

    /// Name of the currently playing ambient bed (matches bundle filename without extension).
    private(set) var currentBedName: String?

    /// The loaded audio file for the active bed.
    private var activeFile: AVAudioFile?

    /// Whether playback is active (not paused or stopped).
    private var isPlaying = false

    /// Timer driving the crossfade envelope. Uses DispatchSourceTimer
    /// on a dedicated queue to avoid main-thread jank causing volume stutter.
    private var crossfadeTimer: DispatchSourceTimer?

    /// Serial queue for crossfade volume updates (off main thread).
    private let crossfadeQueue = DispatchQueue(
        label: "com.bionaural.ambience.crossfade",
        qos: .userInteractive
    )

    // MARK: - Dependencies

    /// Shared thread-safe parameter store — ambientVolume is read here.
    private let parameters: AudioParameters

    /// Weak reference to the engine for node attachment and connection.
    private weak var engine: AVAudioEngine?

    /// Processing format used across all nodes in this layer.
    private var processingFormat: AVAudioFormat?

    // MARK: - Initializer

    /// - Parameters:
    ///   - engine: The shared `AVAudioEngine` instance. The layer attaches
    ///     its submixer and player nodes to this engine.
    ///   - parameters: Thread-safe parameter store. `ambientVolume` controls
    ///     this layer's output level.
    public init(engine: AVAudioEngine, parameters: AudioParameters) {
        self.engine = engine
        self.parameters = parameters
        engine.attach(submixer)
    }

    deinit {
        cancelCrossfade()
        teardownActivePlayer()
        teardownFadingPlayer()
    }

    // MARK: - Public API

    /// The output node for this layer. Connect this to the master mixer
    /// when building the audio engine graph.
    public var outputNode: AVAudioMixerNode { submixer }

    /// Begin playing an ambient bed by bundle filename (without extension).
    ///
    /// If a bed is already playing, this crossfades to the new bed using
    /// `Theme.Audio.ambientCrossfadeDuration`.
    ///
    /// - Parameter bedName: The resource name of the audio file in the app bundle
    ///   (e.g., `"rain"`, `"pink_noise"`, `"wind"`).
    public func play(bedName: String) {
        guard let engine else { return }

        // If already playing a different bed, crossfade instead.
        if isPlaying, currentBedName != nil, currentBedName != bedName {
            crossfadeTo(bedName: bedName)
            return
        }

        // Load the audio file from the bundle.
        guard let file = loadAudioFile(named: bedName) else { return }

        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = file.processingFormat
        processingFormat = format
        engine.connect(player, to: submixer, format: format)

        // Set initial volume from parameters.
        submixer.volume = Float(parameters.ambientVolume)

        // Schedule seamless looping and begin playback.
        scheduleLoop(player: player, file: file)
        player.play()

        activePlayer = player
        activeFile = file
        currentBedName = bedName
        isPlaying = true
    }

    /// Crossfade from the current ambient bed to a new one.
    ///
    /// The outgoing bed fades out over `Theme.Audio.ambientCrossfadeDuration`
    /// while the incoming bed fades in over the same duration.
    ///
    /// - Parameter bedName: The resource name of the new ambient bed.
    public func crossfadeTo(bedName: String) {
        guard let engine else { return }
        guard bedName != currentBedName else { return }
        guard let file = loadAudioFile(named: bedName) else { return }

        // Cancel any in-progress crossfade.
        cancelCrossfade()

        // Move the current player to the fading slot.
        fadingPlayer = activePlayer

        // Create and wire the incoming player.
        let incomingPlayer = AVAudioPlayerNode()
        engine.attach(incomingPlayer)

        let format = file.processingFormat
        processingFormat = format
        engine.connect(incomingPlayer, to: submixer, format: format)

        // Start the incoming player at zero volume.
        incomingPlayer.volume = 0.0
        scheduleLoop(player: incomingPlayer, file: file)
        incomingPlayer.play()

        activePlayer = incomingPlayer
        activeFile = file
        currentBedName = bedName

        // Drive the crossfade envelope on a dedicated queue to avoid
        // main-thread jank causing audible volume stutter.
        let crossfadeDuration = Theme.Audio.ambientCrossfadeDuration
        let targetVolume = Float(parameters.ambientVolume)
        let stepInterval: TimeInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(crossfadeDuration / stepInterval)
        var currentStep = 0

        let outgoing = fadingPlayer
        let incoming = incomingPlayer

        let timer = DispatchSource.makeTimerSource(queue: crossfadeQueue)
        timer.schedule(
            deadline: .now() + stepInterval,
            repeating: stepInterval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            guard let self else {
                timer.cancel()
                return
            }

            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)

            // Linear crossfade: outgoing fades out, incoming fades in.
            outgoing?.volume = targetVolume * (1.0 - progress)
            incoming.volume = targetVolume * progress

            if currentStep >= totalSteps {
                timer.cancel()
                self.crossfadeTimer = nil
                self.teardownFadingPlayer()
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    /// Stop all ambient playback immediately with a brief fade-out.
    public func stop() {
        cancelCrossfade()

        let fadeOutDuration = Theme.Audio.ambientCrossfadeDuration
        let stepInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(fadeOutDuration / stepInterval)
        var currentStep = 0

        let playerToStop = activePlayer
        let startVolume = playerToStop?.volume ?? 0.0

        let timer = DispatchSource.makeTimerSource(queue: crossfadeQueue)
        timer.schedule(
            deadline: .now() + stepInterval,
            repeating: stepInterval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)
            playerToStop?.volume = startVolume * (1.0 - progress)

            if currentStep >= totalSteps {
                timer.cancel()
                self?.crossfadeTimer = nil
                self?.teardownActivePlayer()
                self?.teardownFadingPlayer()
                self?.isPlaying = false
                self?.currentBedName = nil
                self?.activeFile = nil
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    /// Update the submixer volume to match the current `AudioParameters.ambientVolume`.
    /// Call this periodically (e.g., from a display link or parameter observer) so
    /// user slider changes take effect during playback.
    public func syncVolume() {
        guard isPlaying else { return }
        submixer.volume = Float(parameters.ambientVolume)
    }

    // MARK: - Seamless Looping

    /// Schedules the audio file for playback with seamless looping.
    ///
    /// Instead of relying on `AVAudioPlayerNode.scheduleFile(... completionHandler:)`
    /// which has unreliable timing, this schedules the file as a looping buffer
    /// to guarantee gapless playback.
    private func scheduleLoop(player: AVAudioPlayerNode, file: AVAudioFile) {
        guard let buffer = loadBuffer(from: file) else { return }
        // Schedule as a looping buffer — AVAudioEngine handles seamless repetition.
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    /// Reads the audio file into a PCM buffer with crossfade applied at
    /// the loop boundary. This eliminates the audible seam when the buffer
    /// loops back to the beginning.
    ///
    /// The crossfade works by overlapping the last N frames with the first
    /// N frames using equal-power (sine/cosine) curves. The buffer is
    /// shortened by the crossfade length so the overlap is baked in.
    private func loadBuffer(from file: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(file.length)
        guard let rawBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            return nil
        }
        do {
            try file.read(into: rawBuffer)
        } catch {
            Logger.audio.warning("Failed to read ambient audio buffer: \(error.localizedDescription)")
            return nil
        }

        // Apply crossfade at loop boundary
        let sampleRate = file.processingFormat.sampleRate
        let crossfadeFrames = min(
            Int(sampleRate * Theme.Audio.loopCrossfadeDuration),
            Int(frameCount) / 4
        )

        guard crossfadeFrames > 100 else { return rawBuffer } // Too short to crossfade

        let channels = Int(file.processingFormat.channelCount)
        let totalFrames = Int(rawBuffer.frameLength)
        let newLength = totalFrames - crossfadeFrames

        guard let crossfadedBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(newLength)
        ) else { return rawBuffer }

        // Copy the main body (everything except the crossfade tail)
        for ch in 0..<channels {
            guard let src = rawBuffer.floatChannelData?[ch],
                  let dst = crossfadedBuffer.floatChannelData?[ch] else { continue }

            // Copy all frames into destination
            for i in 0..<newLength {
                dst[i] = src[i]
            }

            // Apply crossfade: blend the tail (last crossfadeFrames of source)
            // into the head (first crossfadeFrames of destination)
            let tailStart = totalFrames - crossfadeFrames
            for i in 0..<crossfadeFrames {
                let t = Float(i) / Float(crossfadeFrames)
                // Equal-power crossfade: cos for outgoing, sin for incoming
                let fadeOut = cosf(t * .pi / 2) // 1.0 → 0.0
                let fadeIn = sinf(t * .pi / 2)  // 0.0 → 1.0

                let tailSample = src[tailStart + i]
                let headSample = dst[i]

                // Blend: existing head fades in, tail fades out
                dst[i] = headSample * fadeIn + tailSample * fadeOut
            }
        }

        crossfadedBuffer.frameLength = AVAudioFrameCount(newLength)
        return crossfadedBuffer
    }

    // MARK: - File Loading

    /// Loads an audio file from the app bundle by name.
    ///
    /// Searches for common audio extensions in order of preference:
    /// `.caf`, `.aac`, `.m4a`, `.wav`.
    ///
    /// - Parameter name: The resource name (without extension).
    /// - Returns: The loaded `AVAudioFile`, or `nil` if not found.
    private func loadAudioFile(named name: String) -> AVAudioFile? {
        let extensions = Theme.Audio.supportedAmbientFileExtensions
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    return try AVAudioFile(forReading: url)
                } catch {
                    Logger.audio.warning("Failed to load ambient file '\(name).\(ext)': \(error.localizedDescription)")
                    continue
                }
            }
        }
        return nil
    }

    // MARK: - Teardown

    private func teardownFadingPlayer() {
        guard let player = fadingPlayer else { return }
        player.stop()
        engine?.detach(player)
        fadingPlayer = nil
    }

    private func teardownActivePlayer() {
        guard let player = activePlayer else { return }
        player.stop()
        engine?.detach(player)
        activePlayer = nil
    }

    private func cancelCrossfade() {
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
        teardownFadingPlayer()
    }
}
