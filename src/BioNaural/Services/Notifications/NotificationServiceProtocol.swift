import Foundation
import BioNauralShared

// MARK: - NotificationServiceProtocol

/// Contract for scheduling and managing local notifications across BioNaural.
///
/// All implementations must be `Sendable` so they can be safely shared across
/// concurrency domains. The concrete ``NotificationService`` is `@MainActor`;
/// the ``MockNotificationService`` is unconstrained for fast unit testing.
public protocol NotificationServiceProtocol: AnyObject, Sendable {

    // MARK: - Authorization

    /// Whether the user has granted notification permissions.
    var isAuthorized: Bool { get }

    /// Requests notification authorization from the system.
    ///
    /// - Returns: `true` if the user granted (or had already granted) permission.
    func requestAuthorization() async -> Bool

    // MARK: - Scheduling

    /// Schedules a morning brief notification at the specified delivery time.
    ///
    /// - Parameters:
    ///   - deliveryTime: The `Date` whose hour/minute components define the trigger.
    ///   - title: Notification title (e.g. "Good morning, Eric").
    ///   - body: Notification body text.
    ///   - briefData: Optional encoded payload attached via `userInfo` for deep linking.
    func scheduleMorningBrief(
        at deliveryTime: Date,
        title: String,
        body: String,
        briefData: Data?
    ) async

    /// Schedules a pre-event preparation notification ahead of a calendar event.
    ///
    /// The notification fires `minutesBefore` minutes prior to `eventDate`,
    /// suggesting the user start a session in the given ``FocusMode``.
    ///
    /// - Parameters:
    ///   - eventTitle: The calendar event's title.
    ///   - sessionMode: The recommended ``FocusMode`` for the prep session.
    ///   - minutesBefore: Lead time in minutes before the event.
    ///   - eventDate: The event's start date.
    func schedulePreEventPrep(
        eventTitle: String,
        sessionMode: FocusMode,
        minutesBefore: Int,
        eventDate: Date
    ) async

    /// Schedules a daily repeating Flow State reminder.
    ///
    /// - Parameters:
    ///   - trackName: The name of the Flow State or session type.
    ///   - time: The `Date` whose hour/minute components define the daily trigger.
    func scheduleStudyReminder(trackName: String, at time: Date) async

    /// Schedules a weekly insight notification on a specific day and hour.
    ///
    /// - Parameters:
    ///   - dayOfWeek: Calendar day (1 = Sunday … 7 = Saturday).
    ///   - hour: Hour component (0–23).
    ///   - title: Notification title.
    ///   - body: Notification body text.
    func scheduleWeeklyInsight(
        dayOfWeek: Int,
        hour: Int,
        title: String,
        body: String
    ) async

    // MARK: - Cancellation

    /// Cancels all pending and delivered notifications managed by BioNaural.
    func cancelAllPending() async

    /// Cancels pending and delivered notifications whose identifier starts with `prefix`.
    ///
    /// - Parameter prefix: The identifier prefix to match against.
    func cancelNotifications(withIdentifier prefix: String) async

    // MARK: - Inspection

    /// Returns the number of currently pending notification requests.
    func pendingCount() async -> Int
}
