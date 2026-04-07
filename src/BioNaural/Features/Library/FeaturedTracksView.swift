// FeaturedTracksView.swift
// BioNaural
//
// Displays all pre-generated MIDI sequences as playable track cards.
// Organized by mode (Sleep, Relaxation, Focus, Energize) with genre
// variants within each mode. Tapping a track starts the pre-session
// check-in flow, then launches a session with that specific genre.

import BioNauralShared
import SwiftUI

// MARK: - FeaturedTrackItem

/// Represents a single playable track from the pre-generated library.
struct FeaturedTrackItem: Identifiable {
    let id: String
    let genre: String
    let mode: FocusMode
    let bpm: Int
    let key: String
    let trackCount: Int
    let noteCount: Int

    var displayName: String {
        "\(genre.capitalized) \(mode.rawValue.capitalized)"
    }

    var genreEmoji: String {
        switch genre {
        case "ambient":    return "🌊"
        case "lofi":       return "☕"
        case "jazz":       return "🎷"
        case "rock":       return "🎸"
        case "hiphop":     return "🎤"
        case "blues":      return "🎵"
        case "reggae":     return "🌴"
        case "classical":  return "🎻"
        case "latin":      return "💃"
        case "electronic": return "🎛️"
        default:           return "🎶"
        }
    }

    var modeColor: Color {
        switch mode {
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        }
    }
}

// MARK: - FeaturedTracksView

struct FeaturedTracksView: View {

    let onSelectTrack: (FeaturedTrackItem) -> Void

    @State private var tracks: [FocusMode: [FeaturedTrackItem]] = [:]
    @State private var selectedMode: FocusMode = .relaxation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Mode filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(FocusMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMode = mode
                            }
                        } label: {
                            Text(mode.rawValue.capitalized)
                                .font(Theme.Typography.caption)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(
                                    Capsule().fill(selectedMode == mode
                                        ? Theme.Colors.accent.opacity(0.25)
                                        : Theme.Colors.surface)
                                )
                                .overlay(
                                    Capsule().stroke(selectedMode == mode
                                        ? Theme.Colors.accent : .clear, lineWidth: 1.5)
                                )
                                .foregroundStyle(selectedMode == mode
                                    ? Theme.Colors.textPrimary
                                    : Theme.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Track grid for selected mode
            let modeTracks = tracks[selectedMode] ?? []
            if modeTracks.isEmpty {
                Text("No tracks available for \(selectedMode.rawValue)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.xl)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Theme.Spacing.md) {
                    ForEach(modeTracks) { track in
                        trackCard(track)
                    }
                }
            }
        }
        .onAppear { loadTracks() }
    }

    // MARK: - Track Card

    private func trackCard(_ track: FeaturedTrackItem) -> some View {
        Button {
            onSelectTrack(track)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Genre emoji + name
                HStack {
                    Text(track.genreEmoji)
                        .font(.system(size: 24))
                    Spacer()
                    Text("\(track.bpm) BPM")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Text(track.genre.capitalized)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Key: \(track.key) • \(track.trackCount) tracks")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textTertiary)

                // Play indicator
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(track.modeColor)
                    Text("Play")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(track.modeColor)
                    Spacer()
                }
                .padding(.top, Theme.Spacing.xxs)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(track.modeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Load Tracks

    private func loadTracks() {
        guard let catalog = MIDISequencePlayer.loadCatalog() else { return }

        var grouped: [FocusMode: [FeaturedTrackItem]] = [:]
        for seq in catalog.sequences {
            guard let mode = FocusMode(rawValue: seq.mode) else { continue }
            let notes = seq.tracks.reduce(0) { $0 + $1.notes.count }
            guard notes > 0 else { continue }

            let item = FeaturedTrackItem(
                id: "\(seq.genre)_\(seq.mode)",
                genre: seq.genre,
                mode: mode,
                bpm: seq.bpm,
                key: seq.key,
                trackCount: seq.tracks.count,
                noteCount: notes
            )
            grouped[mode, default: []].append(item)
        }

        // Sort genres alphabetically within each mode
        for mode in grouped.keys {
            grouped[mode]?.sort { $0.genre < $1.genre }
        }

        tracks = grouped
    }
}
