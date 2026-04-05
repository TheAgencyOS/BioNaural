// MockCalendarService.swift
// BioNaural
//
// Mock implementation of CalendarServiceProtocol for tests and previews.
// Returns empty data and no-ops for all operations.

import Foundation
import BioNauralShared

// MARK: - MockCalendarService

public final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {

    public var isAuthorized: Bool = false

    public func requestAccess() async -> Bool { false }

    public func todaysEvents() async -> [CalendarEvent] { [] }

    public func events(from startDate: Date, to endDate: Date) async -> [CalendarEvent] { [] }

    public func nextFreeWindow(minimumMinutes: Int) async -> DateInterval? { nil }

    public func logSession(
        mode: FocusMode,
        startDate: Date,
        duration: TimeInterval,
        outcome: String?
    ) async throws {}

    public func sessionHistory(days: Int) async -> [CalendarEvent] { [] }
}
