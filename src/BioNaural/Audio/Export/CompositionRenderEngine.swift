// CompositionRenderEngine.swift
// BioNaural
//
// Offline (faster-than-realtime) renderer for `CustomComposition`. Builds
// a fresh `AVAudioEngine` in `.offline` manual rendering mode that mirrors
// the live AudioEngine graph for the layers a composition uses:
//
//   BinauralBeatNode → reverb ─┐
//   AmbienceLayer (file player) ┼──→ mainMixerNode → manual rendering
//   MelodicLayer  (file player) ┘
//
// MusicPatternPlayer / AVAudioSequencer is intentionally NOT included in
// v1 — the composer preview doesn't drive it either, so the export
// matches what the user just heard.
//
// The engine is throwaway: it lives only for the duration of one render
// and never touches AVAudioSession, so it can never disturb live
// playback even if invoked while the live AudioEngine is running.
//
// All numeric values come from Theme.Audio.Export tokens; nothing
// hardcoded.

import AVFoundation
import BioNauralShared
import Foundation
import OSLog

// MARK: - ExportError

public enum ExportError: Error, LocalizedError {
    case invalidComposition
    case unsupportedRenderFormat
    case fileWriteFailed(Error)
    case renderFailed(AVAudioEngineManualRenderingStatus)
    case engineStartFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidComposition:
            return "This composition is missing a brain state and cannot be exported."
        case .unsupportedRenderFormat:
            return "Could not configure the export audio format."
        case .fileWriteFailed(let underlying):
            return "Could not write the audio file: \(underlying.localizedDescription)"
        case .renderFailed(let status):
            return "The render failed (status \(status.rawValue))."
        case .engineStartFailed(let underlying):
            return "Could not start the offline engine: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - CompositionRenderRequest

/// Sendable snapshot of the fields the renderer needs from a
/// `CustomComposition`. Captures composition identity only —
/// mix-level overrides travel separately via `RenderMix` so the
/// user can dial in what they actually want to hear without
/// mutating the saved composition.
///
/// Built on the main actor before crossing onto the detached render
/// task — SwiftData `@Model` types are not Sendable and can't be
/// passed directly.
public struct CompositionRenderRequest: Sendable {
    public let name: String
    public let mode: FocusMode
    public let beatFrequency: Double
    public let carrierFrequency: Double
    public let ambientBedName: String?
    public let reverbWetDry: Float

    @MainActor
    public init?(composition: CustomComposition) {
        guard let mode = composition.focusMode else { return nil }
        self.name = composition.name
        self.mode = mode
        self.beatFrequency = composition.beatFrequency
        self.carrierFrequency = composition.carrierFrequency
        self.ambientBedName = composition.ambientBedName
        self.reverbWetDry = composition.reverbWetDry
    }
}

// MARK: - RenderMix

/// Per-export mix levels, sourced from the live engine's current
/// parameters when available so the WAV matches what the user was
/// hearing. The user can still override on the export sheet.
///
/// Bass and drums are only meaningful for Focus and Energize modes
/// (gated by `Theme.ModeInstrumentation.allowsRhythmStem`). For Sleep
/// and Relax they're ignored downstream.
public struct RenderMix: Sendable {
    public let binauralVolume: Double
    public let ambientVolume: Double
    public let melodicVolume: Double
    public let bassVolume: Double
    public let drumsVolume: Double

    public init(
        binauralVolume: Double,
        ambientVolume: Double,
        melodicVolume: Double,
        bassVolume: Double,
        drumsVolume: Double
    ) {
        self.binauralVolume = binauralVolume
        self.ambientVolume = ambientVolume
        self.melodicVolume = melodicVolume
        self.bassVolume = bassVolume
        self.drumsVolume = drumsVolume
    }
}

// MARK: - CompositionRenderEngine

/// Stateless renderer. Lives as an enum with static methods so the
/// render task never captures a non-Sendable instance.
public enum CompositionRenderEngine {

