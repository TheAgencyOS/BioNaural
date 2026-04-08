// MIDISequencePlayer.swift
// BioNaural
//
// Plays pre-generated MIDI sequences (from Claude API batch generation)
// through AVAudioUnitSampler with the GeneralUser GS SoundFont.
//
// Each sequence is a JSON file containing 3-5 cohesive tracks
// (melody, bass, chords, drums, texture) all in the same key/scale/tempo.
// Sequences loop seamlessly. Zero per-session API cost.
//
// Architecture:
//   JSON sequences (bundled) → MIDISequencePlayer → AVAudioUnitSampler → Audio
//
// The player uses a single DispatchSourceTimer for ALL note scheduling,
// eliminating the timing drift that occurred with per-voice timers.

import AVFoundation
import BioNauralShared
import Foundation
import os.log

// MARK: - MIDI Sequence Data Model

/// A single MIDI note event from the pre-generated JSON.
public struct MIDINote: Codable {
    public let note: Int
    public let velocity: Int
    public let startTime: Double
    public let duration: Double
}

/// A single track within a sequence (melody, bass, chords, drums, or texture).
public struct MIDITrack: Codable {
    public let name: String
    public let program: Int
    public let role: String
    public let notes: [MIDINote]
    public let totalDuration: Double
}

/// A complete pre-generated MIDI sequence for a genre/mode combination.
public struct MIDISequence: Codable {
    public let genre: String
    public let mode: String
    public let tracks: [MIDITrack]
    public let key: String
    public let bpm: Int
    public let scale: String
    public let variation: Int?  // nil for v3 backward compatibility
}

/// The bundled catalog of all pre-generated sequences.
public struct MIDISequenceCatalog: Codable {
    public let sequences: [MIDISequence]
    public let version: String
}

// MARK: - MIDISequencePlayer

public final class MIDISequencePlayer {

    // MARK: - Properties

    private let engine: AVAudioEngine
    private let parameters: AudioParameters

    /// One sampler per track role, each with its own GM program.
    private var samplers: [String: AVAudioUnitSampler] = [:]
    private let masterSubmixer = AVAudioMixerNode()

    /// Track active notes per sampler to prevent polyphony overload.
    /// AVAudioUnitSampler crashes (EXC_BAD_ACCESS in SamplerNote::Render)
    /// when too many notes accumulate without note-offs.
    private var activeNotes: [String: Set<UInt8>] = [:]
    private let maxPolyphony = 12 // Max simultaneous notes per sampler

    /// The currently loaded sequence.
    private var currentSequence: MIDISequence?

    /// Master scheduler timer — ALL note events from ALL tracks.
    private var schedulerTimer: DispatchSourceTimer?
    private let schedulerQueue = DispatchQueue(
        label: "com.bionaural.midisequence",
        qos: .userInteractive
    )

    /// Playback position (seconds from sequence start).
    private var playbackPosition: Double = 0
    private var isPlaying = false
    private var loopCount = 0

    /// SoundFont URL.
    private var sf2URL: URL?

    private let logger = Logger(subsystem: "com.bionaural", category: "MIDISequencePlayer")

    // MARK: - Init

    public init(engine: AVAudioEngine, parameters: AudioParameters) {
        self.engine = engine
        self.parameters = parameters

        engine.attach(masterSubmixer)
    }

    /// The output node — connect to engine.mainMixerNode.
    public var outputNode: AVAudioMixerNode { masterSubmixer }

    // MARK: - Setup

    /// Load the SoundFont for rendering.
    public func setup() {
        sf2URL = Bundle.main.url(forResource: "BioNaural-Melodic", withExtension: "sf2")
        if sf2URL == nil {
            logger.error("MIDISequencePlayer: SoundFont not found")
        }
    }

    // MARK: - Sequence Loading

    /// Load the pre-generated sequence catalog from the app bundle.
    public static func loadCatalog() -> MIDISequenceCatalog? {
        guard let url = Bundle.main.url(forResource: "midi_sequences", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(MIDISequenceCatalog.self, from: data)
        } catch {
            return nil
        }
    }

