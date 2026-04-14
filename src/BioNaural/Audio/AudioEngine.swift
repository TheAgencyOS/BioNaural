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

    // SF2 layer — SoundFont samplers that the v3 MusicPatternPlayer
    // routes AVAudioSequencer tracks into.
    public private(set) var sf2Renderer: SF2MelodicRenderer?
    public private(set) var multiVoice: MultiVoiceRenderer?

    /// v3 NWL composing-core player. Runs a pre-built Standard MIDI File
    /// through AVAudioSequencer on the audio thread — the single music
    /// source of truth for all melody/bass/drums/chords playback.
    public private(set) var musicPatternPlayer: MusicPatternPlayer?

    /// Most recent biometric state — used to regenerate the MusicPattern
    /// when biometrics change mid-session.
    private var currentBiometricState: BiometricState = .calm

    /// Session-stable randomization of key, scale, instruments, and
    /// progression variant. Generated once per `start(mode:)` call and
    /// reused for biometric regenerations so the listener never hears
    /// instruments change mid-session.
    private var currentSeed: CompositionSeed?

    /// Wall-clock session duration, in minutes, used by the session
    /// arc planner to compute phase boundaries. Callers (Session
    /// launcher) should set this before or after `start(mode:)`.
    /// Defaults to 20 — a reasonable middle for meditation sessions.
    public var sessionArcDurationMinutes: Int = 20

    /// The moment the current session started. Used with
    /// `sessionArcDurationMinutes` to compute session progress.
    private var sessionStartDate: Date?

    /// Label of the currently-active arc phase. Changed by the arc
    /// timer when wallclock crosses a phase boundary; triggers a
    /// MusicPattern regeneration with the new phase intensity.
    private var currentArcPhaseLabel: String?

    /// Timer that wakes every N seconds to check if session progress
    /// has crossed an arc-phase boundary.
    private var arcTimer: Timer?

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
    /// Reverb unit on the binaural beat path — kept for historical
    /// compatibility; mostly inaudible since binaural is default-off.
    public private(set) var reverb: AVAudioUnitReverb?

    /// Dedicated reverb on the music path. Inserted between the
    /// MultiVoiceRenderer output and the main mixer so melody / bass /
    /// chords / texture all share a mode-specific space. Sleep and
    /// relaxation get cathedral-scale tails; focus and energize get
    /// tight rooms. This is the piece that makes the ambient genres
    /// actually sound ambient — before this they were running dry.
    public private(set) var musicReverb: AVAudioUnitReverb?

    /// Delay unit on the music path — adds short stereo echoes on top
    /// of the reverb for relaxation and sleep. Configured per mode.
    private var musicDelay: AVAudioUnitDelay?
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

        // Generate a fresh CompositionSeed so this session picks a new
        // root, scale, instrument palette, and progression variant.
        // The seed is stable for the duration of the session — biometric
        // regens reuse it so the listener doesn't hear a patch change.
        let seed = CompositionSeed.random(for: mode)
        self.currentSeed = seed
        Logger.audio.info("v3 seed — root:\(String(describing: seed.root)) scale:\(String(describing: seed.scale)) variant:\(seed.progressionVariant)")

        // Create the master tonality using the seeded root, scale, and
        // tempo offset so each session has its own pulse as well as
        // its own key.
        let tonality = SessionTonality(
            mode: mode,
            root: seed.root,
            scale: seed.scale,
            tempoOffsetBPM: seed.tempoOffsetBPM
        )
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

        // v3 NWL composing core: pre-compute a complete MusicPattern and
        // let AVAudioSequencer loop it sample-accurately on the audio
        // thread. No DispatchSourceTimer, no per-tick scheduling.
        startMusicPatternLayer(for: mode, tonality: tonality)

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

    // MARK: - v3 Music Pattern Layer

    /// Build and play a complete MusicPattern for the given mode + tonality.
    /// Runs CompositionPlanner → PatternBuilder → MIDIFileBuilder → AVAudioSequencer.
    private func startMusicPatternLayer(for mode: FocusMode, tonality: SessionTonality) {
        guard let sf2URL = Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) else {
            Logger.audio.error("v3: SoundFont missing — music pattern layer disabled")
            return
        }
        guard let mv = multiVoice else {
            Logger.audio.error("v3: MultiVoiceRenderer not available")
            return
        }

        // Configure the multi-voice samplers with mode-appropriate presets.
        // MusicPatternPlayer routes AVAudioSequencer tracks into these samplers.
        do {
            try mv.setup(sf2URL: sf2URL, mode: mode)
        } catch {
            Logger.audio.error("v3: MultiVoiceRenderer setup failed: \(error.localizedDescription)")
            return
        }

        // Reload melody + bass samplers with the seed's randomized GM
        // programs. AVAudioUnitSampler binds to a specific instrument at
        // load time — a MIDI program change in the SMF does NOT swap
        // patches — so we must reload the sampler explicitly for the
        // randomized palette to actually take effect.
        if let seed = currentSeed {
            if let melodyProgram = seed.gmPrograms[.melody] {
                try? mv.reloadMelodicVoice(mv.melody, program: melodyProgram)
            }
            if let bassProgram = seed.gmPrograms[.bass] {
                try? mv.reloadMelodicVoice(mv.bass, program: bassProgram)
            }
            Logger.audio.info("v3 seed patches — melody:\(seed.gmPrograms[.melody] ?? 0) bass:\(seed.gmPrograms[.bass] ?? 0)")
        }

        // Mode-specific articulation — shape envelope on the samplers so
        // the same SoundFont preset speaks differently per mode. Sleep
        // gets slow attack + long release (pad-like); energize gets
        // tight, percussive response.
        applyArticulation(for: mode, voices: mv)

        // Mode-specific music FX — reverb tail + delay. This is what
        // makes relaxation and sleep actually sound ambient instead of
        // a dry SoundFont demo.
        applyMusicFX(for: mode)

        // Establish the session start clock + initial arc phase so
        // the first MusicPattern is built with the intro-phase
        // intensity rather than full tilt.
        if sessionStartDate == nil {
            sessionStartDate = Date()
        }
        let initialPhase = SessionArcPlanner.phase(at: 0.0, for: mode)
        currentArcPhaseLabel = initialPhase.label
        startArcTimer()

        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: currentBiometricState,
            tonality: tonality,
            seed: currentSeed,
            arcIntensity: initialPhase.intensity
        )

        let player = musicPatternPlayer ?? MusicPatternPlayer(engine: engine, voices: mv)
        self.musicPatternPlayer = player

        do {
            try player.play(pattern: pattern)
            Logger.audio.info("v3: MusicPatternPlayer started (\(mode.rawValue), \(pattern.tracks.count) tracks)")
        } catch {
            Logger.audio.error("v3: MusicPatternPlayer failed to start: \(error.localizedDescription)")
        }
    }

    public func stop() {
        // Set amplitude to zero — the render callback's per-sample smoothing
        // (5ms time constant) creates an audible fade-out ramp. isPlaying
        // stays true during the ramp so the callback keeps running.
        parameters.amplitude = 0.0
        currentMode = nil
        sessionTonality = nil
        currentSeed = nil
        stopArcTimer()
        sessionStartDate = nil
        currentArcPhaseLabel = nil

        // Stop volume sync and audio layers gracefully.
        stopVolumeSyncTimer()
        sequencePlayer?.stop()
        musicPatternPlayer?.stop()
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

    /// Forward biometric state to real-time generative layers AND
    /// regenerate the v3 MusicPattern with updated Class parameters.
    /// The new pattern crossfades in at the next bar boundary so the
    /// user hears a musical transition, not a hard cut.
    public func updateBiometricState(_ state: BiometricState) {
        guard state != currentBiometricState else { return }
        currentBiometricState = state

        guard let mode = currentMode, let tonality = sessionTonality else { return }
        let phase = SessionArcPlanner.phase(at: currentSessionProgress(), for: mode)
        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: state,
            tonality: tonality,
            seed: currentSeed,
            arcIntensity: phase.intensity
        )
        musicPatternPlayer?.crossfadeTo(pattern: pattern)
    }

    // MARK: - Session Arc Timer

    /// Current session progress as a fraction [0, 1]. 0 if the
    /// session hasn't started; 1 past the configured duration.
    private func currentSessionProgress() -> Double {
        guard let start = sessionStartDate else { return 0.0 }
        let elapsed = Date().timeIntervalSince(start)
        let total = Double(sessionArcDurationMinutes) * 60.0
        return max(0.0, min(1.0, elapsed / max(1.0, total)))
    }

    private func startArcTimer() {
        stopArcTimer()
        // Wake every 10 seconds — phase boundaries move on minute
        // scale, so 10s is granular enough and avoids burning the CPU.
        arcTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.tickArcTimer()
        }
    }

    private func stopArcTimer() {
        arcTimer?.invalidate()
        arcTimer = nil
    }

    /// Called on every arc timer tick. If session progress has
    /// crossed into a new phase, regenerate the MusicPattern with
    /// the new intensity and crossfade it in at the next bar boundary.
    private func tickArcTimer() {
        guard let mode = currentMode,
              let tonality = sessionTonality,
              musicPatternPlayer != nil
        else { return }

        let progress = currentSessionProgress()
        let phase = SessionArcPlanner.phase(at: progress, for: mode)
        guard phase.label != currentArcPhaseLabel else { return }

        Logger.audio.info("v3 arc: \(self.currentArcPhaseLabel ?? "nil") → \(phase.label) (intensity \(phase.intensity), progress \(progress))")
        currentArcPhaseLabel = phase.label

        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: currentBiometricState,
            tonality: tonality,
            seed: currentSeed,
            arcIntensity: phase.intensity
        )
        musicPatternPlayer?.crossfadeTo(pattern: pattern)
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

    // MARK: - Music FX chain

    /// Configure the music reverb + delay chain for the given mode.
    /// We lean lush across the board — every mode gets meaningful
    /// reverb, and every mode gets at least a short doubling delay
    /// (~15ms) that acts like analog chorus for thicker timbres.
    /// Focus and energize pay for this with slightly longer decays
    /// than a strict "room" reverb would give, but the warmth is
    /// worth the trade.
    private func applyMusicFX(for mode: FocusMode) {
        guard let reverb = musicReverb, let delay = musicDelay else { return }
        switch mode {
        case .sleep:
            reverb.loadFactoryPreset(.cathedral)
            reverb.wetDryMix = 80.0          // maximum enveloping tail
            delay.delayTime = 0.42           // slow dreamy echo
            delay.feedback = 42.0
            delay.lowPassCutoff = 4000.0
            delay.wetDryMix = 22.0
        case .relaxation:
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 65.0          // lots of air
            delay.delayTime = 0.32
            delay.feedback = 35.0
            delay.lowPassCutoff = 5500.0
            delay.wetDryMix = 20.0
        case .focus:
            // Focus is now ambient — use the same lush space as
            // relaxation. Large hall + slow delay.
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 60.0
            delay.delayTime = 0.30
            delay.feedback = 32.0
            delay.lowPassCutoff = 5500.0
            delay.wetDryMix = 18.0
        case .energize:
            // Energize is now hip-hop — a warm medium room, short
            // slapback delay on melody/leads. Kick still dominates.
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 30.0
            delay.delayTime = 0.12           // ~16th-note slapback
            delay.feedback = 25.0
            delay.lowPassCutoff = 6000.0
            delay.wetDryMix = 20.0
        }
    }

    // MARK: - Articulation (MIDI CC)

    /// Send mode-appropriate attack/release and brightness CCs to every
    /// sampler voice. CC 73 = attack time, CC 72 = release time,
    /// CC 74 = brightness (low-pass filter cutoff). Values 0-127.
    private func applyArticulation(for mode: FocusMode, voices: MultiVoiceRenderer) {
        struct Envelope { let attack: UInt8; let release: UInt8; let brightness: UInt8 }
        // All four modes are tuned for lush warmth: slower attacks,
        // longer releases, darker filter settings than a "clean" mix
        // would use. The new music reverb tail picks up the slack.
        let env: Envelope
        switch mode {
        case .sleep:      env = Envelope(attack: 118, release: 125, brightness: 30)   // ultra soft pad
        case .relaxation: env = Envelope(attack:  92, release: 110, brightness: 48)   // warm
        case .focus:      env = Envelope(attack:  96, release: 115, brightness: 42)   // ambient pad
        case .energize:   env = Envelope(attack:  30, release:  55, brightness: 68)   // warm rhodes / hip-hop
        }
        let samplers = [voices.melody.sampler, voices.bass.sampler, voices.drums.sampler]
        for sampler in samplers {
            sampler.sendController(73, withValue: env.attack,     onChannel: 0)
            sampler.sendController(72, withValue: env.release,    onChannel: 0)
            sampler.sendController(74, withValue: env.brightness, onChannel: 0)
        }
    }

    // MARK: - SF2 Layer Setup

    /// Attach the SoundFont samplers. The v3 MusicPatternPlayer routes
    /// AVAudioSequencer tracks into `multiVoice.melody/bass/drums` — this
    /// method just wires the nodes into the engine graph.
    private func setupSF2Layer() {
        guard sf2Renderer == nil else { return }

        guard Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) != nil else {
            Logger.audio.error("SoundFont NOT FOUND: \(Theme.SF2.resourceName).\(Theme.SF2.resourceExtension)")
            return
        }

        // SF2MelodicRenderer is retained for MIDISequencePlayer compatibility
        // and the composition preview. v3 music playback uses MultiVoiceRenderer.
        let renderer = SF2MelodicRenderer(engine: engine, parameters: parameters)
        if let sf2URL = Bundle.main.url(
            forResource: Theme.SF2.resourceName,
            withExtension: Theme.SF2.resourceExtension
        ) {
            do {
                try renderer.setup(sf2URL: sf2URL, presetIndex: Theme.SF2.PresetIndex.focusPad)
                engine.connect(renderer.outputNode, to: engine.mainMixerNode, format: nil)
                self.sf2Renderer = renderer
            } catch {
                Logger.audio.error("SF2 setup failed: \(error.localizedDescription)")
            }
        }

        let mv = MultiVoiceRenderer(engine: engine)
        self.multiVoice = mv

        // Insert a dedicated music reverb + delay chain between the
        // MultiVoiceRenderer output and the main mixer. Before this,
        // the music path was running dry — ambient pads had no space,
        // relaxation sounded cheap, and sleep was less immersive than
        // it should be. The chain is:
        //
        //   mv.outputNode → musicDelay → musicReverb → mainMixer
        //
        // Mode-specific presets are applied in startMusicPatternLayer
        // so the same chain shapes every mode differently.
        let delay = AVAudioUnitDelay()
        delay.delayTime = 0.0
        delay.feedback = 0.0
        delay.wetDryMix = 0.0
        engine.attach(delay)
        self.musicDelay = delay

        let reverbUnit = AVAudioUnitReverb()
        reverbUnit.loadFactoryPreset(.mediumHall)
        reverbUnit.wetDryMix = 30.0
        engine.attach(reverbUnit)
        self.musicReverb = reverbUnit

        engine.connect(mv.outputNode, to: delay, format: nil)
        engine.connect(delay, to: reverbUnit, format: nil)
        engine.connect(reverbUnit, to: engine.mainMixerNode, format: nil)

        Logger.audio.info("SF2 samplers ready — melody + bass + drums (music FX chain attached)")
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
