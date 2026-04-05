// SonicMemoryListView.swift
// BioNaural
//
// Displays all saved sonic memories in a scrollable list.
// Accessible from Settings or the Sonic Memory section.
// Supports swipe-to-delete with confirmation and staggered
// card animations.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SonicMemoryListView

struct SonicMemoryListView: View {

    @Query(sort: \SonicMemory.dateCreated, order: .reverse)
    private var memories: [SonicMemory]

    @Environment(\.modelContext) private var modelContext

    @State private var showingInput = false
    @State private var memoryToDelete: SonicMemory? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyState
                } else {
                    memoryList
                }
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Sonic Memories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingInput = true
                    } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .accessibilityLabel(Text("Add sonic memory"))
                }
            }
            .sheet(isPresented: $showingInput) {
                SonicMemoryInputView { _ in
                    // Memory is inserted into modelContext by the input view
                }
            }
            .alert(
                "Delete Memory?",
                isPresented: .init(
                    get: { memoryToDelete != nil },
                    set: { if !$0 { memoryToDelete = nil } }
                ),
                presenting: memoryToDelete
            ) { memory in
                Button("Delete", role: .destructive) {
                    deleteMemory(memory)
                }
                Button("Cancel", role: .cancel) {
                    memoryToDelete = nil
                }
            } message: { memory in
                Text("This will permanently remove \u{201C}\(memory.userDescription)\u{201D} and its associated data.")
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            Image(systemName: "waveform.and.mic")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("No sonic memories yet")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Describe a meaningful sound and BioNaural will shape your sessions around it.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.xxxl)

            Button {
                showingInput = true
            } label: {
                Text("Add your first")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent, in: Capsule())
            }
            .accessibilityLabel(Text("Add your first sonic memory"))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Memory List

    @ViewBuilder
    private var memoryList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                    NavigationLink {
                        SonicMemoryDetailView(memory: memory)
                    } label: {
                        SonicMemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            memoryToDelete = memory
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .transition(.opacity)
                    .animation(
                        Theme.Animation.staggeredFadeIn(index: index),
                        value: memories.count
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // MARK: - Deletion

    private func deleteMemory(_ memory: SonicMemory) {
        withAnimation(Theme.Animation.standard) {
            modelContext.delete(memory)
            memoryToDelete = nil
        }
    }
}

// MARK: - SonicMemoryCardView

/// Single memory card for the list. Shows a colored emotion dot,
/// description, subtitle metadata, session count badge, and chevron.
private struct SonicMemoryCardView: View {

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

    private var subtitle: String {
        var parts: [String] = []
        if let emotion = EmotionalAssociation(rawValue: memory.emotionalAssociation) {
            parts.append(emotion.displayName)
        }
        if let mode = memory.focusMode {
            parts.append(mode.displayName)
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Emotion dot
            Circle()
                .fill(emotionColor)
                .frame(
                    width: Theme.Spacing.sm,
                    height: Theme.Spacing.sm
                )
                .accessibilityHidden(true)

            // Text content
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(memory.userDescription)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            // Session count badge
            if memory.sessionCount > .zero {
                Text("\(memory.sessionCount)")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(
                        Theme.Colors.surfaceRaised,
                        in: Capsule()
                    )
                    .accessibilityLabel(Text("\(memory.sessionCount) sessions"))
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(memory.userDescription). \(subtitle)"))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("SonicMemoryListView") {
    SonicMemoryListView()
        .preferredColorScheme(.dark)
}
#endif
