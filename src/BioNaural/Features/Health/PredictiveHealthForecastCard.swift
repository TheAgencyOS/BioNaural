// PredictiveHealthForecastCard.swift
// BioNaural
//
// Forward-looking health predictions surfaced before upcoming stressors.
// "You have a client call Thursday. Based on 6 similar events: expect
// sleep quality -12%, resting HR +4 bpm starting Wednesday night."
// The "how does it know that?" moment.
// All values from Theme tokens. Native SwiftUI only.

import SwiftUI
import BioNauralShared

// MARK: - Constants

private extension Constants {
    enum Forecast {
        static let confidenceLowThreshold: Double = 0.4
        static let confidenceModerateThreshold: Double = 0.7
        static let confidenceDotCount: Int = 3
    }
}

// MARK: - HealthForecast

struct HealthForecast: Identifiable, Sendable {
    let id: String
    let eventTitle: String
    let eventDate: Date
    let stressLevel: String
    let predictions: [ForecastPrediction]
    let sampleCount: Int
    let suggestedPrepMode: FocusMode?
    let suggestedPrepMinutes: Int?
    let confidence: Double // 0-1
}

// MARK: - ForecastPrediction

struct ForecastPrediction: Identifiable, Sendable {
    let id: String
    let metric: String
    let icon: String
    let delta: String
    let timing: String
    let isNegative: Bool
}

// MARK: - PredictiveHealthForecastCard

struct PredictiveHealthForecastCard: View {