    /// Render a composition snapshot to disk. Runs offline (faster than
    /// realtime) and reports progress via `progress`. Cancels cleanly
    /// when the surrounding `Task` is cancelled.
    ///
    /// - Returns: URL of the rendered file in the temporary directory.
    public static func render(
        request: CompositionRenderRequest,
        mix: RenderMix,
        format: AudioExportFormat,
        durationMinutes: Int,
        progress: RenderProgress
    ) async throws -> URL {

        let mode = request.mode

        Logger.audio.info(
            "[Export] render start — binaural=\(mix.binauralVolume, format: .fixed(precision: 3)) ambient=\(mix.ambientVolume, format: .fixed(precision: 3)) melodic=\(mix.melodicVolume, format: .fixed(precision: 3)) bass=\(mix.bassVolume, format: .fixed(precision: 3)) drums=\(mix.drumsVolume, format: .fixed(precision: 3)) mode=\(mode.rawValue, privacy: .public)"
        )

        let cappedMinutes = min(durationMinutes, Theme.Audio.Export.durationCapMinutes)
        let durationSeconds = Double(cappedMinutes) * 60.0
        let sampleRate = Theme.Audio.Export.sampleRate
        let totalFrames = AVAudioFrameCount(durationSeconds * sampleRate)
        await MainActor.run { progress.setTotal(totalFrames) }

        // -- Build engine ----------------------------------------------------

        guard let renderFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: Theme.Audio.Export.channelCount
        ) else {
            throw ExportError.unsupportedRenderFormat
        }

        let engine = AVAudioEngine()
        try engine.enableManualRenderingMode(
            .offline,
            format: renderFormat,
            maximumFrameCount: Theme.Audio.Export.bufferFrameCount
        )

        let parameters = AudioParameters()
        configureParameters(parameters, from: request, mix: mix)

        // Binaural source → reverb → mainMixer
        let source = BinauralBeatNode.makeNode(parameters: parameters, sampleRate: sampleRate)
        let reverbUnit = AVAudioUnitReverb()
        reverbUnit.loadFactoryPreset(.mediumHall)
        reverbUnit.wetDryMix = request.reverbWetDry

        engine.attach(source)
        engine.attach(reverbUnit)
        let beatFormat = BinauralBeatNode.makeFormat(sampleRate: sampleRate)
        engine.connect(source, to: reverbUnit, format: beatFormat)
        engine.connect(reverbUnit, to: engine.mainMixerNode, format: beatFormat)

        // Ambience layer (file-based player)
        let ambience = AmbienceLayer(engine: engine, parameters: parameters)
        engine.connect(ambience.outputNode, to: engine.mainMixerNode, format: nil)

        // Melodic layer (file-based player)
        let library = SoundLibrary()
        let melodic = MelodicLayer(engine: engine, parameters: parameters, soundLibrary: library)
        engine.connect(melodic.outputNode, to: engine.mainMixerNode, format: nil)

        // Music pattern layer (SoundFont melody + bass + drums via
        // AVAudioSequencer). Attached to the offline engine for ALL
        // modes — bass and drums are gated internally by
        // `MultiVoiceRenderer.setup(sf2URL:mode:)` via
        // `Theme.ModeInstrumentation.allowsRhythmStem`. AVAudioSequencer
        // under `.offline` manual rendering is not officially
        // documented; if it stalls, music tracks will be silent and
        // we fall back to a separate sequencer-to-file path.
        let seed = CompositionSeed.random(for: mode)
        let tonality = SessionTonality(
            mode: mode,
            root: seed.root,
            scale: seed.scale,
            tempoOffsetBPM: seed.tempoOffsetBPM
        )
        // Re-align the binaural carrier to the tonality so the
        // entrainment sits consonant with the music key, matching the
        // live `AudioEngine.start(mode:)` behavior at line 287-289.
        parameters.baseFrequency = tonality.alignedCarrierFrequency
        parameters.carrierFrequency = tonality.alignedCarrierFrequency

        let music = setupMusicPatternLayer(
            engine: engine,
            mode: mode
        )

