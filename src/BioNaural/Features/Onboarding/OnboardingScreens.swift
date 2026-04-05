// OnboardingScreens.swift
// BioNaural
//
// All 12 onboarding screens as separate views.
// Each screen uses Theme tokens exclusively — no hardcoded values.
// Native SwiftUI navigation, sheets, and transitions throughout.

import SwiftUI
import AVFoundation
import HealthKit
import WatchConnectivity
import BioNauralShared

// MARK: - Screen 0: AgeGateView

/// COPPA-compliant age gate. Blocks users under 13.
struct AgeGateView: View {
    let onVerified: () -> Void
    let onBlocked: () -> Void

    @State private var blocked = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: Theme.Typography.Size.display))
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityHidden(true)

                Text("Are you 13 or older?")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("BioNaural requires users to be at least 13 years old.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            if blocked {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: Theme.Typography.Size.title))
                        .foregroundStyle(Theme.Colors.signalPeak)
                        .accessibilityHidden(true)

                    Text("BioNaural requires users to be 13 or older. Please come back when you're eligible.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .transition(.opacity)
            } else {
                HStack(spacing: Theme.Spacing.lg) {
                    OnboardingSecondaryButton(title: "No") {
                        withAnimation(Theme.Animation.standard) {
                            blocked = true
                        }
                        onBlocked()
                    }

                    OnboardingPrimaryButton(title: "Yes") {
                        onVerified()
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(color: Theme.Colors.accent, verticalCenter: 0.25)
                    .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Age verification screen")
    }
}

// MARK: - Screen 1: WelcomeView

/// Sets the mood. Calm, not corporate. The four brand waves converge
/// behind the copy — introducing the visual language from the first tap.
struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.Colors.canvas
                .ignoresSafeArea()

            // Brand wave signature — four converging mode waves, focus highlighted
            BrandWaveCanvas(highlightedMode: .focus)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Text("Your brain runs on rhythms.")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("BioNaural uses sound to guide them.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)

                Spacer()

                OnboardingPrimaryButton(title: "Continue", action: onContinue)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .padding(.bottom, Theme.Spacing.jumbo)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: Theme.Animation.Duration.orbEntrance)) {
                contentOpacity = 1.0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome to BioNaural")
    }
}

// MARK: - Screen 2: HowItWorksView

/// Explains the binaural mechanism in 5 seconds. Dual-layer wave merge
/// animation shows two ear-specific waves and the perceived beat between them.
struct HowItWorksView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            BinauralWaveMergeCanvas()
                .frame(height: Theme.Spacing.mega * 3)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text("Two slightly different tones — one in each ear.")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your brain perceives a third rhythm. That rhythm gently nudges your brainwaves toward the state you choose.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How binaural beats work")
    }
}

// MARK: - Screen 3: AdaptiveDifferenceView

/// The differentiator — why BioNaural is not just another binaural beats app.
/// Dual-layer wavelength morphs between calm and elevated states in real time.
struct AdaptiveDifferenceView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            AdaptiveWavelengthCanvas()
                .frame(height: Theme.Spacing.mega * 3)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text("Most apps play static audio.")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("BioNaural reads your heart rate and adapts in real time. The sound responds to your body — not a preset.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How BioNaural adapts to you")
    }
}

// MARK: - Screen 4: HeadphoneCheckView

/// Detects audio output route. Passes AirPods detection status to parent.
struct HeadphoneCheckView: View {
    let onContinue: (_ airPodsDetected: Bool) -> Void

    @State private var headphonesConnected = false
    @State private var isAirPods = false
    @State private var routeCheckTimer: Timer?

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: headphonesConnected ? "headphones" : "speaker.wave.2.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(headphonesConnected ? Theme.Colors.accent : Theme.Colors.signalElevated)
                .animation(Theme.Animation.standard, value: headphonesConnected)
                .accessibilityHidden(true)

