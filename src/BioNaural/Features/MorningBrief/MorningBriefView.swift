// MorningBriefView.swift
// BioNaural
//
// Full-screen morning brief that surfaces personalized health context,
// calendar stressors, and a session prescription. Shown on app open or
// when the user taps the morning brief notification.

import SwiftUI
import BioNauralShared

// MARK: - MorningBriefView

struct MorningBriefView: View {

    let brief: MorningBrief
    let onStartSession: (FocusMode, Int) -> Void
    let onDismiss: () -> Void

    // MARK: - Animation State

    @State private var sectionsVisible: [Bool] = Array(repeating: false, count: 5)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived

    private var modeColor: Color {
        Color.modeColor(for: brief.suggestedMode)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                greetingSection
                    .sectionAppearance(index: 0, visible: sectionsVisible[0])

                healthContextCard
                    .sectionAppearance(index: 1, visible: sectionsVisible[1])

                if !brief.upcomingStressors.isEmpty {
                    calendarContextCard
                        .sectionAppearance(index: 2, visible: sectionsVisible[2])
                }

                prescriptionCard
                    .sectionAppearance(index: 3, visible: sectionsVisible[3])

                startButton
                    .sectionAppearance(index: 4, visible: sectionsVisible[4])
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxxl)
            .padding(.bottom, Theme.Spacing.mega)
        }
        .background(Theme.Colors.canvas)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .accessibilityLabel("Dismiss morning brief")
            }
        }
        .onAppear {
            staggerEntrance()
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(brief.greeting)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            if let dayPattern = brief.dayOfWeekPattern {
                Text(dayPattern)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Health Context Card

    private var healthContextCard: some View {
        HStack(spacing: Theme.Spacing.xs) {
            sleepMetric
            Spacer(minLength: 0)
            hrMetric
            Spacer(minLength: 0)
            hrvMetric
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var sleepMetric: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "moon.fill")
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(Theme.Colors.sleep)

            if let hours = brief.sleepHours {
                Text(String(format: "%.1f", hours))
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textPrimary)
            } else {
                Text("--")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Text(brief.sleepQuality?.capitalized ?? "Sleep")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var hrMetric: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "heart.fill")
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(hrColor)

            Text(hrDeltaLabel)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("HR")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var hrvMetric: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(Theme.Colors.accent)

            Text(hrvTrendArrow)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("HRV")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - HR Helpers

    private var hrColor: Color {
        guard let delta = brief.restingHRDelta else {
            return Theme.Colors.textTertiary
        }
        return delta > 0 ? Theme.Colors.signalElevated : Theme.Colors.signalCalm
    }

    private var hrDeltaLabel: String {
        guard let delta = brief.restingHRDelta else { return "\u{2014}" }
        let rounded = Int(delta.rounded())
        if rounded > 0 {
            return "\u{2191}\(rounded)"
        } else if rounded < 0 {
            return "\u{2193}\(abs(rounded))"
        } else {
            return "\u{2014}"
        }
    }

    private var hrvTrendArrow: String {
        switch brief.hrvTrend {
        case "rising":    return "\u{2191}"
        case "declining": return "\u{2193}"
        case "stable":    return "\u{2192}"
        default:          return "\u{2014}"
        }
    }

    // MARK: - Calendar Context Card

    private var calendarContextCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Upcoming")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(Theme.Typography.Tracking.uppercase)

            ForEach(Array(brief.upcomingStressors.prefix(3))) { stressor in
                stressorRow(stressor)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func stressorRow(_ stressor: BriefStressor) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(stressorColor(for: stressor.stressLevel))
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)

            Text(stressor.eventTitle)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if stressor.prepReady {
                Text("Track ready")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(
                        Theme.Colors.accent.opacity(Theme.Opacity.light),
                        in: Capsule()
                    )
            }

            Text(stressorTimeLabel(stressor.startDate))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func stressorColor(for level: String) -> Color {
        switch level {
        case StressLevel.critical.rawValue: return Theme.Colors.signalPeak
        case StressLevel.high.rawValue:     return Theme.Colors.signalElevated
        case StressLevel.moderate.rawValue: return Theme.Colors.accent
        default:                            return Theme.Colors.textTertiary
        }
    }

    private func stressorTimeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Prescription Card (Hero)

    private var prescriptionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Mode icon + name
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: brief.suggestedMode.systemImageName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(modeColor)

                Text(brief.suggestedMode.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(modeColor)
            }

            // Duration
            Text("\(brief.suggestedDurationMinutes) min")
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)

            // Ambient suggestion
            if let ambientTag = brief.suggestedAmbientTag {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(ambientTag.capitalized)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            // Prescription body text
            Text(brief.bodyText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Colors.accent.opacity(Theme.Opacity.subtle),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            onStartSession(brief.suggestedMode, brief.suggestedDurationMinutes)
        } label: {
            Text("Start Session")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
        }
        .buttonStyle(.borderedProminent)
        .tint(modeColor)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .accessibilityLabel("Start \(brief.suggestedMode.displayName) session for \(brief.suggestedDurationMinutes) minutes")
    }

    // MARK: - Entrance Animation

    private func staggerEntrance() {
        if reduceMotion {
            for index in sectionsVisible.indices {
                sectionsVisible[index] = true
            }
        } else {
            for index in sectionsVisible.indices {
                withAnimation(Theme.Animation.staggeredFadeIn(index: index)) {
                    sectionsVisible[index] = true
                }
            }
        }
    }
}

// MARK: - Section Appearance Modifier

private extension View {

    /// Applies a staggered fade-and-slide entrance to each brief section.
    func sectionAppearance(index: Int, visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : Theme.Spacing.xl)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Morning Brief") {
    NavigationStack {
        MorningBriefView(
            brief: .preview,
            onStartSession: { _, _ in },
            onDismiss: {}
        )
    }
}

extension MorningBrief {

    static var preview: MorningBrief {
        MorningBrief(
            id: UUID(),
            generatedAt: Date(),
            sleepHours: 7.2,
            sleepQuality: "good",
            restingHRDelta: 3,
            hrvTrend: "rising",
            upcomingStressors: [
                BriefStressor(
                    id: "1",
                    eventTitle: "Q2 Planning Review",
                    startDate: Date().addingTimeInterval(3600),
                    stressLevel: "high",
                    prepReady: true
                ),
                BriefStressor(
                    id: "2",
                    eventTitle: "1:1 with Manager",
                    startDate: Date().addingTimeInterval(7200),
                    stressLevel: "moderate",
                    prepReady: false
                )
            ],
            meetingCount: 5,
            firstFreeWindow: DateInterval(
                start: Date().addingTimeInterval(10800),
                duration: 3600
            ),
            suggestedMode: .focus,
            suggestedDurationMinutes: 20,
            suggestedAmbientTag: "rain",
            suggestedCarrierFrequency: 350,
            contextTrackID: nil,
            greeting: "Good morning, Eric.",
            bodyText: "Solid sleep at 7.2 hrs, HRV trending up. 5 meetings today. Save deep work for the 11:00 AM gap. You're primed for a long Focus session.",
            prescriptionText: "Focus for 20 min with rain",
            confidence: 0.82,
            dayOfWeekPattern: "Midweek energy dip is common. Prioritize your best block."
        )
    }
}
#endif
