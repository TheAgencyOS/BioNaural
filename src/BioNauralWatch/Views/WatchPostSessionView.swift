// WatchPostSessionView.swift
// BioNauralWatch
//
// Post-session summary screen shown after a session ends. Displays
// duration, mode, key metrics, and a binary feedback prompt. All
// visual values come from WatchDesign tokens — no hardcoded numbers.

import SwiftUI
import BioNauralShared

// MARK: - WatchSessionResult

/// Aggregated results from a completed Watch session, used to populate
/// the post-session summary screen.
struct WatchSessionResult: Sendable {
    let mode: FocusMode
    let durationSeconds: TimeInterval
    let averageHR: Double?
    let hrDelta: Double?
    let adaptationCount: Int
    let deepStateMinutes: Double
    let timeToCalm: TimeInterval?
}

// MARK: - WatchPostSessionView

struct WatchPostSessionView: View {
    let result: WatchSessionResult
    let onDismiss: () -> Void

    @State private var selectedThumb: ThumbsRating?
    @State private var showThanks = false
    @State private var showContent = false
    @State private var dismissTask: Task<Void, Never>?

    // MARK: - Grid

    private let columns = [
        GridItem(.flexible(), spacing: WatchDesign.Layout.metricGridGap),
        GridItem(.flexible(), spacing: WatchDesign.Layout.metricGridGap)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: WatchDesign.Spacing.lg) {

                // 1. Header
                Text("SESSION COMPLETE")
                    .font(.system(size: WatchDesign.Typography.postHeaderSize))
                    .foregroundStyle(WatchDesign.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(WatchDesign.Typography.headerTracking)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : WatchDesign.Animation.entranceOffset)

                // 2. Duration
                Text(formattedDuration)
                    .font(.system(size: WatchDesign.Typography.postDurationSize, weight: .light, design: .monospaced))
                    .foregroundStyle(WatchDesign.Colors.textPrimary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : WatchDesign.Animation.entranceOffset)
                    .animation(.spring(duration: WatchDesign.Animation.standardDuration).delay(WatchDesign.Animation.staggerDelay), value: showContent)

                // 3. Mode name
                Text(result.mode.displayName.uppercased())
                    .font(.system(size: WatchDesign.Typography.postModeSize))
                    .foregroundStyle(result.mode.watchColor)
                    .tracking(WatchDesign.Typography.headerTracking)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : WatchDesign.Animation.entranceOffset)
                    .animation(.spring(duration: WatchDesign.Animation.standardDuration).delay(WatchDesign.Animation.staggerDelay * 2), value: showContent)

