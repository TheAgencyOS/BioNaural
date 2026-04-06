// MultiVoiceRenderer.swift
// BioNaural
//
// Manages multiple independent AVAudioUnitSampler instances for simultaneous
// multi-preset SoundFont rendering. Each "voice" (melody, bass, drums) gets
// its own sampler with its own GM preset, volume, and MIDI channel.
//
// This replaces the single SF2MelodicRenderer for multi-instrument sessions.
// The GenerativeMIDIEngine, BassLineGenerator, and DrumPatternGenerator
// each get their own voice handle.
//
// Architecture:
//   [Melody Sampler] ─→ [Melody Submixer] ──╮
//   [Bass Sampler]   ─→ [Bass Submixer]   ──┼──→ [Master Submixer] → mainMixer
//   [Drums Sampler]  ─→ [Drums Submixer]  ──╯
//
// Each submixer has independent volume control, read from AudioParameters.

import AVFoundation
import BioNauralShared
import OSLog

// MARK: - NotePlayer Protocol

/// Minimal note-on/note-off interface shared by SF2MelodicRenderer and SFVoice.
/// Bass and drum generators use this protocol so they can be driven by either.
public protocol NotePlayer: AnyObject {
    func noteOn(_ note: UInt8, velocity: UInt8)
    func noteOff(_ note: UInt8)
}

// MARK: - Voice

/// A single SoundFont voice with its own sampler, submixer, and preset.
public final class SFVoice: NotePlayer {

    let name: String
    let sampler: AVAudioUnitSampler
    let submixer: AVAudioMixerNode
    var preset: Int
    var activeNotes: Set<UInt8> = []
    var isReady = false

    init(name: String) {
        self.name = name
        self.sampler = AVAudioUnitSampler()
        self.submixer = AVAudioMixerNode()
        self.preset = 0
    }

    public func noteOn(_ note: UInt8, velocity: UInt8) {
        guard isReady else { return }
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        activeNotes.insert(note)
    }

    public func noteOff(_ note: UInt8) {
        guard isReady else { return }
        sampler.stopNote(note, onChannel: 0)
        activeNotes.remove(note)
    }

    func allNotesOff() {
        for note in activeNotes {
            sampler.stopNote(note, onChannel: 0)
        }
        activeNotes.removeAll()
    }

    func changePreset(_ presetIndex: Int) {
        sampler.sendProgramChange(UInt8(presetIndex), onChannel: 0)
        preset = presetIndex
    }
}

// MARK: - MultiVoiceRenderer

/// Manages multiple independent SoundFont voices for multi-instrument sessions.
public final class MultiVoiceRenderer {

    // MARK: - Voices

    /// Melody voice — pads, piano, synth lead (mode-dependent).
    public let melody: SFVoice

    /// Bass voice — synth bass, always GM 38.
    public let bass: SFVoice

    /// Drums voice — GM percussion (program doesn't matter for channel 10,
    /// but we load GM 0 and use drum-range notes 35-81).
    public let drums: SFVoice

    /// Master submixer for all voices. Connect to engine.mainMixerNode.
    public let masterSubmixer = AVAudioMixerNode()

    // MARK: - State

    public var isReady: Bool {
        melody.isReady // If melody loaded, bass and drums should be too
    }

    private weak var engine: AVAudioEngine?
    private var sf2URL: URL?

    private static let logger = Logger(
        subsystem: "com.bionaural",
        category: "MultiVoiceRenderer"
    )

    // MARK: - Init

    public init(engine: AVAudioEngine) {
        self.engine = engine
        self.melody = SFVoice(name: "melody")
        self.bass = SFVoice(name: "bass")
        self.drums = SFVoice(name: "drums")

        // Attach all nodes to the engine
        engine.attach(masterSubmixer)
        for voice in [melody, bass, drums] {
            engine.attach(voice.sampler)
            engine.attach(voice.submixer)
            engine.connect(voice.sampler, to: voice.submixer, format: nil)
            engine.connect(voice.submixer, to: masterSubmixer, format: nil)
        }
    }

    /// The output node — connect to engine.mainMixerNode.
    public var outputNode: AVAudioMixerNode { masterSubmixer }

    // MARK: - Setup

    /// Load the SoundFont and configure all voices with mode-appropriate presets.
    public func setup(sf2URL: URL, mode: FocusMode) throws {
        self.sf2URL = sf2URL

        // Load melody voice with mode-specific preset
        let melodyPreset: Int
        switch mode {
        case .focus:       melodyPreset = Theme.SF2.PresetIndex.focusPad
        case .relaxation:  melodyPreset = Theme.SF2.PresetIndex.relaxationStrings
        case .sleep:       melodyPreset = Theme.SF2.PresetIndex.sleepPad
        case .energize:    melodyPreset = Theme.SF2.PresetIndex.energizeBells
        }
        try loadVoice(melody, preset: melodyPreset, sf2URL: sf2URL)

        // Load bass voice (GM 38 = Synth Bass 1)
        if Theme.ModeInstrumentation.allowsRhythmStem(for: mode) {
            try loadVoice(bass, preset: Theme.SF2.PresetIndex.bass, sf2URL: sf2URL)
            bass.submixer.volume = 0.55
        } else {
            bass.submixer.volume = 0.0
        }

        // Load drums voice (GM 0, but we'll use drum-range notes 35-81)
        // For GM drum sounds, we load bank 128 (percussion)
        if Theme.ModeInstrumentation.allowsRhythmStem(for: mode) {
            try loadDrumVoice(drums, sf2URL: sf2URL)
            drums.submixer.volume = mode == .focus ? 0.25 : 0.50
        } else {
            drums.submixer.volume = 0.0
        }

        // Set initial volumes
        melody.submixer.volume = 0.65
        masterSubmixer.volume = 1.0

        Self.logger.info("MultiVoiceRenderer ready — melody:\(melodyPreset), bass:\(Theme.SF2.PresetIndex.bass), drums:bank128 for \(mode.rawValue)")
    }

    private func loadVoice(_ voice: SFVoice, preset: Int, sf2URL: URL) throws {
        try voice.sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(preset),
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        voice.preset = preset
        voice.isReady = true
    }

    private func loadDrumVoice(_ voice: SFVoice, sf2URL: URL) throws {
        // GM drums use bank 128 (percussion bank)
        // bankMSB = 120 for percussion in General MIDI
        try voice.sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: 0, // Standard GM drum kit
            bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        voice.preset = 0
        voice.isReady = true
    }

    // MARK: - Volume Control

    /// Update per-voice volumes from AudioParameters.
    /// Called from the volume sync timer (10Hz).
    public func syncVolumes(parameters: AudioParameters) {
        melody.submixer.volume = Float(parameters.melodicVolume) * 0.65
        bass.submixer.volume = Float(parameters.bassVolume)
        drums.submixer.volume = Float(parameters.drumsVolume)
    }

    // MARK: - Cleanup

    public func allNotesOff() {
        melody.allNotesOff()
        bass.allNotesOff()
        drums.allNotesOff()
    }

    public func fadeOutAndStop() {
        allNotesOff()
        masterSubmixer.volume = 0.0
    }
}
