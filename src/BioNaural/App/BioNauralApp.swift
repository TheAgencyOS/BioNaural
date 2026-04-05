// BioNauralApp.swift
// BioNaural
//
// @main entry point. Creates the dependency container, configures the
// SwiftData model container, and sets dark mode as the default appearance.

import SwiftUI
import SwiftData

@main
struct BioNauralApp: App {

    // MARK: - Dependencies

    /// The single dependency container for the entire app lifecycle.
    /// Created once at launch and injected into the environment.
    @State private var dependencies = AppDependencies()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dependencies)
                .modelContainer(dependencies.modelContainer)
                .preferredColorScheme(.dark)
                .task {
                    // Seed demo content on first launch (dev only)
                    let context = dependencies.modelContainer.mainContext
                    DemoContentSeeder.seedIfNeeded(in: context)

                    // Register background tasks on first launch
                    dependencies.backgroundTaskService.registerTasks()
                    dependencies.backgroundTaskService.scheduleMorningBrief(
                        deliveryHour: BackgroundTaskConfig.defaultBriefHour,
                        deliveryMinute: BackgroundTaskConfig.defaultBriefMinute
                    )
                    dependencies.backgroundTaskService.schedulePatternLearning()
                    dependencies.backgroundTaskService.scheduleDailyCleanup()

                    // Request notification authorization
                    _ = await dependencies.notificationService.requestAuthorization()
                }
        }
    }
}
