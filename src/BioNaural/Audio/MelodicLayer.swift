// MelodicLayer.swift
// BioNaural
//
// Manages melodic loop playback with A/B crossfading as the third audio layer.
// Two AVAudioPlayerNode instances alternate: while one plays, the next
// crossfades in over Theme.Audio.melodicCrossfadeDuration (10-15 seconds).
//
// This layer does NOT decide which sounds to play — that responsibility
// belongs to SoundSelector. MelodicLayer only handles playback, looping,
// volume, and crossfading.

import AVFoundation
import Foundation
import OSLog

/// Plays melodic loops with seamless A/B crossfading.
///
/// **Architecture:** Two `AVAudioPlayerNode` instances (A and B) feed into
/// a shared melodic submixer. At any moment, one player is "active" and the
/// other is either silent or fading out. When `crossfadeTo(soundID:)` is
/// called, the roles swap and a smooth volume envelope runs over
/// `Theme.Audio.melodicCrossfadeDuration`.
///
/// **Threading:** All public methods must be called from the main thread.
///
/// **No hardcoded values.** Crossfade duration, step interval, and volumes
/// come from `Theme.Audio` tokens and `AudioParameters`.
public final class MelodicLayer {

    // MARK: - Node Graph

    /// The submixer that downstream consumers connect to.
    private let submixer = AVAudioMixerNode()

    /// Player A — one half of the A/B crossfade pair.
    private let playerA = AVAudioPlayerNode()

    /// Player B — the other half.
    private let playerB = AVAudioPlayerNode()

    /// Tracks which player is currently the "active" (audible) one.
    /// `true` = playerA is active, `false` = playerB is active.
    private var playerAIsActive = true

    // MARK: - State

    /// The SoundID currently playing on the active player.
    private(set) var currentSoundID: SoundID?

    /// Whether playback is active.
    private var isPlaying = false

    /// Timer driving the crossfade envelope. Uses DispatchSourceTimer
    /// on a dedicated queue to avoid main-thread jank causing volume stutter.
    private var crossfadeTimer: DispatchSourceTimer?

    /// Serial queue for crossfade volume updates (off main thread).
    private let crossfadeQueue = DispatchQueue(
        label: "com.bionaural.melodic.crossfade",
        qos: .userInteractive
    )

    // MARK: - Dependencies

    private let parameters: AudioParameters
    private let soundLibrary: SoundLibrary
    private weak var engine: AVAudioEngine?

    // MARK: - Initializer

    /// - Parameters:
    ///   - engine: The shared `AVAudioEngine`. Both players and the submixer
    ///     are attached here.
    ///   - parameters: Thread-safe store. `melodicVolume` controls this layer.
    ///   - soundLibrary: Catalog used to resolve `SoundID` to audio file URLs.
    public init(engine: AVAudioEngine, parameters: AudioParameters, soundLibrary: SoundLibrary) {
        self.engine = engine
        self.parameters = parameters
        self.soundLibrary = soundLibrary

        engine.attach(submixer)
        engine.attach(playerA)
        engine.attach(playerB)
    }

    deinit {
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
        playerA.stop()
        playerB.stop()
    }

    // MARK: - Public API

    /// The output node for the melodic layer. Connect to the master mixer
    /// when building the audio engine graph.
    public var outputNode: AVAudioMixerNode { submixer }

    /// Begin playing a melodic loop identified by `soundID`.
    ///
    /// If nothing is playing, starts immediately at the current
    /// `AudioParameters.melodicVolume`. If a different sound is already
    /// playing, crossfades to the new one.
    ///
    /// - Parameter soundID: Identifier from the `SoundLibrary` catalog.
    public func play(soundID: SoundID) {
        guard let engine else { return }

        // If already playing a different sound, crossfade instead.
        if isPlaying, currentSoundID != nil, currentSoundID != soundID {
            crossfadeTo(soundID: soundID)
            return
        }

        guard let file = loadFile(for: soundID) else { return }

        let active = activePlayer
        let format = file.processingFormat
        safeConnect(active, to: submixer, format: format, engine: engine)

        submixer.volume = Float(parameters.melodicVolume)
        active.volume = 1.0

        scheduleLoop(player: active, file: file)
        active.play()

        currentSoundID = soundID
        isPlaying = true
    }

