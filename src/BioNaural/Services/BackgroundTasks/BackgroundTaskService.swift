// BackgroundTaskService.swift
// BioNaural
//
// Manages BGTaskScheduler for morning brief generation,
// pattern learning, and daily cleanup tasks.
//
// Info.plist requirement:
// BGTaskSchedulerPermittedIdentifiers: [
//     "com.bionaural.morningbrief",
//     "com.bionaural.patternlearning",
//     "com.bionaural.dailycleanup"
// ]

import BackgroundTasks
import Foundation
import OSLog

// MARK: - BackgroundTaskConfig

public enum BackgroundTaskConfig {
    public static let morningBriefTaskID = "com.bionaural.morningbrief"
    public static let patternLearningTaskID = "com.bionaural.patternlearning"
    public static let dailyCleanupTaskID = "com.bionaural.dailycleanup"

    /// Default morning brief generation time (5:30 AM, before most users wake)
    public static let defaultBriefHour: Int = 5
    public static let defaultBriefMinute: Int = 30

    /// Pattern learning runs once daily
    public static let patternLearningIntervalSeconds: TimeInterval = 86400

    /// Cleanup interval (archive expired context tracks, etc.)
    public static let cleanupIntervalSeconds: TimeInterval = 86400
}

// MARK: - Protocol

/// Scheduling interface for recurring background tasks (morning brief,
/// pattern learning, daily cleanup).
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
@MainActor
public protocol BackgroundTaskServiceProtocol: AnyObject, Sendable {

    /// Register all background task identifiers. Call from app init.
    func registerTasks()

    /// Schedule the morning brief generation task.
    func scheduleMorningBrief(deliveryHour: Int, deliveryMinute: Int)

    /// Schedule the daily pattern learning task.
    func schedulePatternLearning()

    /// Schedule daily cleanup (archive expired context tracks, etc.)
    func scheduleDailyCleanup()

    /// Cancel all scheduled background tasks.
    func cancelAll()
}

// MARK: - BackgroundTaskService

/// Manages `BGTaskScheduler` registration and scheduling for recurring
/// background work: morning brief generation, calendar pattern learning,
/// and daily cleanup (e.g., archiving expired context tracks).
///
/// Call ``registerTasks()`` from the app's init phase, then schedule
/// individual tasks as needed. Each handler re-schedules its next
/// occurrence automatically to maintain a repeating cadence.
@MainActor
public final class BackgroundTaskService: BackgroundTaskServiceProtocol {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "com.bionaural", category: "BackgroundTasks")

    /// Closures called when background tasks fire. Set by the app layer.
    public var onMorningBriefTask: (() async -> Void)?
    public var onPatternLearningTask: (() async -> Void)?
    public var onCleanupTask: (() async -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - Registration

    /// Register all background task identifiers. Call from app init.
    public func registerTasks() {
        Self.logger.info("Registering background task identifiers")

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConfig.morningBriefTaskID,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.logger.info("Morning brief task started")
            self?.handleMorningBriefTask(task)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConfig.patternLearningTaskID,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            Self.logger.info("Pattern learning task started")
            self?.handlePatternLearningTask(task)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskConfig.dailyCleanupTaskID,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            Self.logger.info("Daily cleanup task started")
            self?.handleCleanupTask(task)
        }

        Self.logger.info("All background task identifiers registered")
    }

    // MARK: - Scheduling

    /// Schedule the morning brief generation task.
    /// - Parameters:
    ///   - deliveryHour: Hour (0-23) to generate the brief
    ///   - deliveryMinute: Minute (0-59)
    public func scheduleMorningBrief(
        deliveryHour: Int = BackgroundTaskConfig.defaultBriefHour,
        deliveryMinute: Int = BackgroundTaskConfig.defaultBriefMinute
    ) {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskConfig.morningBriefTaskID
        )
        request.earliestBeginDate = nextDate(hour: deliveryHour, minute: deliveryMinute)

        submitRequest(request, label: "morning brief")
    }

    /// Schedule the daily pattern learning task.
    public func schedulePatternLearning() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskConfig.patternLearningTaskID
        )
        request.earliestBeginDate = Date(
            timeIntervalSinceNow: BackgroundTaskConfig.patternLearningIntervalSeconds
        )
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        submitRequest(request, label: "pattern learning")
    }

    /// Schedule daily cleanup (archive expired context tracks, etc.)
    public func scheduleDailyCleanup() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskConfig.dailyCleanupTaskID
        )
        request.earliestBeginDate = Date(
            timeIntervalSinceNow: BackgroundTaskConfig.cleanupIntervalSeconds
        )
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        submitRequest(request, label: "daily cleanup")
    }

    /// Cancel all scheduled background tasks.
    public func cancelAll() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        Self.logger.info("All background tasks cancelled")
    }

    // MARK: - Task Handlers

    private func handleMorningBriefTask(_ task: BGAppRefreshTask) {
        // Schedule next occurrence so the task repeats
        scheduleMorningBrief()

        let workTask = Task {
            await onMorningBriefTask?()
            task.setTaskCompleted(success: true)
            Self.logger.info("Morning brief task completed successfully")
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
            Self.logger.warning("Morning brief task expired before completion")
        }
    }

    private func handlePatternLearningTask(_ task: BGProcessingTask) {
        // Schedule next occurrence so the task repeats
        schedulePatternLearning()

        let workTask = Task {
            await onPatternLearningTask?()
            task.setTaskCompleted(success: true)
            Self.logger.info("Pattern learning task completed successfully")
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
            Self.logger.warning("Pattern learning task expired before completion")
        }
    }

    private func handleCleanupTask(_ task: BGProcessingTask) {
        // Schedule next occurrence so the task repeats
        scheduleDailyCleanup()

        let workTask = Task {
            await onCleanupTask?()
            task.setTaskCompleted(success: true)
            Self.logger.info("Daily cleanup task completed successfully")
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
            Self.logger.warning("Daily cleanup task expired before completion")
        }
    }

    // MARK: - Helpers

    /// Compute the next `Date` for a given hour and minute.
    /// If the time has already passed today, returns tomorrow at that time.
    private func nextDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let candidate = calendar.date(from: components) else {
            Self.logger.error("Failed to compute next date for \(hour):\(minute), falling back to tomorrow")
            return Date(timeIntervalSinceNow: BackgroundTaskConfig.patternLearningIntervalSeconds)
        }

        // If the candidate is in the past (already passed today), advance to tomorrow
        if candidate <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                Self.logger.error("Failed to advance date to tomorrow, falling back to 24h interval")
                return Date(timeIntervalSinceNow: BackgroundTaskConfig.patternLearningIntervalSeconds)
            }
            Self.logger.debug("Morning brief scheduled for tomorrow at \(hour):\(minute)")
            return tomorrow
        }

        Self.logger.debug("Morning brief scheduled for today at \(hour):\(minute)")
        return candidate
    }

    /// Submit a task request with standardized error logging.
    private func submitRequest(_ request: BGTaskRequest, label: String) {
        do {
            try BGTaskScheduler.shared.submit(request)
            Self.logger.info("Scheduled \(label) task: \(request.identifier)")
        } catch BGTaskScheduler.Error.notPermitted {
            Self.logger.error("Not permitted to schedule \(label) task — check BGTaskSchedulerPermittedIdentifiers in Info.plist")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            Self.logger.error("Too many pending task requests when scheduling \(label) task")
        } catch BGTaskScheduler.Error.unavailable {
            Self.logger.error("Background task scheduling unavailable for \(label) task")
        } catch {
            Self.logger.error("Failed to schedule \(label) task: \(error.localizedDescription)")
        }
    }
}
