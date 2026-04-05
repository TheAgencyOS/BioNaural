// ContentView.swift
// BioNaural
//
// Root view — gates between onboarding and main app.
// Uses the real OnboardingView for first-run, then MainView.
// All values from Theme tokens. Native SwiftUI.

import SwiftUI

struct ContentView: View {

    @Environment(AppDependencies.self) private var dependencies
    @AppStorage(ContentView.onboardingCompleteKey) private var isOnboardingComplete = false

    static let onboardingCompleteKey = "bionaural_onboarding_complete"

    var body: some View {
        Group {
            if isOnboardingComplete {
                MainView()
            } else {
                OnboardingView {
                    isOnboardingComplete = true
                }
            }
        }
        .animation(Theme.Animation.sheet, value: isOnboardingComplete)
    }
}

#Preview {
    ContentView()
        .environment(AppDependencies())
}
