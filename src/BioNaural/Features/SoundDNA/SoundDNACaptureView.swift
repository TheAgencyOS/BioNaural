// SoundDNACaptureView.swift
// BioNaural
//
// The Sound DNA capture flow. Presented as a native sheet from the
// Your Sound profile or onboarding. Walks through: listening → identifying →
// analyzing → result. All UI uses Theme tokens, native navigation, and
// standard SwiftUI components.

import SwiftUI

// MARK: - SoundDNACaptureView

struct SoundDNACaptureView: View {

    @Bindable var viewModel: SoundDNACaptureViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.canvas
                    .ignoresSafeArea()

                stateContent
            }
            .navigationTitle("Sound DNA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancel()
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - State-Driven Content

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.captureState {
        case .idle:
            idleView
        case .listening:
            listeningView
        case .identifying:
            progressView(label: "Identifying song")
        case .analyzing:
            progressView(label: "Analyzing audio")
        case .complete(let result):
            SoundDNAResultView(
                result: result,
                isSaved: viewModel.isSavedToProfile,
                onSave: { Task { await viewModel.saveToProfile() } },
                onDismiss: { dismiss() },
                onSampleAnother: { viewModel.reset() }
            )
        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: Theme.Spacing.xxxl))
                .foregroundStyle(Theme.Colors.accent)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Sample a Song")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Play a song you love and we'll extract its musical DNA to personalize your sessions.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Button {
                Task { await viewModel.startCapture() }
            } label: {
                Text("Start Listening")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent, in: RoundedRectangle(
                        cornerRadius: Theme.Radius.xl
                    ))
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()
        }
    }

    // MARK: - Listening State

    private var listeningView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            listeningAnimation

            VStack(spacing: Theme.Spacing.sm) {
                Text("Listening")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("Make sure the song is playing nearby.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Button("Cancel") {
                viewModel.cancel()
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()
        }
    }

    private var listeningAnimation: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: Theme.Radius.xs)
                    .fill(Theme.Colors.accent)
                    .frame(
                        width: Theme.Spacing.xs,
                        height: Theme.Spacing.lg
                    )
                    .scaleEffect(
                        y: 1.0,
                        anchor: .bottom
                    )
                    .animation(
                        .easeInOut(
                            duration: Theme.SoundDNA.listeningAnimationDuration
                        )
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * Theme.SoundDNA.listeningAnimationBarDelay),
                        value: true
                    )
            }
        }
        .frame(height: Theme.Spacing.xxxl)
    }

    // MARK: - Progress State

    private func progressView(label: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.accent)

            Text(label)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Theme.Spacing.xxxl))
                .foregroundStyle(Theme.Colors.stressWarning)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            Button("Try Again") {
                viewModel.reset()
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.accent)

            Spacer()
        }
    }
}
