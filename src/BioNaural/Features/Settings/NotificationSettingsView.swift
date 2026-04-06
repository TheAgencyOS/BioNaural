// NotificationSettingsView.swift
// BioNaural
//
// Form-based settings subpage for granular notification control.
// All values from Theme tokens, all persistence via @AppStorage.

import SwiftUI

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {

    // MARK: - Notification Preferences

    @AppStorage("notification_morning_brief") private var morningBriefEnabled = true
    @AppStorage("notification_morning_brief_time") private var morningBriefTime: Double = Self.defaultMorningTime
    @AppStorage("notification_pre_event") private var preEventEnabled = true
    @AppStorage("notification_pre_event_minutes") private var preEventMinutes = 90
    @AppStorage("notification_study_reminders") private var studyRemindersEnabled = true
    @AppStorage("notification_weekly_insight") private var weeklyInsightEnabled = true
    @AppStorage("notification_monthly_summary") private var monthlySummaryEnabled = true
    @AppStorage("notification_quiet_mode") private var quietModeEnabled = false

    // MARK: - Pre-Event Minute Options

    private static let preEventOptions = [60, 90, 120]

    // MARK: - Default Morning Time (8:00 AM as TimeInterval since reference date)

    private static var defaultMorningTime: Double {
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        return (Calendar.current.date(from: components) ?? Date()).timeIntervalSinceReferenceDate
    }

    // MARK: - Morning Brief Time Binding

    private var morningBriefDate: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: morningBriefTime) },
            set: { morningBriefTime = $0.timeIntervalSinceReferenceDate }
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            morningBriefSection
            eventPreparationSection
            studyRemindersSection
            insightsSection
            quietModeSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .font(Theme.Typography.body)
        .foregroundStyle(Theme.Colors.textPrimary)
    }

    // MARK: - Morning Brief Section

    private var morningBriefSection: some View {
        Section {
            Toggle(
                "Daily Morning Brief",
                isOn: $morningBriefEnabled
            )
            .accessibilityLabel("Enable daily morning brief notification")

            if morningBriefEnabled {
                DatePicker(
                    "Delivery Time",
                    selection: morningBriefDate,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Morning brief delivery time")
            }

            Text("A personalized daily prescription based on your sleep, biometrics, and calendar.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        } header: {
            Text("Morning Brief")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Event Preparation Section

    private var eventPreparationSection: some View {
        Section {
            Toggle(
                "Pre-Event Sessions",
                isOn: $preEventEnabled
            )
            .accessibilityLabel("Enable pre-event session notifications")

            if preEventEnabled {
                Picker("Notify Before", selection: $preEventMinutes) {
                    ForEach(Self.preEventOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .accessibilityLabel("Minutes before event to notify")
                .accessibilityValue("\(preEventMinutes) minutes")
            }

            Text("Get a ready-made session before high-stress calendar events.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        } header: {
            Text("Event Preparation")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Study Reminders Section

    private var studyRemindersSection: some View {
        Section {
            Toggle(
                "Flow State Reminders",
                isOn: $studyRemindersEnabled
            )
            .accessibilityLabel("Enable Flow State reminder notifications")

            Text("Daily reminders during active Flow State periods.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        } header: {
            Text("Study Reminders")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        Section {
            Toggle(
                "Weekly Insight",
                isOn: $weeklyInsightEnabled
            )
            .accessibilityLabel("Enable weekly insight notification")

            Toggle(
                "Monthly Summary",
                isOn: $monthlySummaryEnabled
            )
            .accessibilityLabel("Enable monthly summary notification")
        } header: {
            Text("Insights")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Quiet Mode Section

    private var quietModeSection: some View {
        Section {
            Toggle(
                "Quiet Mode",
                isOn: $quietModeEnabled
            )
            .accessibilityLabel("Enable quiet mode to silence all notifications")

            Text("Silences all BioNaural notifications. Individual settings are preserved.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        } header: {
            Text("Quiet Mode")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("NotificationSettingsView") {
    NavigationStack {
        NotificationSettingsView()
    }
    .preferredColorScheme(.dark)
}
