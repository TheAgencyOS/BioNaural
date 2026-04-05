// MockCalendarPatternLearner.swift
// BioNaural
//
// Mock implementation of CalendarPatternLearnerProtocol for previews,
// tests, and the initial app launch before enough session data exists
// for real pattern discovery.

import Foundation
import BioNauralShared

// MARK: - MockCalendarPatternLearner

public actor MockCalendarPatternLearner: CalendarPatternLearnerProtocol {

    public init() {}

    public func analyzePatterns() async -> [CalendarPattern] {
        []
    }

    public func bestPrepAction(
        for eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) async -> (mode: FocusMode, minutesBefore: Int, durationMinutes: Int)? {
        nil
    }

    public func suggestedRecoveryAfter(
        eventTitle: String,
        existingPatterns: [CalendarPattern]
    ) async -> (mode: FocusMode, durationMinutes: Int)? {
        nil
    }
}
