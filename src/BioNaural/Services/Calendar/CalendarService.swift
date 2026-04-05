// CalendarService.swift
// BioNaural
//
// EventKit implementation of CalendarServiceProtocol.
// Creates a dedicated "BioNaural" calendar for session tracking.
// Reads the user's existing calendars to suggest free windows.
// All EventKit calls are dispatched to a background queue.

import EventKit
import Foundation
import BioNauralShared
import OSLog

// MARK: - CalendarService

@MainActor
public final class CalendarService: CalendarServiceProtocol {

    // MARK: - Properties

    private let store = EKEventStore()
    private static let logger = Logger(subsystem: "com.bionaural", category: "Calendar")

    /// Name of the dedicated BioNaural calendar.
    private static let calendarTitle = "BioNaural"

    // MARK: - Authorization

    public var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    public func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            Self.logger.error("Calendar access denied: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Read Events

    public func todaysEvents() async -> [CalendarEvent] {
        guard isAuthorized else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            Self.logger.error("Failed to compute end of day")
            return []
        }

        return fetchEvents(from: startOfDay, to: endOfDay)
    }

    public func events(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        return fetchEvents(from: startDate, to: endDate)
    }

    public func nextFreeWindow(minimumMinutes: Int) async -> DateInterval? {
        guard isAuthorized else { return nil }

        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            Self.logger.error("Failed to compute end of day for free window search")
            return nil
        }

        let events = fetchEvents(from: now, to: endOfDay)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        // Check gap between now and first event
        if let first = events.first {
            let gapMinutes = Int(first.startDate.timeIntervalSince(now) / 60)
            if gapMinutes >= minimumMinutes {
                return DateInterval(
                    start: now,
                    end: now.addingTimeInterval(TimeInterval(minimumMinutes * 60))
                )
            }
        } else {
            // No events — entire rest of day is free
            return DateInterval(
                start: now,
                end: now.addingTimeInterval(TimeInterval(minimumMinutes * 60))
            )
        }

        // Check gaps between consecutive events
        for i in 0..<(events.count - 1) {
            let gapStart = events[i].endDate
            let gapEnd = events[i + 1].startDate
            let gapMinutes = Int(gapEnd.timeIntervalSince(gapStart) / 60)

            if gapMinutes >= minimumMinutes {
                return DateInterval(
                    start: gapStart,
                    end: gapStart.addingTimeInterval(TimeInterval(minimumMinutes * 60))
                )
            }
        }

        // Check gap after last event
        if let last = events.last {
            let gapMinutes = Int(endOfDay.timeIntervalSince(last.endDate) / 60)
            if gapMinutes >= minimumMinutes {
                return DateInterval(
                    start: last.endDate,
                    end: last.endDate.addingTimeInterval(TimeInterval(minimumMinutes * 60))
                )
            }
        }

        return nil
    }

    // MARK: - Write Sessions

    public func logSession(
        mode: FocusMode,
        startDate: Date,
        duration: TimeInterval,
        outcome: String?
    ) async throws {
        guard isAuthorized else { return }

        let bioCalendar = try findOrCreateBioNauralCalendar()
        let event = EKEvent(eventStore: store)

        event.title = "\(mode.displayName) Session"
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = bioCalendar
        event.availability = .busy

        // Add session details as notes
        var notes = "BioNaural \(mode.displayName) session"
        notes += "\nDuration: \(Int(duration / 60)) minutes"
        if let outcome {
            notes += "\n\(outcome)"
        }
        event.notes = notes

        try store.save(event, span: .thisEvent)
        Self.logger.info("Session logged to calendar: \(mode.displayName) \(Int(duration / 60))min")
    }

    // MARK: - Session History

    public func sessionHistory(days: Int) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            Self.logger.error("Failed to compute start date for session history")
            return []
        }

        return fetchEvents(from: startDate, to: endDate)
            .filter { $0.isBioNauralSession }
    }

    // MARK: - Private

    private func fetchEvents(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        return store.events(matching: predicate)
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    isBioNauralSession: event.calendar.title == Self.calendarTitle
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Finds the existing "BioNaural" calendar or creates one.
    private func findOrCreateBioNauralCalendar() throws -> EKCalendar {
        // Check if it already exists
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == Self.calendarTitle }) {
            return existing
        }

        // Create a new local calendar
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle

        // Use the default local source (iCloud or local)
        if let source = store.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            calendar.source = store.sources.first
        }

        // Set the calendar color to periwinkle
        calendar.cgColor = Theme.Colors.accentCGColor

        try store.saveCalendar(calendar, commit: true)
        Self.logger.info("Created BioNaural calendar")

        return calendar
    }
}
