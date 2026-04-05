// DemoContentSeeder.swift
// BioNaural
//
// Seeds realistic demo data into SwiftData on first launch so the
// Library tab shows sample Compositions, Sessions tracks, and
// Correlations during development. Checks for existing data to
// avoid duplicating on re-launch.

import Foundation
import SwiftData
import BioNauralShared

enum DemoContentSeeder {

    // MARK: - Public Entry Point

    /// Seeds demo content if the database is empty. Safe to call on every launch.
    static func seedIfNeeded(in context: ModelContext) {
        guard needsSeeding(in: context) else { return }

        seedCompositions(in: context)
        seedSavedTracks(in: context)
        seedSonicMemories(in: context)
        seedFocusSessions(in: context)

        try? context.save()
    }

    // MARK: - Existence Check

    private static func needsSeeding(in context: ModelContext) -> Bool {
        let compositionDescriptor = FetchDescriptor<CustomComposition>()
        let trackDescriptor = FetchDescriptor<SavedTrack>()
        let memoryDescriptor = FetchDescriptor<SonicMemory>()
        let sessionDescriptor = FetchDescriptor<FocusSession>()

        let compositionCount = (try? context.fetchCount(compositionDescriptor)) ?? 0
        let trackCount = (try? context.fetchCount(trackDescriptor)) ?? 0
        let memoryCount = (try? context.fetchCount(memoryDescriptor)) ?? 0
        let sessionCount = (try? context.fetchCount(sessionDescriptor)) ?? 0

        return compositionCount == 0 && trackCount == 0 && memoryCount == 0 && sessionCount == 0
    }

    // MARK: - Compositions

    private static func seedCompositions(in context: ModelContext) {
        let now = Date()

        // 1. Rain Focus — focus mode, rain ambient, piano+pad, 25 min, adaptive
        context.insert(CustomComposition(
            name: "Rain Focus",
            createdDate: now.addingTimeInterval(-86400 * 12),
            lastPlayedDate: now.addingTimeInterval(-3600 * 4),
            brainState: FocusMode.focus.rawValue,
            beatFrequency: FocusMode.focus.defaultBeatFrequency,
            carrierFrequency: FocusMode.focus.defaultCarrierFrequency,
            ambientBedName: "rain",
            instruments: [Instrument.piano.rawValue, Instrument.pad.rawValue],
            brightness: Theme.Compose.ModeDefaults.brightness(for: .focus),
            density: Theme.Compose.ModeDefaults.density(for: .focus),
            reverbWetDry: Theme.Compose.Defaults.reverbWetDry,
            binauralVolume: Theme.Compose.Defaults.binauralVolume,
            ambientVolume: Theme.Compose.Defaults.ambientVolume,
            melodicVolume: Theme.Compose.Defaults.melodicVolume,
            durationMinutes: Theme.Compose.Defaults.durationMinutes,
            isAdaptive: true
        ))

        // 2. Night Drift — sleep mode, night ambient + crickets, pad+strings, 45 min
        context.insert(CustomComposition(
            name: "Night Drift",
            createdDate: now.addingTimeInterval(-86400 * 9),
            lastPlayedDate: now.addingTimeInterval(-86400 * 2),
            brainState: FocusMode.sleep.rawValue,
            beatFrequency: FocusMode.sleep.defaultBeatFrequency,
            carrierFrequency: FocusMode.sleep.defaultCarrierFrequency,
            ambientBedName: "night",
            detailTextureName: "crickets",
            instruments: [Instrument.pad.rawValue, Instrument.strings.rawValue],
            brightness: Theme.Compose.ModeDefaults.brightness(for: .sleep),
            density: Theme.Compose.ModeDefaults.density(for: .sleep),
            reverbWetDry: 35.0,
            binauralVolume: 0.4,
            ambientVolume: 0.8,
            melodicVolume: 0.45,
            durationMinutes: 45,
            isAdaptive: false
        ))

        // 3. Ocean Calm — relaxation mode, ocean ambient, strings, 20 min, adaptive
        context.insert(CustomComposition(
            name: "Ocean Calm",
            createdDate: now.addingTimeInterval(-86400 * 6),
            lastPlayedDate: now.addingTimeInterval(-86400),
            brainState: FocusMode.relaxation.rawValue,
            beatFrequency: FocusMode.relaxation.defaultBeatFrequency,
            carrierFrequency: FocusMode.relaxation.defaultCarrierFrequency,
            ambientBedName: "ocean",
            instruments: [Instrument.strings.rawValue],
            brightness: Theme.Compose.ModeDefaults.brightness(for: .relaxation),
            density: Theme.Compose.ModeDefaults.density(for: .relaxation),
            reverbWetDry: 25.0,
            binauralVolume: Theme.Compose.Defaults.binauralVolume,
            ambientVolume: 0.75,
            melodicVolume: 0.5,
            durationMinutes: 20,
            isAdaptive: true
        ))

        // 4. Fire Energy — energize mode, fire detail, guitar+percussion, 15 min
        context.insert(CustomComposition(
            name: "Fire Energy",
            createdDate: now.addingTimeInterval(-86400 * 3),
            brainState: FocusMode.energize.rawValue,
            beatFrequency: FocusMode.energize.defaultBeatFrequency,
            carrierFrequency: FocusMode.energize.defaultCarrierFrequency,
            detailTextureName: "fire",
            instruments: [Instrument.guitar.rawValue, Instrument.percussion.rawValue],
            brightness: Theme.Compose.ModeDefaults.brightness(for: .energize),
            density: Theme.Compose.ModeDefaults.density(for: .energize),
            reverbWetDry: 10.0,
            binauralVolume: 0.6,
            ambientVolume: 0.65,
            melodicVolume: 0.6,
            durationMinutes: 15,
            isAdaptive: false
        ))

        // 5. Forest Work — focus mode, forest ambient + birdsong, texture+piano, 60 min
        context.insert(CustomComposition(
            name: "Forest Work",
            createdDate: now.addingTimeInterval(-86400),
            lastPlayedDate: now.addingTimeInterval(-7200),
            brainState: FocusMode.focus.rawValue,
            beatFrequency: 14.0,
            carrierFrequency: 350.0,
            ambientBedName: "forest",
            detailTextureName: "birdsong",
            instruments: [Instrument.texture.rawValue, Instrument.piano.rawValue],
            brightness: 0.35,
            density: 0.25,
            reverbWetDry: 20.0,
            binauralVolume: Theme.Compose.Defaults.binauralVolume,
            ambientVolume: Theme.Compose.Defaults.ambientVolume,
            melodicVolume: Theme.Compose.Defaults.melodicVolume,
            durationMinutes: 60,
            isAdaptive: false
        ))
    }

