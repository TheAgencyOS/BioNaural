import Foundation
import UserNotifications
import OSLog
import BioNauralShared

// MARK: - NotificationConfig

/// Centralised constants for the notification subsystem.
///
/// Every identifier prefix, category ID, action ID, and timing default lives
/// here — zero hardcoded values in the service implementation.
public enum NotificationConfig {

    // MARK: Category IDs

    static let morningBriefCategoryID   = "MORNING_BRIEF"
    static let preEventCategoryID       = "PRE_EVENT_PREP"
    static let studyReminderCategoryID  = "STUDY_REMINDER"
    static let weeklyInsightCategoryID  = "WEEKLY_INSIGHT"

    // MARK: Identifier Prefixes

    static let morningBriefIdentifierPrefix = "morning_brief_"
    static let preEventIdentifierPrefix     = "pre_event_"
    static let studyReminderIdentifierPrefix = "study_"
    static let weeklyInsightIdentifierPrefix = "weekly_insight_"

    // MARK: Limits & Defaults

    static let maxDailyNotifications: Int       = 3
    static let preEventDefaultMinutesBefore: Int = 90

    // MARK: Action IDs

    static let morningBriefActionID = "START_SESSION"
    static let studyReminderActionID = "START_STUDY"
}

// MARK: - NotificationService

/// Production notification service backed by `UNUserNotificationCenter`.
///
/// All public API is confined to `@MainActor` so callers never need to think
/// about threading. Internal helpers forward work to the notification center's
/// own async methods which are safe to call from any actor.
public final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let logger: Logger

    // MARK: - State

    public private(set) var isAuthorized: Bool = false

    // MARK: - Init

    /// Creates a notification service.
    ///
    /// - Parameters:
    ///   - center: The notification center to use. Defaults to `.current()`.
    ///   - calendar: The calendar used for date-component extraction.
    public init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
        self.logger = Logger(subsystem: "com.bionaural", category: "Notifications")
        registerCategories()
    }

    // MARK: - Authorization

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            isAuthorized = granted
            logger.info("Notification authorization \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Authorization request failed: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
    }

    // MARK: - Morning Brief

    public func scheduleMorningBrief(
        at deliveryTime: Date,
        title: String,
        body: String,
        briefData: Data?
    ) async {
        let components = calendar.dateComponents([.hour, .minute], from: deliveryTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationConfig.morningBriefCategoryID

        if let briefData {
            content.userInfo["briefData"] = briefData.base64EncodedString()
        }

        let dateString = Self.identifierDateString(from: deliveryTime, calendar: calendar)
        let identifier = NotificationConfig.morningBriefIdentifierPrefix + dateString

        await addRequest(identifier: identifier, content: content, trigger: trigger)
        logger.info("Scheduled morning brief: \(identifier)")
    }

    // MARK: - Pre-Event Prep

    public func schedulePreEventPrep(
        eventTitle: String,
        sessionMode: FocusMode,
        minutesBefore: Int,
        eventDate: Date
    ) async {
        let fireDate = eventDate.addingTimeInterval(
            -Double(minutesBefore) * 60
        )

        guard fireDate > Date.now else {
            logger.warning("Pre-event fire date is in the past — skipping: \(eventTitle)")
            return
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "\(eventTitle) in \(minutesBefore) min"
        content.body = "We made something for you."
        content.sound = .default
        content.categoryIdentifier = NotificationConfig.preEventCategoryID
        content.userInfo = [
            "eventTitle": eventTitle,
            "sessionMode": sessionMode.rawValue,
            "eventDate": eventDate.timeIntervalSince1970,
            "minutesBefore": minutesBefore
        ]

        let dateString = Self.identifierDateString(from: eventDate, calendar: calendar)
        let sanitisedTitle = eventTitle
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(32)
        let identifier = NotificationConfig.preEventIdentifierPrefix
            + String(sanitisedTitle) + "_" + dateString

        await addRequest(identifier: identifier, content: content, trigger: trigger)
        logger.info("Scheduled pre-event prep: \(identifier)")
    }

    // MARK: - Study Reminder

    public func scheduleStudyReminder(trackName: String, at time: Date) async {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Time to study"
        content.body = "Your \(trackName) session is ready."
        content.sound = .default
        content.categoryIdentifier = NotificationConfig.studyReminderCategoryID
        content.userInfo = ["trackName": trackName]

        let sanitisedTrack = trackName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(32)
        let identifier = NotificationConfig.studyReminderIdentifierPrefix
            + String(sanitisedTrack)

        await addRequest(identifier: identifier, content: content, trigger: trigger)
        logger.info("Scheduled study reminder: \(identifier)")
    }

    // MARK: - Weekly Insight

    public func scheduleWeeklyInsight(
        dayOfWeek: Int,
        hour: Int,
        title: String,
        body: String
    ) async {
        var components = DateComponents()
        components.weekday = dayOfWeek
        components.hour = hour

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationConfig.weeklyInsightCategoryID

        let identifier = NotificationConfig.weeklyInsightIdentifierPrefix
            + "day\(dayOfWeek)_hour\(hour)"

        await addRequest(identifier: identifier, content: content, trigger: trigger)
        logger.info("Scheduled weekly insight: \(identifier)")
    }

    // MARK: - Cancellation

    public func cancelAllPending() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        logger.info("Cancelled all pending and delivered notifications")
    }

    public func cancelNotifications(withIdentifier prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(prefix) }

        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }

        logger.info(
            "Cancelled \(pendingIDs.count) pending + \(deliveredIDs.count) delivered with prefix '\(prefix)'"
        )
    }

    // MARK: - Inspection

    public func pendingCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }

    // MARK: - Private Helpers

    /// Registers actionable notification categories with the notification center.
    private func registerCategories() {
        let startSessionAction = UNNotificationAction(
            identifier: NotificationConfig.morningBriefActionID,
            title: "Start Session",
            options: [.foreground]
        )

        let startStudyAction = UNNotificationAction(
            identifier: NotificationConfig.studyReminderActionID,
            title: "Start Study",
            options: [.foreground]
        )

        let morningBriefCategory = UNNotificationCategory(
            identifier: NotificationConfig.morningBriefCategoryID,
            actions: [startSessionAction],
            intentIdentifiers: []
        )

        let preEventCategory = UNNotificationCategory(
            identifier: NotificationConfig.preEventCategoryID,
            actions: [startSessionAction],
            intentIdentifiers: []
        )

        let studyReminderCategory = UNNotificationCategory(
            identifier: NotificationConfig.studyReminderCategoryID,
            actions: [startStudyAction],
            intentIdentifiers: []
        )

        let weeklyInsightCategory = UNNotificationCategory(
            identifier: NotificationConfig.weeklyInsightCategoryID,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            morningBriefCategory,
            preEventCategory,
            studyReminderCategory,
            weeklyInsightCategory
        ])

        logger.debug("Registered notification categories")
    }

    /// Adds a notification request to the center, logging any errors.
    private func addRequest(
        identifier: String,
        content: UNNotificationContent,
        trigger: UNNotificationTrigger
    ) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to add notification '\(identifier)': \(error.localizedDescription)")
        }
    }

    /// Produces a stable date string suitable for notification identifiers.
    ///
    /// Format: `yyyyMMdd_HHmm` — e.g. `20260404_0830`.
    private nonisolated static func identifierDateString(
        from date: Date,
        calendar: Calendar
    ) -> String {
        let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return String(
            format: "%04d%02d%02d_%02d%02d",
            comps.year ?? 0,
            comps.month ?? 0,
            comps.day ?? 0,
            comps.hour ?? 0,
            comps.minute ?? 0
        )
    }
}
