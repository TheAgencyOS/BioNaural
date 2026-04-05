// OnboardingView.swift
// BioNaural
//
// Container view that manages the 12-screen onboarding flow.
// Persists progress to UserDefaults so the user resumes from the
// last completed screen after a force-quit. On completion, sets
// "onboardingComplete" flag and transitions to MainView.

import SwiftUI

// MARK: - UserDefaults Keys

private enum OnboardingKeys {
    static let currentScreen = "onboarding_currentScreen"
    static let complete = "onboardingComplete"
    static let ageVerified = "onboarding_ageVerified"
    static let epilepsyAcknowledged = "onboarding_epilepsyAcknowledged"
    static let calibrationRestingHR = "onboarding_calibrationRestingHR"
    static let calibrationHRV = "onboarding_calibrationHRV"
    static let soundPreference = "onboarding_soundPreference"
    static let spatialAudioSkipped = "onboarding_spatialAudioSkipped"
}

// MARK: - Sound Preference

/// The user's initial sound palette preference, set during onboarding.
/// Maps to initial SoundProfile weights.
enum SoundPreference: String, CaseIterable, Identifiable {
    case nature
    case musical
    case minimal
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nature:  return "Nature-forward"
        case .musical: return "Musical"
        case .minimal: return "Minimal"
        case .mixed:   return "Mix of everything"
        }
    }

    var subtitle: String {
        switch self {
        case .nature:  return "Rain, wind, birds, water"
        case .musical: return "Pads, piano, strings"
        case .minimal: return "Beats and subtle texture"
        case .mixed:   return "A bit of each, balanced"
        }
    }

    var iconName: String {
        switch self {
        case .nature:  return "leaf.fill"
        case .musical: return "music.note"
        case .minimal: return "waveform.path"
        case .mixed:   return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Onboarding Screen Count

private enum OnboardingConstants {
    static let totalScreens = 12
    static let firstScreenIndex = 0
    static let lastScreenIndex = 11
}

// MARK: - OnboardingView

struct OnboardingView: View {

    @State private var currentScreen: Int
    @State private var isAgeBlocked = false
    @State private var ageVerified: Bool
    @State private var epilepsyAcknowledged: Bool
    @State private var soundPreference: SoundPreference?
    @State private var showSpatialAudioScreen: Bool = false
    @State private var calibrationRestingHR: Double?
    @State private var calibrationHRV: Double?

    /// Binding from the parent to flip when onboarding completes.
    var onComplete: () -> Void

    // MARK: - Environment

    @Environment(AppDependencies.self) private var dependencies

    // MARK: - Init

    init(onComplete: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let saved = defaults.integer(forKey: OnboardingKeys.currentScreen)
        _currentScreen = State(initialValue: saved)
        _ageVerified = State(initialValue: defaults.bool(forKey: OnboardingKeys.ageVerified))
        _epilepsyAcknowledged = State(initialValue: defaults.bool(forKey: OnboardingKeys.epilepsyAcknowledged))

        if let raw = defaults.string(forKey: OnboardingKeys.soundPreference) {
            _soundPreference = State(initialValue: SoundPreference(rawValue: raw))
        } else {
            _soundPreference = State(initialValue: nil)
        }

        let savedHR = defaults.double(forKey: OnboardingKeys.calibrationRestingHR)
        _calibrationRestingHR = State(initialValue: savedHR > 0 ? savedHR : nil)
        let savedHRV = defaults.double(forKey: OnboardingKeys.calibrationHRV)
        _calibrationHRV = State(initialValue: savedHRV > 0 ? savedHRV : nil)

        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.Colors.canvas
                .ignoresSafeArea()

            screenContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentScreen)
        }
        .animation(Theme.Animation.standard, value: currentScreen)
        .preferredColorScheme(.dark)
    }

    // MARK: - Screen Router

    @ViewBuilder
    private var screenContent: some View {
        switch currentScreen {
        case 0:
            AgeGateView(
                onVerified: {
                    ageVerified = true
                    UserDefaults.standard.set(true, forKey: OnboardingKeys.ageVerified)
                    advance()
                },
                onBlocked: {
                    isAgeBlocked = true
                }
            )

        case 1:
            WelcomeView(onContinue: advance)

        case 2:
            HowItWorksView(onContinue: advance)

        case 3:
            AdaptiveDifferenceView(onContinue: advance)

        case 4:
            HeadphoneCheckView(
                onContinue: { airPodsDetected in
                    showSpatialAudioScreen = airPodsDetected
                    advance()
                }
            )

        case 5:
            if showSpatialAudioScreen {
                SpatialAudioTestView(onContinue: advance)
            } else {
                // Skip spatial audio test for non-AirPods headphones
                Color.clear
                    .onAppear { advance() }
            }

        case 6:
            EpilepsyDisclaimerView(
                onAcknowledged: {
                    epilepsyAcknowledged = true
                    UserDefaults.standard.set(true, forKey: OnboardingKeys.epilepsyAcknowledged)
                    advance()
                }
            )

        case 7:
            HealthKitPermissionView(onContinue: advance)

        case 8:
            WatchDetectionView(onContinue: advance)

        case 9:
            CalibrationView(
                onComplete: { restingHR, hrv in
                    if let hr = restingHR, let hv = hrv {
                        calibrationRestingHR = hr
                        calibrationHRV = hv
                        UserDefaults.standard.set(hr, forKey: OnboardingKeys.calibrationRestingHR)
                        UserDefaults.standard.set(hv, forKey: OnboardingKeys.calibrationHRV)
                    }
                    advance()
                }
            )

        case 10:
            SoundPreferenceView(
                onSelected: { preference in
                    soundPreference = preference
                    UserDefaults.standard.set(preference.rawValue, forKey: OnboardingKeys.soundPreference)
                    advance()
                }
            )

        case 11:
            FirstSessionView(
                onSessionStarted: {
                    completeOnboarding()
                }
            )

        default:
            Color.clear
                .onAppear { completeOnboarding() }
        }
    }

    // MARK: - Navigation

    private func advance() {
        let next = currentScreen + 1
        guard next < OnboardingConstants.totalScreens else {
            completeOnboarding()
            return
        }
        currentScreen = next
        UserDefaults.standard.set(next, forKey: OnboardingKeys.currentScreen)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: OnboardingKeys.complete)
        UserDefaults.standard.removeObject(forKey: OnboardingKeys.currentScreen)
        onComplete()
    }
}

// MARK: - Static Helpers

extension OnboardingView {

    /// Whether onboarding has been completed previously.
    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: OnboardingKeys.complete)
    }

    /// Resets all onboarding state. Used in Settings for testing.
    static func resetOnboarding() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: OnboardingKeys.complete)
        defaults.removeObject(forKey: OnboardingKeys.currentScreen)
        defaults.removeObject(forKey: OnboardingKeys.ageVerified)
        defaults.removeObject(forKey: OnboardingKeys.epilepsyAcknowledged)
        defaults.removeObject(forKey: OnboardingKeys.calibrationRestingHR)
        defaults.removeObject(forKey: OnboardingKeys.calibrationHRV)
        defaults.removeObject(forKey: OnboardingKeys.soundPreference)
        defaults.removeObject(forKey: OnboardingKeys.spatialAudioSkipped)
    }
}
