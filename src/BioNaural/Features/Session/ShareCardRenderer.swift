// ShareCardRenderer.swift
// BioNaural
//
// Renders a full biometric summary share card for post-session sharing.
// Includes the adaptation map hero visual, session mode and duration,
// heart rate and HRV deltas, adaptation count, and frequency range.
// Complements ShareableMapGenerator (which renders the map alone).

import SwiftUI
import BioNauralShared

// MARK: - ShareCardRenderer

@MainActor
enum ShareCardRenderer {

    // MARK: - Card Format

    enum CardFormat {
        /// 1080x1920 -- Instagram/TikTok Stories.
        case stories
        /// 1080x1080 -- square (Feed posts, Twitter).
        case square

        var size: CGSize {
            switch self {
            case .stories: return CGSize(width: 1080, height: 1920)
            case .square:  return CGSize(width: 1080, height: 1080)
            }
        }
    }

    // MARK: - Rendering

    /// Renders a full biometric summary card as a UIImage.
    ///
    /// - Parameters:
    ///   - session: The completed focus session to visualize.
    ///   - format: The output card format (stories or square).
    /// - Returns: A rendered `UIImage`, or `nil` if rendering fails.
    static func render(session: FocusSession, format: CardFormat) -> UIImage? {
        let content = ShareCardContent(session: session, format: format)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - ShareCardContent

/// The SwiftUI view composed for image rendering. Laid out at the exact
/// pixel dimensions of the target format -- no screen scaling.
private struct ShareCardContent: View {

    let session: FocusSession
    let format: ShareCardRenderer.CardFormat

    private var size: CGSize { format.size }
    private var mode: FocusMode { session.focusMode ?? .focus }
    private var modeColor: Color { Color.modeColor(for: mode) }

    /// Scale factor relative to a 1080-wide canvas. Typography and spacing
    /// tokens are designed for ~390pt screens, so we scale up proportionally
    /// for the 1080px render target.
    private var scaleFactor: CGFloat { size.width / 390.0 }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.Colors.canvas

            VStack(spacing: Theme.Spacing.xxl * scaleFactor) {
                Spacer()
                    .frame(height: Theme.Spacing.jumbo * scaleFactor)

                // Hero -- Adaptation Map
                adaptationMapSection

                // Divider
                dividerLine

                // Mode + Duration header
                sessionHeader

                // Biometric metric cards (2x2 grid)
                metricGrid

                Spacer()

                // Wordmark
                wordmark
            }
            .padding(.horizontal, Theme.Spacing.xxxl * scaleFactor)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Adaptation Map Hero

    private var adaptationMapSection: some View {
        VStack(spacing: Theme.Spacing.sm * scaleFactor) {
            AdaptationMapView(
                events: session.adaptationEvents,
                sessionDuration: session.duration,
                mode: mode
            )
            .frame(height: size.height * adaptationMapHeightFraction)
            .padding(.horizontal, Theme.Spacing.lg * scaleFactor)
        }
    }

    private var adaptationMapHeightFraction: CGFloat {
        switch format {
        case .stories: return 0.12
        case .square:  return 0.18
        }
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(Theme.Colors.divider)
            .frame(height: scaleFactor)
            .padding(.horizontal, Theme.Spacing.xl * scaleFactor)
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        HStack(spacing: Theme.Spacing.md * scaleFactor) {
            Image(systemName: mode.systemImageName)
                .font(.system(size: Theme.Typography.Size.title * scaleFactor))
                .foregroundStyle(modeColor)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs * scaleFactor) {
                Text("\(mode.displayName) Session")
                    .font(.system(
                        size: Theme.Typography.Size.headline * scaleFactor,
                        weight: .bold,
                        design: .default
                    ))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(formattedMinutes)
                    .font(.system(
                        size: Theme.Typography.Size.callout * scaleFactor,
                        weight: .medium,
                        design: .monospaced
                    ))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg * scaleFactor)
    }

    // MARK: - Metric Grid

    private var metricGrid: some View {
        VStack(spacing: Theme.Spacing.md * scaleFactor) {
            HStack(spacing: Theme.Spacing.md * scaleFactor) {
                heartRateCard
                hrvCard
            }

            HStack(spacing: Theme.Spacing.md * scaleFactor) {
                adaptationsCard
                frequencyRangeCard
            }
        }
        .padding(.horizontal, Theme.Spacing.lg * scaleFactor)
    }

    // MARK: - Heart Rate Card

    private var heartRateCard: some View {
        let startHR = session.maxHeartRate
        let endHR = session.minHeartRate
        let delta: Double? = {
            guard let s = startHR, let e = endHR else { return nil }
            return s - e
        }()

        return metricCard(
            icon: "heart.fill",
            iconColor: Theme.Colors.signalPeak,
            label: "HR",
            value: hrValueText(start: startHR, end: endHR),
            delta: delta.map { hrDeltaText(delta: $0) },
            deltaColor: delta.map { $0 > 0 ? Theme.Colors.confirmationGreen : Theme.Colors.stressWarning }
        )
    }

    // MARK: - HRV Card

    private var hrvCard: some View {
        let avgHRV = session.averageHRV
        let hasData = avgHRV != nil

        return metricCard(
            icon: "waveform.path.ecg",
            iconColor: Theme.Colors.signalCalm,
            label: "HRV",
            value: hasData ? "\(Int(avgHRV!)) ms" : "--",
            delta: nil,
            deltaColor: nil
        )
    }

    // MARK: - Adaptations Card

    private var adaptationsCard: some View {
        let count = session.adaptationEvents.count

        return metricCard(
            icon: "arrow.triangle.branch",
            iconColor: Theme.Colors.accent,
            label: "Adapts",
            value: "\(count)",
            delta: nil,
            deltaColor: nil
        )
    }

    // MARK: - Frequency Range Card

    private var frequencyRangeCard: some View {
        let startFreq = session.beatFrequencyStart
        let endFreq = session.beatFrequencyEnd
        let low = min(startFreq, endFreq)
        let high = max(startFreq, endFreq)

        return metricCard(
            icon: "clock.arrow.2.circlepath",
            iconColor: modeColor,
            label: "Range",
            value: "\(Int(low))-\(Int(high)) Hz",
            delta: nil,
            deltaColor: nil
        )
    }

    // MARK: - Generic Metric Card

    private func metricCard(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        delta: String?,
        deltaColor: Color?
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm * scaleFactor) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.body * scaleFactor))
                .foregroundStyle(iconColor)