    /// Find a matching sequence for a genre and mode.
    /// Randomly selects among available variations to prevent
    /// habituation (user hears a different version each session).
    public static func findSequence(
        genre: String,
        mode: FocusMode,
        catalog: MIDISequenceCatalog
    ) -> MIDISequence? {
        // Collect all matching sequences (may have 10 variations)
        let matches = catalog.sequences.filter {
            $0.genre == genre && $0.mode == mode.rawValue
        }
        if !matches.isEmpty {
            return matches.randomElement()
        }
        // Fallback: any sequence for this mode
        let modeMatches = catalog.sequences.filter { $0.mode == mode.rawValue }
        return modeMatches.randomElement()
    }

    // MARK: - Playback

    /// Start playing a sequence. Creates samplers for each track and
    /// schedules all notes via a single master timer.
    public func play(sequence: MIDISequence) {
        stop()

        guard let sf2URL else {
            logger.error("Cannot play — SoundFont not loaded")
            return
        }

        currentSequence = sequence
        playbackPosition = 0
        loopCount = 0

        // Create a sampler for each track
        for track in sequence.tracks {
            let sampler = AVAudioUnitSampler()
            engine.attach(sampler)
            engine.connect(sampler, to: masterSubmixer, format: nil)

            do {
                if track.role == "drums" {
                    // Drums use GM percussion bank
                    try sampler.loadSoundBankInstrument(
                        at: sf2URL,
                        program: 0,
                        bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB),
                        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                    )
                } else {
                    try sampler.loadSoundBankInstrument(
                        at: sf2URL,
                        program: UInt8(max(0, min(127, track.program))),
                        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                    )
                }
            } catch {
                logger.error("Failed to load program \(track.program) for \(track.name): \(error.localizedDescription)")
            }

            samplers[track.role] = sampler
        }

        // Set initial volumes
        masterSubmixer.volume = 0.7

        isPlaying = true
        startScheduler(sequence: sequence)

