// Date+Formatting.swift
// BioNaural
//
// Date formatting extensions for session history, timestamps, and relative
// time display. All formatters are cached as statics to avoid repeated
// allocation on the hot path (table views, lists).

import Foundation

// MARK: - Relative Time

extension Date {

    /// Relative description: "Just now", "2 hours ago", "Yesterday", "3 days ago".
    ///
    /// Uses `RelativeDateTimeFormatter` for locale-aware output. Falls back to
    /// the session date format for dates older than one week.
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        // Under 60 seconds — avoid "0 seconds ago"
        if interval < 60 {
            return "Just now"
        }

        // Within the last week — use the relative formatter
        if isThisWeek {
            return Self.relativeFormatter.localizedString(for: self, relativeTo: now)
        }

        // Older than a week — fall back to absolute date
        return sessionDate
    }
}

// MARK: - Absolute Formats

extension Date {

    /// Session header format: "Mon, Apr 3 at 9:15 AM".
    ///
    /// Uses a fixed template so the output is consistent regardless of locale
    /// calendar preferences, while still respecting 12/24-hour settings.
    var sessionDate: String {
        Self.sessionDateFormatter.string(from: self)
    }

    /// Short time-only format: "9:15 AM".
    var shortTime: String {
        Self.shortTimeFormatter.string(from: self)
    }
}

// MARK: - Calendar Queries

extension Date {

    /// Whether this date falls within the current calendar day.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Whether this date falls within yesterday's calendar day.
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Whether this date falls within the current calendar week.
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

// MARK: - Cached Formatters

private extension Date {

    /// Relative formatter cached for the lifetime of the process.
    nonisolated(unsafe) static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "Mon, Apr 3 at 9:15 AM" — day-of-week, abbreviated month, day, time.
    static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d 'at' h:mm a")
        return formatter
    }()

    /// "9:15 AM" — time only, respects user's 12/24-hour preference.
    static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