    // MARK: - Saved Tracks (Sessions)

    private static func seedSavedTracks(in context: ModelContext) {
        let now = Date()

        // 1. Morning Focus — focus mode, 25 min, avg HR 68, beat 15->12 Hz
        context.insert(SavedTrack(
            sessionID: UUID(),
            name: "Morning Focus",
            mode: FocusMode.focus.rawValue,
            durationSeconds: 25 * 60,
            averageHeartRate: 68,
            beatFrequencyStart: 15.0,
            beatFrequencyEnd: 12.0,
            carrierFrequency: FocusMode.focus.defaultCarrierFrequency,
            ambientBedID: "rain",
            melodicLayerIDs: [Instrument.piano.rawValue, Instrument.pad.rawValue],
            dateSaved: now.addingTimeInterval(-86400 * 10),
            playCount: 7,
            isFavorite: true
        ))

        // 2. Deep Sleep — sleep mode, 45 min, avg HR 58, beat 6->2 Hz
        context.insert(SavedTrack(
            sessionID: UUID(),
            name: "Deep Sleep",
            mode: FocusMode.sleep.rawValue,
            durationSeconds: 45 * 60,
            averageHeartRate: 58,
            beatFrequencyStart: 6.0,
            beatFrequencyEnd: 2.0,
            carrierFrequency: FocusMode.sleep.defaultCarrierFrequency,
            ambientBedID: "night",
            melodicLayerIDs: [Instrument.pad.rawValue, Instrument.strings.rawValue],
            dateSaved: now.addingTimeInterval(-86400 * 7),
            playCount: 12,
            isFavorite: true
        ))

        // 3. Recovery — relaxation mode, 20 min, avg HR 64, beat 10->8 Hz
        context.insert(SavedTrack(
            sessionID: UUID(),
            name: "Recovery",
            mode: FocusMode.relaxation.rawValue,
            durationSeconds: 20 * 60,
            averageHeartRate: 64,
            beatFrequencyStart: 10.0,
            beatFrequencyEnd: 8.0,
            carrierFrequency: FocusMode.relaxation.defaultCarrierFrequency,
            ambientBedID: "ocean",
            melodicLayerIDs: [Instrument.strings.rawValue],
            dateSaved: now.addingTimeInterval(-86400 * 4),
            playCount: 3,
            isFavorite: false
        ))

        // 4. Afternoon Push — focus mode, 30 min, avg HR 72, beat 14->11 Hz
        context.insert(SavedTrack(
            sessionID: UUID(),
            name: "Afternoon Push",
            mode: FocusMode.focus.rawValue,
            durationSeconds: 30 * 60,
            averageHeartRate: 72,
            beatFrequencyStart: 14.0,
            beatFrequencyEnd: 11.0,
            carrierFrequency: 350.0,
            ambientBedID: "forest",
            melodicLayerIDs: [Instrument.texture.rawValue, Instrument.piano.rawValue],
            dateSaved: now.addingTimeInterval(-86400 * 2),
            playCount: 5,
            isFavorite: false
        ))
    }