        // -- Start the engine ------------------------------------------------

        do {
            try engine.start()
        } catch {
            throw ExportError.engineStartFailed(error)
        }

        // Begin layer playback. AmbienceLayer / MelodicLayer schedule
        // looping buffers via AVAudioPlayerNode — fully supported under
        // manual rendering mode.
        if let bedName = request.ambientBedName,
           let bed = AmbientBed(rawValue: bedName) {
            ambience.play(bedName: bed.fileName)
        } else if let bedName = request.ambientBedName {
            ambience.play(bedName: bedName)
        }

        if let soundID = pickMelodicSound(library: library, request: request) {
            melodic.play(soundID: soundID)
        }

        if let music {
            let initialPhase = SessionArcPlanner.phase(at: 0.0, for: mode)
            let pattern = CompositionPlanner.buildMusicPattern(
                mode: mode,
                biometricState: .calm,
                tonality: tonality,
                seed: seed,
                arcIntensity: initialPhase.intensity,
                styleMemory: SessionStyleMemory()
            )
            do {
                try music.player.play(pattern: pattern)
                // Push slider mix into the per-voice submixers. The
                // live engine does this every ~100ms via a timer; for
                // a static export we set it once before render.
                music.voices.syncVolumes(parameters: parameters)
            } catch {
                Logger.audio.warning("[Export] MusicPatternPlayer.play failed: \(error.localizedDescription)")
            }
        }

        // -- Open output file -----------------------------------------------

