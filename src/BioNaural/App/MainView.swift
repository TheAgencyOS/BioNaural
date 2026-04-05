// MainView.swift
// BioNaural
//
// Root navigation — TabView with glass tab bar.
// Three tabs: Home (smart hub), Compose, Insights.
// Home features contextual recommendation, mode carousel,
// streak counter, and pre-session check-in sheet.
// All values from Theme tokens. Native SwiftUI.

import SwiftUI
import SwiftData
import BioNauralShared
import OSLog

// MARK: - Navigation Destination

enum AppDestination: Hashable, Codable {
    case session(FocusMode)
    case composedSession(id: UUID)
    case science
    case settings
    case morningBrief
    case contextTrackLibrary
    case sonicMemoryList
    case yourSound
    case bodyMusicLibrary
    case preEventSession(eventTitle: String, mode: FocusMode)
}

// MARK: - MainView

struct MainView: View {

    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedTab: AppTab = .home
    @State private var homeNavigationPath = NavigationPath()

    var body: some View {
        if #available(iOS 26.0, *) {
            ios26TabView
        } else {
            legacyTabView
        }
    }

    // MARK: - iOS 26+ (Liquid Glass with separated search circle + bottom accessory)

    @available(iOS 26.0, *)
    private var ios26TabView: some View {
        TabView {
            Tab("Home", systemImage: "waveform.circle.fill") {
                NavigationStack(path: $homeNavigationPath) {
                    HomeTab(navigationPath: $homeNavigationPath)
                        .navigationDestination(for: AppDestination.self) { destination in
                            sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                        }
                }
            }

            Tab("Compose", systemImage: "slider.horizontal.2.square") {
                NavigationStack {
                    ComposerView()
                        .navigationDestination(for: AppDestination.self) { destination in
                            sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                        }
                }
            }

            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    LibraryView()
                        .navigationDestination(for: AppDestination.self) { destination in
                            sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                        }
                }
            }

            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack {
                    InsightsView()
                }
            }
        }
        .tint(Theme.Colors.accent)
        .overlay(alignment: .bottom) {
            if dependencies.audioEngine.isPlaying, dependencies.activeSessionMode != nil {
                sessionMiniPlayer
                    .padding(.bottom, Theme.Spacing.mega + Theme.Spacing.xl)
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.standard, value: dependencies.activeSessionMode != nil)
            }
        }
    }

    // MARK: - Legacy (iOS 17-25)

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeNavigationPath) {
                HomeTab(navigationPath: $homeNavigationPath)
                    .navigationDestination(for: AppDestination.self) { destination in
                        sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                    }
            }
                .tabItem { Label("Home", systemImage: "waveform.circle.fill") }
                .tag(AppTab.home)

            NavigationStack {
                ComposerView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                    }
            }
            .tabItem { Label("Compose", systemImage: "slider.horizontal.2.square") }
            .tag(AppTab.compose)

            NavigationStack {
                LibraryView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        sharedDestinationView(for: destination, audioEngine: dependencies.audioEngine)
                    }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                InsightsView()
            }
            .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.insights)
        }
        .tint(Theme.Colors.accent)
        .overlay(alignment: .bottom) {
            if dependencies.audioEngine.isPlaying, dependencies.activeSessionMode != nil {
                sessionMiniPlayer
                    .padding(.bottom, Theme.Spacing.mega) // clear the tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Theme.Animation.standard, value: dependencies.audioEngine.isPlaying)
            }
        }
    }

    // MARK: - Session Mini Player

    private var sessionMiniPlayer: some View {
        let mode = dependencies.activeSessionMode ?? .focus
        let modeColor = Color.modeColor(for: mode)
        let beatFrequency = dependencies.audioEngine.parameters.beatFrequency
        let elapsed = dependencies.activeSessionElapsed

        return Button {
            selectedTab = .home
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // Active indicator dot — mode-colored
                Circle()
                    .fill(modeColor)
                    .frame(
                        width: Theme.MiniPlayer.indicatorSize,
                        height: Theme.MiniPlayer.indicatorSize
                    )

                // Mode name
                Text(mode.displayName)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Compact wavelength
                WavelengthView(
                    biometricState: .calm,
                    sessionMode: mode,
                    beatFrequency: beatFrequency,
                    isPlaying: true,
                    layerColor: modeColor,
                    isCompact: true
                )
                .frame(height: Theme.MiniPlayer.wavelengthHeight)
                .clipShape(Capsule())

                // Elapsed time
                Text(formatMiniPlayerTime(elapsed))
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()

                // Stop button
                Button {
                    stopActiveSession()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Stop session")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.displayName) session active, \(formatMiniPlayerTime(elapsed)) elapsed. Tap to return.")
    }

    // MARK: - Mini Player Helpers

    private func stopActiveSession() {
        dependencies.audioEngine.stop()
        dependencies.activeSessionMode = nil
        dependencies.activeSessionElapsed = 0
    }

    private func formatMiniPlayerTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private enum AppTab: Hashable {
    case home, compose, library, insights
}

// MARK: - Shared Navigation Destination

/// Shared destination resolver used by both Home and Compose tab NavigationStacks.
/// Keeps navigation logic in one place to prevent divergence.
@MainActor @ViewBuilder
private func sharedDestinationView(
    for destination: AppDestination,
    audioEngine: any AudioEngineProtocol
) -> some View {
    switch destination {
    case .session(let mode):
        SessionView(viewModel: SessionViewModel(
            mode: mode,
            durationMinutes: mode.defaultDurationMinutes,
            isAdaptive: false,
            pomodoroEnabled: false,
            audioEngine: audioEngine
        ))
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
    case .composedSession(let compositionID):
        ComposedSessionLauncher(
            compositionID: compositionID,
            audioEngine: audioEngine
        )
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
    case .science:
        Text("Coming soon").foregroundStyle(Theme.Colors.textTertiary)
    case .settings:
        SettingsView()
    case .morningBrief:
        Text("Morning Brief").foregroundStyle(Theme.Colors.textTertiary) // placeholder for now
    case .contextTrackLibrary:
        ContextTrackLibraryView()
    case .sonicMemoryList:
        SonicMemoryListView()
    case .yourSound:
        YourSoundView()
    case .bodyMusicLibrary:
        BodyMusicLibraryView()
    case .preEventSession(let title, let mode):
        Text("Pre-Event: \(title)").foregroundStyle(Theme.Colors.textTertiary) // placeholder
    }
}

// MARK: - Home Tab

// MARK: - Composed Session Launcher

/// Fetches a CustomComposition by ID from SwiftData and launches the session.
/// Used by the navigation destination for `.composedSession(id:)`.
private struct ComposedSessionLauncher: View {

    let compositionID: UUID
    let audioEngine: any AudioEngineProtocol

    @Query private var compositions: [CustomComposition]

    var body: some View {
        if let composition = compositions.first(where: { $0.id == compositionID }) {
            SessionView(viewModel: SessionViewModel(
                mode: composition.focusMode ?? .focus,
                durationMinutes: composition.durationMinutes,
                isAdaptive: composition.isAdaptive,
                pomodoroEnabled: false,
                audioEngine: audioEngine
            ))
            .onAppear {
                IntentDonation.donateStartSession(
                    mode: composition.focusMode ?? .focus,
                    durationMinutes: composition.durationMinutes
                )
            }
        } else {
            Text("Composition not found")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

// MARK: - Home Tab

private struct HomeTab: View {

    @Environment(AppDependencies.self) private var dependencies
    @Binding var navigationPath: NavigationPath

    // Health data
    @State private var restingHR: Double?
    @State private var hrv: Double?
    @State private var sleepHours: Double?

    // Session history for recommendation + streak
    @Query(sort: \FocusSession.startDate, order: .reverse)
    private var allSessions: [FocusSession]

    // Morning brief + pre-event
    @State private var morningBrief: MorningBrief?
    @State private var upcomingStressor: ClassifiedEvent?
    @State private var freeWindow: DateInterval?
    @State private var showPreEventCard = false

    // Check-in sheet state
    @State private var showCheckIn = false
    @State private var showSoundDNA = false
    @State private var checkInMode: FocusMode = .focus

    // Entrance animation
    @State private var sectionsVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: .zero) {
                // === MODE CAROUSEL (with recommendation as card 0) ===
                ModeCarouselView(
                    recommendation: carouselRecommendation,
                    onStartSession: { mode in
                        presentCheckIn(mode)
                    }
                )
                .staggeredFadeIn(index: 1, isVisible: sectionsVisible)

                Spacer()
                    .frame(height: Theme.Spacing.xxl)

                // === WATCH STATUS ===
                watchStatus
                    .staggeredFadeIn(index: 2, isVisible: sectionsVisible)

                Spacer()
                    .frame(height: Theme.Spacing.xxl)

                // === CONTEXTUAL SECTION (calendar-aware) ===
                contextualSection
                    .padding(.horizontal, Theme.Spacing.pageMargin)
                    .staggeredFadeIn(index: 3, isVisible: sectionsVisible)
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .task {
            await loadHealthData()

            // Load morning brief (after health data)
            let generator = MorningBriefGenerator(
                healthKitService: dependencies.healthKitService,
                calendarService: dependencies.calendarService,
                calendarClassifier: dependencies.calendarClassifier,
                userModelBuilder: nil  // v1.1: wire UserModelBuilder from AppDependencies when available
            )
            morningBrief = await generator.generateBrief()

            // Load calendar context for contextual section
            if dependencies.calendarService.isAuthorized {
                let todayEvents = await dependencies.calendarService.todaysEvents()
                let classified = await dependencies.calendarClassifier.classifyBatch(todayEvents)

                // Find first high/critical stressor within next 4 hours
                let fourHoursFromNow = Date().addingTimeInterval(Constants.Circadian.stressorLookaheadSeconds)
                upcomingStressor = classified.first { event in
                    event.stressLevel >= .high && event.startDate <= fourHoursFromNow && event.startDate > Date()
                }

                freeWindow = await dependencies.calendarService.nextFreeWindow(minimumMinutes: Constants.Circadian.minimumFreeWindowMinutes)
            }
        }
        .background { NebulaBokehBackground() }
        .navigationTitle("BioNaural")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    soundDNAButton
                    settingsButton
                }
            }
        }
        .sheet(isPresented: $showSoundDNA) {
            soundDNACaptureSheet
        }
        .sheet(isPresented: $showCheckIn) {
            PreSessionCheckInSheet(
                mode: checkInMode,
                isWatchConnected: dependencies.isWatchConnected
            ) { mood, duration, isAdaptive in
                startSession(checkInMode, mood: mood, durationMinutes: duration, isAdaptive: isAdaptive)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                sectionsVisible = true
                return
            }
            withAnimation(Theme.Animation.standard) {
                sectionsVisible = true
            }
        }
    }

    // MARK: - Circadian Suggestion Engine

    private struct CircadianResult {
        let mode: FocusMode
        let reason: String
    }

    /// Bridges circadian suggestion into the carousel recommendation format.
    private var carouselRecommendation: CarouselRecommendation {
        let suggestion = circadianSuggestion
        return CarouselRecommendation(
            mode: suggestion.mode,
            reason: suggestion.reason,
            restingHR: restingHR,
            hrv: hrv,
            sleepHours: sleepHours,
            isWatchConnected: dependencies.isWatchConnected
        )
    }

    private var circadianSuggestion: CircadianResult {
        let hour = Calendar.current.component(.hour, from: Date())

        // Factor in biometrics if available
        let lowHRV = (hrv ?? HealthDefaults.hrv) < Constants.lowHRVThreshold
        let poorSleep = (sleepHours ?? HealthDefaults.sleepHours) < Constants.poorSleepHoursThreshold

        switch hour {
        case Constants.Circadian.morningStart..<Constants.Circadian.peakStart:
            if poorSleep {
                return CircadianResult(mode: .energize, reason: "Short night \u{2014} a quick activation will help you start the day.")
            }
            return CircadianResult(mode: .energize, reason: "Morning activation to start your day with energy.")
        case Constants.Circadian.peakStart..<Constants.Circadian.middayStart:
            return CircadianResult(mode: .focus, reason: "Peak cognitive hours \u{2014} ideal for deep work.")
        case Constants.Circadian.middayStart..<Constants.Circadian.afternoonStart:
            if lowHRV {
                return CircadianResult(mode: .relaxation, reason: "Your HRV is low \u{2014} a midday reset would help recover.")
            }
            return CircadianResult(mode: .focus, reason: "Post-lunch focus to power through the afternoon.")
        case Constants.Circadian.afternoonStart..<Constants.Circadian.eveningStart:
            return CircadianResult(mode: .focus, reason: "Afternoon deep work session.")
        case Constants.Circadian.eveningStart..<Constants.Circadian.nightStart:
            return CircadianResult(mode: .relaxation, reason: "Wind down from the day. Your nervous system will thank you.")
        case Constants.Circadian.nightStart..<Constants.Circadian.lateNightStart:
            return CircadianResult(mode: .sleep, reason: "Prepare your brain for sleep with a theta descent.")
        default:
            return CircadianResult(mode: .sleep, reason: "Late night \u{2014} guide your brain toward delta for deep rest.")
        }
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        let streak = currentStreak
        let thisWeekCount = sessionsThisWeek

        return HStack(spacing: Theme.Spacing.lg) {
            // Streak
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                    .foregroundStyle(streak > 0 ? Theme.Colors.energize : Theme.Colors.textTertiary)

                Text(streak > 0 ? "\(streak)-day streak" : "Start a streak")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(streak > 0 ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
            }

            Spacer()

            // This week count
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(thisWeekCount)")
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.accent)

                Text("this week")
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(streak > 0 ? "\(streak) day streak, \(thisWeekCount) sessions this week" : "\(thisWeekCount) sessions this week")
    }

    // MARK: Streak Calculation

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streakCount = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's a session today first
        let hasToday = allSessions.contains { calendar.isDate($0.startDate, inSameDayAs: checkDate) }

        if !hasToday {
            // No session today — check from yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        while true {
            let dayHasSession = allSessions.contains {
                calendar.isDate($0.startDate, inSameDayAs: checkDate)
            }

            if dayHasSession {
                streakCount += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streakCount
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return allSessions.filter { $0.startDate >= startOfWeek }.count
    }

    // MARK: - Last Session Card

    @ViewBuilder
    private var lastSessionCard: some View {
        if let lastSession = allSessions.first {
            let mode = lastSession.focusMode ?? .focus
            let modeColor = Color.modeColor(for: mode)

            HStack(spacing: Theme.Spacing.md) {
                // Mode icon
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(Theme.Opacity.accentLight))
                        .frame(
                            width: Theme.Spacing.xxxl + Theme.Spacing.xs,
                            height: Theme.Spacing.xxxl + Theme.Spacing.xs
                        )

                    Image(systemName: mode.systemImageName)
                        .font(.system(size: Theme.Typography.Size.caption))
                        .foregroundStyle(modeColor)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Last session")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)

                    Text("\(mode.displayName) \u{2022} \(lastSession.durationSeconds.formattedDuration)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Spacer()

                Text(lastSession.startDate.timeAgo)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .strokeBorder(
                                Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )
            )
        }
    }

    // MARK: - Sound DNA Button

    private var soundDNAButton: some View {
        Button {
            showSoundDNA = true
        } label: {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.accent)
        }
        .accessibilityLabel("Sound DNA")
    }

    private var soundDNACaptureSheet: some View {
        let service = SoundDNAService()
        let store = SwiftDataSoundProfileStore(
            modelContext: dependencies.modelContainer.mainContext
        )
        let manager = SoundProfileManager(store: store)
        let vm = SoundDNACaptureViewModel(
            service: service,
            profileManager: manager,
            modelContext: dependencies.modelContainer.mainContext
        )
        return SoundDNACaptureView(viewModel: vm)
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .accessibilityLabel("Settings")
    }

    // MARK: - Quick Access Row

    @ViewBuilder
    private func quickAccessCard(
        title: String,
        icon: String,
        tint: Color,
        destination: AppDestination
    ) -> some View {
        NavigationLink {
            sharedDestinationContent(for: destination)
        } label: {
            ZStack(alignment: .topLeading) {
                // Subtle radial glow
                RadialGradient(
                    colors: [tint.opacity(Theme.Opacity.light), Color.clear],
                    center: .topLeading,
                    startRadius: .zero,
                    endRadius: Theme.Spacing.mega * 2
                )

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: Theme.Typography.Size.headline, weight: .light))
                        .foregroundStyle(tint)

                    Spacer()

                    Text(title)
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(Theme.Spacing.lg)
            }
            .aspectRatio(1, contentMode: .fill)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .strokeBorder(
                        Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Contextual Section (Calendar-Aware)

    @ViewBuilder
    private var contextualSection: some View {
        if let stressor = upcomingStressor {
            upcomingStressorCard(stressor)
        } else if let window = freeWindow {
            freeWindowCard(window)
        } else {
            quickAccessCards
        }
    }

    /// Fallback: the original 3-column quick access grid.
    private var quickAccessCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            quickAccessCard(
                title: "Tracks",
                icon: "music.note.list",
                tint: Theme.Colors.accent,
                destination: .contextTrackLibrary
            )
            quickAccessCard(
                title: "Sessions",
                icon: "waveform",
                tint: Theme.Colors.relaxation,
                destination: .bodyMusicLibrary
            )
            quickAccessCard(
                title: "Correlations",
                icon: "memories",
                tint: Theme.Colors.sleep,
                destination: .sonicMemoryList
            )
        }
    }

    @ViewBuilder
    private func sharedDestinationContent(for destination: AppDestination) -> some View {
        switch destination {
        case .contextTrackLibrary:
            ContextTrackLibraryView()
        case .bodyMusicLibrary:
            BodyMusicLibraryView()
        case .sonicMemoryList:
            SonicMemoryListView()
        case .yourSound:
            YourSoundView()
        case .settings:
            SettingsView()
        default:
            Text("Not available")
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    /// Priority 1: A high/critical stress event is approaching.
    private func upcomingStressorCard(_ stressor: ClassifiedEvent) -> some View {
        let modeColor = Color.modeColor(for: stressor.suggestedMode)
        let stressColor = stressor.stressLevel == .critical
            ? Theme.Colors.signalPeak
            : Theme.Colors.signalElevated
        let timeText = stressor.startDate.formatted(date: .omitted, time: .shortened)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: event title + stress dot + time
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(stressColor)
                    .frame(
                        width: Theme.Spacing.xs,
                        height: Theme.Spacing.xs
                    )

                Text("\(stressor.title) at \(timeText)")
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }

            // Suggestion line
            Text("Prep with a \(stressor.suggestedSessionMinutes)-min \(stressor.suggestedMode.displayName) session")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)

            // Play button
            Button {
                presentCheckIn(stressor.suggestedMode)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: Theme.Typography.Size.small, weight: .medium))

                    Text("Start \(stressor.suggestedMode.displayName)")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(modeColor)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(modeColor.opacity(Theme.Opacity.accentLight))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(stressor.suggestedMode.displayName) session to prepare for \(stressor.title)")
        }
        .padding(Theme.Spacing.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)

                // Subtle radial glow matching streak badge pattern
                RadialGradient(
                    colors: [stressColor.opacity(Theme.Opacity.light), Color.clear],
                    center: .topLeading,
                    startRadius: .zero,
                    endRadius: Theme.Spacing.mega * 3
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stressor.title) at \(timeText), \(stressor.stressLevel.rawValue) stress. Suggested: \(stressor.suggestedSessionMinutes) minute \(stressor.suggestedMode.displayName) session.")
    }

    /// Priority 2: A free time window exists with no imminent stressor.
    private func freeWindowCard(_ window: DateInterval) -> some View {
        let freeMinutes = Int(window.duration / 60)
        let endTimeText = window.end.formatted(date: .omitted, time: .shortened)
        let suggestion = circadianSuggestion
        let modeColor = Color.modeColor(for: suggestion.mode)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: free window description
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text("\(freeMinutes) min free before \(endTimeText)")
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()
            }

            // Suggestion based on circadian engine
            Text("Good time for a \(suggestion.mode.displayName) session")
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textSecondary)

            // Play button
            Button {
                presentCheckIn(suggestion.mode)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: Theme.Typography.Size.small, weight: .medium))

                    Text("Start \(suggestion.mode.displayName)")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(modeColor)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(modeColor.opacity(Theme.Opacity.accentLight))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(suggestion.mode.displayName) session during \(freeMinutes) minute free window")
        }
        .padding(Theme.Spacing.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)

                RadialGradient(
                    colors: [modeColor.opacity(Theme.Opacity.light), Color.clear],
                    center: .topLeading,
                    startRadius: .zero,
                    endRadius: Theme.Spacing.mega * 3
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(freeMinutes) minutes free before \(endTimeText). Suggested: \(suggestion.mode.displayName) session.")
    }

    // MARK: - Health Data

    /// Convenience alias for population-average health defaults.
    private typealias HealthDefaults = Constants.HealthDefaults

    private func loadHealthData() async {
        let hk = dependencies.healthKitService

        // Try live → recent → 7-day average → population default
        if dependencies.isWatchConnected {
            restingHR = await hk.latestHeartRate()
        }
        if restingHR == nil {
            restingHR = await hk.latestRestingHR()
        }
        if restingHR == nil {
            restingHR = await hk.averageRestingHR(days: Constants.healthAverageDays)
        }
        if restingHR == nil {
            restingHR = HealthDefaults.restingHR
        }

        hrv = await hk.latestHRV()
        if hrv == nil {
            hrv = await hk.averageHRV(days: Constants.healthAverageDays)
        }
        if hrv == nil {
            hrv = HealthDefaults.hrv
        }

        if let sleep = await hk.lastNightSleep() {
            sleepHours = sleep.hours
        }
        if sleepHours == nil {
            sleepHours = HealthDefaults.sleepHours
        }
    }

    // MARK: - Check-In Flow

    private func presentCheckIn(_ mode: FocusMode) {
        dependencies.hapticService.buttonPress()
        checkInMode = mode
        showCheckIn = true
    }

    private func startSession(
        _ mode: FocusMode,
        mood: CheckInMood,
        durationMinutes: Int,
        isAdaptive: Bool
    ) {
        // Setup and start audio engine
        do {
            try dependencies.audioEngine.setup()
            try dependencies.audioEngine.start(mode: mode)
        } catch {
            Logger.audio.error("Audio start failed: \(error.localizedDescription)")
        }

        // Track active session for mini player
        dependencies.activeSessionMode = mode
        dependencies.activeSessionElapsed = 0

        // Donate to Siri so it learns session patterns
        IntentDonation.donateStartSession(mode: mode, durationMinutes: durationMinutes)

        navigationPath.append(AppDestination.session(mode))
    }

    // MARK: - Watch Status

    private var watchStatus: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(dependencies.isWatchConnected
                      ? Theme.Colors.signalCalm.opacity(Theme.Opacity.half)
                      : Theme.Colors.textTertiary)
                .frame(width: Theme.Spacing.xs, height: Theme.Spacing.xs)

            Text(dependencies.isWatchConnected ? "Apple Watch connected" : "No Watch connected")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

}

// MARK: - FocusMode Convenience

extension FocusMode {

    var defaultDurationMinutes: Int {
        switch self {
        case .focus:       return Constants.SessionDuration.focusDefault
        case .relaxation:  return Constants.SessionDuration.relaxationDefault
        case .sleep:       return Constants.SessionDuration.sleepDefault
        case .energize:    return Constants.SessionDuration.energizeDefault
        }
    }

    var durationOptions: [Int] {
        switch self {
        case .focus:       return Constants.SessionDuration.focusOptions
        case .relaxation:  return Constants.SessionDuration.relaxationOptions
        case .sleep:       return Constants.SessionDuration.sleepOptions
        case .energize:    return Constants.SessionDuration.energizeOptions
        }
    }
}

// MARK: - Preview

#Preview("Main View") {
    MainView()
        .environment(AppDependencies())
}