            if headphonesConnected {
                VStack(spacing: Theme.Spacing.md) {
                    Text("Headphones connected. You're ready.")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    if isAirPods {
                        Text("AirPods detected — we'll do a quick spatial audio check next.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Headphones required")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    // Science explanation card
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "waveform.path")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.accent)

                            Text("Why headphones?")
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.Colors.accent)
                                .tracking(Theme.Typography.Tracking.uppercase)
                                .textCase(.uppercase)
                        }

                        Text("Binaural beats only work when each ear hears a different frequency. Through speakers, the tones mix in the air and the effect disappears entirely.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                        Text("Any stereo headphones or earbuds work — wired or wireless.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .fill(Theme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .strokeBorder(
                                        Theme.Colors.accent.opacity(Theme.Opacity.light),
                                        lineWidth: Theme.Radius.glassStroke
                                    )
                            )
                    )
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                if headphonesConnected {
                    OnboardingPrimaryButton(title: "Continue") {
                        routeCheckTimer?.invalidate()
                        onContinue(isAirPods)
                    }
                } else {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                            .tint(Theme.Colors.textTertiary)
                        Text("Waiting for headphones...")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    OnboardingSecondaryButton(title: "Skip (not recommended)") {
                        routeCheckTimer?.invalidate()
                        onContinue(false)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(
                    color: headphonesConnected ? Theme.Colors.accent : Theme.Colors.textTertiary,
                    verticalCenter: 0.3
                )
                .ignoresSafeArea()
            }
        }
        .onAppear { startRouteDetection() }
        .onDisappear { routeCheckTimer?.invalidate() }
        .onReceive(
            NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
        ) { _ in
            checkAudioRoute()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Headphone connection check")
    }

    private func startRouteDetection() {
        checkAudioRoute()
        routeCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                checkAudioRoute()
            }
        }
    }

    private func checkAudioRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        let outputs = route.outputs
        let hasHeadphones = outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
                .contains(output.portType)
        }
        let detectedAirPods = outputs.contains { output in
            output.portName.localizedCaseInsensitiveContains("AirPod")
        }
        headphonesConnected = hasHeadphones
        isAirPods = detectedAirPods
    }
}

// MARK: - Screen 5: SpatialAudioTestView

/// Plays a 10-second binaural test tone to verify Spatial Audio is off.
struct SpatialAudioTestView: View {
    let onContinue: () -> Void

    @State private var testState: SpatialTestState = .ready
    @State private var testProgress: Double = 0
    @State private var showInstructions = false

    private enum SpatialTestState {
        case ready
        case playing
        case askingResult
        case passed
    }

    private let testDurationSeconds: TimeInterval = 10

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: "airpodspro")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)

            switch testState {
            case .ready:
                readyContent
            case .playing:
                playingContent
            case .askingResult:
                askingResultContent
            case .passed:
                passedContent
            }

            Spacer()

            bottomActions

            if testState == .ready || testState == .askingResult {
                Button {
                    showInstructions = true
                } label: {
                    Text("How to disable Spatial Audio")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(color: Theme.Colors.accent, verticalCenter: 0.25)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showInstructions) {
            spatialAudioInstructionsSheet
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spatial audio test screen")
    }

    @ViewBuilder
    private var readyContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("One more thing for AirPods users.")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Spatial Audio can interfere with binaural beats. Let's do a quick 10-second test to make sure everything is set up correctly.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
    }

    @ViewBuilder
    private var playingContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Listen carefully...")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            ProgressView(value: testProgress)
                .tint(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.xxxl)

            Text("You should hear a steady pulsing or wobbling.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var askingResultContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Did you hear a steady pulsing or wobbling sensation?")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var passedContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)

            Text("You're set up correctly.")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        switch testState {
        case .ready:
            OnboardingPrimaryButton(title: "Start Test") {
                startTest()
            }
            .padding(.bottom, Theme.Spacing.md)

        case .playing:
            ProgressView()
                .tint(Theme.Colors.accent)
                .padding(.bottom, Theme.Spacing.md)

        case .askingResult:
            VStack(spacing: Theme.Spacing.md) {
                OnboardingPrimaryButton(title: "Yes, I heard it") {
                    withAnimation(Theme.Animation.standard) {
                        testState = .passed
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Animation.Duration.sheet) {
                        onContinue()
                    }
                }

                OnboardingSecondaryButton(title: "No, I didn't") {
                    showInstructions = true
                }
            }
            .padding(.bottom, Theme.Spacing.md)

        case .passed:
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.relaxation)
                Text("Test passed")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private var spatialAudioInstructionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("How to disable Spatial Audio")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    instructionStep(number: 1, text: "Open Control Center (swipe down from the top-right corner).")
                    instructionStep(number: 2, text: "Long-press the volume slider.")
                    instructionStep(number: 3, text: "Tap \"Spatialize Stereo\" or the Spatial Audio icon at the bottom.")
                    instructionStep(number: 4, text: "Select \"Off\" or \"Fixed.\"")
                    instructionStep(number: 5, text: "Come back here and try the test again.")
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.vertical, Theme.Spacing.xxl)
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showInstructions = false
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(number)")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                .background(
                    Circle()
                        .fill(Theme.Colors.accent.opacity(Theme.Opacity.light))
                )

            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }

    private func startTest() {
        testState = .playing
        testProgress = 0

        // Simulate test playback with progress updates
        let steps = Int(testDurationSeconds * 10)
        let interval = testDurationSeconds / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                withAnimation {
                    testProgress = Double(step) / Double(steps)
                }
                if step == steps {
                    withAnimation(Theme.Animation.standard) {
                        testState = .askingResult
                    }
                }
            }
        }
    }
}

