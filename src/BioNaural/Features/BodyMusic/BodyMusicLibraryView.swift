// BodyMusicLibraryView.swift
// BioNaural
//
// Library of saved session tracks ("Body Music"). Users browse, filter,
// and favorite tracks their body composed during adaptive sessions.
// All values from Theme tokens. Native SwiftUI throughout.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - BodyMusicLibraryView

struct BodyMusicLibraryView: View {

    // MARK: - Data

    @Query(sort: \SavedTrack.dateSaved, order: .reverse)
    private var savedTracks: [SavedTrack]

    // MARK: - State

    @State private var selectedTrack: SavedTrack? = nil
    @State private var filterMode: FocusMode? = nil
    @State private var showFavoritesOnly: Bool = false
    @State private var contentAppeared = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.Spacing.lg) {
                    filterBar
                        .padding(.top, Theme.Spacing.sm)

                    if filteredTracks.isEmpty {
                        emptyState
                    } else {
                        trackList
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .navigationTitle("Body Music")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SavedTrack.ID.self) { trackID in
                if let track = savedTracks.first(where: { $0.id == trackID }) {
                    SavedTrackDetailView(track: track)
                }
            }
            .onAppear {
                guard !reduceMotion else {
                    contentAppeared = true
                    return
                }
                withAnimation(Theme.Animation.standard) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Filtered Tracks

    private var filteredTracks: [SavedTrack] {
        savedTracks.filter { track in
            let matchesMode: Bool
            if let filterMode {
                matchesMode = track.focusMode == filterMode
            } else {
                matchesMode = true
            }

            let matchesFavorite: Bool
            if showFavoritesOnly {
                matchesFavorite = track.isFavorite
            } else {
                matchesFavorite = true
            }

            return matchesMode && matchesFavorite
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                filterCapsule(label: "All", mode: nil)

                ForEach(FocusMode.allCases) { mode in
                    filterCapsule(label: mode.displayName, mode: mode)
                }

                favoritesToggle
            }
            .padding(.horizontal, Theme.Spacing.xxs)
        }
    }

    private func filterCapsule(label: String, mode: FocusMode?) -> some View {
        let isSelected = filterMode == mode

        return Button {
            withAnimation(Theme.Animation.standard) {
                filterMode = mode
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let mode {
                    Image(systemName: mode.systemImageName)
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(
                            isSelected
                                ? Theme.Colors.textOnAccent
                                : Color.modeColor(for: mode)
                        )
                }

                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.textOnAccent
                            : Theme.Colors.textPrimary
                    )
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? (mode.map { Color.modeColor(for: $0) } ?? Theme.Colors.accent)
                            : Theme.Colors.surface
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.clear
                            : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var favoritesToggle: some View {
        Button {
            withAnimation(Theme.Animation.standard) {
                showFavoritesOnly.toggle()
            }
        } label: {
            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                .font(.system(size: Theme.Typography.Size.caption))
                .foregroundStyle(
                    showFavoritesOnly
                        ? Theme.Colors.signalPeak
                        : Theme.Colors.textSecondary
                )
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(
                            showFavoritesOnly
                                ? Theme.Colors.signalPeak.opacity(Theme.Opacity.light)
                                : Theme.Colors.surface
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            showFavoritesOnly
                                ? Theme.Colors.signalPeak.opacity(Theme.Opacity.dim)
                                : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Favorites only")
        .accessibilityAddTraits(showFavoritesOnly ? .isSelected : [])
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "waveform.path")
                .font(.system(size: Theme.Spacing.jumbo))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("Your body hasn't composed anything yet.")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Complete a session to save your first track.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.mega)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Track List

    private var trackList: some View {
        LazyVStack(spacing: Theme.Spacing.md) {
            ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                NavigationLink(value: track.id) {
                    TrackCardView(track: track)
                }
                .buttonStyle(.plain)
                .staggeredFadeIn(index: index, isVisible: contentAppeared)
            }
        }
    }
}

// MARK: - TrackCardView

private struct TrackCardView: View {

    let track: SavedTrack

    @Environment(\.modelContext) private var modelContext

    private var trackModeColor: Color {
        track.focusMode.map { Color.modeColor(for: $0) } ?? Theme.Colors.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            topRow
            metadataRow
            MiniAdaptationWave(
                timelineData: track.adaptationTimeline,
                modeColor: trackModeColor
            )
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(trackModeColor.opacity(Theme.Opacity.accentLight))
                    .frame(
                        width: Theme.Spacing.xxxl,
                        height: Theme.Spacing.xxxl
                    )

                Image(systemName: track.focusMode?.systemImageName ?? "waveform.path")
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(trackModeColor)
            }

            Text(track.name)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(Theme.Animation.standard) {
                    track.isFavorite.toggle()
                }
            } label: {
                Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: Theme.Typography.Size.body))
                    .foregroundStyle(
                        track.isFavorite
                            ? Theme.Colors.signalPeak
                            : Theme.Colors.textTertiary
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(track.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            metadataLabel(
                text: Self.dateFormatter.string(from: track.dateSaved),
                icon: "calendar"
            )

            metadataLabel(
                text: track.formattedDuration,
                icon: "clock"
            )

            if let hr = track.averageHeartRate {
                metadataLabel(
                    text: "\(Int(hr)) BPM",
                    icon: "heart.fill"
                )
            }
        }
    }

    private func metadataLabel(text: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.small))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let mode = track.focusMode?.displayName ?? track.mode.capitalized
        let fav = track.isFavorite ? ", favorite" : ""
        return "\(track.name), \(mode), \(track.formattedDuration)\(fav)"
    }

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.doesRelativeDateFormatting = true
        return f
    }()
}

