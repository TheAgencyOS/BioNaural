// ShareableMapGenerator.swift
// BioNaural
//
// Generates shareable images of the session's adaptation map using SwiftUI's
// ImageRenderer. Supports Stories (1080x1920) and landscape (1920x1080) formats.
// Dark background with adaptation map, mode name, duration, and BioNaural wordmark.

import SwiftUI
import BioNauralShared

// MARK: - ShareableMapGenerator

@MainActor
enum ShareableMapGenerator {

    // MARK: - Output Format

    enum ShareFormat {
        /// 1080x1920 — Instagram/TikTok Stories.
        case stories
        /// 1920x1080 — landscape (Twitter, LinkedIn).
        case landscape

        var size: CGSize {
            switch self {
            case .stories:   return CGSize(width: 1080, height: 1920)
            case .landscape: return CGSize(width: 1920, height: 1080)
            }
        }
    }

    // MARK: - Generation

    /// Renders a shareable image containing the adaptation map and session metadata.
    ///
    /// - Parameters:
    ///   - events: The adaptation events from the session.
    ///   - sessionDuration: Total session duration in seconds.
    ///   - mode: The session's focus mode.
    ///   - format: The output image format.
    /// - Returns: A rendered `UIImage`, or `nil` if rendering fails.
    static func generate(
        events: [AdaptationEventRecord],
        sessionDuration: TimeInterval,
        mode: FocusMode,
        format: ShareFormat
    ) -> UIImage? {
        let content = ShareableMapContent(
            events: events,
            sessionDuration: sessionDuration,
            mode: mode,
            size: format.size
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1.0 // Render at exact pixel dimensions.
        return renderer.uiImage
    }
}

// MARK: - ShareableMapContent

/// The SwiftUI view composed for image rendering.
private struct ShareableMapContent: View {

    let events: [AdaptationEventRecord]
    let sessionDuration: TimeInterval
    let mode: FocusMode
    let size: CGSize

    var body: some View {
        ZStack {
            // Dark background.
            Theme.Colors.canvas

            VStack(spacing: Theme.Spacing.xxxl) {
                Spacer()

                // Mode name.
                Text(mode.displayName.uppercased())
                    .font(Theme.Typography.headline)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .foregroundStyle(Color.modeColor(for: mode))
                    .accessibilityLabel("\(mode.displayName) session")

                // Adaptation map.
                AdaptationMapView(
                    events: events,
                    sessionDuration: sessionDuration,
                    mode: mode
                )
                .frame(height: mapHeight)
                .padding(.horizontal, Theme.Spacing.jumbo)

                // Duration label.
                Text(sessionDuration.formattedDuration)
                    .font(Theme.Typography.timer)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityLabel("Duration: \(sessionDuration.formattedDuration)")

                Spacer()

                // BioNaural wordmark.
                Text("BioNaural")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.bottom, Theme.Spacing.jumbo)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var mapHeight: CGFloat {
        size.height * mapHeightFraction
    }

    private var mapHeightFraction: CGFloat {
        // Map takes ~5% of image height.
        0.05
    }
}

// MARK: - Preview

#Preview("Shareable Map - Stories") {
    let events: [AdaptationEventRecord] = [
        .init(timestamp: 0, reason: "Start", oldBeatFrequency: 14, newBeatFrequency: 14, heartRateAtTime: 72),
        .init(timestamp: 600, reason: "HR rising", oldBeatFrequency: 14, newBeatFrequency: 12, heartRateAtTime: 80),
        .init(timestamp: 1200, reason: "Settled", oldBeatFrequency: 12, newBeatFrequency: 16, heartRateAtTime: 70),
    ]

    ShareableMapContent(
        events: events,
        sessionDuration: 1500,
        mode: .focus,
        size: CGSize(width: 360, height: 640) // Scaled down for preview.
    )
}