            Text(label)
                .font(.system(
                    size: Theme.Typography.Size.caption * scaleFactor,
                    weight: .medium
                ))
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(
                    size: Theme.Typography.Size.data * scaleFactor,
                    weight: .medium,
                    design: .monospaced
                ))
                .foregroundStyle(Theme.Colors.textPrimary)

            if let delta, let color = deltaColor {
                Text(delta)
                    .font(.system(
                        size: Theme.Typography.Size.small * scaleFactor,
                        weight: .bold
                    ))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg * scaleFactor)
        .background(
            Theme.Colors.surface.opacity(Theme.Opacity.glassFill)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        Text("bionaural.app")
            .font(.system(
                size: Theme.Typography.Size.caption * scaleFactor,
                weight: .medium
            ))
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.bottom, Theme.Spacing.jumbo * scaleFactor)
    }

    // MARK: - Formatting Helpers

    private var formattedMinutes: String {
        let minutes = session.durationSeconds / 60
        return "\(minutes) min"
    }

    private func hrValueText(start: Double?, end: Double?) -> String {
        guard let s = start, let e = end else { return "--" }
        return "\(Int(s))\u{2192}\(Int(e))"
    }

    private func hrDeltaText(delta: Double) -> String {
        let sign = delta > 0 ? "\u{25BC}" : "\u{25B2}"
        return "\(sign) \(Int(abs(delta))) bpm"
    }
}

// MARK: - Preview

