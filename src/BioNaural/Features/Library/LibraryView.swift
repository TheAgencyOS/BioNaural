// LibraryView.swift
// BioNaural
//
// Premium library hub with visual hierarchy: hero composition card,
// compact horizontal scroll for remaining compositions, list-style
// Sessions rows, and a 2-column Correlations grid.
// Dark-first design, glass cards, staggered animations, full a11y.
// All values from Theme tokens. No hardcoded numbers.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - LibraryDestination

/// Navigation destinations reachable from the Library hub.
enum LibraryDestination: Hashable {
    case compositions
    case bodyMusic
    case sonicMemories
}

// MARK: - LibraryView

struct LibraryView: View {

    // MARK: - Data

    @Query(sort: \CustomComposition.createdDate, order: .reverse)
    private var compositions: [CustomComposition]

    @Query(sort: \SavedTrack.dateSaved, order: .reverse)
    private var savedTracks: [SavedTrack]

    @Query(sort: \SonicMemory.dateCreated, order: .reverse)
    private var sonicMemories: [SonicMemory]

    // MARK: - State

    @State private var sectionsVisible = false

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var isLibraryEmpty: Bool {
        compositions.isEmpty && savedTracks.isEmpty && sonicMemories.isEmpty
    }

    private var heroComposition: CustomComposition? {
        compositions.first
    }

    private var remainingCompositions: [CustomComposition] {
        Array(compositions.dropFirst().prefix(Constants.Library.maxPreviewItems))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLibraryEmpty {
                    emptyState
                } else {
                    libraryContent
                }
            }
            .background { NebulaBokehBackground() }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .compositions:
                    ComposerView()
                case .bodyMusic:
                    BodyMusicLibraryView()
                case .sonicMemories:
                    SonicMemoryListView()
                }
            }
            .onAppear {
                guard !reduceMotion else {
                    sectionsVisible = true
                    return
                }
                withAnimation(Theme.Animation.standard) {
                    sectionsVisible = true
                }
            }
            .task {
                DemoContentSeeder.seedIfNeeded(in: modelContext)
            }
        }
    }

    // MARK: - Library Content

    private var libraryContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                // Hero + remaining compositions
                if !compositions.isEmpty {
                    compositionsSection
                        .staggeredFadeIn(index: 0, isVisible: sectionsVisible)
                }

                // Sessions — compact list rows
                if !savedTracks.isEmpty {
                    bodyMusicSection
                        .staggeredFadeIn(index: 1, isVisible: sectionsVisible)
                }

                // Correlations — 2-column grid
                if !sonicMemories.isEmpty {
                    sonicMemoriesSection
                        .staggeredFadeIn(index: 2, isVisible: sectionsVisible)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
    }

    // MARK: - Compositions Section

    private var compositionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "COMPOSITIONS", destination: .compositions)

            // Hero card — full-width, tall
            if let hero = heroComposition {
                LibraryHeroCompositionCard(composition: hero)
                    .staggeredFadeIn(index: 0, isVisible: sectionsVisible)
            }

            // Remaining compositions — compact horizontal scroll
            if !remainingCompositions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Theme.Spacing.sm) {
                        ForEach(
                            Array(remainingCompositions.enumerated()),
                            id: \.element.id
                        ) { index, composition in
                            LibraryCompactCompositionCard(composition: composition)
                                .frame(width: Constants.Library.compactCardWidth)
                                .staggeredFadeIn(index: index + 1, isVisible: sectionsVisible)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxs)
                }
            }
        }
    }

    // MARK: - Sessions Section

    private var bodyMusicSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "BODY MUSIC", destination: .bodyMusic)

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(
                    Array(savedTracks.prefix(Constants.Library.maxListItems).enumerated()),
                    id: \.element.id
                ) { index, track in
                    LibraryTrackRow(track: track)
                        .staggeredFadeIn(index: index, isVisible: sectionsVisible)
                }
            }
        }
    }

    // MARK: - Correlations Section

    private var sonicMemoriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "SONIC MEMORIES", destination: .sonicMemories)

            let columns = [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ]

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(
                    Array(sonicMemories.prefix(Constants.Library.maxGridItems).enumerated()),
                    id: \.element.id
                ) { index, memory in
                    LibrarySonicMemoryCard(memory: memory)
                        .staggeredFadeIn(index: index, isVisible: sectionsVisible)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, destination: LibraryDestination) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.small)
                .tracking(Theme.Typography.Tracking.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)

            Spacer()

            NavigationLink(value: destination) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text("See All")
                        .font(Theme.Typography.caption)

                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.Typography.Size.small))
                }
                .foregroundStyle(Theme.Colors.accent)
            }
            .accessibilityLabel("See all \(title.lowercased())")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: Theme.Spacing.jumbo))
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Your library is empty")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Start a session or create a composition to build your collection.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxxl)

            NavigationLink(value: LibraryDestination.compositions) {
                Text("Create a composition")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent, in: Capsule())
            }
            .accessibilityLabel("Create your first composition")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Constants

