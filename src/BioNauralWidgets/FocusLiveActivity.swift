// FocusLiveActivity.swift
// BioNauralWidgets
//
// ActivityConfiguration for BioNaural's focus session Live Activity.
// Provides lock screen, Dynamic Island compact, expanded, and minimal
// presentations. Premium visual treatment with multi-layer orb blooms,
// wavelength accents, and rich typography hierarchy.

import ActivityKit
import SwiftUI
import WidgetKit
import BioNauralShared

// MARK: - FocusLiveActivity

struct FocusLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // MARK: Lock Screen / Banner Presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded Regions
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                // Orb with subtle bloom
                orbCompact(colorName: context.attributes.modeColorName)
            } compactTrailing: {
                // Timer counting up
                Text(
                    Date(
                        timeIntervalSinceNow: -Double(context.state.elapsedSeconds)
                    ),
                    style: .timer
                )
                .monospacedDigit()
                .font(WidgetConstants.Fonts.dataSmall)
                .foregroundStyle(WidgetConstants.Colors.textSecondary)
            } minimal: {
                // Minimal: orb dot with bloom halo
                orbMinimal(colorName: context.attributes.modeColorName)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        let color = modeColor(for: context.attributes.modeColorName)

        HStack(spacing: WidgetConstants.Spacing.md) {
            // Accent bar — vertical gradient in mode color
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.sm,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        color,
                        color.opacity(WidgetConstants.Opacity.medium)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(
                width: WidgetConstants.LockScreen.barWidth,
                height: WidgetConstants.LockScreen.barHeight
            )

            // Session info
            VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xxs) {
                // Mode name in accent color
                Text(context.attributes.modeName)
                    .font(WidgetConstants.Fonts.caption)
                    .foregroundStyle(color)
                    .tracking(WidgetConstants.Tracking.uppercase)
                    .textCase(.uppercase)

                // Timer — large, airy, monospaced
                Text(
                    context.attributes.sessionStartDate,
                    style: .timer
                )
                .font(WidgetConstants.Fonts.timer)
                .foregroundStyle(WidgetConstants.Colors.textPrimary)
                .monospacedDigit()
                .tracking(WidgetConstants.Tracking.data)
            }

            Spacer()

            // Playing indicator — orb with bloom halo
            if context.state.isPlaying {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(WidgetConstants.Opacity.accentLight),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: WidgetConstants.LockScreen.orbBloomSize / 2
                            )
                        )
                        .frame(
                            width: WidgetConstants.LockScreen.orbBloomSize,
                            height: WidgetConstants.LockScreen.orbBloomSize
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(WidgetConstants.Opacity.accentStrong),
                                    color.opacity(WidgetConstants.Opacity.medium),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: WidgetConstants.LockScreen.orbSize / 2
                            )
                        )
                        .frame(
                            width: WidgetConstants.LockScreen.orbSize,
                            height: WidgetConstants.LockScreen.orbSize
                        )

                    Circle()
                        .fill(.white.opacity(WidgetConstants.Opacity.half))
                        .frame(width: 3, height: 3)
                }
            }
        }
        .padding(.horizontal, WidgetConstants.Spacing.lg)
        .padding(.vertical, WidgetConstants.Spacing.md)
        .background(WidgetConstants.Colors.canvas)
        .activityBackgroundTint(WidgetConstants.Colors.canvas)
    }

    // MARK: - Expanded Regions

    @ViewBuilder
    private func expandedLeading(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        let colorName = context.attributes.modeColorName
        let color = modeColor(for: colorName)

        // Mode icon with colored background container
        ZStack {
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.sm,
                style: .continuous
            )
            .fill(color.opacity(WidgetConstants.Opacity.accentLight))
            .frame(
                width: WidgetConstants.DynamicIsland.expandedOrbSize,
                height: WidgetConstants.DynamicIsland.expandedOrbSize
            )

            Image(systemName: modeIconName(for: colorName))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func expandedCenter(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        VStack(spacing: WidgetConstants.Spacing.xxs) {
            Text(context.attributes.modeName)
                .font(WidgetConstants.Fonts.caption)
                .foregroundStyle(WidgetConstants.Colors.textPrimary)

            Text(
                Date(
                    timeIntervalSinceNow: -Double(context.state.elapsedSeconds)
                ),
                style: .timer
            )
            .monospacedDigit()
            .font(WidgetConstants.Fonts.data)
            .foregroundStyle(WidgetConstants.Colors.textPrimary)
            .tracking(WidgetConstants.Tracking.data)
        }
    }

    @ViewBuilder
    private func expandedTrailing(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        let color = modeColor(for: context.attributes.modeColorName)

        // Mini orb indicator
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(WidgetConstants.Opacity.medium),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.DynamicIsland.expandedOrbSize / 2
                    )
                )
                .frame(
                    width: WidgetConstants.DynamicIsland.expandedOrbSize,
                    height: WidgetConstants.DynamicIsland.expandedOrbSize
                )

            Circle()
                .fill(color.opacity(WidgetConstants.Opacity.accentStrong))
                .frame(width: 10, height: 10)

            Circle()
                .fill(.white.opacity(WidgetConstants.Opacity.half))
                .frame(width: 3, height: 3)
        }
    }

    @ViewBuilder
    private func expandedBottom(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        let color = modeColor(for: context.attributes.modeColorName)

        VStack(spacing: WidgetConstants.Spacing.sm) {
            // Metrics row
            HStack(spacing: WidgetConstants.Spacing.lg) {
                // Heart rate
                if let hr = context.state.currentHR {
                    Label {
                        Text("\(hr)")
                            .font(WidgetConstants.Fonts.dataSmall)
                            .foregroundStyle(WidgetConstants.Colors.textSecondary)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetConstants.Colors.signalCalm)
                    }
                }

                // Beat frequency
                Label {
                    Text(beatFrequencyFormatted(context.state.beatFrequency))
                        .font(WidgetConstants.Fonts.dataSmall)
                        .foregroundStyle(WidgetConstants.Colors.textSecondary)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color)
                }
            }

            // Decorative wavelength accent
            WidgetConstants.wavelengthPath(
                width: 180,
                height: WidgetConstants.DynamicIsland.wavelengthHeight,
                cycles: 3.0
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        color.opacity(WidgetConstants.Opacity.accentLight),
                        color.opacity(WidgetConstants.Opacity.accentLight),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: WidgetConstants.DynamicIsland.wavelengthStroke
            )
            .frame(width: 180, height: WidgetConstants.DynamicIsland.wavelengthHeight)
        }
    }

    // MARK: - Compact Orb

    /// Compact leading: small orb with subtle radial bloom.
    private func orbCompact(colorName: String) -> some View {
        let color = modeColor(for: colorName)
        let size = WidgetConstants.DynamicIsland.compactOrbSize

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(WidgetConstants.Opacity.medium),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 2, height: size * 2)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Minimal Orb

    /// Minimal presentation: tiny orb with halo.
    private func orbMinimal(colorName: String) -> some View {
        let color = modeColor(for: colorName)
        let size = WidgetConstants.DynamicIsland.minimalOrbSize

        return ZStack {
            Circle()
                .fill(color.opacity(WidgetConstants.Opacity.medium))
                .frame(width: size + 4, height: size + 4)
                .blur(radius: 2)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Helpers

    private func modeColor(for colorName: String) -> Color {
        switch colorName {
        case "focus":       return Color(hex: WidgetConstants.ModeHex.focus)
        case "relaxation":  return Color(hex: WidgetConstants.ModeHex.relaxation)
        case "sleep":       return Color(hex: WidgetConstants.ModeHex.sleep)
        case "energize":    return Color(hex: WidgetConstants.ModeHex.energize)
        default:            return Color(hex: WidgetConstants.ModeHex.accent)
        }
    }

    private func modeIconName(for colorName: String) -> String {
        switch colorName {
        case "focus":       return "scope"
        case "relaxation":  return "wind"
        case "sleep":       return "moon.fill"
        case "energize":    return "bolt.fill"
        default:            return "circle.fill"
        }
    }

    private func beatFrequencyFormatted(_ hz: Double) -> String {
        let formatted = String(format: "%.1f", hz)
        return "\(formatted) Hz"
    }
}
