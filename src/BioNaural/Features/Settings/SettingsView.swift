// SettingsView.swift
// BioNaural
//
// Native SwiftUI Form-based settings screen. All values from Theme tokens,
// all persistence through UserProfile (SwiftData) and UserDefaults.
// Sections grouped logically: Core Experience, Content Libraries,
// Intelligence & Notifications, Devices & System.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SettingsView

struct SettingsView: View {

    // MARK: - Data

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies

    // MARK: - Local State

    @State private var showExportConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var healthKitAuthorized = false
    @State private var showPaywall = false
    @State private var showOnboarding = false
    @State private var showResetOnboardingConfirmation = false
    @State private var showResetAllDataConfirmation = false
    @State private var premiumOverrideEnabled = false

    // MARK: - Convenience

    private var profile: UserProfile? {
        profiles.first
    }

    // MARK: - Body

    var body: some View {
            Form {
                // ── Core Experience ──
                sessionSection
                soundSection

                // ── Content Libraries ──
                sonicMemorySection
                contextTracksSection
                bodyMusicSection

                // ── Intelligence & Notifications ──
                calendarSection
                notificationsSection

                // ── Devices & System ──
                connectedDevicesSection
                safetySection
                privacySection
                aboutSection

                // ── Developer ──
                developerSection
            }
            .scrollContentBackground(.hidden)
            .background { NebulaBokehBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary)
            .sheet(isPresented: $showExportShare) {
                if let url = exportShareItem {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                }
            }
            .task {
                // Ensure a UserProfile exists so settings bindings persist.
                if profiles.isEmpty {
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    try? modelContext.save()
                }

                // Sync premium override toggle with current state.
                premiumOverrideEnabled = SubscriptionManager.shared.isPremium

                // Track HealthKit authorization status.
                healthKitAuthorized = dependencies.healthKitService.isAvailable
                for await authorized in dependencies.healthKitService.authorizationStatusChanged {
                    healthKitAuthorized = authorized
                }
            }
    }

    // MARK: - Session Section