        logger.info("Playing: \(sequence.genre)/\(sequence.mode) — \(sequence.tracks.count) tracks, \(sequence.bpm) BPM, key=\(sequence.key)")
    }

    /// Stop playback. Does NOT detach samplers (causes render thread crash).
    /// Samplers are silenced and reused on next play().
    public func stop() {
        isPlaying = false
        schedulerTimer?.cancel()
        schedulerTimer = nil

        // Silence all notes but keep samplers attached to avoid
        // EXC_BAD_ACCESS on the audio render thread.
        for (_, sampler) in samplers {
            for note: UInt8 in 0...127 {
                sampler.stopNote(note, onChannel: 0)
            }
            sampler.volume = 0
        }
        masterSubmixer.volume = 0
        activeNotes.removeAll()
        currentSequence = nil
    }

    // MARK: - Safe Note Management

    /// Play a note with polyphony limiting to prevent SamplerNote::Render crash.
    private func safeNoteOn(role: String, sampler: AVAudioUnitSampler, note: UInt8, velocity: UInt8) {
        // Ensure we don't exceed polyphony limit
        var notes = activeNotes[role] ?? []
        if notes.count >= maxPolyphony {
            // Stop the oldest note to make room
            if let oldest = notes.first {
                sampler.stopNote(oldest, onChannel: 0)
                notes.remove(oldest)
            }
        }
        // Stop this specific note if already playing (prevents doubling)
        if notes.contains(note) {
            sampler.stopNote(note, onChannel: 0)
        }
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        notes.insert(note)
        activeNotes[role] = notes
    }

    /// Stop a note and update tracking.
    private func safeNoteOff(role: String, sampler: AVAudioUnitSampler, note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
        activeNotes[role]?.remove(note)
    }

    /// Update per-role volumes from AudioParameters sliders.
    public func syncVolumes() {
        samplers["melody"]?.volume = Float(parameters.melodicVolume)
        samplers["bass"]?.volume = Float(parameters.bassVolume)
        samplers["drums"]?.volume = Float(parameters.drumsVolume)
        samplers["chords"]?.volume = Float(parameters.melodicVolume) * 0.7
        samplers["texture"]?.volume = Float(parameters.melodicVolume) * 0.5
    }

    // MARK: - Scheduler

    /// Single master timer that schedules ALL notes from ALL tracks.
    /// Runs every 50ms, looks 100ms ahead. Uses a flat event list
    /// sorted by time for efficient sequential scanning.
    ///
    /// SEAMLESS LOOPING: Instead of hard-resetting at the loop boundary,
    /// this scheduler treats the sequence as infinite by using modular
    /// arithmetic on the event list. Notes that cross the loop boundary
    /// are allowed to ring out naturally — no abrupt cutoffs.
    /// A 2-second crossfade zone at the end gradually reduces velocity
    /// while the beginning of the next loop fades in.
    private func startScheduler(sequence: MIDISequence) {
        // Build a flat, sorted event list from all tracks
        var events: [(time: Double, role: String, note: UInt8, velocity: UInt8, isOn: Bool)] = []

        for track in sequence.tracks {
            for midiNote in track.notes {
                let note = UInt8(max(0, min(127, midiNote.note)))
                let vel = UInt8(max(1, min(127, midiNote.velocity)))

                events.append((midiNote.startTime, track.role, note, vel, true))   // note-on
                events.append((midiNote.startTime + midiNote.duration, track.role, note, 0, false)) // note-off
            }
        }

        events.sort { $0.time < $1.time }

        let totalDuration = sequence.tracks.map(\.totalDuration).max() ?? 30.0
        let crossfadeZone: Double = 8.0 // seconds of crossfade at loop boundary
        var eventIndex = 0
        var absoluteTime: Double = 0 // monotonically increasing, never resets

        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self, self.isPlaying else { return }

            absoluteTime += 0.05
            let posInLoop = absoluteTime.truncatingRemainder(dividingBy: totalDuration)
            self.playbackPosition = posInLoop

            // Detect loop boundary crossing
            let prevPos = (absoluteTime - 0.05).truncatingRemainder(dividingBy: totalDuration)
            if posInLoop < prevPos {
                // We crossed the loop point — reset event index
                // but DON'T stop any notes (let them ring out naturally)
                eventIndex = 0
                self.loopCount += 1

                // Subtle variation: shift the start offset slightly each loop
                // so the sequence doesn't sound identical every time.
                // This is imperceptible but prevents pattern recognition.
                let jitter = Double.random(in: -0.03...0.03)
                absoluteTime += jitter
            }

            // Crossfade multiplier: full volume except near the end/start
            let fadeMultiplier: Float
            if posInLoop > totalDuration - crossfadeZone {
                // Fading out at end of loop
                let fadeProgress = Float((totalDuration - posInLoop) / crossfadeZone)
                fadeMultiplier = fadeProgress // 1.0 → 0.0
            } else if posInLoop < crossfadeZone && self.loopCount > 0 {
                // Fading in at start of new loop (not first play)
                let fadeProgress = Float(posInLoop / crossfadeZone)
                fadeMultiplier = fadeProgress // 0.0 → 1.0
            } else {
                fadeMultiplier = 1.0
            }

            let lookAhead = posInLoop + 0.1

            // Fire events within the lookahead window
            while eventIndex < events.count && events[eventIndex].time < lookAhead {
                let event = events[eventIndex]

                if event.time >= posInLoop - 0.05 {
                    guard let sampler = self.samplers[event.role] else {
                        eventIndex += 1
                        continue
                    }

                    if event.isOn {
                        let fadedVelocity = UInt8(max(1, min(127, Float(event.velocity) * fadeMultiplier)))
                        self.safeNoteOn(role: event.role, sampler: sampler, note: event.note, velocity: fadedVelocity)
                    } else {
                        self.safeNoteOff(role: event.role, sampler: sampler, note: event.note)
                    }
                }

                eventIndex += 1
            }

            // Handle wrap-around: if lookAhead crossed the boundary,
            // also check events at the beginning of the sequence
            if lookAhead > totalDuration && self.loopCount > 0 {
                let wrapLookAhead = lookAhead - totalDuration
                var wrapIdx = 0
                while wrapIdx < events.count && events[wrapIdx].time < wrapLookAhead {
                    let event = events[wrapIdx]
                    if let sampler = self.samplers[event.role] {
                        if event.isOn {
                            let fadedVelocity = UInt8(max(1, min(127, Float(event.velocity) * fadeMultiplier)))
                            self.safeNoteOn(role: event.role, sampler: sampler, note: event.note, velocity: fadedVelocity)
                        } else {
                            self.safeNoteOff(role: event.role, sampler: sampler, note: event.note)
                        }
                    }
                    wrapIdx += 1
                }
            }
        }

        schedulerTimer = timer
        timer.resume()
    }
}