    // MARK: - Correlations

    private static func seedSonicMemories(in context: ModelContext) {
        let now = Date()

        // 1. "The sound of Sunday mornings" — calm, relaxation, warm+sparse
        context.insert(SonicMemory(
            userDescription: "The sound of Sunday mornings",
            extractedWarmth: 0.85,
            extractedRhythm: 0.1,
            extractedDensity: 0.15,
            extractedBrightness: 0.3,
            preferredInstruments: [Instrument.piano.rawValue, Instrument.pad.rawValue],
            preferredAmbientTags: ["rain", "wind"],
            emotionalAssociation: EmotionalAssociation.calm.rawValue,
            associatedMode: FocusMode.relaxation.rawValue,
            sessionCount: 4,
            averageSuccessScore: 0.82,
            dateCreated: now.addingTimeInterval(-86400 * 14),
            lastUsed: now.addingTimeInterval(-86400 * 3)
        ))

        // 2. "Late night coding flow" — focused, focus, bright+dense
        context.insert(SonicMemory(
            userDescription: "Late night coding flow",
            extractedWarmth: 0.35,
            extractedRhythm: 0.3,
            extractedDensity: 0.75,
            extractedBrightness: 0.7,
            extractedTempo: 90,
            preferredInstruments: [Instrument.texture.rawValue, Instrument.pad.rawValue],
            preferredAmbientTags: ["rain"],
            emotionalAssociation: EmotionalAssociation.focused.rawValue,
            associatedMode: FocusMode.focus.rawValue,
            sessionCount: 8,
            averageSuccessScore: 0.88,
            dateCreated: now.addingTimeInterval(-86400 * 11),
            lastUsed: now.addingTimeInterval(-86400)
        ))

        // 3. "After the gym" — energized, energize, bright+rhythmic
        context.insert(SonicMemory(
            userDescription: "After the gym",
            extractedWarmth: 0.4,
            extractedRhythm: 0.7,
            extractedDensity: 0.55,
            extractedBrightness: 0.75,
            extractedTempo: 120,
            preferredInstruments: [Instrument.guitar.rawValue, Instrument.percussion.rawValue],
            preferredAmbientTags: [],
            emotionalAssociation: EmotionalAssociation.energized.rawValue,
            associatedMode: FocusMode.energize.rawValue,
            sessionCount: 3,
            averageSuccessScore: 0.76,
            dateCreated: now.addingTimeInterval(-86400 * 5),
            lastUsed: now.addingTimeInterval(-86400 * 2)
        ))
    }

    // MARK: - Focus Sessions (for Insights)

    private static func seedFocusSessions(in context: ModelContext) {
        let now = Date()
        let day: TimeInterval = 86400

        // 10 sessions spread over 14 days — mix of modes, realistic biometrics
        let sessions: [(daysAgo: Double, mode: FocusMode, durationMin: Int, hr: Double, hrv: Double, score: Double, completed: Bool)] = [
            (0.5, .focus, 25, 66, 48, 0.78, true),
            (1, .relaxation, 20, 62, 52, 0.85, true),
            (1.5, .focus, 25, 68, 45, 0.72, true),
            (2, .sleep, 30, 58, 55, 0.81, true),
            (3, .focus, 45, 67, 47, 0.76, true),
            (4, .energize, 15, 78, 38, 0.69, true),
            (5, .relaxation, 15, 64, 50, 0.83, true),
            (7, .focus, 25, 70, 44, 0.71, true),
            (10, .sleep, 45, 56, 58, 0.88, true),
            (13, .focus, 25, 72, 42, 0.65, false)
        ]

        for s in sessions {
            let start = now.addingTimeInterval(-day * s.daysAgo)
            let duration = s.durationMin * 60

            context.insert(FocusSession(
                startDate: start,
                endDate: start.addingTimeInterval(TimeInterval(duration)),
                mode: s.mode.rawValue,
                durationSeconds: duration,
                averageHeartRate: s.hr,
                averageHRV: s.hrv,
                minHeartRate: s.hr - 8,
                maxHeartRate: s.hr + 12,
                beatFrequencyStart: s.mode.defaultBeatFrequency,
                beatFrequencyEnd: s.mode.defaultBeatFrequency * 0.8,
                carrierFrequency: s.mode.defaultCarrierFrequency,
                ambientBedID: "rain",
                melodicLayerIDs: ["focus_gentle_piano_01"],
                wasCompleted: s.completed,
                thumbsRating: s.completed ? 1 : nil,
                checkInMood: 0.6,
                checkInGoal: s.mode.rawValue,
                biometricSuccessScore: s.score
            ))
        }
    }
}