    private var sessionSection: some View {
        Section {
            // Default mode picker.
            Picker(
                "Default Mode",
                selection: Binding(
                    get: { FocusMode(rawValue: profile?.preferredMode ?? FocusMode.focus.rawValue) ?? .focus },
                    set: { profile?.preferredMode = $0.rawValue }
                )
            ) {
                ForEach(FocusMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .accessibilityLabel("Default session mode")

            // Default duration stepper.
            Stepper(
                "Duration: \(profile?.preferredDurationMinutes ?? Constants.pomodoroFocusMinutes) min",
                value: Binding(
                    get: { profile?.preferredDurationMinutes ?? Constants.pomodoroFocusMinutes },
                    set: { profile?.preferredDurationMinutes = $0 }
                ),
                in: Constants.minimumSessionMinutes...Constants.maxSessionMinutes,
                step: 5
            )
            .accessibilityLabel("Default session duration")
            .accessibilityValue("\(profile?.preferredDurationMinutes ?? Constants.pomodoroFocusMinutes) minutes")

            // Pomodoro toggle.
            Toggle(
                "Pomodoro Timer",
                isOn: Binding(
                    get: { profile?.pomodoroEnabled ?? false },
                    set: { profile?.pomodoroEnabled = $0 }
                )
            )
            .accessibilityLabel("Enable Pomodoro timer for Focus mode")

            // Pomodoro cycles stepper (shown when Pomodoro is on).
            if profile?.pomodoroEnabled == true {
                Stepper(
                    "Cycles: \(profile?.pomodoroCycles ?? Constants.defaultPomodoroCycles)",
                    value: Binding(
                        get: { profile?.pomodoroCycles ?? Constants.defaultPomodoroCycles },
                        set: { profile?.pomodoroCycles = $0 }
                    ),
                    in: 1...8
                )
                .accessibilityLabel("Pomodoro cycles per set")
            }

            // Adaptation sensitivity slider.
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Adaptation Sensitivity")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Slider(
                    value: Binding(
                        get: { profile?.adaptationSensitivity ?? 0.5 },
                        set: { profile?.adaptationSensitivity = $0 }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Adaptation sensitivity")
                .accessibilityValue(
                    String(format: "%.0f%%", (profile?.adaptationSensitivity ?? 0.5) * 100)
                )
            }
        } header: {
            sectionHeader("Session")
        }
    }

    // MARK: - Sound Section

    private var soundSection: some View {
        Section {
            // Sound style picker.
            Picker(
                "Sound Style",
                selection: Binding(
                    get: { profile?.soundPreference ?? "mix" },
                    set: { profile?.soundPreference = $0 }
                )
            ) {
                Text("Nature").tag("nature")
                Text("Musical").tag("musical")
                Text("Minimal").tag("minimal")
                Text("Mix").tag("mix")
            }
            .accessibilityLabel("Sound style preference")

            // Haptic feedback toggle.
            Toggle(
                "Haptic Feedback",
                isOn: Binding(
                    get: { profile?.hapticFeedbackEnabled ?? true },
                    set: { profile?.hapticFeedbackEnabled = $0 }
                )
            )
            .accessibilityLabel("Enable haptic feedback during sessions")

            // Reset learned preferences.
            Button("Reset Sound Preferences") {
                profile?.soundPreference = "mix"
            }
            .foregroundStyle(Theme.Colors.accent)
            .accessibilityLabel("Reset learned sound preferences to defaults")
        } header: {
            sectionHeader("Sound")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(
                "Session Reminders",
                isOn: Binding(
                    get: { profile?.notificationsEnabled ?? false },
                    set: { profile?.notificationsEnabled = $0 }
                )
            )
            .accessibilityLabel("Enable daily session reminders")

            if profile?.notificationsEnabled == true {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: { profile?.sessionReminderTime ?? defaultReminderTime },
                        set: { profile?.sessionReminderTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Daily reminder time")
            }

            Toggle(
                "Weekly Summary",
                isOn: Binding(
                    get: { profile?.weeklySummaryEnabled ?? false },
                    set: { profile?.weeklySummaryEnabled = $0 }
                )
            )
            .accessibilityLabel("Receive a weekly session summary notification")

            NavigationLink("Advanced Notification Settings") {
                NotificationSettingsView()
            }
        } header: {
            sectionHeader("Notifications")
        }
    }

    // MARK: - Calendar Intelligence Section

    private var calendarSection: some View {
        Section {
            NavigationLink {
                CalendarInsightsView()
            } label: {
                Label("Calendar Insights", systemImage: "calendar.badge.clock")
            }

            NavigationLink {
                FocusFilterSettingsView()
            } label: {
                Label("Focus Filters", systemImage: "moon.circle")
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label("Notification Preferences", systemImage: "bell.badge")
            }
        } header: {
            sectionHeader("Life-Aware Audio")
        }
    }

    // MARK: - Sonic Memory Section

    private var sonicMemorySection: some View {
        Section {
            NavigationLink {
                YourSoundView()
            } label: {
                Label("Your Sound", systemImage: "waveform.circle")
            }

            NavigationLink {
                SonicMemoryListView()
            } label: {
                Label("Sonic Memories", systemImage: "memories")
            }
        } header: {
            sectionHeader("Sound Personalization")
        }
    }

    // MARK: - Context Tracks Section

    private var contextTracksSection: some View {
        Section {
            NavigationLink {
                ContextTrackLibraryView()
            } label: {
                Label("Study & Context Tracks", systemImage: "music.note.list")
            }
        } header: {
            sectionHeader("Context Tracks")
        }
    }

    // MARK: - Body Music Section

    private var bodyMusicSection: some View {
        Section {
            NavigationLink {
                BodyMusicLibraryView()
            } label: {
                Label("Saved Tracks", systemImage: "waveform")
            }
        } header: {
            sectionHeader("Body Music")
        }
    }

    // MARK: - Connected Devices Section

    private var connectedDevicesSection: some View {
        Section {
            HStack {
                Label("Apple Watch", systemImage: "applewatch")
                Spacer()
                Text(dependencies.isWatchConnected ? "Connected" : "Not connected")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        dependencies.isWatchConnected
                            ? Theme.Colors.signalCalm
                            : Theme.Colors.textTertiary
                    )
            }
            .accessibilityLabel(
                "Apple Watch status: \(dependencies.isWatchConnected ? "connected" : "not connected")"
            )

            HStack {
                Label("HealthKit", systemImage: "heart.text.square")
                Spacer()
                Text(healthKitStatusLabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        healthKitAuthorized
                            ? Theme.Colors.signalCalm
                            : Theme.Colors.textTertiary
                    )
            }
            .accessibilityLabel("HealthKit authorization status: \(healthKitStatusLabel)")
        } header: {
            sectionHeader("Connected Services")
        }
    }

    // MARK: - Safety Section

    @State private var showEpilepsyDisclaimer = false
    @State private var showEnergizeSafety = false

    private var safetySection: some View {
        Section {
            Button {
                showEpilepsyDisclaimer = true
            } label: {
                Label("Epilepsy Disclaimer", systemImage: "exclamationmark.triangle")
            }
            .accessibilityLabel("View epilepsy and safety disclaimer")
            .alert("Epilepsy & Photosensitivity", isPresented: $showEpilepsyDisclaimer) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Binaural beats involve rhythmic auditory stimulation. If you have epilepsy or a seizure disorder, " +
                    "consult your physician before use. BioNaural does not use visual flashing, " +
                    "but the audio frequencies may not be suitable for everyone.")
            }

            Button {
                showEnergizeSafety = true
            } label: {
                Label("Energize Safety", systemImage: "bolt.heart")
            }
            .accessibilityLabel("View Energize mode safety information")
            .alert("Energize Mode Safety", isPresented: $showEnergizeSafety) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Energize mode uses upward biometric feedback. Safety guardrails include HR ceiling limits, " +
                    "mandatory cool-down periods, and automatic session termination if heart rate exceeds safe thresholds. " +
                    "If you have a heart condition, consult your physician before using Energize mode.")
            }
        } header: {
            sectionHeader("Safety")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            Button {
                showExportConfirmation = true
            } label: {
                Label("Export My Data", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Export all personal data as JSON")
            .alert("Export Data", isPresented: $showExportConfirmation) {
                Button("Export", role: .none) { exportData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your session history and preferences will be exported as a JSON file.")
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete My Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Delete all personal data")
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all session history, preferences, and learned data. This cannot be undone.")
            }
        } header: {
            sectionHeader("Privacy")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(appVersion)
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .accessibilityLabel("App version \(appVersion)")

            Link(destination: Self.privacyURL) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            .accessibilityLabel("Open privacy policy in browser")

            Link(destination: Self.termsURL) {
                Label("Terms of Service", systemImage: "doc.text")
            }
            .accessibilityLabel("Open terms of service in browser")
        } header: {
            sectionHeader("About")
        }
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            // Replay Onboarding
            Button {
                showOnboarding = true
            } label: {
                Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Replay the onboarding flow")

            // Reset Onboarding State
            Button {
                showResetOnboardingConfirmation = true
            } label: {
                Label("Reset Onboarding State", systemImage: "arrow.triangle.2.circlepath")
            }
            .accessibilityLabel("Reset onboarding so it shows on next launch")
            .alert("Reset Onboarding?", isPresented: $showResetOnboardingConfirmation) {
                Button("Reset", role: .destructive) {
                    OnboardingView.resetOnboarding()
                    UserDefaults.standard.removeObject(forKey: ContentView.onboardingCompleteKey)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Clears all onboarding progress. The onboarding flow will show again on next launch.")
            }

            // Preview Paywall
            Button {
                showPaywall = true
            } label: {
                Label("Preview Paywall", systemImage: "creditcard")
            }
            .accessibilityLabel("Show the paywall screen")

            // Premium Override Toggle
            Toggle(isOn: $premiumOverrideEnabled) {
                Label("Override Premium", systemImage: "crown")
            }
            .tint(Theme.Colors.accent)
            .onChange(of: premiumOverrideEnabled) { _, newValue in
                SubscriptionManager.shared.debugSetPremium(newValue)
            }
            .accessibilityLabel("Toggle premium status for testing")

            // Session Demo
            NavigationLink {
                SessionDemoView()
            } label: {
                Label("Session Demo", systemImage: "waveform.path")
            }
            .accessibilityLabel("Test frequency-synced visuals")

            // Subscription Status
            HStack {
                Label("Premium Status", systemImage: "star.circle")
                Spacer()
                Text(SubscriptionManager.shared.isPremium ? "Active" : "Free")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        SubscriptionManager.shared.isPremium
                            ? Theme.Colors.accent
                            : Theme.Colors.textTertiary
                    )
            }
            .accessibilityLabel(
                "Premium status: \(SubscriptionManager.shared.isPremium ? "active" : "free tier")"
            )

            // Session Count Today
            HStack {
                Label("Sessions Today", systemImage: "number.circle")
                Spacer()
                Text("\(dailySessionCount) / \(FreeTierLimits.maxSessionsPerDay)")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .accessibilityLabel("Sessions today: \(dailySessionCount) of \(FreeTierLimits.maxSessionsPerDay)")

            // Reset All Data
            Button(role: .destructive) {
                showResetAllDataConfirmation = true
            } label: {
                Label("Reset All Data", systemImage: "trash.circle")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Delete all app data and reset to fresh state")
            .alert("Reset Everything?", isPresented: $showResetAllDataConfirmation) {
                Button("Reset", role: .destructive) {
                    deleteData()
                    OnboardingView.resetOnboarding()
                    SubscriptionManager.shared.debugSetPremium(false)
                    premiumOverrideEnabled = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes all sessions, preferences, and learned data. Resets onboarding and premium status. This cannot be undone.")
            }
        } header: {
            sectionHeader("Developer")
        } footer: {
            Text("These tools are for development and testing only.")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: - URLs

    // swiftlint:disable force_unwrapping
    private static let privacyURL = URL(string: "https://bionaural.app/privacy")!
    private static let termsURL = URL(string: "https://bionaural.app/terms")!
    // swiftlint:enable force_unwrapping

    // MARK: - Helpers

    private var healthKitStatusLabel: String {
        if !dependencies.healthKitService.isAvailable {
            return "Not available"
        }
        return healthKitAuthorized ? "Authorized" : "Not authorized"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var dailySessionCount: Int {
        let defaults = UserDefaults.standard
        let storedDate = defaults.object(forKey: FreeTierLimits.dailyCountDateKey) as? Date
        let isToday = storedDate.map { Calendar.current.isDateInToday($0) } ?? false
        return isToday ? defaults.integer(forKey: FreeTierLimits.dailyCountKey) : 0
    }

    private var defaultReminderTime: Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    @State private var exportShareItem: URL?
    @State private var showExportShare = false

    private func exportData() {
        let sessions = (try? modelContext.fetch(FetchDescriptor<FocusSession>())) ?? []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        struct ExportPayload: Encodable {
            let exportDate: Date
            let sessions: [SessionExport]
            let profile: ProfileExport?
        }
        struct SessionExport: Encodable {
            let mode: String
            let startDate: Date
            let durationSeconds: Int
        }
        struct ProfileExport: Encodable {
            let preferredMode: String?
            let preferredDuration: Int?
            let soundPreference: String?
        }

        let payload = ExportPayload(
            exportDate: Date(),
            sessions: sessions.map {
                SessionExport(mode: $0.mode, startDate: $0.startDate, durationSeconds: $0.durationSeconds)
            },
            profile: profile.map {
                ProfileExport(
                    preferredMode: $0.preferredMode,
                    preferredDuration: $0.preferredDurationMinutes,
                    soundPreference: $0.soundPreference
                )
            }
        )

        guard let data = try? encoder.encode(payload) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BioNaural-Export-\(Date().timeIntervalSince1970).json")
        try? data.write(to: url)
        exportShareItem = url
        showExportShare = true
    }

    private func deleteData() {
        try? modelContext.delete(model: FocusSession.self)
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.delete(model: SoundProfile.self)
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: ContentView.onboardingCompleteKey)
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("SettingsView") {
    SettingsView()
        .preferredColorScheme(.dark)
}
