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

    /// Learned sound preferences from the user's Sound DNA samples and
    /// session outcomes. Set by the session launcher before calling `start()`.
    /// When `nil`, the selector falls back to neutral defaults.
    public var soundSelectionProfile: SoundSelectionProfile?

    // SF2 generative layer — real-time MIDI synthesis via SoundFont.
    // GenerativeMIDIEngine produces notes using ScaleMapper + Tonic;
    // SF2MelodicRenderer renders them through the SoundFont.
    public private(set) var sf2Renderer: SF2MelodicRenderer?
    public private(set) var multiVoice: MultiVoiceRenderer?
    public private(set) var generativeMIDI: GenerativeMIDIEngine?
    public private(set) var bassLine: BassLineGenerator?
    public private(set) var drums: DrumPatternGenerator?

    /// Synthesised sub-bass oscillator (energize mode only).
    /// Adds physical low-end (30-80 Hz) that SoundFont samples can't produce.
    private var subBassNode: AVAudioSourceNode?

    // WebView engine removed — MIDISequencePlayer handles all melodic content.

    /// Pre-generated MIDI sequence player. Plays Claude-composed sequences
    /// through the SoundFont — highest quality, zero per-session API cost.
    public private(set) var sequencePlayer: MIDISequencePlayer?

    /// Catalog of all pre-generated MIDI sequences (loaded from bundle).
    private var midiCatalog: MIDISequenceCatalog?

    /// User's selected genre preference (from onboarding or per-session).
    public var genrePreference: String?

    /// Master tonality for the current session. All layers reference this
    /// to ensure harmonic coherence (same key, scale, tempo).
    public private(set) var sessionTonality: SessionTonality?

    // MARK: - Private State

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    /// Reverb unit — exposed for composition preview (reverb depth control).
    public private(set) var reverb: AVAudioUnitReverb?
    private var isSetUp = false

    /// Tracks the current mode for reconfiguration recovery.
    private var currentMode: FocusMode?

    /// Serial queue for non-real-time engine mutations (start/stop/pause/reconfigure).
    /// ALL reads and writes to `isSetUp` and `currentMode` must happen on this queue
    /// to prevent races between user-initiated transport and system-initiated
    /// configuration changes.
    private let controlQueue = DispatchQueue(
        label: "com.bionaural.audioengine.control",
        qos: .userInitiated
    )

    /// Timer source for stop-fade completion (avoids sleeping on the
    /// calling thread).
    private var fadeTimer: DispatchSourceTimer?

    /// Timer that syncs ambient/melodic layer volumes from AudioParameters.
    /// Runs at 10 Hz while the engine is playing so user slider changes
    /// are applied to the actual player nodes.
    private var volumeSyncTimer: Timer?

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

        // -- SF2 generative melodic layer (SoundFont + MIDI) ----------------
        setupSF2Layer()

        // -- Pre-generated MIDI sequence player (highest quality, $0 runtime cost)
        let seqPlayer = MIDISequencePlayer(engine: engine, parameters: parameters)
        engine.connect(seqPlayer.outputNode, to: engine.mainMixerNode, format: nil)
        seqPlayer.setup()
        self.sequencePlayer = seqPlayer
        self.midiCatalog = MIDISequencePlayer.loadCatalog()
        if midiCatalog != nil {
            Logger.audio.info("MIDI catalog loaded — \(self.midiCatalog!.sequences.count) sequences")
        }

        // -- Sub-bass synth (energize only) -----------------------------------
        let subBass = SubBassNode.makeNode(parameters: parameters, sampleRate: sampleRate)
        engine.attach(subBass)
        // Connect direct to mixer (not through reverb — sub-bass needs to stay tight)
        engine.connect(subBass, to: engine.mainMixerNode, format: nil)
        self.subBassNode = subBass

        // -- Output configuration -----------------------------------------
        // Spatial Audio MUST be disabled to preserve stereo binaural beat
        // separation. HRTF processing corrupts the precise L/R frequency
        // difference required for entrainment.
        // 1. .stereoPassThrough bypasses any HRTF spatialization on the source node.
        // 2. The audio session is configured with .playback category and no
        //    spatial options, which prevents system-level Spatial Audio.
        source.renderingAlgorithm = .stereoPassThrough

        // -- Notifications ------------------------------------------------
        registerNotifications()

        // -- Prepare engine (pre-allocates buffers) -----------------------
        engine.prepare()

        isSetUp = true
    }

    // MARK: - Transport

    public func start(mode: FocusMode) throws {
        // Cancel any pending stop timer from a previous session to prevent
        // it from killing this newly started session.
        fadeTimer?.cancel()
        fadeTimer = nil

        if !isSetUp {
            try setup()
        }

        currentMode = mode

        // Create the master tonality — ALL layers use this for key/scale/tempo.
        let tonality = SessionTonality(mode: mode)
        self.sessionTonality = tonality

        // Apply binaural preset using the tonality-aligned carrier frequency.
        // This ensures the carrier is a harmonic of the musical key root.
        parameters.baseFrequency = tonality.alignedCarrierFrequency
        parameters.beatFrequency = mode.defaultBeatFrequency
        parameters.carrierFrequency = tonality.alignedCarrierFrequency

        // Volume hierarchy: binaural/isochronic tones are barely perceptible
        // (just enough to feel the entrainment effect). Ambient and melodic
        // layers carry the actual listening experience.
        parameters.amplitude = Theme.Audio.Amplitude.binauralMax
        parameters.binauralVolume = Theme.Audio.Defaults.binauralVolume
        parameters.ambientVolume = Theme.Audio.Defaults.ambientVolume
        parameters.melodicVolume = Theme.Audio.Defaults.melodicVolume
        parameters.isPlaying = true

        // Enable sub-bass synth for energize mode only
        parameters.subBassEnabled = (mode == .energize)
        if mode == .energize {
            parameters.subBassFrequency = 40.0  // will be overridden by bass notes
            parameters.subBassAmplitude = 0.0
        }

        // Tighter reverb for energize (per FunctionalMusicTheory.md)
        if mode == .energize {
            reverb?.wetDryMix = Theme.Audio.energizeReverbWetDryMix
        } else {
            reverb?.wetDryMix = Theme.Audio.reverbWetDryMix
        }

        if !engine.isRunning {
            try engine.start()
        }

        // Start ambient layer with mode-appropriate default soundscape.
        startAmbienceLayer(for: mode)

        // Start music generation — ONLY ONE source plays at a time.
        // Pre-generated Claude sequences are preferred (they include
        // melody, bass, chords, and drums all cohesive). If available,
        // the native MIDI generators and file-based melodic layer are
        // NOT started — they would just layer random noise on top.
        let usingSequencePlayer = startMusicGeneration(mode: mode, tonality: tonality)

        if !usingSequencePlayer {
            // Fallback: use native generators when no pre-generated sequence exists
            startMelodicLayer(for: mode)
            startGenerativeLayer(for: mode)
            startBassLine(tonality: tonality)
            startDrumPattern(tonality: tonality)
        }

        // Start volume sync so user slider changes reach player nodes.
        startVolumeSyncTimer()
    }

    // MARK: - Ambience Layer Kickoff

    /// Selects and starts a mode-appropriate ambient bed.
    /// Sleep/Relaxation: nature sounds (rain, ocean, wind).
    /// Focus: pink noise or rain. Energize: no ambient (music is the texture).
    private func startAmbienceLayer(for mode: FocusMode) {
        let bedName: String
        switch mode {
        case .sleep:
            bedName = "rain-texture-60s"
        case .relaxation:
            bedName = "ocean-waves-60s"
        case .focus:
            bedName = "pink-noise-60s"
        case .energize:
            // Energize uses music as texture — ambient is quieter
            bedName = "brown-noise-60s"
            parameters.ambientVolume = 0.3
        }
        ambienceLayer?.play(bedName: bedName)
    }

    // MARK: - Melodic Layer Kickoff

    /// Selects and starts a file-based melodic sound for the given mode.
    private func startMelodicLayer(for mode: FocusMode) {
        let profile = soundSelectionProfile ?? SoundSelectionProfile()
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
            preferences: profile
        )

        Logger.audio.error("[AUDIO-DEBUG] MelodicLayer: \(candidates.count) candidates for \(mode.rawValue)")
        Logger.audio.info("MelodicLayer: \(candidates.count) candidates for \(mode.rawValue)")

        // Filter candidates by key compatibility with the session tonality
        let keyCompatible: [SoundID]
        if let tonality = sessionTonality {
            let sessionKeyStr = "\(tonality.root)"
            keyCompatible = candidates.filter { soundID in
                guard let meta = soundLibrary.metadata(for: soundID) else { return true }
                return ScaleMapper.areKeysCompatible(meta.key, sessionKeyStr)
            }
        } else {
            keyCompatible = candidates
        }

        let selected = keyCompatible.isEmpty ? candidates : keyCompatible

        if let firstSound = selected.first {
            let url = soundLibrary.audioFileURL(for: firstSound)
            Logger.audio.info("MelodicLayer: Playing '\(firstSound)' — URL: \(url?.lastPathComponent ?? "NIL") (key-filtered: \(keyCompatible.count)/\(candidates.count) compatible)")
            melodicLayer?.play(soundID: firstSound)
        } else {
            // Fallback: try to play a MusicGen track directly by filename
            Logger.audio.error("[AUDIO-DEBUG] MelodicLayer: No candidates! Trying MusicGen fallback for \(mode.rawValue)")
            Logger.audio.warning("MelodicLayer: No candidates from SoundSelector. Trying MusicGen fallback.")
            let fallbackName = "musicgen-\(mode.rawValue)-30s"
            if let url = Bundle.main.url(forResource: fallbackName, withExtension: "wav") {
                Logger.audio.info("MelodicLayer: Playing fallback '\(fallbackName).wav'")
                melodicLayer?.playURL(url)
            } else {
                Logger.audio.error("MelodicLayer: No audio available for mode \(mode.rawValue)")
            }
        }
    }

    // MARK: - Music Generation Cascade

    /// Start music generation from pre-generated MIDI sequences.
    /// Returns true if a matching sequence was found and is playing.
    @discardableResult
    func startMusicGeneration(mode: FocusMode, tonality: SessionTonality) -> Bool {
        let defaultGenre: String
        switch mode {
        case .sleep:       defaultGenre = "ambient"
        case .relaxation:  defaultGenre = "lofi"
        case .focus:       defaultGenre = "lofi"
        case .energize:    defaultGenre = "electronic"
        }
        let genre = genrePreference ?? defaultGenre

        if let catalog = midiCatalog,
           let sequence = MIDISequencePlayer.findSequence(genre: genre, mode: mode, catalog: catalog) {
            sequencePlayer?.play(sequence: sequence)
            Logger.audio.info("Music: Playing sequence (\(genre)/\(mode.rawValue))")
            return true
        }

        Logger.audio.warning("Music: No sequence found for \(genre)/\(mode.rawValue)")
        return false
    }

    /// Start bass line generator (Focus/Energize only).
    private func startBassLine(tonality: SessionTonality) {
        guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }
        bassLine?.start(tonality: tonality)
    }

    /// Start drum pattern generator (Focus/Energize only).
    private func startDrumPattern(tonality: SessionTonality) {
        guard Theme.ModeInstrumentation.allowsRhythmStem(for: tonality.mode) else { return }
        drums?.start(tonality: tonality)
    }

    public func stop() {
        // Set amplitude to zero — the render callback's per-sample smoothing
        // (5ms time constant) creates an audible fade-out ramp. isPlaying
        // stays true during the ramp so the callback keeps running.
        parameters.amplitude = 0.0
        currentMode = nil
        sessionTonality = nil

        // Stop volume sync and audio layers gracefully.
        stopVolumeSyncTimer()
        sequencePlayer?.stop()
        drums?.stop()
        bassLine?.stop()
        generativeMIDI?.stop()
        stemAudioLayer?.stop()
        melodicLayer?.stop()
        ambienceLayer?.stop()

        let fadeDuration = Theme.Audio.Fade.stopDuration

        // Schedule engine stop after the amplitude ramp completes.
        let timer = DispatchSource.makeTimerSource(queue: controlQueue)
        timer.schedule(deadline: .now() + fadeDuration)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.parameters.isPlaying = false
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

            // Restart all audio layers that were active before pause/interruption.
            // The binaural beat node resumes automatically (it reads isPlaying).
            // AmbienceLayer and MelodicLayer/StemAudioLayer need explicit restart.
            if let mode = currentMode {
                startMelodicLayer(for: mode)
            }

            // Restart volume sync timer.
            startVolumeSyncTimer()
        } catch {
            Logger.audio.error("Resume failed: \(error.localizedDescription)")
            parameters.isPlaying = false
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

    // MARK: - Volume Sync

    private func startVolumeSyncTimer() {
        stopVolumeSyncTimer()
        volumeSyncTimer = Timer.scheduledTimer(
            withTimeInterval: Theme.Audio.ControlLoop.intervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.ambienceLayer?.syncVolume()
            self?.melodicLayer?.syncVolume()
            // Sync multi-voice renderer (bass + drums volumes from sliders)
            if let mv = self?.multiVoice, let params = self?.parameters {
                mv.syncVolumes(parameters: params)
            }
            // Sync pre-generated sequence player volumes
            self?.sequencePlayer?.syncVolumes()
        }
    }

    private func stopVolumeSyncTimer() {
        volumeSyncTimer?.invalidate()
        volumeSyncTimer = nil
    }

    // MARK: - SF2 Generative Layer Setup

    /// Sets up the SoundFont renderer and generative MIDI engine.
    /// Uses SF2MelodicRenderer (AVAudioUnitSampler) to render notes
    /// produced by GenerativeMIDIEngine using Tonic-powered ScaleMapper.
    private func setupSF2Layer() {
        // Only create once — reuse across session starts.
        guard sf2Renderer == nil else { return }

        guard let sf2URL = Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) else {
            Logger.audio.error("SoundFont NOT FOUND: \(Theme.SF2.resourceName).\(Theme.SF2.resourceExtension) — generative MIDI disabled")
            return
        }

        // Create single-voice renderer for melody (GenerativeMIDIEngine uses this)
        let renderer = SF2MelodicRenderer(engine: engine, parameters: parameters)
        do {
            try renderer.setup(sf2URL: sf2URL, presetIndex: Theme.SF2.PresetIndex.focusPad)
            self.sf2Renderer = renderer
        } catch {
            Logger.audio.error("SF2 setup failed: \(error.localizedDescription)")
            return
        }

        // Create multi-voice renderer (separate samplers for melody, bass, drums)
        let mv = MultiVoiceRenderer(engine: engine)
        engine.connect(mv.outputNode, to: engine.mainMixerNode, format: nil)
        self.multiVoice = mv

        // GenerativeMIDIEngine drives the melody voice
        let midi = GenerativeMIDIEngine(renderer: renderer, parameters: parameters)
        self.generativeMIDI = midi

        Logger.audio.info("Multi-voice renderer created: melody + bass + drums")
    }

    /// Starts the generative MIDI engine for the given mode.
    /// Selects the appropriate SoundFont preset and begins algorithmic
    /// note generation using ScaleMapper-driven pitch selection.
    private func startGenerativeLayer(for mode: FocusMode) {
        guard let sf2URL = Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) else { return }

        // Set up the multi-voice renderer with mode-specific presets
        if let mv = multiVoice {
            do {
                try mv.setup(sf2URL: sf2URL, mode: mode)

                // Create bass and drum generators with their own voice handles
                let bassGen = BassLineGenerator(renderer: mv.bass)
                let drumGen = DrumPatternGenerator(renderer: mv.drums)
                self.bassLine = bassGen
                self.drums = drumGen

                Logger.audio.info("Multi-voice renderer configured for \(mode.rawValue)")
            } catch {
                Logger.audio.error("Multi-voice setup failed: \(error.localizedDescription)")
            }
        }

        // Change the melody renderer's preset for the mode
        if let renderer = sf2Renderer {
            let presetIndex: Int
            switch mode {
            case .focus:       presetIndex = Theme.SF2.PresetIndex.focusPad
            case .relaxation:  presetIndex = Theme.SF2.PresetIndex.relaxationStrings
            case .sleep:       presetIndex = Theme.SF2.PresetIndex.sleepPad
            case .energize:    presetIndex = Theme.SF2.PresetIndex.energizeBells
            }
            renderer.changePreset(presetIndex)
        }

        // Wire bass generator to MIDI engine so chord changes propagate
        if let bassGen = bassLine {
            generativeMIDI?.bassLineGenerator = bassGen
        }

        // Start generative melody with calm initial state and shared tonality
        generativeMIDI?.start(mode: mode, biometricState: .calm, tonality: sessionTonality)
    }

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
        volumeSyncTimer?.invalidate()
        fadeTimer?.cancel()
        NotificationCenter.default.removeObserver(self)
        engine.stop()
    }
}
