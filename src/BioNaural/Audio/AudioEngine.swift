// AudioEngine.swift
// BioNaural
//
// Concrete AudioEngineProtocol implementation managing the full
// AVAudioEngine graph: BinauralBeatNode -> Reverb -> Mixer -> Output.

import AVFoundation
import Atomics
import BioNauralShared
import OSLog

public final class AudioEngine: AudioEngineProtocol {

    // MARK: - Public Properties

    public let parameters = AudioParameters()

    public var isPlaying: Bool { parameters.isPlaying }

    public var isRunning: Bool { engine.isRunning }

    // MARK: - Audio Layers

    /// Sound catalog loaded from bundled sounds.json.
    public private(set) lazy var soundLibrary = SoundLibrary()

    /// Rule-based sound selector for choosing melodic content.
    public private(set) lazy var soundSelector: RuleBasedSoundSelector = RuleBasedSoundSelector(library: soundLibrary)

    /// Ambient bed layer (rain, noise, wind).
    public private(set) var ambienceLayer: AmbienceLayer?

    /// Melodic content layer (pads, piano, strings) — file-based (v1).
    public private(set) var melodicLayer: MelodicLayer?

    /// Stem-separated audio layer — AI-generated content with per-stem
    /// biometric mixing (v2). When active, replaces MelodicLayer.
    public private(set) var stemAudioLayer: StemAudioLayer?

    /// Whether stem-based mixing is currently active.
    public var isStemMixingActive: Bool { stemAudioLayer?.currentPack != nil }

    // SF2 generative layer — stubbed until SF2MelodicRenderer ships.
    // public private(set) var sf2Renderer: SF2MelodicRenderer?
    // public private(set) var generativeMIDI: GenerativeMIDIEngine?

    // MARK: - Private State

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    /// Reverb unit — exposed for composition preview (reverb depth control).
    public private(set) var reverb: AVAudioUnitReverb?
    private var isSetUp = false

    /// Tracks the current mode for reconfiguration recovery.
    private var currentMode: FocusMode?

    /// Serial queue for non-real-time engine mutations (start/stop/pause).
    private let controlQueue = DispatchQueue(
        label: "com.bionaural.audioengine.control",
        qos: .userInitiated
    )

    /// Timer source for stop-fade completion (avoids sleeping on the
    /// calling thread).
    private var fadeTimer: DispatchSourceTimer?

    // MARK: - Initializer

    public init() {}

    // MARK: - Setup

    public func setup() throws {
        guard !isSetUp else { return }

        // -- Audio session ------------------------------------------------
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setSupportsMultichannelContent(false)
        try session.setActive(true)

        // -- Build the graph ----------------------------------------------
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = BinauralBeatNode.makeFormat(sampleRate: sampleRate)

        let source = BinauralBeatNode.makeNode(
            parameters: parameters,
            sampleRate: sampleRate
        )
        self.sourceNode = source

        let reverbUnit = AVAudioUnitReverb()
        reverbUnit.loadFactoryPreset(.mediumHall)
        reverbUnit.wetDryMix = Theme.Audio.reverbWetDryMix
        self.reverb = reverbUnit

        engine.attach(source)
        engine.attach(reverbUnit)

        engine.connect(source, to: reverbUnit, format: format)
        engine.connect(reverbUnit, to: engine.mainMixerNode, format: format)

        // -- Ambience layer -----------------------------------------------
        let ambience = AmbienceLayer(engine: engine, parameters: parameters)
        engine.connect(ambience.outputNode, to: engine.mainMixerNode, format: nil)
        self.ambienceLayer = ambience

        // -- Melodic layer ------------------------------------------------
        let melodic = MelodicLayer(engine: engine, parameters: parameters, soundLibrary: soundLibrary)
        engine.connect(melodic.outputNode, to: engine.mainMixerNode, format: nil)
        self.melodicLayer = melodic

        // -- Stem audio layer (v2 — AI-generated content) -------------------
        let stem = StemAudioLayer(engine: engine, parameters: parameters)
        engine.connect(stem.outputNode, to: engine.mainMixerNode, format: nil)
        self.stemAudioLayer = stem

        // -- SF2 melodic layer (v1.5 — stubbed) ----------------------------
        // setupSF2Layer()

        // -- Output configuration -----------------------------------------
        // Spatial audio MUST be disabled to preserve stereo binaural beat
        // separation. HRTF processing corrupts the precise L/R frequency
        // difference required for entrainment.
        // Voice processing and spatialization are disabled via AVAudioSession
        // category configuration (.playback with no spatial options).

        // -- Notifications ------------------------------------------------
        registerNotifications()

        // -- Prepare engine (pre-allocates buffers) -----------------------
        engine.prepare()

        isSetUp = true
    }

    // MARK: - Transport

    public func start(mode: FocusMode) throws {
        if !isSetUp {
            try setup()
        }

        currentMode = mode
        applyPreset(for: mode)
        parameters.amplitude = Theme.Audio.Amplitude.binauralMax
        parameters.binauralVolume = Theme.Audio.Amplitude.defaultBinauralVolume
        parameters.ambientVolume = Theme.Audio.Amplitude.ambientAtCalm
        parameters.melodicVolume = Theme.Audio.Amplitude.binauralMax
        parameters.isPlaying = true

        if !engine.isRunning {
            try engine.start()
        }

        // Start melodic layer (file-based; SF2 generative is v1.5).
        startMelodicLayer(for: mode)
    }

    // MARK: - Melodic Layer Kickoff

