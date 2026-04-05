// FocusLiveActivity.swift
// BioNauralWidgets
//
// ActivityConfiguration for BioNaural's focus session Live Activity.
// Provides lock screen, Dynamic Island compact, expanded, and minimal
// presentations. All visual tokens reference Theme values — no hardcoded
// colors, fonts, or spacing.

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
                // Small orb circle in mode color
                orbCircle(size: WidgetConstants.DynamicIsland.compactOrbSize)
                    .foregroundStyle(modeColor(for: context.attributes.modeColorName))
            } compactTrailing: {
                // Timer counting up from session start
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
                // Minimal: small orb circle in mode color
                orbCircle(size: WidgetConstants.DynamicIsland.minimalOrbSize)
                    .foregroundStyle(modeColor(for: context.attributes.modeColorName))
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        HStack(spacing: WidgetConstants.Spacing.md) {
            // Thin vertical bar in mode color
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.sm,
                style: .continuous
            )
            .fill(modeColor(for: context.attributes.modeColorName))
            .frame(
                width: WidgetConstants.LockScreen.barWidth,
                height: WidgetConstants.LockScreen.barHeight
            )

            VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xxs) {
                Text(context.attributes.modeName)
                    .font(WidgetConstants.Fonts.caption)
                    .foregroundStyle(
                        modeColor(for: context.attributes.modeColorName)
                    )

                // Timer counting up from session start
                Text(
                    context.attributes.sessionStartDate,
                    style: .timer
                )
                .font(WidgetConstants.Fonts.timer)
                .foregroundStyle(WidgetConstants.Colors.textPrimary)
                .monospacedDigit()
            }

            Spacer()

            if context.state.isPlaying {
                // Subtle playing indicator — small pulsing orb
                orbCircle(size: WidgetConstants.LockScreen.orbSize)
                    .foregroundStyle(
                        modeColor(for: context.attributes.modeColorName)
                    )
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
        Image(systemName: modeIconName(for: colorName))
            .font(WidgetConstants.Fonts.headline)
            .foregroundStyle(modeColor(for: colorName))
    }

    @ViewBuilder
    private func expandedCenter(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        Text(context.attributes.modeName)
            .font(WidgetConstants.Fonts.caption)
            .foregroundStyle(WidgetConstants.Colors.textPrimary)
    }

    @ViewBuilder
    private func expandedTrailing(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        Text(
            Date(
                timeIntervalSinceNow: -Double(context.state.elapsedSeconds)
            ),
            style: .timer
        )
        .monospacedDigit()
        .font(WidgetConstants.Fonts.data)
        .foregroundStyle(WidgetConstants.Colors.textPrimary)
    }

    @ViewBuilder
    private func expandedBottom(
        context: ActivityViewContext<FocusActivityAttributes>
    ) -> some View {
        HStack(spacing: WidgetConstants.Spacing.lg) {
            // Heart rate (if available)
            if let hr = context.state.currentHR {
                Label {
                    Text("\(hr)")
                        .font(WidgetConstants.Fonts.dataSmall)
                        .foregroundStyle(WidgetConstants.Colors.textSecondary)
                } icon: {
                    Image(systemName: "heart.fill")
                        .font(WidgetConstants.Fonts.dataSmall)
                        .foregroundStyle(WidgetConstants.Colors.signalCalm)
                }
            }

            // Beat frequency
            Label {
                Text(
                    beatFrequencyFormatted(context.state.beatFrequency)
                )
                .font(WidgetConstants.Fonts.dataSmall)
                .foregroundStyle(WidgetConstants.Colors.textSecondary)
            } icon: {
                Image(systemName: "waveform.path")
                    .font(WidgetConstants.Fonts.dataSmall)
                    .foregroundStyle(
                        modeColor(for: context.attributes.modeColorName)
                            .opacity(WidgetConstants.Opacity.accentStrong)
                    )
            }
        }
    }

    // MARK: - Orb Circle

    /// A small filled circle representing the Orb in miniature.
    /// Uses radial gradient for a soft-edged glow effect even at small sizes.
    private func orbCircle(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(WidgetConstants.Opacity.medium),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .overlay(
                Circle()
                    .fill(.tint)
                    .padding(size * WidgetConstants.DynamicIsland.orbInsetFraction)
            )
            .frame(width: size, height: size)
    }

    // MARK: - Helpers

    /// Resolves a mode color name string to the corresponding SwiftUI Color.
    private func modeColor(for colorName: String) -> Color {
        switch colorName {
        case "focus":
            return Color(hex: WidgetConstants.ModeHex.focus)
        case "relaxation":
            return Color(hex: WidgetConstants.ModeHex.relaxation)
        case "sleep":
            return Color(hex: WidgetConstants.ModeHex.sleep)
        default:
            return Color(hex: WidgetConstants.ModeHex.accent)
        }
    }

    /// Returns the SF Symbol name for a given mode.
    private func modeIconName(for colorName: String) -> String {
        switch colorName {
        case "focus":       return "circle.circle.fill"
        case "relaxation":  return "wind"
        case "sleep":       return "moon.fill"
        default:            return "circle.fill"
        }
    }

    /// Formats beat frequency to one decimal place with Hz suffix.
    private func beatFrequencyFormatted(_ hz: Double) -> String {
        let formatted = String(format: "%.1f", hz)
        return "\(formatted) Hz"
    }
}