#Preview("Share Card - Stories") {
    let session = FocusSession(
        startDate: Date().addingTimeInterval(-1920),
        mode: FocusMode.focus.rawValue,
        durationSeconds: 1920,
        averageHeartRate: 68,
        averageHRV: 48,
        minHeartRate: 64,
        maxHeartRate: 72,
        beatFrequencyStart: 14,
        beatFrequencyEnd: 16,
        carrierFrequency: 375,
        adaptationEvents: [
            .init(timestamp: 0, reason: "Start", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 72),
            .init(timestamp: 300, reason: "HR rising", oldBeatFrequency: 14, newBeatFrequency: 13, heartRateAtTime: 80),
            .init(timestamp: 600, reason: "HR stable", oldBeatFrequency: 13, newBeatFrequency: 12, heartRateAtTime: 75),
            .init(timestamp: 900, reason: "Settling", oldBeatFrequency: 12, newBeatFrequency: 14, heartRateAtTime: 70),
            .init(timestamp: 1200, reason: "Focused", oldBeatFrequency: 14, newBeatFrequency: 15, heartRateAtTime: 67),
            .init(timestamp: 1500, reason: "Deep focus", oldBeatFrequency: 15, newBeatFrequency: 16, heartRateAtTime: 64),
            .init(timestamp: 1800, reason: "Peak focus", oldBeatFrequency: 16, newBeatFrequency: 16, heartRateAtTime: 65),
            .init(timestamp: 1920, reason: "Cooldown", oldBeatFrequency: 16, newBeatFrequency: 15, heartRateAtTime: 66),
            .init(timestamp: 1920, reason: "End", oldBeatFrequency: 15, newBeatFrequency: 14, heartRateAtTime: 68),
            .init(timestamp: 1920, reason: "End state", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 68),
            .init(timestamp: 1920, reason: "Session end", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 68),
            .init(timestamp: 1920, reason: "Finalize", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 68),
            .init(timestamp: 1920, reason: "Complete", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 68),
            .init(timestamp: 1920, reason: "Done", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 68),
        ],
        wasCompleted: true
    )

    ShareCardContent(
        session: session,
        format: .stories
    )
    .frame(width: 360, height: 640)
    .scaleEffect(360.0 / 1080.0)
    .frame(width: 360 * (360.0 / 1080.0), height: 640 * (360.0 / 1080.0))
}

#Preview("Share Card - Square") {
    let session = FocusSession(
        startDate: Date().addingTimeInterval(-2400),
        mode: FocusMode.relaxation.rawValue,
        durationSeconds: 2400,
        averageHeartRate: 62,
        averageHRV: 58,
        minHeartRate: 56,
        maxHeartRate: 74,
        beatFrequencyStart: 10,
        beatFrequencyEnd: 8,
        carrierFrequency: 200,
        adaptationEvents: [
            .init(timestamp: 0, reason: "Start", oldBeatFrequency: 10, newBeatFrequency: 10, heartRateAtTime: 74),
            .init(timestamp: 480, reason: "Calming", oldBeatFrequency: 10, newBeatFrequency: 9, heartRateAtTime: 68),
            .init(timestamp: 960, reason: "Relaxed", oldBeatFrequency: 9, newBeatFrequency: 8, heartRateAtTime: 62),
            .init(timestamp: 1440, reason: "Deep relax", oldBeatFrequency: 8, newBeatFrequency: 8, heartRateAtTime: 58),
            .init(timestamp: 1920, reason: "Sustained", oldBeatFrequency: 8, newBeatFrequency: 8, heartRateAtTime: 56),
        ],
        wasCompleted: true
    )

    ShareCardContent(
        session: session,
        format: .square
    )
    .frame(width: 360, height: 360)
    .scaleEffect(360.0 / 1080.0)
    .frame(width: 360 * (360.0 / 1080.0), height: 360 * (360.0 / 1080.0))
}

#Preview("Share Card - No Biometrics") {
    let session = FocusSession(
        startDate: Date().addingTimeInterval(-1800),
        mode: FocusMode.sleep.rawValue,
        durationSeconds: 1800,
        beatFrequencyStart: 6,
        beatFrequencyEnd: 2,
        carrierFrequency: 150,
        adaptationEvents: [],
        wasCompleted: true
    )

    ShareCardContent(
        session: session,
        format: .stories
    )
    .frame(width: 360, height: 640)
    .scaleEffect(360.0 / 1080.0)
    .frame(width: 360 * (360.0 / 1080.0), height: 640 * (360.0 / 1080.0))
}
