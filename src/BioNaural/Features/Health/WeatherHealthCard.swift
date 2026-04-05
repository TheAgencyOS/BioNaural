// WeatherHealthCard.swift
// BioNaural
//
// SwiftUI card displaying weather-health correlations in the Health view.
// Barometric pressure is the hero metric — falling pressure correlates with
// reduced HRV, mood changes, and migraine onset. The card surfaces this
// insight alongside current conditions and pattern-based recommendations.
// All values from Theme tokens. Native SwiftUI only.

import SwiftUI

// MARK: - WeatherInsight

/// Packaged weather data and derived insight for the Health card.
struct WeatherInsight: Sendable {

    /// Current weather snapshot.
    let current: WeatherContext

    /// Barometric pressure change from yesterday (hPa). Positive = rising.
    let pressureDelta: Double?

    /// Pattern-based insight text (e.g., "Rainy days: your Relaxation sessions score 12% higher").
    let insightText: String?

    /// Whether current conditions are favorable for the user's typical session type.
    let isPositiveForSession: Bool?
}

// MARK: - WeatherHealthCard

struct WeatherHealthCard: View {

    // MARK: - Inputs

    let insight: WeatherInsight

    // MARK: - State

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

            // Accent glow — color shifts with pressure trend
            RadialGradient(
                colors: [glowColor.opacity(Theme.Opacity.light), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * Theme.Health.cardGlowRadiusMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                sectionLabel
                currentConditionsRow
                pressureTrendSection
                if let text = insight.insightText {
                    insightRow(text: text)
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    // MARK: - Glow Color

    private var glowColor: Color {
        switch insight.current.pressureTrend {
        case .rising:  return Theme.Colors.signalCalm
        case .falling: return Theme.Colors.stressWarning
        case .steady:  return Theme.Colors.accent
        }
    }

    // MARK: - Section Label

    private var sectionLabel: some View {
        Text("ENVIRONMENT")
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
            .opacity(animatedOpacity(index: 0))
            .offset(y: animatedOffset(index: 0))
            .animation(staggerAnimation(index: 0), value: appeared)
    }

    // MARK: - Current Conditions Row

    private var currentConditionsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Condition icon
            Image(systemName: insight.current.condition.icon)
                .font(.system(size: Theme.Typography.Size.headline, weight: .medium))
                .foregroundStyle(conditionIconColor)
                .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)

            // Temperature
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(formattedTemperature)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(insight.current.condition.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            // Humidity
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "humidity.fill")
                        .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(formattedHumidity)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Text("Humidity")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .opacity(animatedOpacity(index: 1))
        .offset(y: animatedOffset(index: 1))
        .animation(staggerAnimation(index: 1), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(conditionsAccessibilityLabel)
    }

    private var conditionIconColor: Color {
        switch insight.current.condition {
        case .clear:  return Theme.Colors.energize
        case .rainy, .stormy: return Theme.Colors.accent
        case .snowy:  return Theme.Colors.textPrimary
        default:      return Theme.Colors.textSecondary
        }
    }

    // MARK: - Pressure Trend Section (Hero Metric)

    private var pressureTrendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Pressure reading with trend arrow
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(String(format: "%.0f", insight.current.pressureHPa))
                    .font(Theme.Typography.data)
                    .tracking(Theme.Typography.Tracking.data)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("hPa")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer(minLength: 0)

                // Trend arrow with color
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: insight.current.pressureTrend.icon)
                        .font(.system(size: Theme.Typography.Size.callout, weight: .semibold))
                        .foregroundStyle(pressureTrendColor)

                    Text(insight.current.pressureTrend.label)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(pressureTrendColor)
                }
            }

            // Delta from yesterday (if available)
            if let delta = insight.pressureDelta {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(delta >= 0 ? "+" : "")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(pressureDeltaColor(delta))
                    +
                    Text(String(format: "%.1f hPa from yesterday", delta))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(pressureDeltaColor(delta))
                }
            }

            // Contextual advisory
            pressureAdvisory
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(pressureTrendColor.opacity(Theme.Opacity.light))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(
                            pressureTrendColor.opacity(Theme.Opacity.dim),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .opacity(animatedOpacity(index: 2))
        .offset(y: animatedOffset(index: 2))
        .animation(staggerAnimation(index: 2), value: appeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pressureAccessibilityLabel)
    }

    private var pressureTrendColor: Color {
        switch insight.current.pressureTrend {
        case .rising:  return Theme.Colors.signalCalm
        case .falling: return Theme.Colors.stressWarning
        case .steady:  return Theme.Colors.textTertiary
        }
    }

    private func pressureDeltaColor(_ delta: Double) -> Color {
        if abs(delta) < WeatherConfig.pressureChangeDeltaThreshold / 2 {
            return Theme.Colors.textTertiary
        }
        return delta > 0 ? Theme.Colors.signalCalm : Theme.Colors.stressWarning
    }

    @ViewBuilder
    private var pressureAdvisory: some View {
        switch insight.current.pressureTrend {
        case .falling:
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.stressWarning)

                Text("Pressure dropping \u{2014} your HRV may be lower today")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.stressWarning)
            }

        case .rising:
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.signalCalm)

                Text("Pressure rising \u{2014} good conditions for Focus")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.signalCalm)
            }

        case .steady:
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text("Pressure steady \u{2014} neutral conditions")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Insight Row

    private func insightRow(text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)

            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
        .opacity(animatedOpacity(index: 3))
        .offset(y: animatedOffset(index: 3))
        .animation(staggerAnimation(index: 3), value: appeared)
        .accessibilityLabel("Weather insight: \(text)")
    }

    // MARK: - Formatted Values

    private var formattedTemperature: String {
        String(format: "%.0f\u{00B0}C", insight.current.temperatureCelsius)
    }

    private var formattedHumidity: String {
        String(format: "%.0f%%", insight.current.humidity * 100)
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

    // MARK: - Accessibility Labels

    private var conditionsAccessibilityLabel: String {
        "\(insight.current.condition.label), \(formattedTemperature), humidity \(formattedHumidity)"
    }

    private var pressureAccessibilityLabel: String {
        var parts: [String] = [
            "Barometric pressure: \(String(format: "%.0f", insight.current.pressureHPa)) hectopascals, \(insight.current.pressureTrend.label)"
        ]

        if let delta = insight.pressureDelta {
            let direction = delta >= 0 ? "up" : "down"
            parts.append("\(String(format: "%.1f", abs(delta))) hectopascals \(direction) from yesterday")
        }

        switch insight.current.pressureTrend {
        case .falling:
            parts.append("Caution: Pressure dropping, your HRV may be lower today")
        case .rising:
            parts.append("Good conditions for Focus sessions")
        case .steady:
            parts.append("Neutral conditions")
        }

        return parts.joined(separator: ". ")
    }

    private var cardAccessibilityLabel: String {
        var parts: [String] = [
            "Environment card.",
            conditionsAccessibilityLabel,
            pressureAccessibilityLabel
        ]

        if let text = insight.insightText {
            parts.append("Insight: \(text)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Preview

#Preview("Weather Health Card — Falling Pressure") {
    ScrollView {
        VStack(spacing: Theme.Spacing.xxl) {
            WeatherHealthCard(
                insight: WeatherInsight(
                    current: WeatherContext(
                        date: Date(),
                        temperatureCelsius: 14.2,
                        humidity: 0.78,
                        pressureHPa: 1005.3,
                        pressureTrend: .falling,
                        condition: .rainy,
                        uvIndex: 2
                    ),
                    pressureDelta: -6.8,
                    insightText: "Rainy days: your Relaxation sessions score 12% higher",
                    isPositiveForSession: true
                )
            )

            WeatherHealthCard(
                insight: WeatherInsight(
                    current: WeatherContext(
                        date: Date(),
                        temperatureCelsius: 22.1,
                        humidity: 0.45,
                        pressureHPa: 1018.7,
                        pressureTrend: .rising,
                        condition: .clear,
                        uvIndex: 6
                    ),
                    pressureDelta: 4.2,
                    insightText: nil,
                    isPositiveForSession: true
                )
            )

            WeatherHealthCard(
                insight: WeatherInsight(
                    current: WeatherContext(
                        date: Date(),
                        temperatureCelsius: 18.5,
                        humidity: 0.62,
                        pressureHPa: 1013.2,
                        pressureTrend: .steady,
                        condition: .cloudy,
                        uvIndex: 3
                    ),
                    pressureDelta: 0.3,
                    insightText: "Cloudy afternoons: your Focus sessions average 8 minutes longer",
                    isPositiveForSession: nil
                )
            )
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, Theme.Spacing.xxl)
    }
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
