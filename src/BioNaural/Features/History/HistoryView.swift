// HistoryView.swift
// BioNaural
//
// List of past sessions with mode filtering, empty state, and navigation
// to session detail. Fetches from SwiftData via @Query, sorted by date
// descending. Supports filtering by mode with elegant pill selectors.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - ModeFilter

/// Filter options for the history list.
private enum ModeFilter: String, CaseIterable, Identifiable {
    case all
    case focus
    case relaxation
    case sleep
    case energize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:         return "All"
        case .focus:       return "Focus"
        case .relaxation:  return "Relaxation"
        case .sleep:       return "Sleep"
        case .energize:    return "Energize"
        }
    }

    /// Returns the corresponding `FocusMode`, or `nil` for "All".
    var focusMode: FocusMode? {
        switch self {
        case .all:         return nil
        case .focus:       return .focus
        case .relaxation:  return .relaxation
        case .sleep:       return .sleep
        case .energize:    return .energize
        }
    }

    /// SF Symbol for the filter pill.
    var systemImageName: String {
        switch self {
        case .all:         return "waveform.path"
        case .focus:       return "brain.head.profile"
        case .relaxation:  return "leaf.fill"
        case .sleep:       return "moon.fill"
        case .energize:    return "bolt.fill"
        }
    }

    /// The accent color for this filter.
    var color: Color {
        switch self {
        case .all:         return Theme.Colors.accent
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        }
    }
}

// MARK: - HistoryView

struct HistoryView: View {

    // MARK: - Data

    @Query(sort: \FocusSession.startDate, order: .reverse)
    private var allSessions: [FocusSession]

    // MARK: - State

    @State private var selectedFilter: ModeFilter = .all
    @State private var cardsAppeared = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed

    private var filteredSessions: [FocusSession] {
        guard let mode = selectedFilter.focusMode else {
            return allSessions
        }
        return allSessions.filter { $0.mode == mode.rawValue }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Atmospheric background
                atmosphericBackground

                VStack(spacing: .zero) {
                    filterBar
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.lg)

                    if filteredSessions.isEmpty {
                        emptyState
                    } else {
                        sessionList
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                guard !reduceMotion else {
                    cardsAppeared = true
                    return
                }
                withAnimation(Theme.Animation.standard) {
                    cardsAppeared = true
                }
            }
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Theme.Colors.accent.opacity(Theme.Opacity.canvasRadialWash),
                    Color.clear
                ],
                center: .top,
                startRadius: .zero,
                endRadius: Theme.Spacing.mega * Theme.Spacing.xxs
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Filter Bar (Pill Selectors)

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ModeFilter.allCases) { filter in
                    filterPill(for: filter)
                }
            }
        }
        .accessibilityLabel("Filter sessions by mode")
    }

    private func filterPill(for filter: ModeFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(Theme.Animation.press) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: filter.systemImageName)
                    .font(.system(size: Theme.Typography.Size.small))

                Text(filter.displayName)
                    .font(Theme.Typography.caption)
            }
            .foregroundStyle(isSelected ? Theme.Colors.textOnAccent : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : Theme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? Theme.Animation.OrbScale.breathingMax : Theme.Animation.OrbScale.breathingMin)
        .animation(Theme.Animation.press, value: isSelected)
        .sensoryFeedback(.selection, trigger: selectedFilter)
        .accessibilityLabel("\(filter.displayName) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(Array(filteredSessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(GlassRowButtonStyle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            toggleFavorite(session)
                        } label: {
                            Label(
                                session.thumbsRating == 1 ? "Unfavorite" : "Favorite",
                                systemImage: session.thumbsRating == 1 ? "heart.slash" : "heart.fill"
                            )
                        }
                        .tint(Theme.Colors.accent)
                    }
                    .staggeredFadeIn(index: index, isVisible: cardsAppeared)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
    }

    // MARK: - Swipe Action Helpers

    private func deleteSession(_ session: FocusSession) {
        withAnimation(Theme.Animation.standard) {
            modelContext.delete(session)
        }
    }

    private func toggleFavorite(_ session: FocusSession) {
        withAnimation(Theme.Animation.press) {
            session.thumbsRating = session.thumbsRating == 1 ? nil : 1
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            // Animated mini-orb
            emptyStateOrb

            VStack(spacing: Theme.Spacing.sm) {
                Text(emptyStateTitle)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(emptyStateSubtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyStateTitle). \(emptyStateSubtitle)")
    }

    @State private var emptyOrbScale: CGFloat = Theme.Animation.OrbScale.breathingMin

    private var emptyStateOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedFilter.color.opacity(Theme.Opacity.medium),
                            selectedFilter.color.opacity(Theme.Opacity.subtle)
                        ],
                        center: .center,
                        startRadius: .zero,
                        endRadius: Theme.Spacing.jumbo / 2
                    )
                )
                .frame(
                    width: Theme.Spacing.jumbo,
                    height: Theme.Spacing.jumbo
                )
                .scaleEffect(emptyOrbScale)

            Image(systemName: emptyStateIcon)
                .font(.system(size: Theme.Typography.Size.headline))
                .foregroundStyle(selectedFilter.color)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Animation.orbBreathing) {
                emptyOrbScale = Theme.Animation.OrbScale.breathingMax
            }
        }
        .accessibilityHidden(true)
    }

    private var emptyStateIcon: String {
        selectedFilter.systemImageName
    }

    private var emptyStateTitle: String {
        if selectedFilter == .all {
            return "No Sessions Yet"
        }
        return "No \(selectedFilter.displayName) Sessions"
    }

    private var emptyStateSubtitle: String {
        if selectedFilter == .all {
            return "Complete your first session to see it here."
        }
        return "Complete a \(selectedFilter.displayName) session to see it here."
    }
}

// MARK: - Glass Row Button Style

/// A button style that wraps the label in a glass-effect card
/// with a spring press animation.
private struct GlassRowButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .strokeBorder(
                        Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
            .scaleEffect(configuration.isPressed ? Theme.Animation.OrbScale.breathingMin : Theme.Animation.OrbScale.breathingMin)
            .opacity(configuration.isPressed ? Theme.Opacity.translucent : Theme.Opacity.full)
            .animation(
                reduceMotion ? .identity : Theme.Animation.press,
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#Preview("HistoryView") {
    HistoryView()
        .preferredColorScheme(.dark)
}
