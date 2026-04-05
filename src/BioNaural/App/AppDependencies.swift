// AppDependencies.swift
// BioNaural
//
// Dependency injection container. Holds all service instances used across
// the app. Injected into the SwiftUI environment as an @Observable object
// so any view can pull dependencies via @Environment(AppDependencies.self).

import Foundation
import SwiftUI
import Observation
import SwiftData
import BioNauralShared

// MARK: - Supporting Types

/// A circadian-aware mode suggestion for the current time of day.
public struct CircadianSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let suggestedMode: FocusMode
    public let reason: String

    public init(
        id: UUID = UUID(),
        suggestedMode: FocusMode,
        reason: String
    ) {
        self.id = id
        self.suggestedMode = suggestedMode
        self.reason = reason
    }
}

/// A proactive insight card derived from the user model.
public struct ProactiveInsight: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public let iconName: String

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        iconName: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.iconName = iconName
    }
}

// MARK: - AppDependencies

@Observable
final class AppDependencies {

    // MARK: - Services

    let audioEngine: any AudioEngineProtocol
    let healthKitService: any HealthKitServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let headMotionService: any HeadMotionServiceProtocol
    @ObservationIgnored let hapticService: HapticService
    let notificationService: any NotificationServiceProtocol
    let backgroundTaskService: BackgroundTaskService
    let calendarClassifier: CalendarEventClassifier
    let calendarPatternLearner: any CalendarPatternLearnerProtocol
    let contextTrackManager: ContextTrackManager
    let spotlightIndexer: any SpotlightIndexerProtocol
    let journalService: any JournalSuggestionServiceProtocol
    let weatherService: any WeatherServiceProtocol

    // MARK: - Watch Status

    /// Whether the Apple Watch is currently connected and reachable.
    var isWatchConnected: Bool = false

    // MARK: - Active Session State (for mini player)

    /// The focus mode of the currently playing session. `nil` when no session is active.
    var activeSessionMode: FocusMode?

    /// Elapsed seconds of the active session. Updated by the session timer.
    var activeSessionElapsed: TimeInterval = 0

    // MARK: - Persistence

    let modelContainer: ModelContainer

    // MARK: - Production Init

    /// Creates the dependency container with concrete production implementations.
    /// Called from the @main app entry point.
    @MainActor
    init() {
        let schema = Schema([
            FocusSession.self,
            UserProfile.self,
            SoundProfile.self,
            CustomComposition.self,
            SonicMemory.self,
            SoundDNASample.self,
            ContextTrack.self,
            SavedTrack.self,
            CalendarPatternStore.self,
            UserBehavioralPatternsModel.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("[AppDependencies] Failed to create ModelContainer: \(error)")
        }

        let mainContext = ModelContext(modelContainer)

        self.audioEngine = AudioEngine()
        self.healthKitService = HealthKitService()
        self.calendarService = CalendarService()
        self.headMotionService = HeadMotionService()
        self.hapticService = HapticService()
        self.notificationService = NotificationService()
        self.backgroundTaskService = BackgroundTaskService()
        self.calendarClassifier = CalendarEventClassifier()
        // Real pattern learner backed by SwiftData session outcomes.
        let sessionOutcomeStore = SessionOutcomeStore(modelContext: mainContext)
        self.calendarPatternLearner = CalendarPatternLearner(
            sessionStore: sessionOutcomeStore,
            calendarService: self.calendarService,
            healthKitService: self.healthKitService
        )
        self.contextTrackManager = ContextTrackManager(modelContext: mainContext)
        self.spotlightIndexer = SpotlightIndexer()
        self.journalService = JournalSuggestionServiceFactory.create()
        self.weatherService = LiveWeatherService()
    }

    // MARK: - Test Init

    /// Creates the dependency container with injected mock implementations.
    /// Used exclusively in unit tests and SwiftUI previews.
    @MainActor
    init(
        audioEngine: any AudioEngineProtocol,
        healthKitService: any HealthKitServiceProtocol,
        calendarService: any CalendarServiceProtocol = MockCalendarService(),
        headMotionService: any HeadMotionServiceProtocol = MockHeadMotionService(),
        hapticService: HapticService = HapticService(),
        notificationService: any NotificationServiceProtocol = MockNotificationService(),
        inMemoryPersistence: Bool = true
    ) {
        self.audioEngine = audioEngine
        self.healthKitService = healthKitService
        self.calendarService = calendarService
        self.headMotionService = headMotionService
        self.hapticService = hapticService
        self.notificationService = notificationService
        self.backgroundTaskService = BackgroundTaskService()
        self.calendarClassifier = CalendarEventClassifier()

        let schema = Schema([
            FocusSession.self,
            UserProfile.self,
            SoundProfile.self,
            CustomComposition.self,
            SonicMemory.self,
            SoundDNASample.self,
            ContextTrack.self,
            SavedTrack.self,
            CalendarPatternStore.self,
            UserBehavioralPatternsModel.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemoryPersistence
        )
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("[AppDependencies] Failed to create test ModelContainer: \(error)")
        }

        let testContext = ModelContext(modelContainer)
        self.calendarPatternLearner = MockCalendarPatternLearner()
        self.contextTrackManager = ContextTrackManager(modelContext: testContext)
        self.spotlightIndexer = MockSpotlightIndexer()
        self.journalService = MockJournalSuggestionService()
        self.weatherService = MockWeatherService()
    }
}