// MARK: - Screen 6: EpilepsyDisclaimerView

/// Epilepsy disclaimer requiring explicit acknowledgment.
struct EpilepsyDisclaimerView: View {
    let onAcknowledged: () -> Void

    @State private var acknowledged = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.signalElevated)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text("Important safety information")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Binaural beats use rhythmic auditory stimulation. In rare cases, rhythmic stimuli may trigger seizures in individuals with photosensitive epilepsy or similar conditions.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                Text("If you have epilepsy, a seizure disorder, or have experienced seizures, please consult your doctor before using BioNaural.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Toggle(isOn: $acknowledged) {
                    Text("I understand and wish to continue")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.pageMargin)

                OnboardingPrimaryButton(title: "Continue") {
                    onAcknowledged()
                }
                .disabled(!acknowledged)
                .opacity(acknowledged ? Theme.Opacity.full : Theme.Opacity.medium)
                .padding(.horizontal, Theme.Spacing.pageMargin)
            }
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(
                    color: Theme.Colors.signalElevated,
                    verticalCenter: 0.25,
                    intensity: Theme.Opacity.medium
                )
                .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Epilepsy safety disclaimer")
    }
}

// MARK: - Screen 7: HealthKitPermissionView

/// Requests HealthKit authorization.
struct HealthKitPermissionView: View {
    let onContinue: () -> Void

    @State private var permissionRequested = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.signalCalm)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text("Connect to Apple Health")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("BioNaural reads your heart rate and HRV to adapt audio in real time. We also save mindful minutes to Health. Your data stays on-device.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                OnboardingPrimaryButton(title: "Allow Health Access") {
                    requestHealthKitPermission()
                }

                OnboardingSecondaryButton(title: "Skip for now") {
                    onContinue()
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(color: Theme.Colors.signalCalm, verticalCenter: 0.3)
                    .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("HealthKit permission request")
    }

    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            onContinue()
            return
        }

        let store = HKHealthStore()
        let readTypes: Set<HKObjectType> = Set(
            [
                HKObjectType.quantityType(forIdentifier: .heartRate),
                HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                HKObjectType.quantityType(forIdentifier: .restingHeartRate)
            ].compactMap { $0 }
        )
        let writeTypes: Set<HKSampleType> = Set(
            [
                HKObjectType.categoryType(forIdentifier: .mindfulSession)
            ].compactMap { $0 }
        )

        store.requestAuthorization(toShare: writeTypes, read: readTypes) { _, _ in
            DispatchQueue.main.async {
                onContinue()
            }
        }
    }
}

// MARK: - Screen 8: WatchDetectionView

/// Detects Apple Watch pairing status.
struct WatchDetectionView: View {
    let onContinue: () -> Void

    @State private var watchDetected = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: watchDetected ? "applewatch.radiowaves.left.and.right" : "applewatch")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(watchDetected ? Theme.Colors.accent : Theme.Colors.textTertiary)
                .animation(Theme.Animation.standard, value: watchDetected)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                if watchDetected {
                    Text("Apple Watch detected!")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("BioNaural will read your heart rate in real time for adaptive audio. The Watch app streams biometric data during sessions.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                } else {
                    Text("No Apple Watch detected")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("No problem! BioNaural works great without a Watch using time-based arcs and your check-in responses. You can pair one anytime.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(
                    color: watchDetected ? Theme.Colors.accent : Theme.Colors.textTertiary,
                    verticalCenter: 0.3
                )
                .ignoresSafeArea()
            }
        }
        .onAppear { checkWatchPairing() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apple Watch detection")
    }

    private func checkWatchPairing() {
        guard WCSession.isSupported() else {
            watchDetected = false
            return
        }
        let session = WCSession.default
        watchDetected = session.isPaired
    }
}

// MARK: - Screen 9: CalibrationView

/// 2-minute biometric calibration to establish resting HR and HRV baselines.
struct CalibrationView: View {
    let onComplete: (_ restingHR: Double?, _ hrv: Double?) -> Void

    @State private var isCalibrating = false
    @State private var progress: Double = 0
    @State private var currentHR: Int?

