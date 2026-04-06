// GenerativeMIDIEngine.swift
// BioNaural
//
// Algorithmic note generator that drives the SF2MelodicRenderer.
// Reads biometric state and session mode, queries ScaleMapper for
// valid pitches, and emits note-on/note-off events at musically
// coherent intervals.
//
// This is NOT random noise. It uses voice leading (prefer stepwise
// motion), phrase structure (note groups with rests), humanization
// (velocity/timing jitter), and density modulation (biometric state
// controls how many notes per beat).
//
// Threading: ALL mutable state lives on generationQueue. Public
// methods dispatch to generationQueue for thread safety. Note events
// are dispatched to main thread for AVAudioUnit compatibility.
//
// v1.5: Rule-based. v2: ML contextual bandit replaces the rules.

import Foundation
import BioNauralShared
@preconcurrency import Tonic

// MARK: - GenerativeMIDIEngine

public final class GenerativeMIDIEngine: @unchecked Sendable {

    // MARK: - Dependencies

    private let renderer: SF2MelodicRenderer
    private let parameters: AudioParameters

    /// Shared tonality — all notes, chords, and bass must be in this key/scale/tempo.
    private var tonality: SessionTonality?

    /// Reference to bass generator so chord changes can update the bass root.
    public weak var bassLineGenerator: BassLineGenerator?

    // MARK: - State (accessed ONLY on generationQueue)

    private var mode: FocusMode = .focus
    private var biometricState: BiometricState = .calm
    private var isRunning = false

    /// Timer driving note generation.
    private var noteTimer: DispatchSourceTimer?

    /// Currently sounding notes with their scheduled-off times.
    private var pendingNoteOffs: [(note: UInt8, offTime: Date)] = []

    /// Last note played (for voice leading — prefer small intervals).
    private var lastNote: UInt8?

    /// Phrase counter — rest after N notes.
    private var notesSinceRest: Int = 0

    // MARK: - Chord Progression State

    /// Current chord progression for the active mode.
    private var chordProgression: [[Int]] = []
    /// Current chord index within the progression.
    private var currentChordIndex: Int = 0
    /// Timer for chord changes (separate from melody notes).
    private var chordTimer: DispatchSourceTimer?
    /// Currently sounding chord notes.
    private var activeChordNotes: [UInt8] = []
    /// Number of chord changes made (for progression cycling).
    private var chordChangeCount: Int = 0

    /// The generation queue — ALL mutable state access is serialized here.
    private let generationQueue = DispatchQueue(
        label: "com.bionaural.generativemidi",
        qos: .userInitiated
    )

    // MARK: - Initializer

    public init(renderer: SF2MelodicRenderer, parameters: AudioParameters) {
        self.renderer = renderer
        self.parameters = parameters
    }

    // MARK: - Public API

    /// Start generating notes for the given mode and tonality.
    /// All generated notes, chords, and bass will be in the tonality's key/scale/tempo.
    public func start(mode: FocusMode, biometricState: BiometricState, tonality: SessionTonality? = nil) {
        generationQueue.async { [weak self] in
            guard let self, !self.isRunning else { return }

            self.mode = mode
            self.biometricState = biometricState
            self.tonality = tonality
            self.isRunning = true
            self.lastNote = nil
            self.notesSinceRest = 0
            self.pendingNoteOffs.removeAll()

            // Select SF2 preset for this mode.
            let presetIndex = self.presetIndex(for: mode)
            DispatchQueue.main.async { [weak self] in
                self?.renderer.changePreset(presetIndex)
                self?.renderer.fadeIn()
            }

            // Start both melody generation and chord progression.
            self.scheduleNextNote()
            self.startChordProgression()
        }
    }

    /// Update biometric state (thread-safe — dispatches to generationQueue).
    public func updateBiometricState(_ state: BiometricState) {
        generationQueue.async { [weak self] in
            self?.biometricState = state
        }
    }

