// EnergizeScreeningView.swift
// BioNaural
//
// First-use health screening for Energize mode.
// Presented as a .sheet the first time a user taps the Energize card.
// This is NOT part of general onboarding — it's a mode-specific safety gate.
// All text from Theme.Typography. All colors from Theme.Colors. No hardcoded values.

import SwiftUI
import os

// MARK: - Screening State

/// Tracks which screen the user is on and their health questionnaire responses.
@Observable
final class EnergizeScreeningState {

    /// Current screen in the 3-step flow.
    var currentScreen: Screen = .intro

    /// Health condition toggles.
    var hasSeizureHistory = false
    var hasPanicDisorder = false
    var hasCardiacCondition = false
    var isPregnant = false

    /// Whether the enhanced warning was acknowledged (user chose to continue).
    var showEnhancedWarning = false

    enum Screen {
        case intro
        case questionnaire
        case safetyExplanation
    }

    /// True if any health condition is checked.
    var hasAnyCondition: Bool {
        hasSeizureHistory || hasPanicDisorder || hasCardiacCondition || isPregnant
    }

    func reset() {
        currentScreen = .intro
        hasSeizureHistory = false
        hasPanicDisorder = false
        hasCardiacCondition = false
        isPregnant = false
        showEnhancedWarning = false
    }
}

// MARK: - UserDefaults Keys

private enum EnergizeScreeningKeys {
    static let screeningComplete = "energize_screening_complete"
    static let healthSeizureHistory = "energize_health_seizure_history"
    static let healthPanicDisorder = "energize_health_panic_disorder"
    static let healthCardiacCondition = "energize_health_cardiac_condition"
    static let healthPregnant = "energize_health_pregnant"
}

// MARK: - EnergizeScreeningView

struct EnergizeScreeningView: View {

    /// Called when the user completes screening and wants to start their first Energize session.
    let onComplete: () -> Void

    /// Called when the user chooses to skip Energize entirely.
    let onSkip: () -> Void

    @State private var state = EnergizeScreeningState()

    var body: some View {
        NavigationStack {
            Group {
                switch state.currentScreen {
                case .intro:
                    introScreen
                case .questionnaire:
                    questionnaireScreen
                case .safetyExplanation:
                    safetyScreen
                }
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSkip()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Closes the Energize screening and skips this mode")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.canvas)
    }

    // MARK: - Screen 1: Intro

    @ViewBuilder
    private var introScreen: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: Theme.Typography.Size.display))
                    .foregroundStyle(Theme.Colors.energize)
                    .accessibilityHidden(true)

                Text("Energize is designed to increase alertness")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("This mode uses higher-frequency audio to help wake you up. Before your first Energize session, please review these questions.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            screeningPrimaryButton(title: "Continue") {
                withAnimation(Theme.Animation.standard) {
                    state.currentScreen = .questionnaire
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Screen 2: Health Questionnaire

    @ViewBuilder
    private var questionnaireScreen: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxxl) {
                Spacer(minLength: Theme.Spacing.xxxl)

                VStack(spacing: Theme.Spacing.lg) {
                    Text("Do any of these apply to you?")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: Theme.Spacing.md) {
                        conditionToggle(
                            label: "History of seizures or epilepsy",
                            isOn: $state.hasSeizureHistory
                        )
                        conditionToggle(
                            label: "Panic attacks or anxiety disorder",
                            isOn: $state.hasPanicDisorder
                        )
                        conditionToggle(
                            label: "Cardiac condition or heart medication",
                            isOn: $state.hasCardiacCondition
                        )
                        conditionToggle(
                            label: "Currently pregnant",
                            isOn: $state.isPregnant
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                }

                if state.showEnhancedWarning {
                    enhancedWarningView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    questionnaireButtons
                }

                Spacer(minLength: Theme.Spacing.xxl)
            }
        }
    }

