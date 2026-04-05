// YourSoundView.swift
// BioNaural
//
// Overview of the user's Sound Profile — displays aggregated preferences
// from Sound DNA samples, Sonic Memories, and biometric learning. Provides
// access to the Sound DNA capture flow and Sonic Memory input. Accessible
// from Settings or a profile section, not the main session screen.

import SwiftUI
import SwiftData

// MARK: - YourSoundView

struct YourSoundView: View {

    @Environment(AppDependencies.self) private var deps
    @Query(sort: \SoundDNASample.dateCreated, order: .reverse) private var samples: [SoundDNASample]
    @Query(sort: \SonicMemory.dateCreated, order: .reverse) private var memories: [SonicMemory]

    @State private var profile: SoundProfile?
    @State private var showCapture = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                profileSummarySection
                soundDNASection
                sonicMemoriesSection
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.canvas)
        .navigationTitle("Your Sound")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadProfile() }
        .sheet(isPresented: $showCapture) {
            soundDNACaptureSheet
        }
    }

    // MARK: - Profile Summary

    private var profileSummarySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            sectionHeader(title: "Sound Profile", icon: "waveform.circle")

            if let profile {
                VStack(spacing: Theme.Spacing.sm) {
                    profileRow(
                        label: "Brightness",
                        value: formatPreference(profile.brightnessPreference),
                        icon: "sun.max"
                    )
                    profileRow(
                        label: "Density",
                        value: formatPreference(profile.densityPreference),
                        icon: "square.stack.3d.up"
                    )
                    if let warmth = profile.warmthPreference {
                        profileRow(
                            label: "Warmth",
                            value: formatPreference(warmth),
                            icon: "flame"
                        )
                    }
                    if let tempo = profile.tempoAffinity {
                        profileRow(
                            label: "Tempo Affinity",
                            value: "\(Int(tempo)) BPM",
                            icon: "metronome"
                        )
                    }
                    if let key = profile.keyPreference {
                        profileRow(
                            label: "Key Preference",
                            value: key,
                            icon: "pianokeys"
                        )
                    }
                }
                .padding(Theme.Spacing.md)
                .background(
                    Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card)
                )

                Text("Based on \(profile.soundDNASampleCount) song\(profile.soundDNASampleCount == 1 ? "" : "s") + session learning")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            } else {
                emptyProfileCard
            }
        }
    }

    private var emptyProfileCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: Theme.Spacing.xl))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text("No sound profile yet")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("Sample a song or complete a few sessions to build your profile.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - Sound DNA Samples

    private var soundDNASection: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                sectionHeader(title: "Sound DNA", icon: "waveform.badge.magnifyingglass")
                Spacer()
                Button {
                    showCapture = true
                } label: {
                    Label("Sample", systemImage: "plus.circle")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            if samples.isEmpty {
                Text("No songs sampled yet.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(samples.prefix(Theme.SoundDNA.maxActiveProfileSamples)) { sample in
                    sampleRow(sample)
                }
            }
        }
    }

    private func sampleRow(_ sample: SoundDNASample) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: sample.isIdentified ? "music.note" : "waveform")
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(sample.displayName)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let genre = sample.genre {
                    Text(genre)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            if let bpm = sample.extractedBPM {
                Text("\(Int(bpm))")
                    .font(Theme.Typography.data)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - Sonic Memories

    private var sonicMemoriesSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            sectionHeader(title: "Sonic Memories", icon: "brain.head.profile")

            if memories.isEmpty {
                Text("No sonic memories yet.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(memories.prefix(Theme.SoundDNA.maxDisplayedSonicMemories)) { memory in
                    HStack(spacing: Theme.Spacing.sm) {
                        if let emotion = memory.emotion {
                            Image(systemName: emotion.systemImageName)
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: Theme.Spacing.xl)
                        }

                        Text(memory.userDescription)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(Theme.Spacing.sm)
                    .background(
                        Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
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
    }

    private func formatPreference(_ value: Double) -> String {
        switch value {
        case 0.0..<0.33: return "Low"
        case 0.33..<0.66: return "Medium"
        default: return "High"
        }
    }

    private func loadProfile() async {
        // Load via a new fetch — SoundProfileManager may not expose direct query
        let context = deps.modelContainer.mainContext
        let descriptor = FetchDescriptor<SoundProfile>()
        profile = try? context.fetch(descriptor).first
    }

    private var soundDNACaptureSheet: some View {
        let service = SoundDNAService()
        let store = SwiftDataSoundProfileStore(
            modelContext: deps.modelContainer.mainContext
        )
        let manager = SoundProfileManager(store: store)
        let vm = SoundDNACaptureViewModel(
            service: service,
            profileManager: manager,
            modelContext: deps.modelContainer.mainContext
        )
        return SoundDNACaptureView(viewModel: vm)
    }
}