    /// Stop generating notes and fade out.
    public func stop() {
        generationQueue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.noteTimer?.cancel()
            self.noteTimer = nil
            self.stopChordProgression()
            self.pendingNoteOffs.removeAll()
            self.lastNote = nil
            self.notesSinceRest = 0

            DispatchQueue.main.async { [weak self] in
                self?.renderer.fadeOutAndStop()
            }
        }
    }

    // MARK: - Note Generation Loop (runs on generationQueue)

    private func scheduleNextNote() {
        guard isRunning else { return }

        let interval = nextNoteInterval()

        let timer = DispatchSource.makeTimerSource(queue: generationQueue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.generateNote()
        }
        self.noteTimer?.cancel()
        self.noteTimer = timer
        timer.resume()
    }

    private func generateNote() {
        guard isRunning else { return }

        // Process pending note-offs first.
        processNoteOffs()

        // Check rest probability — insert silence between phrases.
        if shouldRest() {
            notesSinceRest = 0
            scheduleNextNote()
            return
        }

        // Get valid pitches from ScaleMapper.
        let validNotes = validMIDINotes()
        guard !validNotes.isEmpty else {
            scheduleNextNote()
            return
        }

        // Check polyphony cap.
        if pendingNoteOffs.count >= Theme.SF2.maxConcurrentNotes {
            scheduleNextNote()
            return
        }

        // Pick the next note using voice leading.
        let note = pickNote(from: validNotes)
        let velocity = generateVelocity()
        let duration = generateDuration()

        // Schedule note-on (dispatch to main for AVAudioUnit safety).
        DispatchQueue.main.async { [weak self] in
            self?.renderer.noteOn(note, velocity: velocity)
        }

        // Track for note-off.
        let offTime = Date().addingTimeInterval(duration)
        pendingNoteOffs.append((note: note, offTime: offTime))

        lastNote = note
        notesSinceRest += 1

        scheduleNextNote()
    }

    // MARK: - Note-Off Processing

    private func processNoteOffs() {
        let now = Date()
        let expired = pendingNoteOffs.filter { $0.offTime <= now }

        for entry in expired {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOff(entry.note)
            }
        }

        pendingNoteOffs.removeAll { $0.offTime <= now }
    }

    // MARK: - Pitch Selection

    private func validMIDINotes() -> [UInt8] {
        let octaveRange = midiOctaveRange()

        // Use SessionTonality if available (ensures all layers share the same key)
        if let tonality {
            return tonality.validNotes(octaveRange: octaveRange)
        }

        // Fallback to ScaleMapper
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

    private func pickNote(from candidates: [UInt8]) -> UInt8 {
        guard let last = lastNote else {
            // First note — pick based on mode character.
            // Sleep: start high in range (to descend). Energize: start low (to ascend).
            let startPosition: Double
            switch mode {
            case .sleep:       startPosition = 0.7  // Upper range — will descend
            case .relaxation:  startPosition = 0.5  // Middle — arch shape
            case .focus:       startPosition = 0.5  // Middle — stay centered
            case .energize:    startPosition = 0.3  // Lower range — will ascend
            }
            let targetIndex = Int(Double(candidates.count) * startPosition)
            let jitterRange = Theme.SF2.VoiceLeading.firstNoteJitter
            let jitter = Int.random(in: -jitterRange...jitterRange)
            let index = max(0, min(candidates.count - 1, targetIndex + jitter))
            return candidates[index]
        }

        // Mode-specific melodic contour bias:
        // Sleep: prefer descending motion (settling)
        // Relaxation: prefer arch (rise then fall within phrase)
        // Focus: prefer flat/oscillating (stability)
        // Energize: prefer ascending motion (building energy)
        let directionalBias = melodicDirectionBias()

        // Separate candidates into those above and below last note
        let below = candidates.filter { $0 < last }
        let above = candidates.filter { $0 > last }
        let same = candidates.filter { $0 == last }

        // Apply directional bias
        let roll = Double.random(in: 0...1)
        let preferDown = roll < directionalBias.descendProbability
        let preferUp = roll > (1.0 - directionalBias.ascendProbability)

        var pool: [UInt8]
        if preferDown && !below.isEmpty {
            pool = below
        } else if preferUp && !above.isEmpty {
            pool = above
        } else {
            pool = candidates
        }

        // Within the directional pool, still prefer small intervals (voice leading)
        let sorted = pool.sorted { a, b in
            abs(Int(a) - Int(last)) < abs(Int(b) - Int(last))
        }

        let useNear = Double.random(in: 0...1) < Theme.SF2.VoiceLeading.nearProbability
        if useNear {
            let nearCount = min(Theme.SF2.VoiceLeading.nearCount, sorted.count)
            return sorted[Int.random(in: 0..<nearCount)]
        } else {
            return sorted.randomElement() ?? candidates[0]
        }
    }

    /// Returns mode-specific melodic direction probabilities.
    /// These encode the contour research from FunctionalMusicTheory.md.
    private func melodicDirectionBias() -> (descendProbability: Double, ascendProbability: Double) {
        switch mode {
        case .sleep:
            // Strongly descending — settling, lullaby-like
            return (descendProbability: 0.65, ascendProbability: 0.15)
        case .relaxation:
            // Gentle arch — rise then fall. Balanced with slight downward bias.
            let phraseProgress = Double(notesSinceRest) / Double(max(1, Theme.SF2.PhraseLength.relaxation))
            if phraseProgress < 0.5 {
                return (descendProbability: 0.25, ascendProbability: 0.45)  // Rising phase
            } else {
                return (descendProbability: 0.50, ascendProbability: 0.20)  // Falling phase
            }
        case .focus:
            // Flat/oscillating — stay near center. Equal probability.
            return (descendProbability: 0.35, ascendProbability: 0.35)
        case .energize:
            // Ascending, building energy. Large leaps allowed.
            return (descendProbability: 0.20, ascendProbability: 0.55)
        }
    }

    // MARK: - Velocity

    private func generateVelocity() -> UInt8 {
        // Mode-specific velocity ranges:
        // Sleep: very soft (30-55), Relaxation: soft (40-65), Focus: moderate (50-80), Energize: strong (70-100)
        let range: ClosedRange<UInt8>
        switch mode {
        case .sleep:       range = 30...55
        case .relaxation:  range = 40...65
        case .focus:       range = 50...80
        case .energize:    range = 70...100
        }

        let base = Int(UInt8.random(in: range))

        let offset: Int
        switch biometricState {
        case .calm:     offset = Theme.SF2.VelocityOffset.calm
        case .focused:  offset = Theme.SF2.VelocityOffset.focused
        case .elevated: offset = Theme.SF2.VelocityOffset.elevated
        case .peak:     offset = Theme.SF2.VelocityOffset.peak
        }

        let clamped = max(Int(range.lowerBound), min(127, base + offset))
        return UInt8(clamped)
    }

    // MARK: - Duration

    private func generateDuration() -> TimeInterval {
        let multiplier = durationMultiplier()
        let minDur = Theme.SF2.durationMin * multiplier
        let maxDur = Theme.SF2.durationMax * multiplier
        return TimeInterval.random(in: minDur...maxDur)
    }

    private func durationMultiplier() -> Double {
        switch mode {
        case .focus:       return Theme.SF2.DurationMultiplier.focus
        case .relaxation:  return Theme.SF2.DurationMultiplier.relaxation
        case .sleep:       return Theme.SF2.DurationMultiplier.sleep
        case .energize:    return Theme.SF2.DurationMultiplier.energize
        }
    }

    // MARK: - Timing

    private func nextNoteInterval() -> TimeInterval {
        // Use tonality tempo if available — notes align to musical beats.
        // One beat = 60/BPM seconds. Note interval is a fraction of a beat
        // multiplied by the mode density.
        let base: TimeInterval
        if let tonality {
            // Base interval = one beat, scaled by density
            base = tonality.beatDuration
        } else {
            base = Theme.SF2.noteInterval
        }
        let jitter = TimeInterval.random(
            in: -Theme.SF2.noteIntervalJitter...Theme.SF2.noteIntervalJitter
        )
        let density = densityMultiplier()

        return max(Theme.SF2.minimumNoteInterval, (base + jitter) / density)
    }

    private func densityMultiplier() -> Double {
        let modeDensity: Double
        switch mode {
        case .focus:       modeDensity = Theme.SF2.Density.focus
        case .relaxation:  modeDensity = Theme.SF2.Density.relaxation
        case .sleep:       modeDensity = Theme.SF2.Density.sleep
        case .energize:    modeDensity = Theme.SF2.Density.energize
        }

        let biometricModifier: Double
        switch biometricState {
        case .calm:     biometricModifier = Theme.SF2.BiometricDensity.calm
        case .focused:  biometricModifier = Theme.SF2.BiometricDensity.focused
        case .elevated: biometricModifier = Theme.SF2.BiometricDensity.elevated
        case .peak:     biometricModifier = Theme.SF2.BiometricDensity.peak
        }

        return modeDensity * biometricModifier
    }

    // MARK: - Rest Logic

    private func shouldRest() -> Bool {
        let phraseLength: Int
        switch mode {
        case .focus:       phraseLength = Theme.SF2.PhraseLength.focus
        case .relaxation:  phraseLength = Theme.SF2.PhraseLength.relaxation
        case .sleep:       phraseLength = Theme.SF2.PhraseLength.sleep
        case .energize:    phraseLength = Theme.SF2.PhraseLength.energize
        }

        guard notesSinceRest >= phraseLength else { return false }

        // Mode-specific rest probability:
        // Energize rarely rests (momentum), Sleep rests often (silence is music)
        let restProb: Double
        switch mode {
        case .energize:    restProb = 0.15  // Rarely pause — keep driving
        case .focus:       restProb = 0.25  // Occasional breath
        case .relaxation:  restProb = 0.35  // Gentle pauses
        case .sleep:       restProb = 0.50  // Lots of silence
        }
        return Double.random(in: 0...1) < restProb
    }

    // MARK: - Preset Mapping

    private func presetIndex(for mode: FocusMode) -> Int {
        switch mode {
        case .focus:       return Theme.SF2.PresetIndex.focusPad
        case .relaxation:  return Theme.SF2.PresetIndex.relaxationStrings
        case .sleep:       return Theme.SF2.PresetIndex.sleepPad
        case .energize:    return Theme.SF2.PresetIndex.energizeBells
        }
    }

    // MARK: - Chord Progression System

    /// Returns mode-appropriate chord progressions as arrays of scale degrees.
    /// Each chord is represented as offsets from root (in semitones).
    /// Progressions are musically informed by functional music theory research.
    private func progressionsForMode(_ mode: FocusMode) -> [[Int]] {
        switch mode {
        case .sleep:
            // Static/minimal: I → I → IV → I. No tension, no dominant.
            // Pentatonic minor: root-based drones with occasional subdominant.
            return [
                [0, 7],      // Root + 5th (open voicing, drone)
                [0, 7],      // Repeat (stability)
                [5, 12],     // IV chord (subdominant, gentle motion)
                [0, 7],      // Return to root
            ]
        case .relaxation:
            // Lydian color: I → IVmaj7 → I → vi.
            // Floating quality from the #4 (Lydian). Gentle harmonic rhythm.
            return [
                [0, 4, 7],       // I major (root position)
                [5, 9, 12],      // IV (with Lydian #4 implied by scale)
                [0, 4, 7],       // I major
                [9, 12, 16],     // vi minor (relative minor, reflective)
                [0, 4, 7],       // I major
                [5, 9, 12],      // IV
                [7, 11, 14],     // V (gentle dominant)
                [0, 4, 7],       // I (resolution)
            ]
        case .focus:
            // Steady, predictable loop: I → vi → IV → I.
            // Familiar pop progression that fades into background.
            return [
                [0, 4, 7],      // I major
                [9, 12, 16],    // vi minor
                [5, 9, 12],     // IV major
                [0, 4, 7],      // I major
            ]
        case .energize:
            // Driving, forward: I → V → vi → IV (anthem progression).
            // With occasional key lifts for energy injection.
            return [
                [0, 4, 7],      // I major
                [7, 11, 14],    // V major
                [9, 12, 16],    // vi minor
                [5, 9, 12],     // IV major
                [0, 4, 7],      // I (repeat with variation)
                [5, 9, 12],     // IV
                [7, 11, 14],    // V (building)
                [0, 4, 7, 12],  // I (octave doubling for power)
            ]
        }
    }

    /// Start the chord progression loop. Plays sustained chord tones
    /// underneath the melodic line for harmonic foundation.
    private func startChordProgression() {
        chordProgression = progressionsForMode(mode)
        currentChordIndex = 0
        chordChangeCount = 0
        playNextChord()
    }

    /// Stop chord progression and release all chord notes.
    private func stopChordProgression() {
        chordTimer?.cancel()
        chordTimer = nil
        releaseChordNotes()
    }

    private func playNextChord() {
        guard isRunning, !chordProgression.isEmpty else { return }

        // Release previous chord notes
        releaseChordNotes()

        // Get current chord (scale degree offsets from root)
        let chordOffsets = chordProgression[currentChordIndex % chordProgression.count]

        // Use SessionTonality root if available, otherwise fall back to ScaleMapper
        let root = tonality?.root ?? ScaleMapper.rootNote(for: mode)
        let baseOctave: Int
        switch mode {
        case .sleep:       baseOctave = 2  // Low register for sleep
        case .relaxation:  baseOctave = 3  // Mid-low for relaxation
        case .focus:       baseOctave = 3  // Mid for focus
        case .energize:    baseOctave = 3  // Mid, with octave doublings
        }

        // Convert scale degree offsets to MIDI notes using the session root
        let baseMIDI = root.intValue + (baseOctave * 12)
        var chordNotes: [UInt8] = []

        for offset in chordOffsets {
            let midi = baseMIDI + offset
            if midi >= 0, midi <= 127 {
                chordNotes.append(UInt8(midi))
            }
        }

        // Play chord notes with soft velocity (pad layer, not dominant)
        let chordVelocity: UInt8
        switch mode {
        case .sleep:       chordVelocity = 35  // Very soft
        case .relaxation:  chordVelocity = 45  // Soft
        case .focus:       chordVelocity = 50  // Moderate
        case .energize:    chordVelocity = 65  // Present
        }

        for note in chordNotes {
            // Add slight timing humanization (±15ms between chord tones)
            let delay = Double.random(in: 0...0.015)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.renderer.noteOn(note, velocity: chordVelocity)
            }
        }
        activeChordNotes = chordNotes

        // Notify bass generator of the new chord root so bass follows the harmony
        if let firstChordNote = chordNotes.first {
            bassLineGenerator?.updateChordRoot(firstChordNote)
        }

        // Advance to next chord
        currentChordIndex += 1
        chordChangeCount += 1

        // Schedule next chord change based on mode's harmonic rhythm
        let chordDuration = chordChangeInterval()

        let timer = DispatchSource.makeTimerSource(queue: generationQueue)
        timer.schedule(deadline: .now() + chordDuration)
        timer.setEventHandler { [weak self] in
            self?.playNextChord()
        }
        chordTimer?.cancel()
        chordTimer = timer
        timer.resume()
    }

    /// Harmonic rhythm: how often chords change.
    /// Expressed in bars (4 beats) using the session tempo for cohesion.
    private func chordChangeInterval() -> TimeInterval {
        let barDuration = tonality?.barDuration ?? 4.0 // fallback 4s per bar

        switch mode {
        case .sleep:
            // 4-8 bars per chord (near-static harmony)
            return barDuration * Double.random(in: 4.0...8.0)
        case .relaxation:
            // 2-4 bars per chord
            return barDuration * Double.random(in: 2.0...4.0)
        case .focus:
            // 1-2 bars per chord (steady, predictable)
            return barDuration * Double.random(in: 1.0...2.0)
        case .energize:
            // 1 bar per chord (driving harmonic motion)
            return barDuration * Double.random(in: 0.5...1.0)
        }
    }

    private func releaseChordNotes() {
        for note in activeChordNotes {
            DispatchQueue.main.async { [weak self] in
                self?.renderer.noteOff(note)
            }
        }
        activeChordNotes.removeAll()
    }
}