    let forecast: HealthForecast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.half),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )

            // Accent glow
            RadialGradient(
                colors: [glowColor.opacity(Theme.Opacity.light), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                headerRow
                predictionRows
                confidenceIndicator
                if forecast.suggestedPrepMode != nil {
                    prepSuggestion
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    // MARK: - Glow Color

    // NOTE: HealthForecast.stressLevel uses "medium" while CalendarEventClassifier.StressLevel
    // uses .moderate ("moderate"). This comparison handles both until the model is unified.
    private var glowColor: Color {
        switch forecast.stressLevel {
        case StressLevel.high.rawValue:
            return Theme.Colors.stressWarning
        case StressLevel.moderate.rawValue, "medium":
            return Theme.Colors.signalElevated
        default:
            return Theme.Colors.accent
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                // Stress level dot
                Circle()
                    .fill(stressDotColor)
                    .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                    .accessibilityLabel("Stress level: \(forecast.stressLevel)")

                Text(forecast.eventTitle)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(countdownText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .opacity(animatedOpacity(index: 0))
            .offset(y: animatedOffset(index: 0))
            .animation(staggerAnimation(index: 0), value: appeared)
        }
    }

    private var stressDotColor: Color {
        switch forecast.stressLevel {
        case StressLevel.high.rawValue:
            return Theme.Colors.stressWarning
        case StressLevel.moderate.rawValue, "medium":
            return Theme.Colors.signalElevated
        case StressLevel.low.rawValue:
            return Theme.Colors.signalCalm
        default:
            return Theme.Colors.accent
        }
    }

    private var countdownText: String {
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.day, .hour], from: now, to: forecast.eventDate)

        if let days = components.day, days > 0 {
            return days == 1 ? "in 1 day" : "in \(days) days"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "in 1 hour" : "in \(hours) hours"
        } else {
            return "soon"
        }
    }

    // MARK: - Prediction Rows

    private var predictionRows: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(forecast.predictions.enumerated()), id: \.element.id) { index, prediction in
                PredictionRow(prediction: prediction)
                    .opacity(animatedOpacity(index: index + 1))
                    .offset(y: animatedOffset(index: index + 1))
                    .animation(staggerAnimation(index: index + 1), value: appeared)
            }
        }
    }

    // MARK: - Confidence Indicator

    private var confidenceIndicator: some View {
        let animationIndex = forecast.predictions.count + 1

        return HStack(spacing: Theme.Spacing.sm) {
            Text("Based on \(forecast.sampleCount) similar events")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            ConfidenceDots(confidence: forecast.confidence)
        }
        .opacity(animatedOpacity(index: animationIndex))
        .offset(y: animatedOffset(index: animationIndex))
        .animation(staggerAnimation(index: animationIndex), value: appeared)
        .accessibilityLabel(
            "Based on \(forecast.sampleCount) similar events. Confidence: \(confidenceLabel)."
        )
    }

    private var confidenceLabel: String {
        switch forecast.confidence {
        case 0..<Constants.Forecast.confidenceLowThreshold:
            return "low"
        case Constants.Forecast.confidenceLowThreshold..<Constants.Forecast.confidenceModerateThreshold:
            return "moderate"
        default:
            return "high"
        }
    }

    // MARK: - Prep Suggestion

    @ViewBuilder
    private var prepSuggestion: some View {
        if let mode = forecast.suggestedPrepMode {
            let animationIndex = forecast.predictions.count + 2
            let modeColor = Color.modeColor(for: mode)

            Button(action: {}, label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: mode.systemImageName)
                        .font(.system(size: Theme.Typography.Size.callout, weight: .medium))
                        .foregroundStyle(modeColor)

                    if let minutes = forecast.suggestedPrepMinutes {
                        Text("\(minutes)-min \(mode.displayName) recommended")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    } else {
                        Text("\(mode.displayName) recommended")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Capsule()
                        .fill(modeColor.opacity(Theme.Opacity.light))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    modeColor.opacity(Theme.Opacity.dim),
                                    lineWidth: Theme.Radius.glassStroke
                                )
                        )
                )
            })
            .buttonStyle(.plain)
            .opacity(animatedOpacity(index: animationIndex))
            .offset(y: animatedOffset(index: animationIndex))
            .animation(staggerAnimation(index: animationIndex), value: appeared)
            .accessibilityLabel(prepAccessibilityLabel)
        }
    }

    private var prepAccessibilityLabel: String {
        guard let mode = forecast.suggestedPrepMode else { return "" }
        if let minutes = forecast.suggestedPrepMinutes {
            return "\(minutes) minute \(mode.displayName) session recommended before this event"
        }
        return "\(mode.displayName) session recommended before this event"
    }

    // MARK: - Animation Helpers

    private func animatedOpacity(index: Int) -> Double {
        reduceMotion ? Theme.Opacity.full : (appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
    }

    private func animatedOffset(index: Int) -> CGFloat {
        reduceMotion ? 0 : (appeared ? 0 : Theme.Spacing.sm)
    }

    private func staggerAnimation(index: Int) -> Animation? {
        reduceMotion ? nil : Theme.Animation.staggeredFadeIn(index: index)
    }

    // MARK: - Card Accessibility Label

    private var cardAccessibilityLabel: String {
        var parts: [String] = []
        parts.append("Upcoming event: \(forecast.eventTitle), \(countdownText).")
        parts.append("Stress level: \(forecast.stressLevel).")

        for prediction in forecast.predictions {
            let direction = prediction.isNegative ? "worsening" : "improving"
            parts.append("\(prediction.metric): \(prediction.delta), \(prediction.timing), \(direction).")
        }

        parts.append("Based on \(forecast.sampleCount) similar events. Confidence: \(confidenceLabel).")

        if let mode = forecast.suggestedPrepMode {
            if let minutes = forecast.suggestedPrepMinutes {
                parts.append("\(minutes) minute \(mode.displayName) session recommended.")
            } else {
                parts.append("\(mode.displayName) session recommended.")
            }
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Prediction Row

private struct PredictionRow: View {

    let prediction: ForecastPrediction

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon in colored circle
            Circle()
                .fill(iconBackgroundColor.opacity(Theme.Opacity.dim))
                .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                .overlay(
                    Image(systemName: prediction.icon)
                        .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(iconBackgroundColor)
                )

            // Metric name
            Text(prediction.metric)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Delta value
            Text(prediction.delta)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(deltaColor)

            // Timing
            Text(prediction.timing)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(prediction.metric): \(prediction.delta), \(prediction.timing)"
        )
    }

    private var iconBackgroundColor: Color {
        prediction.isNegative ? Theme.Colors.signalElevated : Theme.Colors.signalCalm
    }

    private var deltaColor: Color {
        prediction.isNegative ? Theme.Colors.signalPeak : Theme.Colors.signalCalm
    }
}

// MARK: - Confidence Dots

private struct ConfidenceDots: View {

    let confidence: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<Constants.Forecast.confidenceDotCount, id: \.self) { index in
                Circle()
                    .fill(
                        Double(index) / Double(Constants.Forecast.confidenceDotCount) < confidence
                            ? Theme.Colors.accent
                            : Theme.Colors.accent.opacity(Theme.Opacity.light)
                    )
                    .frame(width: Theme.Spacing.xs, height: Theme.Spacing.xs)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Predictive Health Forecast") {
    ScrollView {
        VStack(spacing: Theme.Spacing.xxl) {
            PredictiveHealthForecastCard(
                forecast: HealthForecast(
                    id: "preview-1",
                    eventTitle: "Client Call — Acme Corp",
                    eventDate: Calendar.current.date(
                        byAdding: .day, value: 2, to: .now
                    ) ?? Date(),
                    stressLevel: StressLevel.high.rawValue,
                    predictions: [
                        ForecastPrediction(
                            id: "pred-hr",
                            metric: "Resting HR",
                            icon: "heart.fill",
                            delta: "+4 bpm",
                            timing: "night before",
                            isNegative: true
                        ),
                        ForecastPrediction(
                            id: "pred-sleep",
                            metric: "Sleep Quality",
                            icon: "moon.fill",
                            delta: "-12%",
                            timing: "night before",
                            isNegative: true
                        ),
                        ForecastPrediction(
                            id: "pred-hrv",
                            metric: "HRV",
                            icon: "waveform.path.ecg",
                            delta: "-8 ms",
                            timing: "morning of",
                            isNegative: true
                        )
                    ],
                    sampleCount: 6,
                    suggestedPrepMode: .relaxation,
                    suggestedPrepMinutes: 15,
                    confidence: 0.72
                )
            )

            PredictiveHealthForecastCard(
                forecast: HealthForecast(
                    id: "preview-2",
                    eventTitle: "Morning Run",
                    eventDate: Calendar.current.date(
                        byAdding: .day, value: 1, to: .now
                    ) ?? Date(),
                    stressLevel: StressLevel.low.rawValue,
                    predictions: [
                        ForecastPrediction(
                            id: "pred-hr-2",
                            metric: "Resting HR",
                            icon: "heart.fill",
                            delta: "-3 bpm",
                            timing: "afternoon",
                            isNegative: false
                        ),
                        ForecastPrediction(
                            id: "pred-hrv-2",
                            metric: "HRV",
                            icon: "waveform.path.ecg",
                            delta: "+5 ms",
                            timing: "evening",
                            isNegative: false
                        )
                    ],
                    sampleCount: 14,
                    suggestedPrepMode: nil,
                    suggestedPrepMinutes: nil,
                    confidence: 0.88
                )
            )
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, Theme.Spacing.xxl)
    }
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
