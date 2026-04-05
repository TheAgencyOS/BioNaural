// ContextTrackLibraryView.swift
// BioNaural
//
// Library view showing all context tracks grouped by active/archived status.
// Each track appears as a card with mode color, purpose icon, session stats,
// and expiry date. Supports creating new study tracks, archiving, and deleting.
// All values from Theme tokens. Native SwiftUI. Dark-first.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - ContextTrackLibraryView

struct ContextTrackLibraryView: View {

    @Query(sort: \ContextTrack.dateCreated, order: .reverse)
    private var allTracks: [ContextTrack]

    @Environment(\.modelContext) private var modelContext

    @State private var showingSetup = false
    @State private var showArchived = false
    @State private var trackToDelete: ContextTrack? = nil

    private var activeTracks: [ContextTrack] {
        allTracks.filter { $0.isActive }
    }

    private var archivedTracks: [ContextTrack] {
        allTracks.filter { !$0.isActive }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentedPicker

                Group {
                    if showArchived {
                        archivedContent
                    } else {
                        activeContent
                    }
                }
                .animation(Theme.Animation.standard, value: showArchived)
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Your Tracks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSetup = true
                    } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .accessibilityLabel("Create new track")
                }
            }
            .sheet(isPresented: $showingSetup) {
                StudyTrackSetupView { _ in }
            }
            .alert(
                "Delete Track?",
                isPresented: .init(
                    get: { trackToDelete != nil },
                    set: { if !$0 { trackToDelete = nil } }
                ),
                presenting: trackToDelete
            ) { track in
                Button("Delete", role: .destructive) {
                    withAnimation(Theme.Animation.standard) {
                        modelContext.delete(track)
                    }
                    trackToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    trackToDelete = nil
                }
            } message: { track in
                Text("This will permanently remove \"\(track.name)\". This action cannot be undone.")
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        Picker("Filter", selection: $showArchived) {
            Text("Active").tag(false)
            Text("Archived").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Active Content

    private var activeContent: some View {
        Group {
            if activeTracks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(Array(activeTracks.enumerated()), id: \.element.id) { index, track in
                            NavigationLink {
                                ContextTrackDetailView(track: track)
                            } label: {
                                trackCard(track, dimmed: false)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                            .animation(
                                Theme.Animation.staggeredFadeIn(index: index),
                                value: activeTracks.count
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.jumbo)
                }
            }
        }
    }

    // MARK: - Archived Content

    private var archivedContent: some View {
        Group {
            if archivedTracks.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()

                    Image(systemName: "archivebox")
                        .font(Theme.Typography.display)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    Text("No archived tracks")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(Array(archivedTracks.enumerated()), id: \.element.id) { index, track in
                            NavigationLink {
                                ContextTrackDetailView(track: track)
                            } label: {
                                trackCard(track, dimmed: true)
                            }
                            .buttonStyle(.plain)
                            .animation(
                                Theme.Animation.staggeredFadeIn(index: index),
                                value: archivedTracks.count
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.jumbo)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("No tracks yet")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Create a study track to boost your recall.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingSetup = true
            } label: {
                Text("Create Track")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }
            .padding(.top, Theme.Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    // MARK: - Track Card

    private func trackCard(_ track: ContextTrack, dimmed: Bool) -> some View {
        let mode = track.focusMode ?? .focus
        let modeColor = Color.modeColor(for: mode)
        let purpose = track.trackPurpose ?? .custom

        return HStack(spacing: Theme.Spacing.md) {
            // Leading icon
            Image(systemName: purpose.systemImageName)
                .font(Theme.Typography.headline)
                .foregroundStyle(modeColor)
                .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
                .background(modeColor.opacity(Theme.Opacity.accentLight))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(track.name)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(purpose.displayName)
                        .font(Theme.Typography.small)
                        .foregroundStyle(modeColor)

                    if track.totalSessionCount > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Text("\(track.totalSessionCount) sessions")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if let score = track.averageSuccessScore {
                        Text("\u{00B7}")
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Text("\(Int(score * 100))% avg")
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                if let expiry = track.activeUntil {
                    Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            // Trailing chevron
            Image(systemName: "chevron.right")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .opacity(dimmed ? Theme.Opacity.half : Theme.Opacity.full)
        .contextMenu {
            contextMenuItems(for: track)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for track: ContextTrack) -> some View {
        Button {
            withAnimation(Theme.Animation.standard) {
                track.isArchived.toggle()
            }
        } label: {
            Label(
                track.isArchived ? "Unarchive" : "Archive",
                systemImage: track.isArchived ? "tray.and.arrow.up" : "archivebox"
            )
        }

        Button(role: .destructive) {
            trackToDelete = track
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview("Track Library") {
    ContextTrackLibraryView()
        .preferredColorScheme(.dark)
}
