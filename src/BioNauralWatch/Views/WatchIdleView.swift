// WatchIdleView.swift
// BioNauralWatch
//
// Main idle screen for the Watch app. Replaces the old WatchMainView idle
// state and WatchModeSelectionView. Shows a smart suggestion with learning
// indicator, start button, quick-mode row, and today summary. All visual
// values sourced from WatchDesign tokens — no hardcoded numbers.

import SwiftUI
import WatchKit
import BioNauralShared

// MARK: - WatchIdleView

struct WatchIdleView: View {

    // MARK: - Environment & State

    @Environment(WatchSessionManager.self) private var sessionManager
    @State private var profile = WatchLearningProfile.load()
    @State private var showDurationPicker = false
    @State private var durationPickerMode: FocusMode = .focus
    @State private var selectedDuration: Int = WatchDesign.Layout.durationPickerDefault

    private let suggestionEngine = WatchSuggestionEngine()

    // MARK: - Computed Suggestion

    private var suggestion: WatchSuggestion {
        suggestionEngine.computeSuggestion(
            profile: profile,
            currentHR: sessionManager.currentHeartRate,
            restingHR: nil,
            recentSleepHours: nil
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: WatchDesign.Layout.sectionSpacing) {
                // Suggestion card — carousel card style with wave in upper portion
                suggestionCard

                // Quick-start row
                quickModeSection

                // Today summary / streak
                todaySummaryText

                // Last session card (if exists and no session today)
                if let summary = sessionManager.lastSessionSummary,
                   !isSessionToday(summary.endDate) {
                    lastSessionCard(summary)
                }
            }
            .padding(.horizontal, WatchDesign.Layout.horizontalPadding)
        }
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
        }
        .alert(
            "Low Battery",
            isPresented: .init(
                get: { sessionManager.showBatteryWarning },
                set: { if !$0 { sessionManager.dismissBatteryWarning() } }
            )
        ) {
            if sessionManager.pendingSessionMode != nil {
                Button("Start Anyway") {
                    sessionManager.confirmBatteryWarning()
                }
                Button("Cancel", role: .cancel) {
                    sessionManager.dismissBatteryWarning()
                }
            } else {
                Button("OK", role: .cancel) {
                    sessionManager.dismissBatteryWarning()
                }
            }
        } message: {
            Text(sessionManager.batteryWarningMessage)
        }
    }

    // MARK: - Suggestion Card (Carousel Card Style)

    /// The main suggestion area styled like an iPhone carousel card:
    /// wave section in the upper portion, content overlay below,
    /// mode-colored gradient wash bleeding from top-left.
    private var suggestionCard: some View {
        ZStack(alignment: .leading) {
            // Card background — linear gradient wash
            RoundedRectangle(cornerRadius: WatchDesign.Card.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: suggestion.mode.watchColor.opacity(WatchDesign.Card.gradientStartOpacity), location: 0.0),
                            .init(color: WatchDesign.Colors.surface.opacity(WatchDesign.Card.gradientMidOpacity), location: 0.45),
                            .init(color: WatchDesign.Colors.canvas, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WatchDesign.Card.cornerRadius, style: .continuous)
                        .strokeBorder(
                            suggestion.mode.watchColor.opacity(WatchDesign.Opacity.dividerThin),
                            lineWidth: 1
                        )
                )

            // Left accent stripe — mode color fading to transparent
            LinearGradient(
                colors: [
                    suggestion.mode.watchColor.opacity(WatchDesign.Card.gradientStartOpacity * 2),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: WatchDesign.Card.accentStripeWidth)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: WatchDesign.Card.cornerRadius,
                    bottomLeadingRadius: WatchDesign.Card.cornerRadius
                )
            )

            // Content overlay
            VStack(spacing: WatchDesign.Spacing.sm) {
                // Wave section (upper portion of card)
                WatchWavelengthView(
                    biometricState: suggestion.currentHRState ?? .calm,
                    sessionMode: suggestion.mode,
                    beatFrequency: 0, // Static mode-locked cycles for idle
                    isPlaying: true
                )
                .frame(height: WatchDesign.Wavelength.height)

                // Learning indicator
                WatchLearningIndicator(profile: profile)

                // Suggestion title
                Text(suggestion.title)
                    .font(.system(size: titleFontSize))
                    .fontWeight(.medium)
                    .foregroundStyle(WatchDesign.Colors.textPrimary)

                // Context text
                Text(suggestion.contextText)
                    .font(.system(size: WatchDesign.Typography.contextSize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)
                    .lineSpacing(WatchDesign.Typography.contextSize * 0.4)
                    .multilineTextAlignment(.center)

                // Biometric pill (confident + HR available)
                if profile.learningStage == .confident,
                   let hr = suggestion.currentHR,
                   let state = suggestion.currentHRState {
                    WatchBiometricPill(heartRate: hr, state: state)
                }

                // Start button
                startButton
            }
            .padding(.horizontal, WatchDesign.Spacing.md)
            .padding(.vertical, WatchDesign.Spacing.lg)
        }
        .shadow(
            color: suggestion.mode.watchColor.opacity(WatchDesign.Card.ambientGlowOpacity),
            radius: WatchDesign.Layout.suggestionGlowBlur,
            y: WatchDesign.Spacing.md
        )
    }

    // MARK: - Title Font Size

    private var titleFontSize: CGFloat {
        switch profile.learningStage {
        case .coldStart, .learning:
            return WatchDesign.Typography.suggestionTitleSize
        case .confident:
            return WatchDesign.Typography.confidentTitleSize
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            let duration: Int? = profile.learningStage == .confident
                ? suggestion.durationMinutes
                : nil
            sessionManager.startSession(
                mode: suggestion.mode,
                durationMinutes: duration
            )
        } label: {
            Text(startButtonLabel)
                .font(.system(size: WatchDesign.Typography.startButtonSize))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, WatchDesign.Layout.startButtonVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: WatchDesign.Layout.startButtonCornerRadius)
                        .fill(suggestion.mode.watchColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(suggestion.mode.displayName) session")
        .accessibilityHint("Starts a \(suggestion.mode.displayName) session")
    }

    private var startButtonLabel: String {
        if profile.learningStage == .confident, let duration = suggestion.durationMinutes {
            return "Start \(suggestion.mode.displayName) \u{00b7} \(duration)m"
        }
        return "Start \(suggestion.mode.displayName)"
    }

    // MARK: - Quick-Mode Section

    private var quickModeSection: some View {
        VStack(spacing: WatchDesign.Layout.innerSpacing) {
            // Thin divider
            Rectangle()
                .fill(WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.dividerThin))
                .frame(height: 1)
                .accessibilityHidden(true)

            HStack(spacing: WatchDesign.Layout.quickModeGap) {
                ForEach(FocusMode.allCases) { mode in
                    quickModeIcon(for: mode)
                }
            }
        }
    }

    private func quickModeIcon(for mode: FocusMode) -> some View {
        VStack {
            Image(systemName: mode.watchIconName)
                .font(.system(size: WatchDesign.Layout.quickModeIconFontSize))
                .foregroundStyle(mode.watchColor)
                .frame(
                    width: WatchDesign.Layout.quickModeIconSize,
                    height: WatchDesign.Layout.quickModeIconSize
                )
                .background(
                    RoundedRectangle(cornerRadius: WatchDesign.Layout.quickModeCornerRadius)
                        .fill(mode.watchColor.opacity(WatchDesign.Opacity.quickModeBackground))
                )
        }
        .onTapGesture {
            WKInterfaceDevice.current().play(.click)
            sessionManager.startSession(mode: mode, durationMinutes: nil)
        }
        .onLongPressGesture {
            WKInterfaceDevice.current().play(.click)
            durationPickerMode = mode
            selectedDuration = WatchDesign.Layout.durationPickerDefault
            showDurationPicker = true
        }
        .accessibilityLabel("\(mode.displayName) mode")
        .accessibilityHint("Tap to start. Long press for duration.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Today Summary

    @ViewBuilder
    private var todaySummaryText: some View {
        let todayCount = todaySessionCount
        let todayMins = todaySessionMinutes

        switch profile.learningStage {
        case .coldStart, .learning:
            if todayCount > 0 {
                Text("\(todayCount) session\(todayCount == 1 ? "" : "s") \u{00b7} \(todayMins) min today")
                    .font(.system(size: WatchDesign.Typography.todaySummarySize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

        case .confident:
            let weeklyHours = formattedWeeklyHours
            if profile.streakDays > 0 {
                Text("\(profile.streakDays)-day streak \u{00b7} \(weeklyHours) this week")
                    .font(.system(size: WatchDesign.Typography.todaySummarySize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Last Session Card

    private func lastSessionCard(_ summary: WatchSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: WatchDesign.Layout.innerSpacing) {
            Text("Last Session")
                .font(.caption2)
                .foregroundStyle(WatchDesign.Colors.textSecondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: summary.mode.watchIconName)
                    .foregroundStyle(summary.mode.watchColor)
                    .accessibilityHidden(true)

                Text(summary.mode.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(WatchDesign.Colors.textPrimary)

                Spacer()

                Text(summary.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(WatchDesign.Colors.textPrimary)
            }

            Text(summary.formattedTimeAgo)
                .font(.caption2)
                .foregroundStyle(WatchDesign.Colors.textTertiary)
        }
        .padding(WatchDesign.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: WatchDesign.Layout.cardCornerRadius)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last session: \(summary.mode.displayName), \(summary.formattedDuration), \(summary.formattedTimeAgo)")
    }

    // MARK: - Duration Picker Sheet

    private var durationPickerSheet: some View {
        VStack(spacing: WatchDesign.Layout.sectionSpacing) {
            Text("\(durationPickerMode.displayName) Duration")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(durationPickerMode.watchColor)

            Picker("Minutes", selection: $selectedDuration) {
                ForEach(
                    stride(
                        from: WatchDesign.Layout.durationPickerMin,
                        through: WatchDesign.Layout.durationPickerMax,
                        by: WatchDesign.Layout.durationPickerStep
                    ).map { $0 },
                    id: \.self
                ) { minutes in
                    Text("\(minutes) min")
                        .tag(minutes)
                }
            }
            #if os(watchOS)
            .pickerStyle(.wheel)
            #endif
            .labelsHidden()
            .accessibilityLabel("Session duration")
            .accessibilityHint("Selects the session length in minutes")

            Button {
                showDurationPicker = false
                sessionManager.startSession(
                    mode: durationPickerMode,
                    durationMinutes: selectedDuration
                )
            } label: {
                Text("Start")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(durationPickerMode.watchColor)
            .accessibilityLabel("Start \(durationPickerMode.displayName) session")
            .accessibilityHint("Begins a \(selectedDuration) minute \(durationPickerMode.displayName) session")
        }
        .padding(.horizontal, WatchDesign.Layout.horizontalPadding)
    }

    // MARK: - Helpers

    /// Returns the number of sessions recorded today.
    private var todaySessionCount: Int {
        guard let lastDate = profile.lastSessionDate,
              Calendar.current.isDateInToday(lastDate) else {
            return 0
        }
        // The profile tracks sessions by hour; count today's hours that have entries.
        // Since we don't have a per-day breakdown, use the last session date as a
        // rough proxy: if the last session was today, at minimum 1 session happened.
        // A more precise count would require per-day tracking on the profile.
        let currentHour = Calendar.current.component(.hour, from: Date())
        var count = 0
        for hour in 0...currentHour {
            count += profile.sessionsByHourOfDay[hour] ?? 0
        }
        return max(count, 1)
    }

    /// Returns the total minutes of sessions today (approximation from weekly tracking).
    private var todaySessionMinutes: Int {
        guard let lastDate = profile.lastSessionDate,
              Calendar.current.isDateInToday(lastDate) else {
            return 0
        }
        // Approximate from the average durations across all modes used today.
        let avgSeconds = profile.averageDurationByMode.values.reduce(0, +)
            / max(Double(profile.averageDurationByMode.count), 1)
        return max(Int(avgSeconds / 60.0) * todaySessionCount, 1)
    }

    /// Formats weekly minutes as hours with one decimal place.
    private var formattedWeeklyHours: String {
        let hours = profile.weeklyMinutes / 60.0
        return String(format: "%.1fh", hours)
    }

    /// Returns true if the given date is today.
    private func isSessionToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