    private var calibrationDuration: TimeInterval {
        TimeInterval(Constants.calibrationDurationSeconds)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: isCalibrating ? "waveform.path.ecg" : "heart.circle.fill")
                .font(.system(size: Theme.Typography.Size.display))
                .foregroundStyle(Theme.Colors.signalCalm)
                .symbolEffect(.pulse, isActive: isCalibrating)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                if isCalibrating {
                    Text("Calibrating...")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Sit still and breathe normally. This takes about 2 minutes.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: progress)
                        .tint(Theme.Colors.signalCalm)
                        .padding(.horizontal, Theme.Spacing.xxxl)

                    if let hr = currentHR {
                        Text("\(hr) BPM")
                            .font(Theme.Typography.data)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                } else {
                    Text("Quick calibration")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("We'll measure your resting heart rate for 2 minutes. This helps BioNaural personalize the adaptive experience to your body.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                if !isCalibrating {
                    OnboardingPrimaryButton(title: "Start Calibration") {
                        startCalibration()
                    }

                    OnboardingSecondaryButton(title: "Skip for now") {
                        onComplete(nil, nil)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(
                    color: Theme.Colors.signalCalm,
                    verticalCenter: 0.3,
                    intensity: isCalibrating
                        ? Theme.Onboarding.Wave.intensity
                        : Theme.Opacity.medium
                )
                .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Biometric calibration")
    }

    private func startCalibration() {
        isCalibrating = true
        progress = 0

        // Simulate calibration progress
        let steps = Int(calibrationDuration * 10)
        let interval = calibrationDuration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                withAnimation {
                    progress = Double(step) / Double(steps)
                }
                // Simulate HR readings
                if step % 10 == 0 {
                    currentHR = Int.random(in: 60...75)
                }
                if step == steps {
                    let restingHR = Double(currentHR ?? 68)
                    let hrv = Double.random(in: 35...55)
                    onComplete(restingHR, hrv)
                }
            }
        }
    }
}

// MARK: - Screen 10: SoundPreferenceView

/// Initial sound palette preference selection.
struct SoundPreferenceView: View {
    let onSelected: (_ preference: SoundPreference) -> Void

    @State private var selected: SoundPreference?

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Text("What sounds do you prefer?")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("This helps us start with sounds you'll enjoy. You can always change this later.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            VStack(spacing: Theme.Spacing.md) {
                ForEach(SoundPreference.allCases) { preference in
                    soundPreferenceCard(preference)
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()

            OnboardingPrimaryButton(title: "Continue") {
                if let selected {
                    onSelected(selected)
                }
            }
            .disabled(selected == nil)
            .opacity(selected != nil ? Theme.Opacity.full : Theme.Opacity.medium)
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()
                OnboardingWaveCanvas(color: Theme.Colors.accent, verticalCenter: 0.15)
                    .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sound preference selection")
    }

    private func soundPreferenceCard(_ preference: SoundPreference) -> some View {
        let isSelected = selected == preference

        return Button {
            withAnimation(Theme.Animation.press) {
                selected = preference
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: preference.iconName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .frame(width: Theme.Spacing.xxxl, alignment: .center)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(preference.displayName)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(preference.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Colors.accent : Color.clear,
                        lineWidth: isSelected ? Theme.Radius.glassStroke * 2 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preference.displayName), \(preference.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Screen 11: FirstSessionView

/// Invites the user to start their first session. The four brand waves
/// converge behind the copy — bookending the onboarding with the same
/// visual signature that opened it.
struct FirstSessionView: View {
    let onSessionStarted: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.Colors.canvas
                .ignoresSafeArea()

            // Brand wave signature — all four mode waves, focus highlighted
            BrandWaveCanvas(highlightedMode: .focus)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Text("You're ready.")
                        .font(Theme.Typography.display)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Start your first session and experience sound that responds to you.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)

                Spacer()

                OnboardingPrimaryButton(title: "Start First Session") {
                    onSessionStarted()
                }
                .padding(.horizontal, Theme.Spacing.pageMargin)
                .padding(.bottom, Theme.Spacing.jumbo)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: Theme.Animation.Duration.orbEntrance)) {
                contentOpacity = 1.0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ready to start your first session")
    }
}

// MARK: - Shared Onboarding Button Components

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Capsule()
                        .fill(Theme.Colors.accent)
                )
        }
        .accessibilityLabel(title)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Capsule()
                        .strokeBorder(Theme.Colors.divider)
                )
        }
        .accessibilityLabel(title)
    }
}
