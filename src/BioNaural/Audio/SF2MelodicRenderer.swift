// SF2MelodicRenderer.swift
// BioNaural
//
// Real-time SoundFont renderer for the generative melodic layer.
// Wraps an AVAudioUnitMIDIInstrument (backed by SF2Lib's AUv3 Audio Unit
// or Apple's AUSampler as a fallback) and exposes a clean note-on/note-off
// API consumed by GenerativeMIDIEngine.
//
// Architecture:
//   GenerativeMIDIEngine → SF2MelodicRenderer → AVAudioUnitMIDIInstrument
//                                              → submixer → mainMixerNode
//
// The renderer owns a submixer for volume control and fade in/out.
// It does NOT decide what notes to play — that's GenerativeMIDIEngine's job.
//
// Threading: noteOn/noteOff are called from GenerativeMIDIEngine's timer
// (main actor). Setup is synchronous. The underlying AUv3 renders on the
// audio thread — no locks cross this boundary.

import AVFoundation
import BioNauralShared
import OSLog

// MARK: - SF2MelodicRenderer

/// Manages SoundFont-based audio rendering as an AVAudioEngine node.
///
/// Call `setup()` once to load the SF2 file and attach to the engine.
/// Then use `noteOn`/`noteOff` to drive playback from the generative engine.
public final class SF2MelodicRenderer: NotePlayer {

    // MARK: - Node Graph

    /// Submixer for volume control. Connect this to the main mixer.
    private let submixer = AVAudioMixerNode()

    /// The MIDI instrument node (SF2Lib AUv3 or Apple's AUSampler).
    private var instrument: AVAudioUnitMIDIInstrument?

    // MARK: - State

    /// Whether the renderer has been set up and is ready for notes.
    private(set) var isReady = false

    /// Currently active notes (for cleanup on stop).
    private var activeNotes: Set<UInt8> = []

    /// Current preset index.
    private var currentPresetIndex: Int = 0

    /// Active fade timer (cancelled before starting a new fade).
    private var fadeTimer: Timer?

    // MARK: - Dependencies

    private weak var engine: AVAudioEngine?
    private let parameters: AudioParameters

    private static let logger = Logger(
        subsystem: "com.bionaural",
        category: "SF2MelodicRenderer"
    )

    // MARK: - Initializer

    /// - Parameters:
    ///   - engine: The shared AVAudioEngine.
    ///   - parameters: Thread-safe parameter store (melodicVolume controls this layer).
    public init(engine: AVAudioEngine, parameters: AudioParameters) {
        self.engine = engine
        self.parameters = parameters

        engine.attach(submixer)
    }

    // MARK: - Public API

    /// The output node. Connect to the main mixer when building the graph.
    public var outputNode: AVAudioMixerNode { submixer }

    /// Load a SoundFont file and prepare for rendering.
    ///
    /// Uses Apple's built-in AUSampler (AVAudioUnitSampler) which natively
    /// loads SF2 files. SF2Lib can be swapped in as an AUv3 Audio Unit
    /// via `AVAudioUnit.instantiate` when its component is registered.
    ///
    /// - Parameters:
    ///   - sf2URL: URL to the bundled .sf2 file.
    ///   - presetIndex: The program number to select (from Theme.SF2.PresetIndex).
    public func setup(sf2URL: URL, presetIndex: Int) throws {
        guard let engine else { return }

        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: submixer, format: nil)

        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(presetIndex),
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )

        self.instrument = sampler
        self.currentPresetIndex = presetIndex
        self.isReady = true

        // Start at moderate volume — the GenerativeMIDIEngine calls fadeIn()
        // which ramps to full, but we want notes audible immediately.
        submixer.volume = 0.6

        Self.logger.info("SF2 renderer ready — preset \(presetIndex)")
    }

    /// Change the active preset without reloading the SF2 file.
    ///
    /// - Parameter presetIndex: The program number to switch to.
    public func changePreset(_ presetIndex: Int) {
        guard let instrument else { return }
        instrument.sendProgramChange(UInt8(presetIndex), onChannel: 0)
        currentPresetIndex = presetIndex
    }

    /// Send a MIDI note-on to the SF2 renderer.
    ///
    /// - Parameters:
    ///   - note: MIDI note number (0-127).
    ///   - velocity: MIDI velocity (0-127).
    public func noteOn(_ note: UInt8, velocity: UInt8) {
        guard isReady, let instrument else { return }
        instrument.startNote(note, withVelocity: velocity, onChannel: 0)
        activeNotes.insert(note)
    }

    /// Send a MIDI note-off to the SF2 renderer.
    ///
    /// - Parameter note: MIDI note number (0-127).
    public func noteOff(_ note: UInt8) {
        guard isReady, let instrument else { return }
        instrument.stopNote(note, onChannel: 0)
        activeNotes.remove(note)
    }

    /// Kill all sounding notes immediately.
    public func allNotesOff() {
        guard isReady, let instrument else { return }
        for note in activeNotes {
            instrument.stopNote(note, onChannel: 0)
        }
        activeNotes.removeAll()
    }

    /// Fade in the submixer volume over the configured duration.
    public func fadeIn() {
        guard isReady else { return }
        cancelFade()

        let targetVolume = Float(parameters.melodicVolume)
        let duration = Theme.SF2.fadeInDuration
        let steps = Int(duration / Theme.Audio.crossfadeStepInterval)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(
            withTimeInterval: Theme.Audio.crossfadeStepInterval,
            repeats: true
        ) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.submixer.volume = targetVolume * progress

            if currentStep >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
            }
        }
    }

    /// Fade out and stop all notes.
    public func fadeOutAndStop() {
        guard isReady else { return }
        cancelFade()

        let startVolume = submixer.volume
        let duration = Theme.SF2.fadeOutDuration
        let steps = Int(duration / Theme.Audio.crossfadeStepInterval)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(
            withTimeInterval: Theme.Audio.crossfadeStepInterval,
            repeats: true
        ) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.submixer.volume = startVolume * (1.0 - progress)

            if currentStep >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                self?.allNotesOff()
            }
        }
    }

    /// Cancel any in-progress fade.
    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    /// Sync submixer volume with AudioParameters.
    public func syncVolume() {
        guard isReady else { return }
        submixer.volume = Float(parameters.melodicVolume)
    }
}
