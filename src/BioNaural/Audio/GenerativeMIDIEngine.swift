// GenerativeMIDIEngine.swift
// BioNaural
//
// v2: Single master sequencer with pattern-based generation.
//
// Architecture: ONE DispatchSourceTimer ticks at 16th-note resolution.
// All melody, chord, and note-off events fire from this single clock —
// no independent timers, no drift between tracks.
//
// Melody uses pre-generated multi-bar PATTERNS that repeat with subtle
// variation, not random single notes. Chord changes happen on exact bar
// boundaries. Everything stays in sync because everything shares one clock.
//
// Threading: ALL mutable state on generationQueue. Note events dispatched
// to main thread for AVAudioUnit safety.

import Foundation
import BioNauralShared
@preconcurrency import Tonic

// MARK: - GenerativeMIDIEngine

public final class GenerativeMIDIEngine: @unchecked Sendable {

    // MARK: - Dependencies

    private let renderer: SF2MelodicRenderer
    private let parameters: AudioParameters

    /// Shared tonality — key/scale/tempo for the entire session.
    private var tonality: SessionTonality?

    /// Bass generator — receives chord root updates.
    public weak var bassLineGenerator: BassLineGenerator?

    // MARK: - State (generationQueue only)

    private var mode: FocusMode = .focus
    private var biometricState: BiometricState = .calm
    private var isRunning = false

    // Master clock state
    private var masterTimer: DispatchSourceTimer?
    private var tickCount: Int = 0           // 16th-note ticks since start
    private var currentBar: Int = 0          // bars elapsed
    private var ticksPerBar: Int = 16        // 16th notes per 4/4 bar

    // Melody pattern state
    private var melodyPattern: [PatternNote?] = []  // nil = rest
    private var patternLength: Int = 0               // in ticks
    private var patternRepeatCount: Int = 0

    // Chord state
    private var chordProgression: [[Int]] = []
    private var currentChordIndex: Int = 0
    private var activeChordNotes: [UInt8] = []
    private var barsPerChord: Int = 4

    // Active notes for cleanup
    private var activeMelodyNote: UInt8?

    private let generationQueue = DispatchQueue(
        label: "com.bionaural.generativemidi",
        qos: .userInitiated
    )

    // MARK: - Pattern Note

    private struct PatternNote {
        let note: UInt8
        let velocity: UInt8
        let durationTicks: Int  // how many 16th-note ticks to sustain
    }

    // MARK: - Init

    public init(renderer: SF2MelodicRenderer, parameters: AudioParameters) {
        self.renderer = renderer
        self.parameters = parameters
    }

    // MARK: - Public API

    public func start(mode: FocusMode, biometricState: BiometricState, tonality: SessionTonality? = nil) {
        generationQueue.async { [weak self] in
            guard let self, !self.isRunning else { return }

            self.mode = mode
            self.biometricState = biometricState
            self.tonality = tonality
            self.isRunning = true
            self.tickCount = 0
            self.currentBar = 0
            self.patternRepeatCount = 0
            self.activeMelodyNote = nil
            self.activeChordNotes = []

            // Select preset
            let presetIndex = self.presetIndex(for: mode)
            DispatchQueue.main.async { [weak self] in
                self?.renderer.changePreset(presetIndex)
                self?.renderer.fadeIn()
            }

            // Set up chord progression and timing
            self.chordProgression = self.progressionsForMode(mode)
            self.currentChordIndex = 0
            self.barsPerChord = self.barsPerChordForMode(mode)

            // Generate initial melody pattern
            self.generateNewPattern()

            // Play first chord immediately
            self.playChord()

            // Start the master clock
            self.startMasterClock()
        }
    }

    public func updateBiometricState(_ state: BiometricState) {
        generationQueue.async { [weak self] in
            self?.biometricState = state
        }
    }