    @ViewBuilder
    private func conditionToggle(label: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(Theme.Animation.press) {
                isOn.wrappedValue.toggle()
                // Reset enhanced warning when toggles change
                if state.showEnhancedWarning {
                    state.showEnhancedWarning = false
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: Theme.Typography.Size.headline))
                    .foregroundStyle(
                        isOn.wrappedValue ? Theme.Colors.energize : Theme.Colors.textTertiary
                    )

                Text(label)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(ScreeningToggleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isOn.wrappedValue ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to toggle")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var questionnaireButtons: some View {
        VStack(spacing: Theme.Spacing.md) {
            screeningPrimaryButton(title: "None of these apply") {
                withAnimation(Theme.Animation.standard) {
                    if state.hasAnyCondition {
                        state.showEnhancedWarning = true
                    } else {
                        state.currentScreen = .safetyExplanation
                    }
                }
            }

            if state.hasAnyCondition {
                screeningPrimaryButton(title: "One or more applies") {
                    withAnimation(Theme.Animation.standard) {
                        state.showEnhancedWarning = true
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    @ViewBuilder
    private var enhancedWarningView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: Theme.Typography.Size.headline))
                    .foregroundStyle(Theme.Colors.energize)
                    .accessibilityHidden(true)

                Text("We recommend consulting your physician before using Energize mode. BioNaural monitors your heart rate " +
                    "throughout and will automatically reduce intensity if needed. You can continue or skip this mode.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

            VStack(spacing: Theme.Spacing.md) {
                screeningPrimaryButton(title: "Continue with caution") {
                    withAnimation(Theme.Animation.standard) {
                        state.currentScreen = .safetyExplanation
                    }
                }

                screeningSecondaryButton(title: "Skip Energize") {
                    storeHealthResponses()
                    onSkip()
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }

    // MARK: - Screen 3: Safety Explanation

    @ViewBuilder
    private var safetyScreen: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: Theme.Typography.Size.display))
                    .foregroundStyle(Theme.Colors.energize)
                    .accessibilityHidden(true)

                Text("Your Apple Watch is your safety net.")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("During Energize sessions, BioNaural continuously monitors your heart rate. If it rises too high, " +
                    "the audio automatically shifts to calming frequencies. Every session ends with a mandatory cool-down.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            screeningPrimaryButton(title: "Start First Energize Session") {
                storeHealthResponses()
                markScreeningComplete()
                onComplete()
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Persistence

    private func storeHealthResponses() {
        let defaults = UserDefaults.standard
        defaults.set(state.hasSeizureHistory, forKey: EnergizeScreeningKeys.healthSeizureHistory)
        defaults.set(state.hasPanicDisorder, forKey: EnergizeScreeningKeys.healthPanicDisorder)
        defaults.set(state.hasCardiacCondition, forKey: EnergizeScreeningKeys.healthCardiacCondition)
        defaults.set(state.isPregnant, forKey: EnergizeScreeningKeys.healthPregnant)
    }

    private func markScreeningComplete() {
        UserDefaults.standard.set(true, forKey: EnergizeScreeningKeys.screeningComplete)
    }

    /// Check if the user has already completed the Energize screening.
    static var isScreeningComplete: Bool {
        UserDefaults.standard.bool(forKey: EnergizeScreeningKeys.screeningComplete)
    }

    // MARK: - Button Components

    @ViewBuilder
    private func screeningPrimaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.energize)
                .clipShape(Capsule())
        }
        .buttonStyle(ScreeningButtonStyle())
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func screeningSecondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(ScreeningButtonStyle())
        .accessibilityLabel(title)
    }
}

// MARK: - Button Styles

private struct ScreeningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? Theme.Opacity.translucent : Theme.Opacity.full)
            .animation(Theme.Animation.press, value: configuration.isPressed)
    }
}

private struct ScreeningToggleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.press, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Energize Screening") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            EnergizeScreeningView(
                onComplete: { Logger.session.info("Energize screening complete — start session") },
                onSkip: { Logger.session.info("User skipped Energize screening") }
            )
        }
        .preferredColorScheme(.dark)
}
