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

    /// Start generating notes for the given mode.
    public func start(mode: FocusMode, biometricState: BiometricState) {
        generationQueue.async { [weak self] in
            guard let self, !self.isRunning else { return }

            self.mode = mode
            self.biometricState = biometricState
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

            self.scheduleNextNote()
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
        let scale = ScaleMapper.scale(for: mode, biometricState: biometricState)
        let root = ScaleMapper.rootNote(for: mode)
        let key = Key(root: root, scale: scale)
        let octaveRange = midiOctaveRange()

        return key.noteSet.array.flatMap { note -> [UInt8] in
            octaveRange.compactMap { octave -> UInt8? in
                let midi = Int(note.noteNumber) + (octave - 4) * 12
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
            // First note — pick from the middle of the range.
            let midIndex = candidates.count / 2
            let jitterRange = Theme.SF2.VoiceLeading.firstNoteJitter
            let jitter = Int.random(in: -jitterRange...jitterRange)
            let index = max(0, min(candidates.count - 1, midIndex + jitter))
            return candidates[index]
        }

        // Sort candidates by interval distance from last note.
        let sorted = candidates.sorted { a, b in
            abs(Int(a) - Int(last)) < abs(Int(b) - Int(last))
        }

        // Weight toward small intervals for smooth voice leading.
        let useNear = Double.random(in: 0...1) < Theme.SF2.VoiceLeading.nearProbability
        if useNear {
            let nearCount = min(Theme.SF2.VoiceLeading.nearCount, sorted.count)
            return sorted[Int.random(in: 0..<nearCount)]
        } else {
            return sorted.randomElement() ?? candidates[0]
        }
    }

    // MARK: - Velocity

    private func generateVelocity() -> UInt8 {
        let base = Int(UInt8.random(in: Theme.SF2.velocityMin...Theme.SF2.velocityMax))

        let offset: Int
        switch biometricState {
        case .calm:     offset = Theme.SF2.VelocityOffset.calm
        case .focused:  offset = Theme.SF2.VelocityOffset.focused
        case .elevated: offset = Theme.SF2.VelocityOffset.elevated
        case .peak:     offset = Theme.SF2.VelocityOffset.peak
        }

        let clamped = max(Int(Theme.SF2.velocityMin), min(Int(Theme.SF2.velocityMax), base + offset))
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
        let base = Theme.SF2.noteInterval
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

        return Double.random(in: 0...1) < Theme.SF2.restProbability
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
}
