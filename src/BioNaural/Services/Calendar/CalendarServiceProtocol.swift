// CalendarServiceProtocol.swift
// BioNaural
//
// Protocol for Apple Calendar (EventKit) integration.
// Reads upcoming events to suggest optimal session times,
// writes completed sessions as calendar events for tracking.

import Foundation
import BioNauralShared

// MARK: - CalendarServiceProtocol

/// Contract for calendar integration.
/// Implementations read user events to inform session timing and
/// write session records for personal tracking.
@MainActor
public protocol CalendarServiceProtocol: AnyObject, Sendable {

    /// Whether the user has granted calendar access.
    var isAuthorized: Bool { get }

    /// Request calendar access from the user.
    func requestAccess() async -> Bool

    /// Fetch today's events to identify free time windows for sessions.
    /// Returns events sorted by start time.
    func todaysEvents() async -> [CalendarEvent]

    /// Fetch events for a date range (for the Health view timeline).
    func events(from startDate: Date, to endDate: Date) async -> [CalendarEvent]

    /// Find the next free time window of at least `minimumMinutes` duration.
    /// Returns nil if no suitable window exists today.
    func nextFreeWindow(minimumMinutes: Int) async -> DateInterval?

    /// Write a completed BioNaural session to the calendar.
    /// Creates a non-editable event in a dedicated "BioNaural" calendar.
    func logSession(
        mode: FocusMode,
        startDate: Date,
        duration: TimeInterval,
        outcome: String?
    ) async throws

    /// Fetch BioNaural session events from the dedicated calendar.
    func sessionHistory(days: Int) async -> [CalendarEvent]
}

// MARK: - CalendarEvent

/// Lightweight representation of a calendar event.
public struct CalendarEvent: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let isBioNauralSession: Bool

    /// Duration in minutes.
    public var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}