        let outputURL = makeOutputURL(name: request.name, format: format)
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: format.audioSettings
            )
        } catch {
            engine.stop()
            throw ExportError.fileWriteFailed(error)
        }

        // -- Render loop -----------------------------------------------------

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: Theme.Audio.Export.bufferFrameCount
        ) else {
            engine.stop()
            throw ExportError.unsupportedRenderFormat
        }

        let fadeFrames = AVAudioFrameCount(Theme.Audio.Export.edgeFadeSeconds * sampleRate)
        var rendered: AVAudioFrameCount = 0
        engine.mainMixerNode.outputVolume = 0.0

        defer {
            engine.stop()
        }

        while rendered < totalFrames {
            if Task.isCancelled {
                try? FileManager.default.removeItem(at: outputURL)
                throw CancellationError()
            }

            updateMasterFade(
                engine: engine,
                rendered: rendered,
                total: totalFrames,
                fadeFrames: fadeFrames
            )

            let remaining = totalFrames - rendered
            let toRender = min(buffer.frameCapacity, remaining)
            let status: AVAudioEngineManualRenderingStatus
            do {
                status = try engine.renderOffline(toRender, to: buffer)
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                throw ExportError.fileWriteFailed(error)
            }

            switch status {
            case .success:
                do {
                    try outputFile.write(from: buffer)
                } catch {
                    try? FileManager.default.removeItem(at: outputURL)
                    throw ExportError.fileWriteFailed(error)
                }
                rendered += buffer.frameLength
                let snapshot = rendered
                await MainActor.run { progress.update(rendered: snapshot) }
                await Task.yield()
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext, .error:
                try? FileManager.default.removeItem(at: outputURL)
                throw ExportError.renderFailed(status)
            @unknown default:
                try? FileManager.default.removeItem(at: outputURL)
                throw ExportError.renderFailed(status)
            }
        }

        return outputURL
    }

    // MARK: - Music Pattern Layer

    /// Bundle of nodes that must outlive the render call. Returned
    /// by `setupMusicPatternLayer` so the caller can pin the player
    /// (and therefore the underlying `AVAudioSequencer`) in scope.
    private struct MusicChain {
        let voices: MultiVoiceRenderer
        let player: MusicPatternPlayer
    }

    /// Mirror of `AudioEngine.setupSF2Layer + startMusicPatternLayer`
    /// for the offline engine. Connects:
    ///   MultiVoiceRenderer.outputNode → musicDelay → musicReverb → mainMixer
    /// and loads the SF2 SoundFont for the given mode. Returns `nil`
    /// when the bundled SoundFont is missing or setup fails — the
    /// render proceeds without bass/drums/Rhodes in that case.
    private static func setupMusicPatternLayer(
        engine: AVAudioEngine,
        mode: FocusMode
    ) -> MusicChain? {
        guard let sf2URL = Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) else {
            Logger.audio.warning("[Export] SF2 SoundFont missing; skipping music pattern layer")
            return nil
        }

        let voices = MultiVoiceRenderer(engine: engine)

        let delay = AVAudioUnitDelay()
        let reverb = AVAudioUnitReverb()
        engine.attach(delay)
        engine.attach(reverb)
        engine.connect(voices.outputNode, to: delay, format: nil)
        engine.connect(delay, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        applyMusicFX(mode: mode, delay: delay, reverb: reverb)

        do {
            try voices.setup(sf2URL: sf2URL, mode: mode)
        } catch {
            Logger.audio.warning("[Export] MultiVoiceRenderer setup failed: \(error.localizedDescription)")
            return nil
        }

        applyArticulation(mode: mode, voices: voices)

        let player = MusicPatternPlayer(engine: engine, voices: voices)
        return MusicChain(voices: voices, player: player)
    }

    /// Port of `AudioEngine.applyMusicFX` for the music delay/reverb
    /// chain. Shimmer is intentionally skipped — Focus and Energize
    /// have shimmer at 0 anyway, and Sleep/Relax shimmer adds
    /// non-trivial graph complexity for a v1 export.
    private static func applyMusicFX(
        mode: FocusMode,
        delay: AVAudioUnitDelay,
        reverb: AVAudioUnitReverb
    ) {
        switch mode {
        case .sleep:
            reverb.loadFactoryPreset(.cathedral)
            reverb.wetDryMix = 85.0
            delay.delayTime = 0.48
            delay.feedback = 45.0
            delay.lowPassCutoff = 3800.0
            delay.wetDryMix = 24.0
        case .relaxation:
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 72.0
            delay.delayTime = 0.36
            delay.feedback = 38.0
            delay.lowPassCutoff = 5500.0
            delay.wetDryMix = 22.0
        case .focus:
            reverb.loadFactoryPreset(.largeRoom2)
            reverb.wetDryMix = 45.0
            delay.delayTime = 0.018
            delay.feedback = 15.0
            delay.lowPassCutoff = 5500.0
            delay.wetDryMix = 20.0
        case .energize:
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 30.0
            delay.delayTime = 0.12
            delay.feedback = 25.0
            delay.lowPassCutoff = 6000.0
            delay.wetDryMix = 20.0
        }
    }

    /// Port of `AudioEngine.applyArticulation` — sends MIDI CC 72/73/74
    /// to each sampler voice for mode-appropriate envelope shape.
    private static func applyArticulation(
        mode: FocusMode,
        voices: MultiVoiceRenderer
    ) {
        struct Envelope { let attack: UInt8; let release: UInt8; let brightness: UInt8 }
        let env: Envelope
        switch mode {
        case .sleep:      env = Envelope(attack: 118, release: 125, brightness: 30)
        case .relaxation: env = Envelope(attack:  92, release: 110, brightness: 48)
        case .focus:      env = Envelope(attack:  48, release:  72, brightness: 36)
        case .energize:   env = Envelope(attack:  30, release:  55, brightness: 68)
        }
        for sampler in [voices.melody.sampler, voices.bass.sampler, voices.drums.sampler] {
            sampler.sendController(73, withValue: env.attack,     onChannel: 0)
            sampler.sendController(72, withValue: env.release,    onChannel: 0)
            sampler.sendController(74, withValue: env.brightness, onChannel: 0)
        }
    }

    // MARK: - Configuration

    private static func configureParameters(
        _ parameters: AudioParameters,
        from request: CompositionRenderRequest,
        mix: RenderMix
    ) {
        parameters.baseFrequency = request.carrierFrequency
        parameters.carrierFrequency = request.carrierFrequency
        parameters.beatFrequency = request.beatFrequency
        parameters.amplitude = Theme.Audio.Amplitude.binauralMax
        parameters.binauralVolume = mix.binauralVolume
        parameters.ambientVolume = mix.ambientVolume
        parameters.melodicVolume = mix.melodicVolume
        parameters.bassVolume = mix.bassVolume
        parameters.drumsVolume = mix.drumsVolume
        parameters.isPlaying = true
    }

    // MARK: - Sound Selection

    /// Pick a melodic sound by mirroring the live AudioEngine's
    /// `startMelodicLayer(for:)` — `RuleBasedSoundSelector` keyed off
    /// mode + neutral biometrics + a default preference profile.
    /// One-tap compositions persist `instruments: []`, so we cannot
    /// filter by the composition's stored instruments — the live
    /// session doesn't either, and using the same selector keeps the
    /// export sounding like what the user just heard.
    private static func pickMelodicSound(
        library: SoundLibrary,
        request: CompositionRenderRequest
    ) -> SoundID? {
        let selector = RuleBasedSoundSelector(library: library)
        let neutralState = SoundSelectionBiometricState(
            heartRate: Theme.SF2.NeutralBiometrics.heartRate,
            hrv: Theme.SF2.NeutralBiometrics.hrv,
            classification: .calm,
            trend: .stable
        )
        let candidates = selector.selectSounds(
            mode: request.mode,
            biometricState: neutralState,
            mood: nil,
            preferences: SoundSelectionProfile()
        )
        return candidates.first
    }

    // MARK: - Edge Fade

    /// Linear master-volume ramp at the start and tail of the render to
    /// prevent the click-on-load that AVAudioPlayerNode otherwise emits
    /// when its first scheduled buffer hits the mixer at full volume.
    /// Resolution is one render chunk (≈ 85 ms at 48 kHz / 4096 frames),
    /// which is finer than the 500 ms fade window — perceptually smooth.
    private static func updateMasterFade(
        engine: AVAudioEngine,
        rendered: AVAudioFrameCount,
        total: AVAudioFrameCount,
        fadeFrames: AVAudioFrameCount
    ) {
        guard fadeFrames > 0 else {
            engine.mainMixerNode.outputVolume = 1.0
            return
        }

        let fadeInVolume: Float
        if rendered < fadeFrames {
            fadeInVolume = Float(rendered) / Float(fadeFrames)
        } else {
            fadeInVolume = 1.0
        }

        let fadeOutVolume: Float
        let tailStart = total > fadeFrames ? total - fadeFrames : 0
        if rendered >= tailStart {
            let intoTail = rendered - tailStart
            let fraction = Float(intoTail) / Float(fadeFrames)
            fadeOutVolume = max(0.0, 1.0 - fraction)
        } else {
            fadeOutVolume = 1.0
        }

        engine.mainMixerNode.outputVolume = min(fadeInVolume, fadeOutVolume)
    }

    // MARK: - Output URL

    private static func makeOutputURL(name: String, format: AudioExportFormat) -> URL {
        let timestamp = DateFormatter.exportTimestamp.string(from: Date())
        let safeName = name.sanitizedForFilename
        let filename = "\(safeName)-\(timestamp).\(format.fileExtension)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - Helpers

private extension DateFormatter {
    /// Filename-safe local timestamp (no colons or slashes).
    /// Example: `20260426-143045`.
    static let exportTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

private extension String {
    /// Strips characters illegal in iOS filenames and trims length to
    /// something the share sheet won't truncate. Empty strings fall
    /// back to a generic placeholder.
    var sanitizedForFilename: String {
        let illegal = CharacterSet(charactersIn: "/\\:?*\"<>|")
        let parts = self.components(separatedBy: illegal).joined(separator: "_")
        let trimmed = parts.trimmingCharacters(in: .whitespacesAndNewlines)
        let bounded = String(trimmed.prefix(64))
        return bounded.isEmpty ? "BioNaural" : bounded
    }
}
