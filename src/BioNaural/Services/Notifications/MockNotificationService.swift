import Foundation
import BioNauralShared

// MARK: - MockNotificationService

/// A test double for ``NotificationServiceProtocol`` that records all
/// scheduling calls in-memory without touching `UNUserNotificationCenter`.
///
/// Use this in SwiftUI previews, unit tests, and UI tests to verify
/// notification logic without requiring device permissions.
public final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {

    // MARK: - Recorded Types

    /// A recorded morning brief scheduling call.
    public struct MorningBrief: Equatable, Sendable {
        public let deliveryTime: Date
        public let title: String
        public let body: String
        public let briefData: Data?
    }

    /// A recorded pre-event prep scheduling call.
    public struct PreEventPrep: Equatable, Sendable {
        public let eventTitle: String
        public let sessionMode: FocusMode
        public let minutesBefore: Int
        public let eventDate: Date
    }

    /// A recorded study reminder scheduling call.
    public struct StudyReminder: Equatable, Sendable {
        public let trackName: String
        public let time: Date
    }

    /// A recorded weekly insight scheduling call.
    public struct WeeklyInsight: Equatable, Sendable {
        public let dayOfWeek: Int
        public let hour: Int
        public let title: String
        public let body: String
    }

    // MARK: - State

    public var isAuthorized: Bool
    public var authorizationRequestCount: Int = 0

    // MARK: - Recorded Calls

    public private(set) var scheduledMorningBriefs: [MorningBrief] = []
    public private(set) var scheduledPreEventPreps: [PreEventPrep] = []
    public private(set) var scheduledStudyReminders: [StudyReminder] = []
    public private(set) var scheduledWeeklyInsights: [WeeklyInsight] = []
    public private(set) var cancelAllPendingCallCount: Int = 0
    public private(set) var cancelledPrefixes: [String] = []

    // MARK: - Init

    /// Creates a mock service.
    ///
    /// - Parameter isAuthorized: Initial authorization state. Defaults to `true`
    ///   so tests don't need to call `requestAuthorization()` unless testing that flow.
    public init(isAuthorized: Bool = true) {
        self.isAuthorized = isAuthorized
    }

    // MARK: - Protocol Conformance

    public func requestAuthorization() async -> Bool {
        authorizationRequestCount += 1
        return isAuthorized
    }

    public func scheduleMorningBrief(
        at deliveryTime: Date,
        title: String,
        body: String,
        briefData: Data?
    ) async {
        scheduledMorningBriefs.append(
            MorningBrief(
                deliveryTime: deliveryTime,
                title: title,
                body: body,
                briefData: briefData
            )
        )
    }

    public func schedulePreEventPrep(
        eventTitle: String,
        sessionMode: FocusMode,
        minutesBefore: Int,
        eventDate: Date
    ) async {
        scheduledPreEventPreps.append(
            PreEventPrep(
                eventTitle: eventTitle,
                sessionMode: sessionMode,
                minutesBefore: minutesBefore,
                eventDate: eventDate
            )
        )
    }

    public func scheduleStudyReminder(trackName: String, at time: Date) async {
        scheduledStudyReminders.append(
            StudyReminder(trackName: trackName, time: time)
        )
    }

    public func scheduleWeeklyInsight(
        dayOfWeek: Int,
        hour: Int,
        title: String,
        body: String
    ) async {
        scheduledWeeklyInsights.append(
            WeeklyInsight(
                dayOfWeek: dayOfWeek,
                hour: hour,
                title: title,
                body: body
            )
        )
    }

    public func cancelAllPending() async {
        cancelAllPendingCallCount += 1
        scheduledMorningBriefs.removeAll()
        scheduledPreEventPreps.removeAll()
        scheduledStudyReminders.removeAll()
        scheduledWeeklyInsights.removeAll()
    }

    public func cancelNotifications(withIdentifier prefix: String) async {
        cancelledPrefixes.append(prefix)
    }

    public func pendingCount() async -> Int {
        scheduledMorningBriefs.count
            + scheduledPreEventPreps.count
            + scheduledStudyReminders.count
            + scheduledWeeklyInsights.count
    }

    // MARK: - Test Helpers

    /// Resets all recorded state to initial values.
    public func reset() {
        authorizationRequestCount = 0
        scheduledMorningBriefs.removeAll()
        scheduledPreEventPreps.removeAll()
        scheduledStudyReminders.removeAll()
        scheduledWeeklyInsights.removeAll()
        cancelAllPendingCallCount = 0
        cancelledPrefixes.removeAll()
    }
}
