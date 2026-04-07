// StemAudioLayer.swift
// BioNaural
//
// Multi-stem audio playback with independent per-stem volume control.
// Loads a StemPackMetadata (3-4 audio files: pads, texture, bass,
// optional rhythm) and plays all stems simultaneously. Per-stem volumes
// are driven by BiometricStemMixer via AudioParameters.
//
// Supports A/B crossfading between stem packs using the same pattern
// as MelodicLayer: one set of stems fades out while the new set fades in.
//
// Threading: All public methods must be called from the main thread.
// Volume reads come from AudioParameters (atomic, lock-free).
//
// No hardcoded values — all durations, volumes, and smoothing constants
// come from Theme.Audio.StemMix tokens.

import AVFoundation
import Foundation
import OSLog

/// Plays a stem-separated audio pack with independent per-stem volume
/// control driven by biometric state.
///
/// **Architecture:** Each stem slot (pads, texture, bass, rhythm) has
/// its own `AVAudioPlayerNode` feeding into a shared submixer. A Timer
/// at `Theme.Audio.StemMix.updateInterval` reads volume targets from
/// `AudioParameters` and applies exponential smoothing to each stem's
/// player volume.
///
/// **Crossfading:** When switching packs, a second set of players
/// fades in while the current set fades out over
/// `Theme.Audio.StemMix.packCrossfadeDuration`.
public final class StemAudioLayer {

    // MARK: - Node Graph

    /// The submixer that downstream consumers connect to.
    private let submixer = AVAudioMixerNode()

    /// Active stem players — one per slot.
    private var activePlayers: [StemSlot: AVAudioPlayerNode] = [:]

    /// Outgoing stem players during a pack crossfade.
    private var fadingPlayers: [StemSlot: AVAudioPlayerNode] = [:]

    // MARK: - State

    /// The currently loaded stem pack.
    private(set) var currentPack: StemPackMetadata?

    /// Whether playback is active.
    private var isPlaying = false

    /// Timer driving per-stem volume updates from AudioParameters.
    /// Uses DispatchSourceTimer on a dedicated queue to avoid main-thread jank.
    private var volumeUpdateTimer: DispatchSourceTimer?

    /// Timer driving pack crossfade envelope.
    private var crossfadeTimer: DispatchSourceTimer?

    /// Serial queue for volume and crossfade updates (off main thread).
    private let mixQueue = DispatchQueue(
        label: "com.bionaural.stems.mix",
        qos: .userInteractive
    )

    /// Current smoothed volumes per stem (for exponential smoothing).
    private var currentVolumes: [StemSlot: Float] = [
        .pads: Theme.Audio.StemMix.defaultFullVolume,
        .texture: Theme.Audio.StemMix.defaultFullVolume,
        .bass: Theme.Audio.StemMix.defaultFullVolume,
        .rhythm: Theme.Audio.StemMix.defaultRhythmVolume
    ]

    // MARK: - Dependencies

    private let parameters: AudioParameters
    private weak var engine: AVAudioEngine?

    // MARK: - Initializer

    /// - Parameters:
    ///   - engine: The shared `AVAudioEngine`. Stem players and the submixer
    ///     are attached here.
    ///   - parameters: Thread-safe store. Stem volume targets are read here.
    public init(engine: AVAudioEngine, parameters: AudioParameters) {
        self.engine = engine
        self.parameters = parameters
        engine.attach(submixer)
    }

    deinit {
        stopVolumeUpdates()
        cancelCrossfade()
        stopAllPlayers(activePlayers)
        stopAllPlayers(fadingPlayers)
    }

    // MARK: - Public API

    /// The output node for this layer. Connect to the master mixer
    /// when building the audio engine graph.
    public var outputNode: AVAudioMixerNode { submixer }

