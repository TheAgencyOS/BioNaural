// MonthlySummaryView.swift
// BioNaural
//
// Monthly Neural Summary — BioNaural's "Wrapped" feature.
// Four swipeable cards showing the user's month in review:
// Overview, Biometric Journey, Sound Profile, and Insight.
// Shareable via ImageRenderer. All values from Theme tokens.

import SwiftUI
import SwiftData
import Charts
import BioNauralShared

// MARK: - MonthlySummaryView

struct MonthlySummaryView: View {

    // MARK: - Input

    let month: Date

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var summary: MonthlySummary?
    @State private var selectedCard: Int = 0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    // MARK: - Constants

    private static let cardCount = 4

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            if let summary {
                if summary.hasEnoughData {
                    fullSummaryContent(summary: summary)
                } else {
                    insufficientDataView(summary: summary)
                }
            } else {
                loadingView
            }
        }
        .task {
            let generator = MonthlySummaryGenerator(modelContext: modelContext)
            summary = generator.generate(for: month)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                SummaryShareSheet(items: [image])
            }
        }
    }

    // MARK: - Full Summary

    @ViewBuilder
    private func fullSummaryContent(summary: MonthlySummary) -> some View {
        VStack(spacing: .zero) {
            summaryHeader(summary: summary)

            TabView(selection: $selectedCard) {
                OverviewCard(summary: summary)
                    .tag(0)
                BiometricJourneyCard(summary: summary)
                    .tag(1)
                SoundProfileCard(summary: summary)
                    .tag(2)
                InsightCard(summary: summary)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageIndicator
                .padding(.bottom, Theme.Spacing.lg)
        }
    }

    // MARK: - Header

    private func summaryHeader(summary: MonthlySummary) -> some View {
        HStack {
            Text(summary.monthDisplayName)
                .font(Theme.Typography.caption)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Button {
                generateShareImage(for: selectedCard, summary: summary)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                    .background(
                        Circle()
                            .fill(Theme.Colors.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share this card")
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<Self.cardCount, id: \.self) { index in
                Circle()
                    .fill(
                        index == selectedCard
                            ? Theme.Colors.accent
                            : Theme.Colors.textTertiary
                    )
                    .frame(
                        width: Theme.Spacing.xs,
                        height: Theme.Spacing.xs
                    )
                    .animation(Theme.Animation.standard, value: selectedCard)
            }
        }
    }

    // MARK: - Insufficient Data

    private func insufficientDataView(summary: MonthlySummary) -> some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: Theme.Spacing.md) {
                Text("Your \(summary.monthDisplayName) Summary")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Not enough data for a full summary. Keep going!")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }

            if summary.totalSessions > 0 {
                HStack(spacing: Theme.Spacing.xxl) {
                    miniStat(
                        value: "\(summary.totalSessions)",
                        label: summary.totalSessions == 1 ? "Session" : "Sessions"
                    )
                    miniStat(
                        value: "\(summary.totalMinutes)",
                        label: "Minutes"
                    )
                }
                .padding(.top, Theme.Spacing.md)
            }

            Text("\(MonthlySummaryConfig.minimumSessionsForFullSummary)+ sessions unlock your full summary")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.data)
                .tracking(Theme.Typography.Tracking.data)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .tint(Theme.Colors.accent)

            Text("Building your summary...")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Share Image Generation

    private func generateShareImage(for cardIndex: Int, summary: MonthlySummary) {
        let content = ShareableSummaryCard(
            cardIndex: cardIndex,
            summary: summary,
            outputSize: ShareableAspectRatio.story.size
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = shareRenderScale
        renderer.proposedSize = ProposedViewSize(ShareableAspectRatio.story.size)
        shareImage = renderer.uiImage
        showShareSheet = shareImage != nil
    }

    private var shareRenderScale: CGFloat { 1.0 }
}

// MARK: - Share Aspect Ratio

private enum ShareableAspectRatio {
    case story
    case landscape

    var size: CGSize {
        switch self {
        case .story:     return CGSize(width: storyWidth, height: storyHeight)
        case .landscape: return CGSize(width: landscapeWidth, height: landscapeHeight)
        }
    }

    private var storyWidth: CGFloat { 1080 }
    private var storyHeight: CGFloat { 1920 }
    private var landscapeWidth: CGFloat { 1920 }
    private var landscapeHeight: CGFloat { 1080 }
}

// MARK: - Card 1: Overview

private struct OverviewCard: View {
    let summary: MonthlySummary

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Your")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(summary.monthDisplayName)
                        .font(Theme.Typography.display)
                        .tracking(Theme.Typography.Tracking.display)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Summary")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.jumbo)

                VStack(spacing: Theme.Spacing.xxl) {
                    heroMetric(
                        value: "\(summary.totalSessions)",
                        label: "Sessions",
                        icon: "waveform.path",
                        color: Theme.Colors.accent
                    )
                    heroMetric(
                        value: formattedTotalTime,
                        label: "Total Time",
                        icon: "clock.fill",
                        color: Theme.Colors.signalCalm
                    )
                }

                if let mode = summary.mostUsedMode {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: mode.systemImageName)
                            .font(.system(size: Theme.Typography.Size.title))
                            .foregroundStyle(modeColor(for: mode))

                        Text("Most used: \(mode.displayName)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("\(summary.mostUsedModeSessionCount) sessions")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(modeColor(for: mode).opacity(Theme.Opacity.subtle))
                    )
                }

                HStack(spacing: Theme.Spacing.md) {
                    statPill(
                        value: String(format: "%.1f", summary.sessionsPerWeekAverage),
                        label: "per week"
                    )
                    statPill(
                        value: "\(Int(summary.completionRate * 100))%",
                        label: "completed"
                    )
                }

                if !summary.modeDistribution.isEmpty {
                    modeDistributionBar
                }

                Spacer(minLength: Theme.Spacing.jumbo)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }

    private func heroMetric(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.headline))
                .foregroundStyle(color)
                .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                .background(
                    Circle()
                        .fill(color.opacity(Theme.Opacity.light))
                )

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.data)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Theme.Colors.surface)
        )
    }

    private var modeDistributionBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Mode Distribution")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            GeometryReader { geometry in
                HStack(spacing: Theme.Spacing.xxs) {
                    ForEach(summary.modeDistribution) { entry in
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(modeColor(for: entry.mode))
                            .frame(width: max(geometry.size.width * entry.fraction - Theme.Spacing.xxs, 0))
                    }
                }
            }
            .frame(height: Theme.Spacing.sm)
            .clipShape(Capsule())

            HStack(spacing: Theme.Spacing.lg) {
                ForEach(summary.modeDistribution) { entry in
                    HStack(spacing: Theme.Spacing.xxs) {
                        Circle()
                            .fill(modeColor(for: entry.mode))
                            .frame(width: Theme.Spacing.xs, height: Theme.Spacing.xs)
                        Text("\(entry.mode.displayName) \(Int(entry.fraction * 100))%")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    private var formattedTotalTime: String {
        let hours = summary.totalMinutes / 60
        let minutes = summary.totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Card 2: Biometric Journey

private struct BiometricJourneyCard: View {
    let summary: MonthlySummary

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Biometric")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Journey")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.top, Theme.Spacing.jumbo)

                if let headline = summary.biometricHeadline {
                    Text(headline)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                if !summary.weeklyHRTrend.isEmpty {
                    biometricChart(
                        title: "Heart Rate Trend",
                        unit: "BPM",
                        data: summary.weeklyHRTrend,
                        color: Theme.Colors.signalPeak
                    )
                }

                if !summary.weeklyHRVTrend.isEmpty {
                    biometricChart(
                        title: "HRV Trend",
                        unit: "ms",
                        data: summary.weeklyHRVTrend,
                        color: Theme.Colors.signalCalm
                    )
                }

                if let best = summary.bestSession {
                    bestSessionCard(best)
                }

                if let avgScore = summary.averageBiometricScore {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(Theme.Colors.accent)

                        Text("Average biometric score: \(Int(avgScore * 100))%")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .padding(.vertical, Theme.Spacing.md)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(Theme.Colors.surface)
                    )
                }

                Spacer(minLength: Theme.Spacing.jumbo)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }

    private func biometricChart(
        title: String,
        unit: String,
        data: [WeeklyBiometricPoint],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()

                if let last = data.last {
                    Text("\(Int(last.value)) \(unit)")
                        .font(Theme.Typography.dataSmall)
                        .tracking(Theme.Typography.Tracking.data)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            Chart(data) { point in
                LineMark(
                    x: .value("Week", point.weekLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: Theme.Wavelength.Stroke.elevated))

                AreaMark(
                    x: .value("Week", point.weekLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            color.opacity(Theme.Opacity.dim),
                            color.opacity(Theme.Opacity.minimal)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                PointMark(
                    x: .value("Week", point.weekLabel),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .symbolSize(Theme.Spacing.md * Theme.Spacing.md)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.Colors.divider)
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(height: chartHeight)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    private var chartHeight: CGFloat { Theme.Spacing.mega * 2 }

    private func bestSessionCard(_ best: BestSessionHighlight) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.Colors.signalElevated)
                Text("Best Session")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(best.mode.displayName)
                        .font(Theme.Typography.body)
                        .foregroundStyle(modeColor(for: best.mode))
                    Text(best.sessionDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                    Text("\(Int(best.biometricScore * 100))%")
                        .font(Theme.Typography.data)
                        .foregroundStyle(Theme.Colors.signalCalm)
                    Text("\(best.durationMinutes)m")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(
                    Theme.Colors.signalElevated.opacity(Theme.Opacity.accentLight),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Card 3: Sound Profile

private struct SoundProfileCard: View {
    let summary: MonthlySummary

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Sound")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Profile")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.top, Theme.Spacing.jumbo)

                Text("What worked for you this month")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                if !summary.topSounds.isEmpty {
                    topSoundsSection
                }

                if !summary.instrumentBreakdown.isEmpty {
                    instrumentBreakdownSection
                }

                if let insight = summary.soundInsight {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.Colors.signalElevated)

                        Text(insight)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                    }
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .fill(Theme.Colors.signalElevated.opacity(Theme.Opacity.subtle))
                    )
                }

                Spacer(minLength: Theme.Spacing.jumbo)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }

    private var topSoundsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Top Sounds")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            ForEach(Array(summary.topSounds.enumerated()), id: \.element.id) { index, sound in
                HStack(spacing: Theme.Spacing.md) {
                    Text("\(index + 1)")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(rankColor(for: index))
                        .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                        .background(
                            Circle()
                                .fill(rankColor(for: index).opacity(Theme.Opacity.light))
                        )

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(formatSoundName(sound.soundID))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("\(sound.sessionCount) session\(sound.sessionCount == 1 ? "" : "s")")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    Spacer()

                    Text("\(Int(sound.averageBiometricScore * 100))%")
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.signalCalm)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    private var instrumentBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Instrument Preference")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            ForEach(summary.instrumentBreakdown) { entry in
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack {
                        Text(entry.instrument)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(entry.fraction * 100))%")
                            .font(Theme.Typography.dataSmall)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(Theme.Colors.divider)
                                .frame(height: barHeight)

                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .fill(instrumentBarColor(for: entry.instrument))
                                .frame(
                                    width: max(geometry.size.width * entry.fraction, 0),
                                    height: barHeight
                                )
                        }
                    }
                    .frame(height: barHeight)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.surface)
        )
    }

    private var barHeight: CGFloat { Theme.Spacing.xs }

    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0:  return Theme.Colors.signalElevated
        case 1:  return Theme.Colors.accent
        default: return Theme.Colors.textSecondary
        }
    }

    private func instrumentBarColor(for instrument: String) -> Color {
        switch instrument.lowercased() {
        case "piano":      return Theme.Colors.focus
        case "pad":        return Theme.Colors.sleep
        case "strings":    return Theme.Colors.relaxation
        case "guitar":     return Theme.Colors.signalElevated
        case "texture":    return Theme.Colors.signalCalm
        default:           return Theme.Colors.accent
        }
    }

    private func formatSoundName(_ soundID: String) -> String {
        soundID
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

// MARK: - Card 4: Insight

private struct InsightCard: View {
    let summary: MonthlySummary

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Your")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Insight")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.top, Theme.Spacing.jumbo)

                if let insight = summary.primaryInsight {
                    insightHero(insight)
                } else {
                    Text("Keep building your history to unlock personalized insights.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                if !summary.compositeAdaptationEvents.isEmpty {
                    compositeMapSection
                }

                Spacer(minLength: Theme.Spacing.jumbo)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
    }

    private func insightHero(_ insight: InsightFinding) -> some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: insight.iconName)
                .font(.system(size: Theme.Typography.Size.title))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: Theme.Spacing.mega, height: Theme.Spacing.mega)
                .background(
                    Circle()
                        .fill(Theme.Colors.accent.opacity(Theme.Opacity.light))
                )

            Text(insight.headline)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(insight.detail)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
        .padding(.vertical, Theme.Spacing.xxl)
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(
                    Theme.Colors.accent.opacity(Theme.Opacity.accentLight),
                    lineWidth: 1
                )
        )
    }

    private var compositeMapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Your Month in Wavelengths")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            ZStack {
                ForEach(
                    Array(summary.compositeAdaptationEvents.enumerated()),
                    id: \.offset
                ) { index, entry in
                    AdaptationMapView(
                        events: entry.events,
                        sessionDuration: entry.sessionDuration,
                        mode: entry.mode
                    )
                    .frame(height: compositeMapHeight)
                    .opacity(compositeLayerOpacity(
                        index: index,
                        total: summary.compositeAdaptationEvents.count
                    ))
                }
            }
            .frame(height: compositeMapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
    }

    private var compositeMapHeight: CGFloat { Theme.Spacing.mega * 2 }

    private func compositeLayerOpacity(index: Int, total: Int) -> Double {
        guard total > 0 else { return Theme.Opacity.full }
        let base = Theme.Opacity.medium
        let step = (Theme.Opacity.full - base) / Double(max(total, 1))
        return base + step * Double(index)
    }
}