private extension Constants {

    enum Library {
        /// Maximum items in the horizontal composition scroll (excluding hero).
        static let maxPreviewItems: Int = 4

        /// Maximum Sessions rows shown.
        static let maxListItems: Int = 5

        /// Maximum Correlation grid items.
        static let maxGridItems: Int = 6

        /// Compact composition card width.
        static let compactCardWidth: CGFloat = Theme.Spacing.mega * 2

        /// Hero card aspect ratio (width:height).
        static let heroAspectRatio: CGFloat = 16 / 9

        /// Track row icon size.
        static let trackIconSize: CGFloat = Theme.Spacing.jumbo
    }
}

// MARK: - Hero Composition Card

/// Full-width hero card for the most recent composition. Shows wave
/// visualization, mode badge, composition name, and duration.
private struct LibraryHeroCompositionCard: View {

    let composition: CustomComposition

    private var mode: FocusMode {
        composition.focusMode ?? .focus
    }

    private var modeColor: Color {
        Color.modeColor(for: mode)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Mode-colored radial glow
            RadialGradient(
                colors: [
                    modeColor.opacity(Theme.Opacity.accentLight),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 4
            )
            .accessibilityHidden(true)

            // Wave signature — fills the card
            CompositionWaveView(composition: composition)
                .accessibilityHidden(true)

            // Bottom overlay
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Mode badge
                Text(mode.displayName.uppercased())
                    .font(Theme.Typography.small)
                    .tracking(Theme.Typography.Tracking.uppercase)
                    .foregroundStyle(modeColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(modeColor.opacity(Theme.Opacity.accentLight), in: Capsule())

                Text(composition.name)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Text("\(composition.durationMinutes) min")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.surface.opacity(Theme.Opacity.medium),
                        Theme.Colors.surface.opacity(Theme.Opacity.translucent)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .aspectRatio(Constants.Library.heroAspectRatio, contentMode: .fill)
        .libraryCardGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(composition.name), \(mode.displayName), \(composition.durationMinutes) minutes")
    }
}

// MARK: - Compact Composition Card

/// Smaller horizontal scroll card for non-hero compositions.
/// Shows wave signature, name, and duration in a tighter format.
private struct LibraryCompactCompositionCard: View {

    let composition: CustomComposition

    private var mode: FocusMode {
        composition.focusMode ?? .focus
    }

    private var modeColor: Color {
        Color.modeColor(for: mode)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RadialGradient(
                colors: [
                    modeColor.opacity(Theme.Opacity.accentLight),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 2
            )
            .accessibilityHidden(true)

            CompositionWaveView(composition: composition)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Spacer()

                Text(composition.name)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(composition.durationMinutes) min")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.surface.opacity(Theme.Opacity.half),
                        Theme.Colors.surface.opacity(Theme.Opacity.translucent)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .aspectRatio(1, contentMode: .fill)
        .libraryCardGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(composition.name), \(composition.durationMinutes) minutes")
    }
}

// MARK: - Library Track Row

/// Compact horizontal row for a Sessions track. Mode icon on the
/// left, track info in the center, duration + date on the right.
private struct LibraryTrackRow: View {

    let track: SavedTrack

    private var trackModeColor: Color {
        track.focusMode.map { Color.modeColor(for: $0) } ?? Theme.Colors.accent
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Mode icon
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(trackModeColor.opacity(Theme.Opacity.accentLight))
                    .frame(
                        width: Constants.Library.trackIconSize,
                        height: Constants.Library.trackIconSize
                    )

                Image(systemName: track.focusMode?.systemImageName ?? "waveform.path")
                    .font(.system(size: Theme.Typography.Size.body))
                    .foregroundStyle(trackModeColor)
            }
            .accessibilityHidden(true)

            // Track info
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(track.name)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Text(track.focusMode?.displayName ?? "Session")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            // Duration + date
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(track.formattedDuration)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(Self.dateFormatter.string(from: track.dateSaved))
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            // Favorite indicator
            if track.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .libraryCardGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.name), \(track.formattedDuration)")
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

// MARK: - Library Correlation Card

/// Grid card for a correlation. Emotion-colored accent line on top,
/// description text, and emotion chip at the bottom.
private struct LibrarySonicMemoryCard: View {

    let memory: SonicMemory

    private var emotionColor: Color {
        guard let emotion = EmotionalAssociation(rawValue: memory.emotionalAssociation) else {
            return Theme.Colors.accent
        }
        switch emotion {
        case .calm:      return Theme.Colors.relaxation
        case .focused:   return Theme.Colors.focus
        case .energized: return Theme.Colors.energize
        case .nostalgic: return Theme.Colors.sleep
        case .safe:      return Theme.Colors.signalCalm
        case .joyful:    return Theme.Colors.signalElevated
        }
    }

    private var emotion: EmotionalAssociation? {
        EmotionalAssociation(rawValue: memory.emotionalAssociation)
    }

    private var emotionLabel: String {
        emotion?.displayName ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Emotion accent bar at top
            RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                .fill(emotionColor)
                .frame(height: Theme.Radius.segmentHeight)
                .accessibilityHidden(true)

            // Description
            Text(memory.userDescription)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Emotion chip
            if let emotion {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: emotion.systemImageName)
                        .font(.system(size: Theme.Typography.Size.small))
                        .foregroundStyle(emotionColor)

                    Text(emotionLabel)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(minHeight: Theme.Spacing.mega * 2)
        .background {
            RadialGradient(
                colors: [
                    emotionColor.opacity(Theme.Opacity.subtle),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: Theme.Spacing.mega * 2
            )
            .accessibilityHidden(true)
        }
        .libraryCardGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(memory.userDescription). \(emotionLabel)")
    }
}

// MARK: - Glass Card Modifier

/// Applies iOS 26 Liquid Glass on supported versions, falls back to
/// the standard surface + divider stroke pattern on iOS 17-25.
private struct LibraryCardGlassModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                )
                .glassEffect(
                    .regular.tint(
                        Theme.Colors.surface.opacity(Theme.Opacity.glassFill)
                    ),
                    in: .rect(cornerRadius: Theme.Radius.xl, style: .continuous)
                )
        } else {
            content
                .background(Theme.Colors.surface)
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
    }
}

private extension View {
    func libraryCardGlass() -> some View {
        modifier(LibraryCardGlassModifier())
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Library — Populated") {
    LibraryView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [CustomComposition.self, SavedTrack.self, SonicMemory.self],
            inMemory: true
        )
}

#Preview("Library — Empty") {
    LibraryView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [CustomComposition.self, SavedTrack.self, SonicMemory.self],
            inMemory: true
        )
}
#endif