    /// Load and begin playing a stem pack.
    ///
    /// If a different pack is already playing, crossfades to the new one.
    /// If the same pack is already playing, does nothing.
    ///
    /// - Parameters:
    ///   - pack: The stem pack metadata.
    ///   - baseURL: The directory containing the stem audio files.
    public func play(pack: StemPackMetadata, baseURL: URL) {
        guard let engine else { return }

        if isPlaying, currentPack?.id == pack.id { return }

        if isPlaying, currentPack != nil {
            crossfadeTo(pack: pack, baseURL: baseURL)
            return
        }

        // Load and wire each stem.
        var players: [StemSlot: AVAudioPlayerNode] = [:]

        let stemFiles: [(StemSlot, String)] = stemFileList(from: pack)

        for (slot, fileName) in stemFiles {
            guard let file = loadFile(named: fileName, at: baseURL) else { continue }

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: submixer, format: file.processingFormat)

            let initialVolume = currentVolumes[slot] ?? Theme.Audio.StemMix.defaultFullVolume
            player.volume = initialVolume

            scheduleLoop(player: player, file: file)
            player.play()

            players[slot] = player
        }

        activePlayers = players
        currentPack = pack
        isPlaying = true

        startVolumeUpdates()
    }

    /// Crossfade from the current pack to a new one.
    public func crossfadeTo(pack: StemPackMetadata, baseURL: URL) {
        guard let engine else { return }
        guard pack.id != currentPack?.id else { return }

        cancelCrossfade()

        // Move active players to fading slot.
        fadingPlayers = activePlayers
        activePlayers = [:]

        // Create and wire incoming players.
        let stemFiles = stemFileList(from: pack)
        var incomingPlayers: [StemSlot: AVAudioPlayerNode] = [:]

        for (slot, fileName) in stemFiles {
            guard let file = loadFile(named: fileName, at: baseURL) else { continue }

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: submixer, format: file.processingFormat)
            player.volume = 0.0

            scheduleLoop(player: player, file: file)
            player.play()

            incomingPlayers[slot] = player
        }

        activePlayers = incomingPlayers
        currentPack = pack

        // Drive crossfade envelope.
        let duration = Theme.Audio.StemMix.packCrossfadeDuration
        let stepInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(duration / stepInterval)
        var currentStep = 0

        let outgoing = fadingPlayers

        let timer = DispatchSource.makeTimerSource(queue: mixQueue)
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

            // Equal-power crossfade.
            let fadeOut = cos(progress * .pi / 2.0)
            let fadeIn = sin(progress * .pi / 2.0)

            for (slot, player) in outgoing {
                let baseVolume = self.currentVolumes[slot] ?? Theme.Audio.StemMix.defaultFullVolume
                player.volume = baseVolume * fadeOut
            }

            for (slot, player) in self.activePlayers {
                let baseVolume = self.currentVolumes[slot] ?? Theme.Audio.StemMix.defaultFullVolume
                player.volume = baseVolume * fadeIn
            }

            if currentStep >= totalSteps {
                timer.cancel()
                self.crossfadeTimer = nil
                self.teardownFadingPlayers()
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    /// Stop all stem playback with a fade-out.
    public func stop() {
        guard isPlaying else { return }
        stopVolumeUpdates()
        cancelCrossfade()

        let duration = Theme.Audio.StemMix.packCrossfadeDuration
        let stepInterval = Theme.Audio.crossfadeStepInterval
        let totalSteps = Int(duration / stepInterval)
        var currentStep = 0

        let playersToFade = activePlayers
        let startVolumes: [StemSlot: Float] = playersToFade.mapValues { $0.volume }

        let timer = DispatchSource.makeTimerSource(queue: mixQueue)
        timer.schedule(
            deadline: .now() + stepInterval,
            repeating: stepInterval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            currentStep += 1
            let progress = Float(currentStep) / Float(totalSteps)

            // Equal-power fade-out matching crossfadeTo() pattern.
            let fadeGain = cos(progress * .pi / 2.0)

            for (slot, player) in playersToFade {
                let baseVolume = startVolumes[slot] ?? Theme.Audio.StemMix.defaultFullVolume
                player.volume = baseVolume * fadeGain
            }

            if currentStep >= totalSteps {
                timer.cancel()
                self?.crossfadeTimer = nil
                    self?.stopAllPlayers(self?.activePlayers ?? [:])
                    self?.stopAllPlayers(self?.fadingPlayers ?? [:])
                    self?.activePlayers = [:]
                    self?.fadingPlayers = [:]
                    self?.isPlaying = false
                    self?.currentPack = nil
            }
        }
        crossfadeTimer = timer
        timer.resume()
    }

    // MARK: - Volume Updates

    /// Start the periodic timer that reads stem volume targets from
    /// AudioParameters and applies exponential smoothing.
    private func startVolumeUpdates() {
        stopVolumeUpdates()

        let interval = Theme.Audio.StemMix.updateInterval
        let alpha = Theme.Audio.StemMix.volumeSmoothingAlpha

        let timer = DispatchSource.makeTimerSource(queue: mixQueue)
        timer.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            guard let self, self.isPlaying else { return }

            let targets = self.parameters.stemVolumeTargets

            for slot in StemSlot.allCases {
                guard let player = self.activePlayers[slot] else { continue }

                let target = targets[slot]
                let current = self.currentVolumes[slot] ?? target

                // Exponential smoothing: smooth = current + alpha * (target - current)
                let smoothed = current + alpha * (target - current)
                self.currentVolumes[slot] = smoothed
                player.volume = smoothed
            }
        }
        volumeUpdateTimer = timer
        timer.resume()
    }

    private func stopVolumeUpdates() {
        volumeUpdateTimer?.cancel()
        volumeUpdateTimer = nil
    }

    // MARK: - Stem File List

    /// Extracts the (slot, fileName) pairs from a stem pack, excluding
    /// nil rhythm files.
    private func stemFileList(from pack: StemPackMetadata) -> [(StemSlot, String)] {
        var files: [(StemSlot, String)] = [
            (.pads, pack.padsFileName),
            (.texture, pack.textureFileName),
            (.bass, pack.bassFileName)
        ]
        if let rhythm = pack.rhythmFileName {
            files.append((.rhythm, rhythm))
        }
        return files
    }

    // MARK: - Seamless Looping

    private func scheduleLoop(player: AVAudioPlayerNode, file: AVAudioFile) {
        guard let buffer = loadBuffer(from: file) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }

    /// Reads the audio file into a PCM buffer with an equal-power crossfade
    /// baked into the loop boundary, eliminating the audible seam when the
    /// buffer wraps. Same technique as AmbienceLayer and MelodicLayer.
    private func loadBuffer(from file: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(file.length)
        guard let rawBuffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: frameCount
        ) else { return nil }
        do {
            try file.read(into: rawBuffer)
        } catch {
            Logger.audio.warning("Failed to read stem buffer: \(error.localizedDescription)")
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

            for i in 0..<newLength {
                dst[i] = src[i]
            }

            let tailStart = totalFrames - crossfadeFrames
            for i in 0..<crossfadeFrames {
                let t = Float(i) / Float(crossfadeFrames)
                let fadeOut = cosf(t * .pi / 2)
                let fadeIn  = sinf(t * .pi / 2)

                dst[i] = dst[i] * fadeIn + src[tailStart + i] * fadeOut
            }
        }

        crossfadedBuffer.frameLength = AVAudioFrameCount(newLength)
        return crossfadedBuffer
    }

    // MARK: - File Loading

    private func loadFile(named fileName: String, at baseURL: URL) -> AVAudioFile? {
        let url = baseURL.appendingPathComponent(fileName)
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            Logger.audio.warning("Failed to load stem '\(fileName)': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Teardown

    private func stopAllPlayers(_ players: [StemSlot: AVAudioPlayerNode]) {
        for (_, player) in players {
            player.stop()
            engine?.detach(player)
        }
    }

    private func teardownFadingPlayers() {
        stopAllPlayers(fadingPlayers)
        fadingPlayers = [:]
    }

    private func cancelCrossfade() {
        crossfadeTimer?.cancel()
        crossfadeTimer = nil
        teardownFadingPlayers()
    }
}