// MARK: - MiniAdaptationWave

struct MiniAdaptationWave: View {

    let timelineData: Data?
    let modeColor: Color

    private var snapshots: [AdaptationSnapshot] {
        guard let data = timelineData else { return [] }
        return BodyMusicRecorder.decodeTimeline(data)
    }

    var body: some View {
        Canvas { context, size in
            let points = snapshots
            if points.count >= 2 {
                drawAdaptationPath(context: context, size: size, snapshots: points)
            } else {
                drawStaticLine(context: context, size: size)
            }
        }
        .frame(height: Theme.Spacing.xxxl)
        .accessibilityHidden(true)
    }

    // MARK: - Adaptation Path

    private func drawAdaptationPath(
        context: GraphicsContext,
        size: CGSize,
        snapshots: [AdaptationSnapshot]
    ) {
        guard let firstTimestamp = snapshots.first?.timestamp,
              let lastTimestamp = snapshots.last?.timestamp,
              lastTimestamp > firstTimestamp else {
            drawStaticLine(context: context, size: size)
            return
        }

        let frequencies = snapshots.map(\.beatFrequency)
        let minFreq = frequencies.min() ?? 0
        let maxFreq = frequencies.max() ?? 1
        let freqRange = maxFreq - minFreq
        let effectiveRange = freqRange > 0 ? freqRange : 1.0

        let timeRange = lastTimestamp - firstTimestamp
        let verticalPadding: CGFloat = Theme.Spacing.xxs

        var path = Path()
        for (index, snapshot) in snapshots.enumerated() {
            let x = CGFloat((snapshot.timestamp - firstTimestamp) / timeRange) * size.width
            let normalizedY = CGFloat((snapshot.beatFrequency - minFreq) / effectiveRange)
            let y = verticalPadding + (1.0 - normalizedY) * (size.height - verticalPadding * 2)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .color(modeColor.opacity(Theme.Opacity.medium)),
            style: StrokeStyle(lineWidth: waveStrokeWidth, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Static Line

    private func drawStaticLine(context: GraphicsContext, size: CGSize) {
        var path = Path()
        let y = size.height / 2
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))

        context.stroke(
            path,
            with: .color(modeColor.opacity(Theme.Opacity.medium)),
            style: StrokeStyle(lineWidth: waveStrokeWidth, lineCap: .round)
        )
    }

    // MARK: - Constants

    private let waveStrokeWidth: CGFloat = Theme.Radius.legendStroke
}

// MARK: - Preview

#Preview("Body Music Library — Populated") {
    BodyMusicLibraryView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SavedTrack.self, inMemory: true)
}

#Preview("Body Music Library — Empty") {
    BodyMusicLibraryView()
        .preferredColorScheme(.dark)
        .modelContainer(for: SavedTrack.self, inMemory: true)
}