// MARK: - Shareable Summary Card (for ImageRenderer)

private struct ShareableSummaryCard: View {
    let cardIndex: Int
    let summary: MonthlySummary
    let outputSize: CGSize

    var body: some View {
        ZStack {
            Theme.Colors.canvas

            VStack(spacing: .zero) {
                Group {
                    switch cardIndex {
                    case 0: OverviewCard(summary: summary)
                    case 1: BiometricJourneyCard(summary: summary)
                    case 2: SoundProfileCard(summary: summary)
                    case 3: InsightCard(summary: summary)
                    default: OverviewCard(summary: summary)
                    }
                }

                Spacer(minLength: .zero)

                Text("BioNaural")
                    .font(wordmarkFont)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .tracking(Theme.Typography.Tracking.display)
                    .padding(.bottom, bottomPadding)
            }
        }
        .frame(width: outputSize.width, height: outputSize.height)
        .environment(\.colorScheme, .dark)
    }

    private var wordmarkFont: Font {
        let baseRatio = Theme.Typography.Size.caption / referenceScreenWidth
        return Font.system(
            size: outputSize.width * baseRatio * fontScaleMultiplier,
            weight: .medium,
            design: .default
        )
    }

    private var referenceScreenWidth: CGFloat { 393 }
    private var fontScaleMultiplier: CGFloat { 1.2 }
    private var bottomPadding: CGFloat { outputSize.height * Theme.Opacity.minimal }
}

// MARK: - Mode Color Helper (File-level)

private func modeColor(for mode: FocusMode) -> Color {
    Color.modeColor(for: mode)
}

// MARK: - Summary Share Sheet

private struct SummaryShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

// MARK: - Previews

#Preview("Monthly Summary") {
    NavigationStack {
        MonthlySummaryView(month: Date())
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: FocusSession.self, inMemory: true)
}
