// GenrePickerView.swift
// BioNaural
//
// Grid of genre tiles for onboarding. User taps 1-3 favorites.
// Selection is stored in SoundProfile and informs all music generation.
// Also usable as a per-session genre selector (smaller variant).

import BioNauralShared
import SwiftUI

// MARK: - GenrePickerView

struct GenrePickerView: View {

    @Binding var selectedGenres: Set<String>
    let maxSelections: Int
    let compact: Bool

    init(
        selectedGenres: Binding<Set<String>>,
        maxSelections: Int = 3,
        compact: Bool = false
    ) {
        self._selectedGenres = selectedGenres
        self.maxSelections = maxSelections
        self.compact = compact
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.sm),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !compact {
                Text("What music do you enjoy?")
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Choose up to \(maxSelections) genres to personalize your sessions")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                ForEach(Theme.ModeInstrumentation.genreOptions, id: \.id) { genre in
                    genreTile(id: genre.id, label: genre.label, category: "")
                }
            }
        }
    }

    private func genreTile(id: String, label: String, category: String) -> some View {
        let isSelected = selectedGenres.contains(id)
        let canSelect = selectedGenres.count < maxSelections || isSelected

        return Button {
            if isSelected {
                selectedGenres.remove(id)
            } else if canSelect {
                selectedGenres.insert(id)
            }
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                Text(genreEmoji(id))
                    .font(.system(size: compact ? 20 : 28))
                Text(label)
                    .font(compact ? Theme.Typography.caption : Theme.Typography.callout)
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 60 : 80)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.2) : Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isSelected ? Theme.Colors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .opacity(canSelect ? 1.0 : 0.4)
    }

    private func genreEmoji(_ id: String) -> String {
        switch id {
        case "ambient":     return "🌊"
        case "lofi":        return "☕"
        case "rock":        return "🎸"
        case "hiphop":      return "🎤"
        case "jazz":        return "🎷"
        case "blues":       return "🎵"
        case "reggae":      return "🌴"
        case "classical":   return "🎻"
        case "latin":       return "💃"
        case "electronic":  return "🎛️"
        default:            return "🎶"
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selected: Set<String> = ["lofi", "jazz"]
        var body: some View {
            ScrollView {
                GenrePickerView(selectedGenres: $selected)
                    .padding()
            }
            .background(Theme.Colors.canvas)
        }
    }
    return PreviewWrapper()
}