    /// Selects and starts a file-based melodic sound for the given mode.
    private func startMelodicLayer(for mode: FocusMode) {
        let defaultProfile = SoundSelectionProfile()
        let defaultBiometricState = SoundSelectionBiometricState(
            heartRate: Theme.SF2.NeutralBiometrics.heartRate,
            hrv: Theme.SF2.NeutralBiometrics.hrv,
            classification: .calm,
            trend: .stable
        )

        let candidates = soundSelector.selectSounds(
            mode: mode,
            biometricState: defaultBiometricState,
            mood: nil,
            preferences: defaultProfile
        )

        if let firstSound = candidates.first {
            melodicLayer?.play(soundID: firstSound)
        }
    }

    public func stop() {
        // Ramp amplitude to zero, then stop the engine after the fade.
        parameters.isPlaying = false
        parameters.amplitude = 0.0
        currentMode = nil

        // Stop audio layers gracefully.
        stemAudioLayer?.stop()
        melodicLayer?.stop()
        ambienceLayer?.stop()

        let fadeDuration = Theme.Audio.Fade.stopDuration

        // Schedule engine stop after the fade completes.
        let timer = DispatchSource.makeTimerSource(queue: controlQueue)
        timer.schedule(deadline: .now() + fadeDuration)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.engine.stop()
            self.fadeTimer?.cancel()
            self.fadeTimer = nil
        }
        self.fadeTimer?.cancel()
        self.fadeTimer = timer
        timer.resume()
    }

    public func pause() {
        parameters.isPlaying = false
        engine.pause()
    }

    public func resume() {
        guard isSetUp else { return }
        parameters.isPlaying = true
        do {
            try engine.start()

            // Restart the melodic layer that was active before the pause/interruption.
            if let mode = currentMode {
                startMelodicLayer(for: mode)
            }
        } catch {
            Logger.audio.error("Resume failed: \(error.localizedDescription)")
        }
    }

    public func selectSoundscape(_ bedName: String) {
        ambienceLayer?.crossfadeTo(bedName: bedName)
    }

    // MARK: - Stem Pack Loading

    /// Load a stem-separated content pack for biometric-adaptive mixing.
    ///
    /// When a stem pack is active, the file-based `MelodicLayer` is paused
    /// and the `AmbienceLayer` volume is reduced (stems contain their own
    /// ambient texture). The binaural beat layer is never affected.
    ///
    /// - Parameters:
    ///   - pack: Metadata describing the stem files and their tags.
    ///   - baseURL: Directory containing the stem audio files.
    public func loadStemPack(_ pack: StemPackMetadata, baseURL: URL) {
        // Pause file-based melodic layer — stems replace it.
        melodicLayer?.stop()

        // Reduce ambient layer volume — stems have their own texture.
        parameters.ambientVolume = Theme.Audio.StemMix.ambientVolumeWithStems

        // Start stem playback.
        stemAudioLayer?.play(pack: pack, baseURL: baseURL)
    }

    /// Unload the current stem pack and restore file-based layers.
    public func unloadStemPack() {
        stemAudioLayer?.stop()

        // Restore ambient volume.
        parameters.ambientVolume = Theme.Audio.Amplitude.ambientAtCalm

        // Restart melodic layer if we have a mode.
        if let mode = currentMode {
            startMelodicLayer(for: mode)
        }
    }

    // MARK: - SF2 Layer Setup (Stubbed)
    // SF2MelodicRenderer and GenerativeMIDIEngine are v1.5 features.
    // The setup and start methods below are commented out until those
    // types are implemented. The file-based melodic layer handles all
    // melodic content in v1.
    //
    // private func setupSF2Layer() { ... }
    // private func startGenerativeLayer(for mode: FocusMode) { ... }

    // MARK: - Preset Application

    private func applyPreset(for mode: FocusMode) {
        let carrier = mode.defaultCarrierFrequency
        let beat = mode.defaultBeatFrequency

        parameters.baseFrequency = carrier
        parameters.beatFrequency = beat
        parameters.carrierFrequency = carrier
    }

    // MARK: - Notification Handling

    private func registerNotifications() {
        let nc = NotificationCenter.default

        nc.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        nc.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        nc.addObserver(
            self,
            selector: #selector(handleConfigurationChange(_:)),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        switch type {
        case .began:
            parameters.isPlaying = false

        case .ended:
            let optionsRaw = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) {
                resume()
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw)
        else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones disconnected — pause for safety.
            pause()

        case .newDeviceAvailable:
            // Check for CarPlay — binaural beats over car speakers are
            // useless and potentially dangerous. Block playback.
            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
            let isCarPlay = outputs.contains(where: { $0.portType.rawValue == "CarPlay" })
            if isCarPlay {
                stop()
            }

        default:
            break
        }
    }

    @objc private func handleConfigurationChange(_ notification: Notification) {
        // The hardware sample rate or channel count changed (e.g., Bluetooth
        // codec switch). Tear down and rebuild the graph.
        let wasPlaying = parameters.isPlaying
        let wasMode = currentMode
        parameters.isPlaying = false

        // Stop all layers BEFORE detaching nodes.
        stemAudioLayer?.stop()
        melodicLayer?.stop()
        ambienceLayer?.stop()

        engine.stop()

        // Detach the old source node so we can build a fresh one at the
        // new sample rate.
        if let old = sourceNode {
            engine.detach(old)
            sourceNode = nil
        }
        if let old = reverb {
            engine.detach(old)
            reverb = nil
        }

        // Clear old layer references — setup() will create new ones.
        stemAudioLayer = nil
        melodicLayer = nil
        ambienceLayer = nil

        // Rebuild on the control queue so we don't block the notification.
        controlQueue.async { [weak self] in
            guard let self else { return }
            self.isSetUp = false
            do {
                try self.setup()
                if wasPlaying, let mode = wasMode {
                    try self.start(mode: mode)
                }
            } catch {
                Logger.audio.error("Reconfiguration failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        fadeTimer?.cancel()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
    }
}
