// SessionDetailView.swift
// BioNaural
//
// Full detail view for a completed session. Shows duration hero,
// metrics grid, adaptation map, sound selections, check-in data,
// biometric success score, and share button.
// All values from Theme tokens. Native SwiftUI throughout.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SessionDetailView

struct SessionDetailView: View {

    // MARK: - Input

    let session: FocusSession

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var contentAppeared = false

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                durationHero
                metricsGrid
                adaptationMapSection
                soundSelectionsSection
                checkInSection
                biometricScoreSection
                shareSection
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .background(atmosphericBackground)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !reduceMotion else {
                contentAppeared = true
                return
            }
            withAnimation(Theme.Animation.standard) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [
                    modeColor(for: session.focusMode).opacity(Theme.Opacity.canvasRadialWash),
                    Color.clear
                ],
                center: .top,
                startRadius: .zero,
                endRadius: Theme.Spacing.mega * Theme.Spacing.xxs
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Duration Hero

    private var durationHero: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(formattedDuration(session.durationSeconds))
                .font(Theme.Typography.timer)
                .foregroundStyle(Theme.Colors.textPrimary)
                .tracking(Theme.Typography.Tracking.data)

            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(modeColor(for: session.focusMode).opacity(Theme.Opacity.accentLight))
                        .frame(
                            width: Theme.Spacing.xxl,
                            height: Theme.Spacing.xxl
                        )

