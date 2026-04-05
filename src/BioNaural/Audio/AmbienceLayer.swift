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

    /// Timer driving the crossfade envelope.
    private var crossfadeTimer: Timer?

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

        // Drive the crossfade envelope on the main thread via Timer.
        let crossfadeDuration = Theme.Audio.ambientCrossfadeDuration
        let targetVolume = Float(parameters.ambientVolume)
        let stepInterval: TimeInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(crossfadeDuration / stepInterval)
        var currentStep = 0

        let outgoing = fadingPlayer
        let incoming = incomingPlayer

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)

            // Linear crossfade: outgoing fades out, incoming fades in.
            outgoing?.volume = targetVolume * (1.0 - progress)
            incoming.volume = targetVolume * progress

            if currentStep >= totalSteps {
                timer.invalidate()
                self.crossfadeTimer = nil
                self.teardownFadingPlayer()
            }
        }
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

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)
            playerToStop?.volume = startVolume * (1.0 - progress)

            if currentStep >= totalSteps {
                timer.invalidate()
                self?.crossfadeTimer = nil
                self?.teardownActivePlayer()
                self?.teardownFadingPlayer()
                self?.isPlaying = false
                self?.currentBedName = nil
                self?.activeFile = nil
            }
        }
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

    /// Reads the entire audio file into a PCM buffer for loop scheduling.
    private func loadBuffer(from file: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            return nil
        }
        do {
            try file.read(into: buffer)
            return buffer
        } catch {
            Logger.audio.warning("Failed to read ambient audio buffer: \(error.localizedDescription)")
            return nil
        }
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
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        teardownFadingPlayer()
    }
}