    /// Crossfade from the current melodic loop to a new one.
    ///
    /// The outgoing loop fades out while the incoming loop fades in over
    /// `Theme.Audio.melodicCrossfadeDuration` (typically 10-15 seconds).
    ///
    /// - Parameter soundID: The identifier of the incoming sound.
    public func crossfadeTo(soundID: SoundID) {
        guard let engine else { return }
        guard soundID != currentSoundID else { return }
        guard let file = loadFile(for: soundID) else { return }

        // Cancel any in-progress crossfade.
        cancelCrossfade()

        // The current active player becomes the outgoing one.
        let outgoing = activePlayer

        // Swap roles.
        playerAIsActive.toggle()
        let incoming = activePlayer

        // Wire the incoming player.
        let format = file.processingFormat
        safeConnect(incoming, to: submixer, format: format, engine: engine)

        incoming.volume = 0.0
        scheduleLoop(player: incoming, file: file)
        incoming.play()

        currentSoundID = soundID

        // Drive the crossfade.
        let crossfadeDuration = Theme.Audio.melodicCrossfadeDuration
        let stepInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(crossfadeDuration / stepInterval)
        var currentStep = 0

        let outgoingStartVolume = outgoing.volume

        let timer = DispatchSource.makeTimerSource(queue: crossfadeQueue)
        timer.schedule(
            deadline: .now() + stepInterval,
            repeating: stepInterval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            guard self != nil else {
                timer.cancel()
                return
            }

            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)

            // Equal-power crossfade for perceptually constant loudness.
            let fadeOutGain = cos(progress * .pi / 2.0)
            let fadeInGain = sin(progress * .pi / 2.0)

            outgoing.volume = outgoingStartVolume * fadeOutGain
            incoming.volume = fadeInGain

            if currentStep >= totalSteps {
                timer.cancel()
                self?.crossfadeTimer = nil
                    outgoing.stop()
                    self?.engine?.detach(outgoing)
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    /// Stop all melodic playback with a fade-out.
    public func stop() {
        cancelCrossfade()

        // Reset state IMMEDIATELY so a subsequent play() doesn't try to crossfade.
        // This prevents the crash when stop→start happens quickly.
        isPlaying = false
        currentSoundID = nil

        let fadeOutDuration = Theme.Audio.melodicCrossfadeDuration
        let stepInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(fadeOutDuration / stepInterval)
        var currentStep = 0

        let playerToFade = activePlayer
        let startVolume = playerToFade.volume

        let timer = DispatchSource.makeTimerSource(queue: crossfadeQueue)
        timer.schedule(
            deadline: .now() + stepInterval,
            repeating: stepInterval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)
            playerToFade.volume = startVolume * (1.0 - progress)

            if currentStep >= totalSteps {
                timer.cancel()
                self?.crossfadeTimer = nil
                self?.playerA.stop()
                self?.playerB.stop()
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    /// Update the submixer volume to match `AudioParameters.melodicVolume`.
    /// Call periodically so user slider changes take effect during playback.
    public func syncVolume() {
        guard isPlaying else { return }
        submixer.volume = Float(parameters.melodicVolume)
    }

    // MARK: - Player Management

    /// Returns whichever player is currently designated as "active."
    private var activePlayer: AVAudioPlayerNode {
        playerAIsActive ? playerA : playerB
    }

    /// Returns whichever player is currently designated as "inactive."
    private var inactivePlayer: AVAudioPlayerNode {
        playerAIsActive ? playerB : playerA
    }

    // MARK: - Seamless Looping

    /// Schedules the audio file as a looping buffer for gapless repetition.
    private func scheduleLoop(player: AVAudioPlayerNode, file: AVAudioFile) {
        guard let buffer = loadBuffer(from: file) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    /// Reads the audio file into a PCM buffer with an equal-power crossfade
    /// baked into the loop boundary, eliminating the audible seam when the
    /// buffer wraps. Identical technique to `AmbienceLayer.loadBuffer`.
    private func loadBuffer(from file: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(file.length)
        guard let rawBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            return nil
        }
        do {
            try file.read(into: rawBuffer)
        } catch {
            Logger.audio.warning("Failed to read melodic audio buffer: \(error.localizedDescription)")
            return nil
        }

        // Bake crossfade at the loop boundary
        let sampleRate = file.processingFormat.sampleRate
        let crossfadeFrames = min(
            Int(sampleRate * Theme.Audio.loopCrossfadeDuration),
            Int(frameCount) / 4
        )
        guard crossfadeFrames > 100 else { return rawBuffer }

        let channels = Int(file.processingFormat.channelCount)
        let totalFrames = Int(rawBuffer.frameLength)
        let newLength = totalFrames - crossfadeFrames

        guard let crossfadedBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(newLength)
        ) else { return rawBuffer }

        for ch in 0..<channels {
            guard let src = rawBuffer.floatChannelData?[ch],
                  let dst = crossfadedBuffer.floatChannelData?[ch] else { continue }

            // Copy the main body
            for i in 0..<newLength {
                dst[i] = src[i]
            }

            // Blend the tail into the head with equal-power curves
            let tailStart = totalFrames - crossfadeFrames
            for i in 0..<crossfadeFrames {
                let t = Float(i) / Float(crossfadeFrames)
                let fadeOut = cosf(t * .pi / 2) // tail: 1.0 -> 0.0
                let fadeIn  = sinf(t * .pi / 2) // head: 0.0 -> 1.0

                dst[i] = dst[i] * fadeIn + src[tailStart + i] * fadeOut
            }
        }

        crossfadedBuffer.frameLength = AVAudioFrameCount(newLength)
        return crossfadedBuffer
    }

    // MARK: - File Loading

    /// Resolves a `SoundID` to an `AVAudioFile` via the sound library.
    private func loadFile(for soundID: SoundID) -> AVAudioFile? {
        guard let url = soundLibrary.audioFileURL(for: soundID) else {
            Logger.audio.warning("MelodicLayer: No URL for soundID '\(soundID)' in sound library")
            return nil
        }
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            Logger.audio.warning("Failed to load melodic file for '\(soundID)': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Direct URL Playback

    /// Play an audio file directly by URL (bypasses SoundLibrary lookup).
    /// Used as a fallback for MusicGen-generated tracks.
    public func playURL(_ url: URL) {
        guard let engine else { return }

        do {
            let file = try AVAudioFile(forReading: url)
            let active = activePlayer
            let format = file.processingFormat
            safeConnect(active, to: submixer, format: format, engine: engine)

            submixer.volume = Float(parameters.melodicVolume)
            active.volume = 1.0

            scheduleLoop(player: active, file: file)
            active.play()

            currentSoundID = url.deletingPathExtension().lastPathComponent
            isPlaying = true
            Logger.audio.info("MelodicLayer: Playing URL directly: \(url.lastPathComponent)")
        } catch {
            Logger.audio.error("MelodicLayer: Failed to play URL \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: - Safe Connection

    /// Safely connect a player node to a mixer, re-attaching if necessary.
    /// Prevents the crash: "required condition is false: _nodes containsObject"
    /// that occurs when nodes become detached after engine stop/restart.
    private func safeConnect(
        _ node: AVAudioPlayerNode,
        to mixer: AVAudioMixerNode,
        format: AVAudioFormat,
        engine: AVAudioEngine
    ) {
        // Only disconnect if the node is actually attached — calling
        // disconnectNodeOutput on an unattached node throws an exception.
        if engine.attachedNodes.contains(node) {
            engine.disconnectNodeOutput(node)
        }

        // Re-attach if the node was detached (can happen after engine.stop())
        if !engine.attachedNodes.contains(node) {
            engine.attach(node)
        }
        if !engine.attachedNodes.contains(mixer) {
            engine.attach(mixer)
        }

        engine.connect(node, to: mixer, format: format)
    }

    // MARK: - Teardown

    private func cancelCrossfade() {
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
    }
}
