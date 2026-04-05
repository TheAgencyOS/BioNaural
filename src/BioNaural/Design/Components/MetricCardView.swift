// MetricCardView.swift
// BioNaural
//
// Reusable card for displaying a biometric metric (HR, HRV, etc.).
// Used in post-session summary, settings, and analytics screens.
// All visual tokens sourced from Theme.

import SwiftUI

// MARK: - MetricCardView

struct MetricCardView: View {

    // MARK: - Inputs

    /// SF Symbol name for the metric icon.
    let icon: String

    /// Formatted value string (e.g., "72", "45ms", "+3").
    let value: String

    /// Descriptive label (e.g., "Heart Rate", "HRV", "HR Delta").
    let label: String

    /// Optional accent color for the icon. Defaults to Theme.Colors.accent.
    var iconColor: Color = Theme.Colors.accent

    // MARK: - Body

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.headline))
                .foregroundStyle(iconColor)

            Text(value)
                .font(Theme.Typography.data)
                .tracking(Theme.Typography.Tracking.data)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.lg)
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - Preview

#Preview("Metric Cards") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        HStack(spacing: Theme.Spacing.md) {
            MetricCardView(
                icon: "heart.fill",
                value: "72",
                label: "Avg HR",
                iconColor: Theme.Colors.signalPeak
            )

            MetricCardView(
                icon: "waveform.path.ecg",
                value: "45ms",
                label: "HRV"
            )

            MetricCardView(
                icon: "arrow.down.heart.fill",
                value: "-8",
                label: "HR Delta",
                iconColor: Theme.Colors.signalCalm
            )
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
    .preferredColorScheme(.dark)
}
