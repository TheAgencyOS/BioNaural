// ExploreView.swift
// BioNaural
//
// "Everything in one place" — a premium hub surfacing all four modes
// with rich cards, recent session activity, and session stats.
// Atmospheric background, glass cards, radial glows per mode.
// All values from Theme tokens. Native SwiftUI.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - ExploreView

struct ExploreView: View {

    @Environment(AppDependencies.self) private var dependencies

    @Query(sort: \FocusSession.startDate, order: .reverse)
    private var recentSessions: [FocusSession]

    private let modes: [FocusMode] = [.focus, .relaxation, .sleep, .energize]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                statsStrip
                    .padding(.horizontal, Theme.Spacing.pageMargin)

                modesSection
                    .padding(.horizontal, Theme.Spacing.pageMargin)

                recentSection
                    .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background { NebulaBokehBackground() }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: Theme.Spacing.md) {
            statPill(
                value: "\(recentSessions.count)",
                label: "Sessions",
                icon: "waveform.circle.fill",
                color: Theme.Colors.accent
            )

            statPill(
                value: "\(totalMinutes)",
                label: "Minutes",
                icon: "clock.fill",
                color: Theme.Colors.signalCalm
            )

            statPill(
                value: completionRate,
                label: "Completed",
                icon: "checkmark.circle.fill",
                color: Theme.Colors.focus
            )
        }
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                .foregroundStyle(color.opacity(Theme.Opacity.half))

            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(label)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )
        )
    }

    // MARK: - Modes

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Modes")

            VStack(spacing: Theme.Spacing.md) {
                ForEach(modes, id: \.self) { mode in
                    NavigationLink(value: AppDestination.session(mode)) {
                        modeCard(mode)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func modeCard(_ mode: FocusMode) -> some View {
        let color = Color.modeColor(for: mode)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )

            // Mode color glow
            RadialGradient(
                colors: [color.opacity(Theme.Opacity.accentLight), Color.clear],
                center: .leading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 3
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

            HStack(spacing: Theme.Spacing.xl) {
                // Orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(Theme.Opacity.half), color.opacity(Theme.Opacity.light), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: Theme.Spacing.xxl
                        )
                    )
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(mode.displayName)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(mode.cardDescription)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Play arrow
                Image(systemName: "play.fill")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(color.opacity(Theme.Opacity.half))
                    .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                    .background(
                        Circle()
                            .fill(color.opacity(Theme.Opacity.light))
                    )
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // MARK: - Recent Sessions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionLabel("Recent")

            if recentSessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                        recentRow(session)

                        if index < min(recentSessions.count - 1, 4) {
                            Rectangle()
                                .fill(Theme.Colors.divider.opacity(Theme.Opacity.half))
                                .frame(height: Theme.Radius.glassStroke)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                                .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                        )
                )
            }
        }
    }

    private func recentRow(_ session: FocusSession) -> some View {
        let mode = FocusMode(rawValue: session.mode) ?? .focus
        let color = Color.modeColor(for: mode)

        return HStack(spacing: Theme.Spacing.md) {
            // Mode indicator
            Circle()
                .fill(color)
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(mode.displayName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(session.startDate.formatted(.relative(presentation: .named)))
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer()

            Text(formattedDuration(session.durationSeconds))
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "waveform.path")
                .font(.system(size: Theme.Typography.Size.title, weight: .light))
                .foregroundStyle(Theme.Colors.accent.opacity(Theme.Opacity.medium))

            Text("Your sessions will appear here")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.Colors.divider.opacity(Theme.Opacity.half), lineWidth: Theme.Radius.glassStroke)
                )
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.small)
            .tracking(Theme.Typography.Tracking.uppercase)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var totalMinutes: Int {
        recentSessions.reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var completionRate: String {
        guard !recentSessions.isEmpty else { return "0%" }
        let completed = recentSessions.filter(\.wasCompleted).count
        let rate = Int(Double(completed) / Double(recentSessions.count) * 100)
        return "\(rate)%"
    }
}

// MARK: - Preview

#Preview("Explore") {
    NavigationStack {
        ExploreView()
    }
    .environment(AppDependencies())
    .preferredColorScheme(.dark)
}
