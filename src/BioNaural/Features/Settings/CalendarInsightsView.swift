// CalendarInsightsView.swift
// BioNaural
//
// Transparency screen showing what BioNaural has learned from the user's
// calendar. Reads CalendarPatternStore from SwiftData, displays pattern
// cards or an empty state, and provides a destructive clear-all action.
// All values from Theme tokens.

import SwiftUI
import SwiftData
import OSLog
import BioNauralShared

// MARK: - CalendarInsightsView

struct CalendarInsightsView: View {

    // MARK: - Data

    @Query private var stores: [CalendarPatternStore]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Local State

    @State private var showClearConfirmation = false

    // MARK: - Convenience

    private var patterns: [CalendarPattern] {
        stores.first?.toPatterns() ?? []
    }

    // MARK: - Body

    var body: some View {
        List {
            if patterns.isEmpty {
                emptyStateSection
            } else {
                patternsSection
            }
            privacySection
            if !patterns.isEmpty {
                clearSection
            }
        }
        .navigationTitle("Calendar Insights")
        .navigationBarTitleDisplayMode(.large)
        .font(Theme.Typography.body)
        .foregroundStyle(Theme.Colors.textPrimary)
        .alert("Clear All Patterns", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) { clearAllPatterns() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all learned calendar patterns. BioNaural will start learning again from scratch.")
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: Theme.Spacing.jumbo))
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text("BioNaural is still learning your patterns. After a few weeks of sessions, insights will appear here.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxxl)
            .accessibilityLabel("No calendar patterns discovered yet")
        }
    }

    // MARK: - Patterns Section

    private var patternsSection: some View {
        Section {
            ForEach(patterns) { pattern in
                patternCard(for: pattern)
            }
        } header: {
            Text("Discovered Patterns")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Pattern Card

    private func patternCard(for pattern: CalendarPattern) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            patternIcon(for: pattern)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(patternTitle(for: pattern))
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    Text("Based on \(pattern.sampleCount) sessions")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    strengthIndicator(for: pattern.strength)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patternTitle(for: pattern)). Based on \(pattern.sampleCount) sessions. Strength: \(strengthLabel(for: pattern.strength)).")
    }

    // MARK: - Pattern Icon

    private func patternIcon(for pattern: CalendarPattern) -> some View {
        let (color, symbol) = iconAttributes(for: pattern)
        return Circle()
            .fill(color.opacity(Theme.Opacity.dim))
            .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
            .overlay(
                Image(systemName: symbol)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(color)
            )
    }

    // MARK: - Strength Indicator

    private func strengthIndicator(for strength: Double) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        Double(index) / 3.0 < strength
                            ? Theme.Colors.accent
                            : Theme.Colors.accent.opacity(Theme.Opacity.light)
                    )
                    .frame(width: Theme.Spacing.xs, height: Theme.Spacing.xs)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            Label {
                Text("All calendar analysis happens on your device. No event data ever leaves your iPhone.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .accessibilityLabel("Privacy: All calendar analysis happens on your device. No event data ever leaves your iPhone.")
        } header: {
            Text("Privacy")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Clear Section

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Patterns", systemImage: "trash")
            }
            .accessibilityLabel("Delete all learned calendar patterns")
        }
    }

    // MARK: - Helpers

    /// Produces a human-readable title from a pattern's condition and observation.
    private func patternTitle(for pattern: CalendarPattern) -> String {
        let condition = pattern.condition
            .replacingOccurrences(of: "events_with_", with: "")
            .replacingOccurrences(of: "high_density_day_", with: "Busy day (")
            .replacingOccurrences(of: "_plus", with: "+ events)")
            .replacingOccurrences(of: "heavy_morning_meetings", with: "Heavy morning meetings")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let observation = pattern.observation
            .replacingOccurrences(of: "hr_spikes_", with: "HR spikes ")
            .replacingOccurrences(of: "bpm_before", with: " BPM before")
            .replacingOccurrences(of: "lower_session_scores_after", with: "Lower scores after")
            .replacingOccurrences(of: "best_mode_", with: "Best mode: ")
            .replacingOccurrences(of: "best_evening_mode_", with: "Best evening mode: ")
            .replacingOccurrences(of: "poor_sleep_before", with: "Poor sleep before")
            .replacingOccurrences(of: "afternoon_focus_degraded", with: "Afternoon focus drops")
            .replacingOccurrences(of: "_", with: " ")

        return "\(condition) \u{2014} \(observation)"
    }

    /// Returns the mode color and SF Symbol for a pattern's observation.
    private func iconAttributes(for pattern: CalendarPattern) -> (Color, String) {
        let observation = pattern.observation

        if observation.contains("hr_spike") {
            return (Theme.Colors.signalPeak, "heart.fill")
        }
        if observation.contains("best_mode_focus") || observation.contains("afternoon_focus") {
            return (Theme.Colors.focus, FocusMode.focus.systemImageName)
        }
        if observation.contains("best_mode_relaxation") || observation.contains("lower_session_scores") {
            return (Theme.Colors.relaxation, FocusMode.relaxation.systemImageName)
        }
        if observation.contains("best_mode_sleep") || observation.contains("poor_sleep") {
            return (Theme.Colors.sleep, FocusMode.sleep.systemImageName)
        }
        if observation.contains("best_mode_energize") || observation.contains("best_evening_mode_energize") {
            return (Theme.Colors.energize, FocusMode.energize.systemImageName)
        }
        if observation.contains("best_evening_mode") {
            return (Theme.Colors.relaxation, "moon.stars")
        }

        // Default fallback
        return (Theme.Colors.accent, "chart.bar.xaxis")
    }

    /// Returns a human-readable strength label for accessibility.
    private func strengthLabel(for strength: Double) -> String {
        switch strength {
        case 0..<0.4: return "weak"
        case 0.4..<0.7: return "moderate"
        default: return "strong"
        }
    }

    /// Deletes all stored patterns from SwiftData.
    private func clearAllPatterns() {
        guard let store = stores.first else { return }
        do {
            try store.update(patterns: [])
            try modelContext.save()
        } catch {
            Logger.contextTracks.error(
                "Failed to clear calendar patterns: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Preview

#Preview("Calendar Insights - Empty") {
    NavigationStack {
        CalendarInsightsView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Calendar Insights - With Patterns") {
    NavigationStack {
        CalendarInsightsView()
    }
    .preferredColorScheme(.dark)
}