                    Image(systemName: session.focusMode?.systemImageName ?? "waveform.path")
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(modeColor(for: session.focusMode))
                }

                Text(session.focusMode?.displayName ?? session.mode.capitalized)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if let endDate = session.endDate {
                Text(
                    Self.dateFormatter.string(from: session.startDate)
                    + " \u{2013} "
                    + Self.timeFormatter.string(from: endDate)
                )
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            } else {
                Text(Self.dateFormatter.string(from: session.startDate))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            // Completion badge
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(Theme.Typography.caption)
                Text(session.wasCompleted ? "Completed" : "Ended early")
                    .font(Theme.Typography.caption)
            }
            .foregroundStyle(session.wasCompleted ? Theme.Colors.signalCalm : Theme.Colors.signalElevated)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                Capsule()
                    .fill(
                        (session.wasCompleted ? Theme.Colors.signalCalm : Theme.Colors.signalElevated)
                            .opacity(Theme.Opacity.light)
                    )
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var heroAccessibilityLabel: String {
        let mode = session.focusMode?.displayName ?? session.mode.capitalized
        let status = session.wasCompleted ? "Completed" : "Ended early"
        return "\(mode) session, \(formattedDuration(session.durationSeconds)), \(status)"
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: Theme.Spacing.md),
            GridItem(.flexible(), spacing: Theme.Spacing.md)
        ]

        return LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            if let avgHR = session.averageHeartRate {
                metricCard(
                    label: "Avg HR",
                    value: "\(Int(avgHR))",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: Theme.Colors.signalCalm,
                    index: 0
                )
            }

            if let avgHRV = session.averageHRV {
                metricCard(
                    label: "Avg HRV",
                    value: "\(Int(avgHRV))",
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: Theme.Colors.signalFocus,
                    index: 1
                )
            }

            metricCard(
                label: "Adaptations",
                value: "\(session.adaptationEvents.count)",
                unit: "changes",
                icon: "arrow.triangle.branch",
                color: Theme.Colors.accent,
                index: 2
            )

            if let peakDuration = longestAdaptationInterval(session) {
                metricCard(
                    label: "Peak Duration",
                    value: formattedMinutesSeconds(peakDuration),
                    unit: "",
                    icon: "timer",
                    color: Theme.Colors.signalElevated,
                    index: 3
                )
            }

            if let peakHR = session.maxHeartRate {
                metricCard(
                    label: "Peak HR",
                    value: "\(Int(peakHR))",
                    unit: "BPM",
                    icon: "arrow.up.heart.fill",
                    color: Theme.Colors.signalPeak,
                    index: 4
                )
            }

            metricCard(
                label: "Beat Freq",
                value: String(format: "%.1f \u{2192} %.1f",
                              session.beatFrequencyStart,
                              session.beatFrequencyEnd),
                unit: "Hz",
                icon: "waveform",
                color: modeColor(for: session.focusMode),
                index: 5
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session metrics")
    }

    private func metricCard(
        label: String,
        value: String,
        unit: String,
        icon: String,
        color: Color,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(color)

                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(value)
                .font(Theme.Typography.data)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !unit.isEmpty {
                Text(unit)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
        .staggeredFadeIn(index: index, isVisible: contentAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value) \(unit)")
    }

    // MARK: - Adaptation Map

    @ViewBuilder
    private var adaptationMapSection: some View {
        if let mode = session.focusMode, !session.adaptationEvents.isEmpty {
            sectionContainer(title: "Adaptation Map", icon: "chart.xyaxis.line") {
                AdaptationMapView(
                    events: session.adaptationEvents,
                    sessionDuration: session.duration,
                    mode: mode
                )
                .frame(height: adaptationMapHeight)
            }
        }
    }

    private var adaptationMapHeight: CGFloat { Theme.Spacing.mega * 3 }

    // MARK: - Sound Selections

    @ViewBuilder
    private var soundSelectionsSection: some View {
        let hasAmbient = session.ambientBedID != nil
        let hasMelodic = !session.melodicLayerIDs.isEmpty

        if hasAmbient || hasMelodic {
            sectionContainer(title: "Sounds", icon: "music.note.list") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if let ambientID = session.ambientBedID {
                        soundRow(
                            label: "Ambient",
                            value: formatSoundID(ambientID),
                            icon: "cloud.rain.fill"
                        )
                    }

                    if !session.melodicLayerIDs.isEmpty {
                        ForEach(session.melodicLayerIDs, id: \.self) { layerID in
                            soundRow(
                                label: "Melodic",
                                value: formatSoundID(layerID),
                                icon: "music.quarternote.3"
                            )
                        }
                    }
                }
            }
        }
    }

    private func soundRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Colors.accent.opacity(Theme.Opacity.light))
                    .frame(
                        width: Theme.Spacing.xxxl,
                        height: Theme.Spacing.xxxl
                    )

                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(Theme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(label)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text(value)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Check-In Data

    @ViewBuilder
    private var checkInSection: some View {
        let hasMood = session.checkInMood != nil
        let hasGoal = session.checkInGoal != nil

        if hasMood || hasGoal {
            sectionContainer(title: "Check-In", icon: "person.text.rectangle") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let mood = session.checkInMood {
                        checkInRow(
                            label: "Mood",
                            value: moodDescription(mood),
                            detail: String(format: "%.0f%%", mood * 100)
                        )
                    }

                    if let goalRaw = session.checkInGoal,
                       let goal = FocusMode(rawValue: goalRaw) {
                        checkInRow(
                            label: "Goal",
                            value: goal.displayName,
                            detail: nil
                        )
                    }
                }
            }
        }
    }

    private func checkInRow(label: String, value: String, detail: String?) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            if let detail {
                Text(detail)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Biometric Success Score

    @ViewBuilder
    private var biometricScoreSection: some View {
        if let score = session.biometricSuccessScore {
            sectionContainer(title: "Biometric Score", icon: "chart.bar.fill") {
                HStack(spacing: Theme.Spacing.lg) {
                    // Score ring
                    ZStack {
                        Circle()
                            .stroke(
                                Theme.Colors.divider,
                                lineWidth: scoreRingStrokeWidth
                            )

                        Circle()
                            .trim(from: .zero, to: score)
                            .stroke(
                                scoreColor(score),
                                style: StrokeStyle(
                                    lineWidth: scoreRingStrokeWidth,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(score * 100))")
                            .font(Theme.Typography.data)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .frame(
                        width: scoreRingSize,
                        height: scoreRingSize
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(scoreLabel(score))
                            .font(Theme.Typography.headline)
                            .foregroundStyle(scoreColor(score))

                        Text(scoreDescription(score))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                    }
                }
            }

            // Thumbs rating
            if let rating = session.thumbsRating {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: rating > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(rating > 0 ? Theme.Colors.signalCalm : Theme.Colors.signalPeak)

                    Text(rating > 0 ? "You liked this session" : "This session could be better")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(rating > 0 ? "Rated thumbs up" : "Rated thumbs down")
            }

            // Feedback tags
            if let tags = session.feedbackTags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.Colors.surfaceRaised)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                            lineWidth: Theme.Radius.glassStroke
                                        )
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var scoreRingSize: CGFloat { Theme.Spacing.mega }
    private var scoreRingStrokeWidth: CGFloat { Theme.Spacing.xs }

    // MARK: - Share Button

    private var shareSection: some View {
        ShareLink(
            item: adaptationShareText(session),
            subject: Text("BioNaural Session"),
            message: Text(adaptationShareText(session))
        ) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Session")
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.accent.opacity(Theme.Opacity.accentLight))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .strokeBorder(
                        Theme.Colors.accent.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .accessibilityLabel("Share session summary")
    }

    // MARK: - Section Container

    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(Theme.Colors.accent)

                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func formattedDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formattedMinutesSeconds(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func modeColor(for mode: FocusMode?) -> Color {
        switch mode {
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        case .none:        return Theme.Colors.accent
        }
    }

    private func longestAdaptationInterval(_ session: FocusSession) -> TimeInterval? {
        let events = session.adaptationEvents
        guard events.count >= 2 else { return nil }
        var maxInterval: TimeInterval = 0
        for i in 1..<events.count {
            let interval = events[i].timestamp - events[i - 1].timestamp
            maxInterval = max(maxInterval, interval)
        }
        return maxInterval > 0 ? maxInterval : nil
    }

    private func formatSoundID(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func moodDescription(_ mood: Double) -> String {
        switch mood {
        case 0..<0.25:    return "Wired / Anxious"
        case 0.25..<0.50: return "Slightly Tense"
        case 0.50..<0.75: return "Balanced"
        default:          return "Calm / Tired"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<0.3:  return Theme.Colors.signalPeak
        case 0.3..<0.6: return Theme.Colors.signalElevated
        case 0.6..<0.8: return Theme.Colors.signalFocus
        default:        return Theme.Colors.signalCalm
        }
    }

    private func scoreLabel(_ score: Double) -> String {
        switch score {
        case 0..<0.3:  return "Developing"
        case 0.3..<0.6: return "Progressing"
        case 0.6..<0.8: return "Strong"
        default:        return "Excellent"
        }
    }

    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 0..<0.3:
            return "Your biometrics showed limited response this session. Keep experimenting with different times and durations."
        case 0.3..<0.6:
            return "Moderate biometric improvement detected. Your body is starting to respond to the audio."
        case 0.6..<0.8:
            return "Strong biometric response. The adaptive algorithm found a good rhythm for you."
        default:
            return "Excellent session. Your heart rate and HRV responded exceptionally well to the adaptive audio."
        }
    }

    private func adaptationShareText(_ session: FocusSession) -> String {
        let mode = session.focusMode?.displayName ?? session.mode.capitalized
        let duration = formattedDuration(session.durationSeconds)
        let adaptations = session.adaptationEvents.count
        let beatRange = String(
            format: "%.1f \u{2192} %.1f Hz",
            session.beatFrequencyStart,
            session.beatFrequencyEnd
        )
        return """
        BioNaural \(mode) Session
        Duration: \(duration)
        Adaptations: \(adaptations)
        Beat Frequency: \(beatRange)
        """
    }
}

// MARK: - Preview

#Preview("Session Detail") {
    NavigationStack {
        SessionDetailView(session: FocusSession(
            startDate: Date().addingTimeInterval(-3600),
            mode: FocusMode.focus.rawValue,
            durationSeconds: 1500,
            averageHeartRate: 68,
            averageHRV: 45,
            minHeartRate: 58,
            maxHeartRate: 82,
            beatFrequencyStart: 14,
            beatFrequencyEnd: 12,
            carrierFrequency: 375,
            adaptationEvents: [
                AdaptationEventRecord(
                    timestamp: 60,
                    reason: "HR elevated",
                    oldBeatFrequency: 14,
                    newBeatFrequency: 13,
                    heartRateAtTime: 75
                ),
                AdaptationEventRecord(
                    timestamp: 300,
                    reason: "HR stabilized",
                    oldBeatFrequency: 13,
                    newBeatFrequency: 12,
                    heartRateAtTime: 68
                )
            ],
            ambientBedID: "rain_gentle",
            melodicLayerIDs: ["pad_warm", "piano_soft"],
            wasCompleted: true,
            thumbsRating: 1,
            feedbackTags: ["relaxing", "good focus"],
            checkInMood: 0.3,
            checkInGoal: FocusMode.focus.rawValue,
            biometricSuccessScore: 0.78
        ))
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: FocusSession.self, inMemory: true)
}