    public func stop() {
        generationQueue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.masterTimer?.cancel()
            self.masterTimer = nil
            self.releaseAllNotes()

            DispatchQueue.main.async { [weak self] in
                self?.renderer.fadeOutAndStop()
            }
        }
    }

    // MARK: - Master Clock

    private func startMasterClock() {
        guard let tonality else { return }

        // Tick at 16th-note resolution: beatDuration / 4
        let tickInterval = tonality.beatDuration / 4.0

        let timer = DispatchSource.makeTimerSource(queue: generationQueue)
        timer.schedule(deadline: .now() + tickInterval, repeating: tickInterval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.masterTick()
        }
        masterTimer?.cancel()
        masterTimer = timer
        timer.resume()
    }

    /// Single master tick — processes ALL musical events from one clock.
    private func masterTick() {
        guard isRunning else { return }

        let tickInBar = tickCount % ticksPerBar
        let barChanged = tickInBar == 0 && tickCount > 0

        // === BAR BOUNDARY: chord changes and pattern evolution ===
        if barChanged {
            currentBar += 1

            // Chord change on exact bar boundary
            if currentBar % barsPerChord == 0 {
                currentChordIndex += 1
                playChord()
            }

            // Pattern evolution: generate new pattern every N bars
            let patternBars = patternLength / ticksPerBar
            if patternBars > 0 && currentBar % patternBars == 0 {
                patternRepeatCount += 1
                // Evolve pattern every 2nd repeat
                if patternRepeatCount % 2 == 0 {
                    generateNewPattern()
                }
            }
        }

        // === MELODY: play pattern notes on the grid ===
        if !melodyPattern.isEmpty {
            let patternTick = tickCount % patternLength

            // Note-off for previous melody note
            if let active = activeMelodyNote {
                // Check if this tick should release the note
                let prevTick = (patternTick == 0) ? patternLength - 1 : patternTick - 1
                if let prevNote = melodyPattern[prevTick % melodyPattern.count],
                   prevNote.note == active {
                    let ticksSinceNoteStart = ticksSinceLastNoteOn(patternTick: patternTick)
                    if let currentNote = melodyPattern[patternTick % melodyPattern.count],
                       currentNote.note != active {
                        // New note starting — release old one
                        noteOff(active)
                        activeMelodyNote = nil
                    }
                }
            }

            // Note-on for current tick
            if let pNote = melodyPattern[patternTick % melodyPattern.count] {
                if activeMelodyNote != pNote.note {
                    // Release any previous note
                    if let active = activeMelodyNote {
                        noteOff(active)
                    }
                    noteOn(pNote.note, velocity: pNote.velocity)
                    activeMelodyNote = pNote.note
                }
            } else {
                // Rest tick — release any held note
                if let active = activeMelodyNote {
                    noteOff(active)
                    activeMelodyNote = nil
                }
            }
        }

        tickCount += 1
    }

    private func ticksSinceLastNoteOn(patternTick: Int) -> Int {
        var t = patternTick - 1
        while t >= 0 {
            if melodyPattern[t % melodyPattern.count] != nil { return patternTick - t }
            t -= 1
        }
        return patternTick
    }

    // MARK: - Pattern Generation

    /// Generate a multi-bar melody pattern that repeats.
    /// Pattern is chord-aware: strong beats use chord tones, weak beats use steps.
    private func generateNewPattern() {
        let patternBars = patternBarsForMode(mode)
        patternLength = patternBars * ticksPerBar

        let validNotes = validMIDINotes()
        guard !validNotes.isEmpty else {
            melodyPattern = Array(repeating: nil, count: patternLength)
            return
        }

        // Get current chord tones
        let chordTones = currentChordTones()

        // Build rhythm template: which ticks get notes vs rests
        let rhythm = rhythmTemplateForMode(mode)

        var pattern: [PatternNote?] = []
        var lastPitch: UInt8 = validNotes[validNotes.count / 2] // start center

        for tick in 0..<patternLength {
            let tickInBar = tick % ticksPerBar
            let shouldPlay = rhythm[tickInBar % rhythm.count]

            guard shouldPlay else {
                pattern.append(nil) // rest
                continue
            }

            // Strong beat (beats 1, 2, 3, 4 = ticks 0, 4, 8, 12): use chord tone
            let isStrongBeat = tickInBar % 4 == 0

            let pitch: UInt8
            if isStrongBeat && !chordTones.isEmpty {
                // Pick closest chord tone to last pitch (voice leading)
                pitch = chordTones.min(by: { abs(Int($0) - Int(lastPitch)) < abs(Int($1) - Int(lastPitch)) }) ?? lastPitch
            } else {
                // Weak beat: stepwise motion from last pitch
                let nearby = validNotes.filter { abs(Int($0) - Int(lastPitch)) <= 4 }
                let biased = applyContourBias(nearby, lastPitch: lastPitch)
                pitch = biased.randomElement() ?? lastPitch
            }

            let velocity = patternVelocity(tickInBar: tickInBar)
            let duration = isStrongBeat ? 3 : 2 // ticks

            pattern.append(PatternNote(note: pitch, velocity: velocity, durationTicks: duration))
            lastPitch = pitch
        }

        melodyPattern = pattern
    }

    /// Rhythm templates: which 16th-note ticks get notes (true) vs rests (false).
    /// These encode the feel per mode — how many notes, where they fall.
    private func rhythmTemplateForMode(_ mode: FocusMode) -> [Bool] {
        switch mode {
        case .sleep:
            // Very sparse: note on beat 1 only, rest for 3 beats
            //                beat1         beat2         beat3         beat4
            return [true, false,false,false, false,false,false,false, false,false,false,false, false,false,false,false]

        case .relaxation:
            // Gentle: notes on beats 1 and 3, with occasional passing tone on beat 2-and
            return [true, false,false,false, false,false,true, false, true, false,false,false, false,false,false,false]

        case .focus:
            // Steady 8ths with rests — lo-fi feel
            return [true, false,true, false, false,true, false,true,  true, false,true, false, true, false,false,false]

        case .energize:
            // Sparse accents — bass and drums carry the groove
            return [true, false,false,false, false,false,false,false, true, false,false,false, false,false,false,false]
        }
    }

    /// How many bars the melody pattern spans before repeating.
    private func patternBarsForMode(_ mode: FocusMode) -> Int {
        switch mode {
        case .sleep:       return 8  // Long phrases, slow evolution
        case .relaxation:  return 4  // Medium phrases
        case .focus:       return 4  // Predictable loops
        case .energize:    return 2  // Short riffs
        }
    }

    private func patternVelocity(tickInBar: Int) -> UInt8 {
        let range: ClosedRange<UInt8>
        switch mode {
        case .sleep:       range = 45...60
        case .relaxation:  range = 55...70
        case .focus:       range = 50...68
        case .energize:    range = 70...90
        }

        // Accent on beat 1 (tick 0)
        let isDownbeat = tickInBar == 0
        let base = isDownbeat ? range.upperBound : UInt8.random(in: range)
        return base
    }

    /// Apply mode-specific contour bias to note candidates.
    private func applyContourBias(_ candidates: [UInt8], lastPitch: UInt8) -> [UInt8] {
        guard !candidates.isEmpty else { return candidates }

        switch mode {
        case .sleep:
            // Prefer descending
            let below = candidates.filter { $0 <= lastPitch }
            return below.isEmpty ? candidates : below
        case .relaxation:
            // Gentle arch — alternate up/down based on pattern position
            return candidates // balanced, no strong bias
        case .focus:
            // Stay near center — prefer same or close
            let near = candidates.filter { abs(Int($0) - Int(lastPitch)) <= 2 }
            return near.isEmpty ? candidates : near
        case .energize:
            // Prefer ascending
            let above = candidates.filter { $0 >= lastPitch }
            return above.isEmpty ? candidates : above
        }
    }

    // MARK: - Chord System (plays on exact bar boundaries from master clock)

    private func playChord() {
        releaseChordNotes()

        guard !chordProgression.isEmpty else { return }

        let chordOffsets = chordProgression[currentChordIndex % chordProgression.count]
        let root = tonality?.root ?? ScaleMapper.rootNote(for: mode)
        let baseOctave: Int
        switch mode {
        case .sleep:       baseOctave = 2
        case .relaxation:  baseOctave = 3
        case .focus:       baseOctave = 3
        case .energize:    baseOctave = 3
        }

        let baseMIDI = root.intValue + (baseOctave * 12)
        var chordNotes: [UInt8] = []

        for offset in chordOffsets {
            let midi = baseMIDI + offset
            if midi >= 0, midi <= 127 {
                chordNotes.append(UInt8(midi))
            }
        }

        let chordVelocity: UInt8
        switch mode {
        case .sleep:       chordVelocity = 45
        case .relaxation:  chordVelocity = 55
        case .focus:       chordVelocity = 50
        case .energize:    chordVelocity = 65
        }

        for note in chordNotes {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOn(note, velocity: chordVelocity)
            }
        }
        activeChordNotes = chordNotes

        // Update bass
        if let firstNote = chordNotes.first {
            bassLineGenerator?.updateChordRoot(firstNote)
        }
    }

    /// How many bars between chord changes per mode.
    private func barsPerChordForMode(_ mode: FocusMode) -> Int {
        switch mode {
        case .sleep:       return 8   // Near-static
        case .relaxation:  return 4   // Gentle motion
        case .focus:       return 4   // Predictable
        case .energize:    return 2   // Driving
        }
    }

    // MARK: - Helpers

    private func currentChordTones() -> [UInt8] {
        guard !chordProgression.isEmpty else { return [] }
        let chordOffsets = chordProgression[currentChordIndex % chordProgression.count]
        let root = tonality?.root ?? ScaleMapper.rootNote(for: mode)
        let octaveRange = midiOctaveRange()

        var tones: [UInt8] = []
        for octave in octaveRange {
            let baseMIDI = root.intValue + (octave * 12)
            for offset in chordOffsets {
                let midi = baseMIDI + offset
                if midi >= 0, midi <= 127 {
                    tones.append(UInt8(midi))
                }
            }
        }
        return tones.sorted()
    }

    private func validMIDINotes() -> [UInt8] {
        let octaveRange = midiOctaveRange()
        if let tonality {
            return tonality.validNotes(octaveRange: octaveRange)
        }
        let scale = ScaleMapper.scale(for: mode, biometricState: biometricState)
        let root = ScaleMapper.rootNote(for: mode)
        let key = Key(root: root, scale: scale)
        return key.noteSet.array.flatMap { note -> [UInt8] in
            octaveRange.compactMap { octave -> UInt8? in
                let midi = Int(note.intValue) + (octave * 12)
                guard midi >= 0, midi <= 127 else { return nil }
                return UInt8(midi)
            }
        }.sorted()
    }

    private func midiOctaveRange() -> ClosedRange<Int> {
        switch mode {
        case .focus:       return Theme.SF2.OctaveRange.focus
        case .relaxation:  return Theme.SF2.OctaveRange.relaxation
        case .sleep:       return Theme.SF2.OctaveRange.sleep
        case .energize:    return Theme.SF2.OctaveRange.energize
        }
    }

    private func presetIndex(for mode: FocusMode) -> Int {
        switch mode {
        case .focus:       return Theme.SF2.PresetIndex.focusPad
        case .relaxation:  return Theme.SF2.PresetIndex.relaxationStrings
        case .sleep:       return Theme.SF2.PresetIndex.sleepPad
        case .energize:    return Theme.SF2.PresetIndex.energizeBells
        }
    }

    // MARK: - Note Helpers

    private func noteOn(_ note: UInt8, velocity: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.renderer.noteOn(note, velocity: velocity)
        }
    }

    private func noteOff(_ note: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.renderer.noteOff(note)
        }
    }

    private func releaseAllNotes() {
        if let active = activeMelodyNote {
            noteOff(active)
            activeMelodyNote = nil
        }
        releaseChordNotes()
    }

    private func releaseChordNotes() {
        for note in activeChordNotes {
            noteOff(note)
        }
        activeChordNotes.removeAll()
    }

    // MARK: - Chord Progressions

    private func progressionsForMode(_ mode: FocusMode) -> [[Int]] {
        switch mode {
        case .sleep:
            return [
                [0, 7],      // Root + 5th (drone)
                [0, 7],      // Repeat
                [5, 12],     // IV
                [0, 7],      // Root
            ]
        case .relaxation:
            return [
                [0, 4, 7],       // I
                [5, 9, 12],      // IV
                [0, 4, 7],       // I
                [9, 12, 16],     // vi
                [0, 4, 7],       // I
                [5, 9, 12],      // IV
                [7, 11, 14],     // V
                [0, 4, 7],       // I
            ]
        case .focus:
            return [
                [0, 4, 7],      // I
                [9, 12, 16],    // vi
                [5, 9, 12],     // IV
                [0, 4, 7],      // I
            ]
        case .energize:
            return [
                [0, 4, 7],      // I
                [7, 11, 14],    // V
                [9, 12, 16],    // vi
                [5, 9, 12],     // IV
                [0, 4, 7],      // I
                [5, 9, 12],     // IV
                [7, 11, 14],    // V
                [0, 4, 7, 12],  // I (power)
            ]
        }
    }
}
