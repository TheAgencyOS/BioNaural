// ContextTrackDetailView.swift
// BioNaural
//
// Detail view for a single context track. Shows header, locked audio
// configuration, calendar keywords, session stats, session history,
// and action buttons. All values from Theme tokens. Native SwiftUI. Dark-first.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - ContextTrackDetailView

struct ContextTrackDetailView: View {

    let track: ContextTrack

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    private var mode: FocusMode { track.focusMode ?? .focus }
    private var modeColor: Color { Color.modeColor(for: mode) }
    private var purpose: TrackPurpose { track.trackPurpose ?? .custom }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                headerSection
                configurationSection
                keywordsSection
                statsSection
                sessionHistorySection
                actionsSection
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .background(Theme.Colors.canvas)
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Track?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(track)
                dismiss()
            }
        } message: {
            Text("This will permanently remove \"\(track.name)\" and unlink it from all sessions.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: purpose.systemImageName)
                .font(Theme.Typography.title)
                .foregroundStyle(modeColor)
                .frame(
                    width: Theme.Spacing.mega,
                    height: Theme.Spacing.mega
                )
                .background(modeColor.opacity(Theme.Opacity.accentLight))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(track.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                purposeBadge
            }

            Spacer()
        }
    }

    private var purposeBadge: some View {
        Text(purpose.displayName)
            .font(Theme.Typography.small)
            .foregroundStyle(modeColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(modeColor.opacity(Theme.Opacity.accentLight))
            .clipShape(Capsule())
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        sectionCard(title: "Configuration") {
            VStack(spacing: Theme.Spacing.md) {
                if let ambient = track.lockedAmbientBedID {
                    configRow(
                        icon: "speaker.wave.2.fill",
                        label: "Ambient",
                        value: ambient.capitalized
                    )
                }

                configRow(
                    icon: mode.systemImageName,
                    label: "Mode",
                    value: mode.displayName,
                    valueColor: modeColor
                )

                if let carrier = track.lockedCarrierFrequency {
                    configRow(
                        icon: "waveform",
                        label: "Carrier frequency",
                        value: String(format: "%.0f Hz", carrier)
                    )
                }

                if let beatRange = track.lockedBeatFrequencyRange,
                   beatRange.count == 2 {
                    configRow(
                        icon: "waveform.path",
                        label: "Beat range",
                        value: String(
                            format: "%.0f\u{2013}%.0f Hz",
                            beatRange[0],
                            beatRange[1]
                        )
                    )
                }

                if !track.lockedMelodicTags.isEmpty {
                    configRow(
                        icon: "music.note",
                        label: "Melodic tags",
                        value: track.lockedMelodicTags.joined(separator: ", ")
                    )
                }
            }
        }
    }

    private func configRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = Theme.Colors.textPrimary
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: Theme.Spacing.xl)

            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.Typography.callout)
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Keywords

    @ViewBuilder
    private var keywordsSection: some View {
        if !track.linkedEventKeywords.isEmpty {
            sectionCard(title: "Calendar Keywords") {
                flowLayout(items: track.linkedEventKeywords)
            }
        }
    }

    private func flowLayout(items: [String]) -> some View {
        let rows = buildRows(items: items, maxPerRow: 4)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(rows[rowIndex], id: \.self) { keyword in
                        keywordPill(keyword)
                    }
                }
            }
        }
    }

    private func keywordPill(_ keyword: String) -> some View {
        Text(keyword)
            .font(Theme.Typography.small)
            .foregroundStyle(Theme.Colors.accent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Theme.Colors.accent.opacity(Theme.Opacity.accentLight))
            .clipShape(Capsule())
    }

    private func buildRows(items: [String], maxPerRow: Int) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count >= maxPerRow {
                rows.append(current)
                current = []
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    // MARK: - Stats

    private var statsSection: some View {
        sectionCard(title: "Stats") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: Theme.Spacing.md
            ) {
                statCell(
                    label: "Total sessions",
                    value: "\(track.totalSessionCount)",
                    icon: "play.circle"
                )

                statCell(
                    label: "Avg success",
                    value: track.averageSuccessScore.map {
                        "\(Int($0 * 100))%"
                    } ?? "\u{2014}",
                    icon: "chart.line.uptrend.xyaxis"
                )

                statCell(
                    label: "Created",
                    value: track.dateCreated.formatted(
                        date: .abbreviated,
                        time: .omitted
                    ),
                    icon: "calendar"
                )

                statCell(
                    label: "Active until",
                    value: track.activeUntil.map {
                        $0.formatted(date: .abbreviated, time: .omitted)
                    } ?? "Permanent",
                    icon: "clock"
                )
            }
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text(label)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Text(value)
                .font(Theme.Typography.data)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    // MARK: - Session History

    @ViewBuilder
    private var sessionHistorySection: some View {
        if !track.sessionIDs.isEmpty {
            sectionCard(title: "Session History") {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(
                        Array(track.sessionIDs.prefix(10).enumerated()),
                        id: \.element
                    ) { index, sessionID in
                        HStack(spacing: Theme.Spacing.md) {
                            Circle()
                                .fill(modeColor)
                                .frame(
                                    width: Theme.Spacing.sm,
                                    height: Theme.Spacing.sm
                                )

                            Text("Session \(index + 1)")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Spacer()

                            Text(sessionID.prefix(8) + "\u{2026}")
                                .font(Theme.Typography.dataSmall)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .padding(.vertical, Theme.Spacing.xxs)

                        if index < track.sessionIDs.prefix(10).count - 1 {
                            Divider()
                                .overlay(Theme.Colors.divider)
                        }
                    }

                    if track.sessionIDs.count > 10 {
                        Text("+\(track.sessionIDs.count - 10) more sessions")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Start session
            Button {
                // Action handled by parent navigation
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.fill")
                        .font(Theme.Typography.callout)

                    Text("Start Session with Track")
                        .font(Theme.Typography.headline)
                }
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(modeColor)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }

            // Archive
            Button {
                withAnimation(Theme.Animation.standard) {
                    track.isArchived.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: track.isArchived ? "tray.and.arrow.up" : "archivebox")
                        .font(Theme.Typography.callout)

                    Text(track.isArchived ? "Unarchive Track" : "Archive Track")
                        .font(Theme.Typography.callout)
                }
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }

            // Delete
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "trash")
                        .font(Theme.Typography.callout)

                    Text("Delete Track")
                        .font(Theme.Typography.callout)
                }
                .foregroundStyle(.red.opacity(Theme.Opacity.accentStrong))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Color.red.opacity(Theme.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }
        }
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(Theme.Typography.Tracking.uppercase)

            content()
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

// MARK: - Preview

#Preview("Track Detail") {
    NavigationStack {
        ContextTrackDetailView(
            track: ContextTrack(
                name: "Organic Chemistry",
                purpose: TrackPurpose.study.rawValue,
                linkedEventKeywords: ["exam", "final", "organic chemistry", "ochem"],
                lockedAmbientBedID: "rain",
                lockedCarrierFrequency: 375.0,
                lockedBeatFrequencyRange: [12.0, 20.0],
                lockedMelodicTags: ["piano", "ambient pad"],
                mode: FocusMode.focus.rawValue,
                sessionIDs: ["abc123", "def456", "ghi789"],
                totalSessionCount: 3,
                averageSuccessScore: 0.82,
                activeUntil: Calendar.current.date(
                    byAdding: .day,
                    value: 30,
                    to: Date()
                )
            )
        )
    }
    .preferredColorScheme(.dark)
}