                // 4. Metrics grid
                LazyVGrid(columns: columns, spacing: WatchDesign.Layout.metricGridGap) {
                    ForEach(metricsForMode, id: \.label) { metric in
                        metricCell(label: metric.label, value: metric.value, color: metric.color)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(metric.label): \(metric.value)")
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : WatchDesign.Animation.entranceOffset)
                .animation(.spring(duration: WatchDesign.Animation.standardDuration).delay(WatchDesign.Animation.staggerDelay * 3), value: showContent)

                // 5. Feedback section
                VStack(spacing: WatchDesign.Spacing.md) {
                    Rectangle()
                        .fill(WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.glassStroke / 2))
                        .frame(height: 1)

                    if showThanks {
                        // 6. Thanks label
                        Text("Thanks")
                            .font(.system(size: WatchDesign.Typography.postModeSize))
                            .foregroundStyle(WatchDesign.Colors.accent)
                            .transition(.opacity)
                    } else {
                        HStack(spacing: WatchDesign.Layout.feedbackButtonSpacing) {
                            feedbackButton(
                                rating: .down,
                                symbol: "hand.thumbsdown.fill",
                                accessibilityText: "Thumbs down"
                            )
                            feedbackButton(
                                rating: .up,
                                symbol: "hand.thumbsup.fill",
                                accessibilityText: "Thumbs up"
                            )
                        }
                    }
                }
                .opacity(showContent ? 1 : 0)
                .animation(.spring(duration: WatchDesign.Animation.standardDuration).delay(WatchDesign.Animation.staggerDelay * 5), value: showContent)
            }
            .padding(.horizontal, WatchDesign.Layout.horizontalPadding)
            .padding(.top, WatchDesign.Spacing.xxxl)
        }
        .onAppear {
            withAnimation(.spring(duration: WatchDesign.Animation.standardDuration)) {
                showContent = true
            }
        }
        .onDisappear { dismissTask?.cancel() }
    }

    // MARK: - Metric Cell

    @ViewBuilder
    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: WatchDesign.Spacing.xxs) {
            Text(label.uppercased())
                .font(.system(size: WatchDesign.Typography.postMetricLabelSize))
                .foregroundStyle(WatchDesign.Colors.textTertiary)
                .tracking(WatchDesign.Typography.metricLabelTracking)

            Text(value)
                .font(.system(size: WatchDesign.Typography.postMetricValueSize, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(WatchDesign.Layout.metricCellPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: WatchDesign.Layout.metricCellCornerRadius, style: .continuous)
                .fill(WatchDesign.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WatchDesign.Layout.metricCellCornerRadius, style: .continuous)
                .strokeBorder(WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.glassStroke / 2), lineWidth: 1)
        )
    }

    // MARK: - Feedback Button

    @ViewBuilder
    private func feedbackButton(rating: ThumbsRating, symbol: String, accessibilityText: String) -> some View {
        let isSelected = selectedThumb == rating

        Button {
            withAnimation(.easeInOut(duration: WatchDesign.Animation.standardDuration)) {
                selectedThumb = rating
                showThanks = true
            }

            dismissTask?.cancel()
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(WatchDesign.Animation.feedbackDismissDelay))
                guard !Task.isCancelled else { return }
                onDismiss()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: WatchDesign.Typography.feedbackIconSize))
                .foregroundStyle(isSelected ? result.mode.watchColor : WatchDesign.Colors.textPrimary)
                .frame(
                    width: WatchDesign.Layout.feedbackButtonSize,
                    height: WatchDesign.Layout.feedbackButtonSize
                )
                .background(
                    Circle()
                        .fill(isSelected
                              ? result.mode.watchColor.opacity(WatchDesign.Opacity.quickModeBackground)
                              : WatchDesign.Colors.surface)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? result.mode.watchColor.opacity(WatchDesign.Opacity.revealWaveDim)
                                : WatchDesign.Colors.textPrimary.opacity(WatchDesign.Opacity.glassFill),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Rate this session")
        .disabled(selectedThumb != nil)
    }

    // MARK: - Formatting

    private var formattedDuration: String {
        let totalSeconds = Int(result.durationSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Mode-Specific Metrics

    private struct MetricItem: Identifiable {
        let label: String
        let value: String
        let color: Color
        var id: String { label }
    }

    private var metricsForMode: [MetricItem] {
        let modeColor = result.mode.watchColor
        let accent = WatchDesign.Colors.accent

        switch result.mode {
        case .focus:
            return [
                MetricItem(
                    label: "Avg HR",
                    value: formatOptionalInt(result.averageHR),
                    color: accent
                ),
                MetricItem(
                    label: "HR Delta",
                    value: formatOptionalDelta(result.hrDelta),
                    color: hrDeltaColor(result.hrDelta)
                ),
                MetricItem(
                    label: "Adapted",
                    value: "\(result.adaptationCount)x",
                    color: modeColor
                ),
                MetricItem(
                    label: "Deep Focus",
                    value: "\(Int(result.deepStateMinutes))m",
                    color: modeColor
                )
            ]

        case .relaxation:
            return [
                MetricItem(
                    label: "Avg HR",
                    value: formatOptionalInt(result.averageHR),
                    color: accent
                ),
                MetricItem(
                    label: "HR Delta",
                    value: formatOptionalDelta(result.hrDelta),
                    color: hrDeltaColor(result.hrDelta)
                ),
                MetricItem(
                    label: "Time to Calm",
                    value: formatOptionalMinutes(result.timeToCalm),
                    color: modeColor
                ),
                MetricItem(
                    label: "HRV Delta",
                    value: "--",
                    color: modeColor
                )
            ]

        case .sleep:
            return [
                MetricItem(
                    label: "Avg HR",
                    value: formatOptionalInt(result.averageHR),
                    color: accent
                ),
                MetricItem(
                    label: "HR Delta",
                    value: formatOptionalDelta(result.hrDelta),
                    color: hrDeltaColor(result.hrDelta)
                ),
                MetricItem(
                    label: "Time to Sleep",
                    value: "--",
                    color: modeColor
                ),
                MetricItem(
                    label: "Deep Sleep",
                    value: "--",
                    color: modeColor
                )
            ]

        case .energize:
            return [
                MetricItem(
                    label: "Avg HR",
                    value: formatOptionalInt(result.averageHR),
                    color: accent
                ),
                MetricItem(
                    label: "HR Delta",
                    value: formatOptionalDelta(result.hrDelta),
                    color: hrDeltaColor(result.hrDelta)
                ),
                MetricItem(
                    label: "Adapted",
                    value: "\(result.adaptationCount)x",
                    color: modeColor
                ),
                MetricItem(
                    label: "Peak",
                    value: "\(Int(result.deepStateMinutes))m",
                    color: modeColor
                )
            ]
        }
    }

    // MARK: - Value Formatting

    private func formatOptionalInt(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value))"
    }

    private func formatOptionalDelta(_ value: Double?) -> String {
        guard let value else { return "--" }
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(Int(value))"
    }

    /// Returns the appropriate color for HR delta based on mode.
    /// Focus/Relaxation/Sleep: negative (calming) is good.
    /// Energize: positive (activating) is good.
    private func hrDeltaColor(_ delta: Double?) -> Color {
        guard let delta else { return WatchDesign.Colors.accent }
        let isBeneficial: Bool
        switch result.mode {
        case .focus, .relaxation, .sleep:
            isBeneficial = delta <= 0
        case .energize:
            isBeneficial = delta >= 0
        }
        return isBeneficial ? WatchDesign.Colors.signalCalm : WatchDesign.Colors.signalElevated
    }

    private func formatOptionalMinutes(_ value: TimeInterval?) -> String {
        guard let value else { return "--" }
        return "\(Int(value / 60))m"
    }
}
