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

    /// Stylistic memory across regenerated MusicPatterns within a
    /// session. Lets each regeneration bias its atom selection
    /// toward atoms that were used recently so blocks feel like a
    /// continuation rather than a reset.
    private var styleMemory: SessionStyleMemory?

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

    /// Classic shimmer reverb effect: MultiVoice output is split
    /// in parallel to a pitch-shifted (+12 semitones) cathedral
    /// reverb, creating an octave-up ghost trailing every note.
    /// Sleep and Relax send heavily to this bus; Focus is bypassed.
    private var shimmerPitch: AVAudioUnitTimePitch?
    private var shimmerReverb: AVAudioUnitReverb?
    private var shimmerBus: AVAudioMixerNode?
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
    /// Sleep/Relaxation: nature sounds (rain, ocean).
    /// Focus: pink noise at a reduced gain — broadband noise reads
    /// perceptually louder than nature loops at the same level, so
    /// Focus takes half the default ambient volume to match the
    /// Sleep/Relax ambient-vs-melodic balance. Energize: brown noise
    /// even quieter since music carries the texture.
    private func startAmbienceLayer(for mode: FocusMode) {
        let bedName: String
        switch mode {
        case .sleep:
            bedName = Constants.Soundscape.rain
        case .relaxation:
            bedName = Constants.Soundscape.ocean
        case .focus:
            // Focus default: no ambient bed, no binaural. The music
            // (Rhodes + bass + drums) IS the soundscape. User can
            // raise either slider in Mix Levels if they want.
            bedName = Constants.Soundscape.pinkNoise
            parameters.ambientVolume = 0.0
            parameters.binauralVolume = 0.0
        case .energize:
            bedName = Constants.Soundscape.brownNoise
            parameters.ambientVolume = Constants.Soundscape.energizeBedVolumeOverride
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

        // Fresh style memory for this session.
        let memory = styleMemory ?? SessionStyleMemory()
        memory.reset()
        styleMemory = memory

        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: currentBiometricState,
            tonality: tonality,
            seed: currentSeed,
            arcIntensity: initialPhase.intensity,
            styleMemory: memory
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
        styleMemory?.reset()

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
    /// user hears a musical transition, not a hard cut. Also shifts
    /// the binaural carrier frequency per biometric state so the
    /// entrainment tone (if enabled) drifts with arousal.
    public func updateBiometricState(_ state: BiometricState) {
        guard state != currentBiometricState else { return }
        currentBiometricState = state

        // Apply biometric-driven carrier frequency push. The iso
        // principle says matching-then-leading works better than
        // abrupt shifts. Sleep and Relax pull the carrier lower
        // under elevated arousal; Focus holds steady.
        if let tonality = sessionTonality, let mode = currentMode {
            parameters.carrierFrequency = biometricAdjustedCarrier(
                base: tonality.alignedCarrierFrequency,
                mode: mode,
                state: state
            )
        }

        guard let mode = currentMode, let tonality = sessionTonality else { return }
        let phase = SessionArcPlanner.phase(at: currentSessionProgress(), for: mode)
        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: state,
            tonality: tonality,
            seed: currentSeed,
            arcIntensity: phase.intensity,
            styleMemory: styleMemory
        )
        musicPatternPlayer?.crossfadeTo(pattern: pattern)
    }

    // MARK: - Reshuffle (MadPlayer-style per-role regeneration)

    /// Roll the dice on one specific track role. Picks a new GM
    /// instrument from the role's program pool, swaps it into the
    /// running CompositionSeed, bumps the role's atom shuffle
    /// offset so the next molecule assembly selects a different
    /// atom, reloads the affected sampler voice with the new
    /// program, and regenerates the MusicPattern with a crossfade.
    /// The user hits this via the "new melody / new ambient / new
    /// bass / new drums" buttons in the mix panel.
    public func reshuffleRole(_ role: TrackRole) {
        guard let mode = currentMode,
              let tonality = sessionTonality,
              var seed = currentSeed,
              let mv = multiVoice
        else { return }

        // 1. Bump the atom offset so the molecule builder picks a
        //    different atom from the candidate pool next time.
        seed.roleAtomOffset[role, default: 0] += 1

        // 2. Pick a different GM program from the role's pool —
        //    avoid repeating the current one when possible.
        if let pool = CompositionSeed.programPool(mode: mode, role: role), !pool.isEmpty {
            let currentProgram = seed.gmPrograms[role]
            let candidates = pool.filter { $0 != currentProgram }
            let newProgram = (candidates.isEmpty ? pool : candidates).randomElement() ?? pool[0]
            seed.gmPrograms[role] = newProgram

            // 3. Reload the sampler voice with the new program.
            //    Melody and bass each have their own sampler.
            //    Drums and chords/texture route through the melody
            //    sampler for now; reloading the melody voice would
            //    disrupt the melodic track, so we skip those for
            //    non-melody/bass roles. Drums stay on the
            //    percussion bank.
            switch role {
            case .melody:
                try? mv.reloadMelodicVoice(mv.melody, program: newProgram)
            case .bass:
                try? mv.reloadMelodicVoice(mv.bass, program: newProgram)
            default:
                break
            }
        }

        self.currentSeed = seed

        // 4. Regenerate the MusicPattern with the updated seed and
        //    crossfade at the next bar boundary.
        let phase = SessionArcPlanner.phase(at: currentSessionProgress(), for: mode)
        let pattern = CompositionPlanner.buildMusicPattern(
            mode: mode,
            biometricState: currentBiometricState,
            tonality: tonality,
            seed: seed,
            arcIntensity: phase.intensity,
            styleMemory: styleMemory
        )
        musicPatternPlayer?.crossfadeTo(pattern: pattern)
        Logger.audio.info("v3 reshuffle: role=\(String(describing: role)) offset=\(seed.roleAtomOffset[role] ?? 0)")
    }

    // MARK: - Biometric carrier adjustment

    /// Apply the iso-principle carrier shift. For Sleep and Relax,
    /// elevated/peak arousal pushes the carrier down a fraction so
    /// the binaural tone (when enabled) leads the user toward lower
    /// frequencies. Focus holds steady — research on cognitive
    /// performance and tone stability supports fixed frequencies
    /// for sustained attention.
    private func biometricAdjustedCarrier(
        base: Double,
        mode: FocusMode,
        state: BiometricState
    ) -> Double {
        let multiplier: Double
        switch mode {
        case .sleep:
            switch state {
            case .calm:     multiplier = 1.00
            case .focused:  multiplier = 0.98
            case .elevated: multiplier = 0.94
            case .peak:     multiplier = 0.90
            }
        case .relaxation:
            switch state {
            case .calm, .focused: multiplier = 1.00
            case .elevated:       multiplier = 0.96
            case .peak:           multiplier = 0.92
            }
        case .focus, .energize:
            multiplier = 1.00
        }
        return max(40.0, min(800.0, base * multiplier))
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
            arcIntensity: phase.intensity,
            styleMemory: styleMemory
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
        let shim = shimmerBus
        switch mode {
        case .sleep:
            reverb.loadFactoryPreset(.cathedral)
            reverb.wetDryMix = 85.0          // maximum enveloping tail
            delay.delayTime = 0.48           // slow dreamy echo
            delay.feedback = 45.0
            delay.lowPassCutoff = 3800.0
            delay.wetDryMix = 24.0
            shim?.volume = 0.42              // heavy shimmer — octave-up ghost
        case .relaxation:
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 72.0          // lots of air
            delay.delayTime = 0.36
            delay.feedback = 38.0
            delay.lowPassCutoff = 5500.0
            delay.wetDryMix = 22.0
            shim?.volume = 0.34              // strong shimmer
        case .focus:
            // Focus is trip-hop / lo-fi — warm room with enough
            // reverb to make the Rhodes lush, not dry and tinny.
            // No shimmer (would fight the dusty lo-fi character).
            reverb.loadFactoryPreset(.largeRoom2)
            reverb.wetDryMix = 45.0           // wetter for warm Rhodes tail
            delay.delayTime = 0.018           // 18ms doubling for width
            delay.feedback = 15.0
            delay.lowPassCutoff = 5500.0      // darker delay tail
            delay.wetDryMix = 20.0
            shim?.volume = 0.0
        case .energize:
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 30.0
            delay.delayTime = 0.12
            delay.feedback = 25.0
            delay.lowPassCutoff = 6000.0
            delay.wetDryMix = 20.0
            shim?.volume = 0.0
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
        case .focus:      env = Envelope(attack:  48, release:  72, brightness: 36)   // dark warm rhodes — no tinny high end
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

        // Music FX chain. MultiVoiceRenderer output splits into TWO
        // parallel paths that sum into the main mixer:
        //
        //   Main path:   mv → delay → musicReverb → mainMixer
        //   Shimmer path: mv → pitch(+12) → shimmerReverb → bus → mainMixer
        //
        // The shimmer path creates the classic octave-up reverb
        // ghost on sustained notes — what makes ambient pads sound
        // spacious and ethereal. Shimmer bus volume is configured
        // per mode (heavy for sleep/relax, zero for focus).
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

        // Shimmer parallel send
        let pitch = AVAudioUnitTimePitch()
        pitch.pitch = 1200           // +12 semitones (one octave up)
        pitch.overlap = 8            // higher overlap = smoother pitch shift
        engine.attach(pitch)
        self.shimmerPitch = pitch

        let shimmerUnit = AVAudioUnitReverb()
        shimmerUnit.loadFactoryPreset(.cathedral)
        shimmerUnit.wetDryMix = 100  // fully wet — the whole point of this path
        engine.attach(shimmerUnit)
        self.shimmerReverb = shimmerUnit

        let shimBus = AVAudioMixerNode()
        shimBus.volume = 0.0         // default off; applyMusicFX sets per mode
        engine.attach(shimBus)
        self.shimmerBus = shimBus

        // Split mv.outputNode into both the main chain and the
        // shimmer chain. AVAudioEngine supports multi-point
        // connections from a mixer node.
        engine.connect(
            mv.outputNode,
            to: [
                AVAudioConnectionPoint(node: delay, bus: 0),
                AVAudioConnectionPoint(node: pitch, bus: 0)
            ],
            fromBus: 0,
            format: nil
        )
        // Main path wiring
        engine.connect(delay, to: reverbUnit, format: nil)
        engine.connect(reverbUnit, to: engine.mainMixerNode, format: nil)
        // Shimmer path wiring
        engine.connect(pitch, to: shimmerUnit, format: nil)
        engine.connect(shimmerUnit, to: shimBus, format: nil)
        engine.connect(shimBus, to: engine.mainMixerNode, format: nil)

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
