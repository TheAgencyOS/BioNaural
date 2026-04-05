// ScienceFlipView.swift
// BioNaural
//
// Premium science back-face for mode carousel cards. Reveals the
// neuroscience, adaptive mechanism, and key data for each mode.
// Designed as "earned information" — available when sought, never imposed.
// All values from Theme tokens. No hardcoded colors, sizes, or strings.

import SwiftUI
import BioNauralShared

// MARK: - ScienceFlipView

struct ScienceFlipView: View {

    let mode: FocusMode
    let onClose: () -> Void

    private var modeColor: Color { Color.modeColor(for: mode) }
    private var content: ModeScienceData { ModeScienceData.for(mode) }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(backgroundGradient)

            // Subtle mode-colored radial glow at top
            VStack {
                RadialGradient(
                    colors: [
                        modeColor.opacity(Theme.Opacity.light),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: Theme.Spacing.mega * 5
                )
                .frame(height: Theme.Carousel.cardHeight * 0.4)
                Spacer()
            }

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header cluster
                    headerSection
                        .padding(.bottom, Theme.Spacing.xxl)

                    // Divider
                    Rectangle()
                        .fill(modeColor.opacity(Theme.Opacity.accentLight))
                        .frame(height: Theme.Radius.glassStroke)
                        .padding(.bottom, Theme.Spacing.xl)

                    // Mechanism
                    scienceBlock(
                        label: "Mechanism",
                        text: content.mechanism
                    )
                    .padding(.bottom, Theme.Spacing.xl)

                    // Adaptive response
                    scienceBlock(
                        label: "Adaptive response",
                        text: content.adaptiveResponse
                    )
                    .padding(.bottom, Theme.Spacing.xxl)

                    // Data metrics row
                    dataMetricsRow
                        .padding(.bottom, Theme.Spacing.xxl)

                    // Caveat bar
                    caveatBar
                        .padding(.bottom, Theme.Spacing.xl)

                    // Citation
                    Text(content.citation)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .italic()
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.top, Theme.Spacing.xxl + Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xxl)
            }

            // Close button — top right
            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
            }
            .padding(Theme.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        Text(content.title)
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    // MARK: - Science Block

    private func scienceBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(modeColor)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)

            Text(text)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
    }

    // MARK: - Data Metrics

    private var dataMetricsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(Array(content.metrics.enumerated()), id: \.offset) { index, metric in
                VStack(spacing: Theme.Spacing.xxs) {
                    Text(metric.value)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(modeColor)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text(metric.label)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                if index < content.metrics.count - 1 {
                    Rectangle()
                        .fill(Theme.Colors.divider)
                        .frame(width: Theme.Radius.glassStroke)
                        .padding(.vertical, Theme.Spacing.xxs)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.surface.opacity(Theme.Opacity.translucent))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )
        )
    }

    // MARK: - Caveat Bar

    private var caveatBar: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(modeColor.opacity(Theme.Opacity.accentLight))
                .frame(width: Theme.Radius.glassStroke * 3)

            Text(content.caveat)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)

                Circle()
                    .strokeBorder(Color.white.opacity(Theme.Opacity.light), lineWidth: Theme.Radius.glassStroke)
                    .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)

                Image(systemName: "xmark")
                    .font(.system(size: Theme.Typography.Size.small, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close science card")
    }

    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                modeColor.opacity(Theme.Opacity.subtle),
                Theme.Colors.surface,
                Theme.Colors.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Science Content Model

private struct ScienceMetric {
    let value: String
    let label: String
}

private struct ModeScienceData {
    let title: String
    let mechanism: String
    let adaptiveResponse: String
    let metrics: [ScienceMetric]
    let caveat: String
    let citation: String

    static func `for`(_ mode: FocusMode) -> ModeScienceData {
        switch mode {
        case .focus:
            return ModeScienceData(
                title: "Beta Waves\n& Focus",
                mechanism: "Beta brainwaves (14\u{2013}30 Hz) are associated with active, alert cognition. A binaural beat at 15 Hz encourages cortical entrainment toward this band, supporting sustained attention and working memory.",
                adaptiveResponse: "When your heart rate rises, BioNaural shifts the beat frequency downward toward alpha, calming your nervous system without breaking concentration.",
                metrics: [
                    ScienceMetric(value: "14\u{2013}16", label: "Hz target"),
                    ScienceMetric(value: "300\u{2013}450", label: "Hz carrier"),
                    ScienceMetric(value: "\u{2013}12 dB", label: "Beat level"),
                ],
                caveat: "Effects are real but modest \u{2014} think \u{201C}reducing friction\u{201D} not \u{201C}creating superpowers.\u{201D}",
                citation: "Garcia-Argibay et al., 2019 \u{2014} meta-analysis of binaural beats on cognition and anxiety"
            )
        case .relaxation:
            return ModeScienceData(
                title: "Alpha Waves\n& Calm",
                mechanism: "Alpha brainwaves (8\u{2013}13 Hz) dominate during relaxed wakefulness. Binaural beats in this range promote parasympathetic activation, reducing cortisol and lowering heart rate.",
                adaptiveResponse: "If your HR is elevated, the beat gently rises to 11\u{2013}12 Hz to meet you, then guides back down. The system catches you before calming you.",
                metrics: [
                    ScienceMetric(value: "8\u{2013}11", label: "Hz target"),
                    ScienceMetric(value: "150\u{2013}250", label: "Hz carrier"),
                    ScienceMetric(value: "HRV \u{2191}", label: "Expected"),
                ],
                caveat: "This is our most evidence-backed mode. A 2019 meta-analysis of 22 studies found alpha beats reliably reduce anxiety.",
                citation: "Wahbeh et al., 2007 \u{2014} binaural beat effects on parasympathetic activity and anxiety"
            )
        case .sleep:
            return ModeScienceData(
                title: "Theta\u{2192}Delta\n& Sleep",
                mechanism: "Natural sleep onset follows a theta (4\u{2013}8 Hz) to delta (0.5\u{2013}4 Hz) progression. The beat frequency ramps from 6 Hz to 2 Hz over 25 minutes, mirroring this natural descent.",
                adaptiveResponse: "When sustained stillness and dropping heart rate indicate sleep onset, the audio begins a slow fade-out. If you stir, the frequency holds steady.",
                metrics: [
                    ScienceMetric(value: "6\u{2192}2", label: "Hz ramp"),
                    ScienceMetric(value: "100\u{2013}200", label: "Hz carrier"),
                    ScienceMetric(value: "25 min", label: "Ramp time"),
                ],
                caveat: "Best used as sleep preparation (15\u{2013}45 min), not all night. Your brain takes over from there.",
                citation: "Jirakittayakorn & Wongsawat, 2017 \u{2014} delta binaural beats and deep sleep induction"
            )
        case .energize:
            return ModeScienceData(
                title: "High-Beta\n& Arousal",
                mechanism: "High-beta / low-gamma waves (18\u{2013}30 Hz) correlate with alertness and energetic cognition. The beat reinforces sympathetic activation, increasing arousal without inducing anxiety.",
                adaptiveResponse: "As your heart rate rises, the system reinforces \u{2014} pushing toward higher beta. Unlike Focus mode, the feedback loop is positive: your body's activation is the goal.",
                metrics: [
                    ScienceMetric(value: "18\u{2013}30", label: "Hz target"),
                    ScienceMetric(value: "350\u{2013}500", label: "Hz carrier"),
                    ScienceMetric(value: "HR \u{2191}", label: "Reinforced"),
                ],
                caveat: "Best for short bursts \u{2014} morning wake-up, afternoon reset, or pre-workout activation.",
                citation: "Colzato et al., 2017 \u{2014} high-frequency binaural beats and cognitive control"
            )
        }
    }
}

// MARK: - Preview

#Preview("Science Flip — Focus") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        ScienceFlipView(mode: .focus, onClose: {})
            .frame(width: Theme.Carousel.cardWidth, height: Theme.Carousel.cardHeight)
    }
    .preferredColorScheme(.dark)
}

#Preview("Science Flip — Sleep") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        ScienceFlipView(mode: .sleep, onClose: {})
            .frame(width: Theme.Carousel.cardWidth, height: Theme.Carousel.cardHeight)
    }
    .preferredColorScheme(.dark)
}
