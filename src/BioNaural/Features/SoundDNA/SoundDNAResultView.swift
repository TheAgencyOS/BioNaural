// SoundDNAResultView.swift
// BioNaural
//
// Displays the extracted musical features after a Sound DNA analysis.
// Shows song identification (if matched), extracted features as visual
// bars, and a save-to-profile action. Uses Theme tokens throughout.

import SwiftUI

// MARK: - SoundDNAResultView

struct SoundDNAResultView: View {

    let result: SoundDNAAnalysisResult
    let isSaved: Bool
    let onSave: () -> Void
    let onDismiss: () -> Void
    let onSampleAnother: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Song identification header
                songHeader

                // Extracted features
                featuresSection

                // Actions
                actionButtons
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xl)
        }
    }

    // MARK: - Song Header

    private var songHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if result.songTitle != nil {
                Image(systemName: "music.note")
                    .font(.system(size: Theme.Spacing.xl))
                    .foregroundStyle(Theme.Colors.accent)

                if let title = result.songTitle {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                if let artist = result.artistName {
                    Text(artist)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                if let genre = result.genre {
                    Text(genre)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            Theme.Colors.surface,
                            in: Capsule()
                        )
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: Theme.Spacing.xl))
                    .foregroundStyle(Theme.Colors.accent)

                Text("Unknown Song")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("We extracted the musical DNA from the audio.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Musical DNA")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: Theme.Spacing.sm) {
                if let bpm = result.bpm {
                    featureRow(
                        label: "Tempo",
                        value: "\(Int(bpm)) BPM",
                        proportion: bpm / Theme.SoundDNA.bpmDetectionRange.upperBound,
                        icon: "metronome"
                    )
                }

                if let key = result.key {
                    let scaleLabel = result.scale == .major ? "Major" : result.scale == .minor ? "Minor" : ""
                    featureRow(
                        label: "Key",
                        value: "\(key) \(scaleLabel)",
                        proportion: nil,
                        icon: "pianokeys"
                    )
                }

                featureRow(
                    label: "Brightness",
                    value: brightnessLabel,
                    proportion: result.brightness,
                    icon: "sun.max"
                )

                featureRow(
                    label: "Warmth",
                    value: warmthLabel,
                    proportion: result.warmth,
                    icon: "flame"
                )

                featureRow(
                    label: "Energy",
                    value: energyLabel,
                    proportion: result.energy,
                    icon: "bolt"
                )

                featureRow(
                    label: "Density",
                    value: densityLabel,
                    proportion: result.density,
                    icon: "square.stack.3d.up"
                )
            }
            .padding(Theme.Spacing.md)
            .background(
                Theme.Colors.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card)
            )
        }
    }

    // MARK: - Feature Row

    private func featureRow(
        label: String,
        value: String,
        proportion: Double?,
        icon: String
    ) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack {
                Image(systemName: icon)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: Theme.Spacing.lg)

                Text(label)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Text(value)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let proportion {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Theme.Radius.xs)
                            .fill(Theme.Colors.surface)
                            .frame(height: Theme.Spacing.xxs)

                        RoundedRectangle(cornerRadius: Theme.Radius.xs)
                            .fill(Theme.Colors.accent)
                            .frame(
                                width: geo.size.width * min(max(proportion, 0), 1),
                                height: Theme.Spacing.xxs
                            )
                    }
                }
                .frame(height: Theme.Spacing.xxs)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if isSaved {
                Label("Added to your Sound Profile", systemImage: "checkmark.circle.fill")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.confirmationGreen)
            } else {
                Button(action: onSave) {
                    Text("Add to Sound Profile")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.accent, in: RoundedRectangle(
                            cornerRadius: Theme.Radius.xl
                        ))
                }
            }

            HStack(spacing: Theme.Spacing.lg) {
                Button("Sample Another", action: onSampleAnother)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.accent)

                Button("Done", action: onDismiss)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Feature Labels

    private var brightnessLabel: String {
        featureLabel(result.brightness, low: "Dark", mid: "Neutral", high: "Bright")
    }

    private var warmthLabel: String {
        featureLabel(result.warmth, low: "Cool", mid: "Neutral", high: "Warm")
    }

    private var energyLabel: String {
        featureLabel(result.energy, low: "Low", mid: "Medium", high: "High")
    }

    private var densityLabel: String {
        featureLabel(result.density, low: "Sparse", mid: "Moderate", high: "Dense")
    }

    private func featureLabel(
        _ value: Double,
        low: String,
        mid: String,
        high: String
    ) -> String {
        if value < Theme.SoundDNA.featureLabelLowThreshold {
            return low
        } else if value < Theme.SoundDNA.featureLabelHighThreshold {
            return mid
        } else {
            return high
        }
    }
}
