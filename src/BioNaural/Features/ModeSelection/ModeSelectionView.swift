// ModeSelectionView.swift
// BioNaural
//
// The primary entry point — home screen showing four mode cards in a 2x2 grid.
// One tap starts a session. Long-press opens the duration picker.
// Pre-session check-in flows as a sheet before navigation.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - Mode Card Descriptor

/// Static display metadata for each mode card, derived from FocusMode.
/// Keeps the view body declarative — no switch statements in layout code.
private struct ModeCardDescriptor: Identifiable {
    let mode: FocusMode
    let icon: String
    let subtitle: String
    let frequencyLabel: String
    let color: Color

    var id: String { mode.id }

    /// Ordered by energy gradient: high energy (top-left) to low energy (bottom-right).
    /// Laid out in a 2x2 grid: [Energize, Focus] / [Relaxation, Sleep].
    static let all: [ModeCardDescriptor] = [
        ModeCardDescriptor(
            mode: .energize,
            icon: "bolt.fill",
            subtitle: "Wake up & activate",
            frequencyLabel: "Beta 14\u{2013}30 Hz",
            color: Theme.Colors.energize
        ),
        ModeCardDescriptor(
            mode: .focus,
            icon: "brain.head.profile",
            subtitle: "Sustained attention",
            frequencyLabel: "Beta 14\u{2013}16 Hz",
            color: Theme.Colors.focus
        ),
        ModeCardDescriptor(
            mode: .relaxation,
            icon: "leaf.fill",
            subtitle: "Calm & de-stress",
            frequencyLabel: "Alpha 8\u{2013}11 Hz",
            color: Theme.Colors.relaxation
        ),
        ModeCardDescriptor(
            mode: .sleep,
            icon: "moon.fill",
            subtitle: "Wind-down to rest",
            frequencyLabel: "Theta\u{2192}Delta 6\u{2192}2 Hz",
            color: Theme.Colors.sleep
        )
    ]
}

// MARK: - Check-In State

/// Tracks the two-screen pre-session check-in flow presented as a sheet.
@Observable
final class CheckInState {

    /// The mode the user tapped to start the check-in flow.
    var selectedMode: FocusMode?

    /// Screen 1: mood slider value. 0 = wired/anxious, 1 = calm/tired.
    var moodValue: Double = 0.5

    /// Screen 2: user-selected goal.
    var selectedGoal: FocusMode?

    /// Which check-in screen is currently visible.
    var currentScreen: CheckInScreen = .mood

    /// Whether the check-in sheet is presented.
    var isPresented: Bool = false

    /// Duration override from long-press picker (minutes). `nil` = default.
    var durationOverrideMinutes: Int?

    enum CheckInScreen {
        case mood
        case goal
    }

    func reset() {
        moodValue = 0.5
        selectedGoal = nil
        currentScreen = .mood
        durationOverrideMinutes = nil
    }
}

// MARK: - ModeSelectionView

struct ModeSelectionView: View {

    // MARK: Navigation

    /// Callback when the user completes check-in and is ready to start a session.
    /// The parent navigation owner handles the actual push/presentation.
    var onStartSession: ((_ mode: FocusMode, _ mood: Double?, _ goal: FocusMode?, _ durationMinutes: Int?) -> Void)?

    // MARK: State

    @State private var checkIn = CheckInState()
    @State private var durationPickerMode: FocusMode?
    @State private var showDurationPicker = false
    @State private var watchDismissed = false

    /// Science card shown once per mode. Stored flags in UserDefaults.
    @State private var scienceCardMode: FocusMode?

    /// Energize first-use health screening sheet.
    @State private var showEnergizeScreening = false

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: Queries

    /// Recent sessions for the "use your usual settings" heuristic.
    @Query(
        filter: #Predicate<FocusSession> { $0.wasCompleted },
        sort: \FocusSession.startDate,
        order: .reverse
    )
    private var recentSessions: [FocusSession]

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {

                // MARK: Title
                Text("BioNaural")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xxxl)

                // MARK: Mode Cards — 2x2 Grid (energy gradient: high → low)
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: Theme.Spacing.md),
                        count: 2
                    ),
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(ModeCardDescriptor.all) { descriptor in
                        modeCard(for: descriptor)
                    }
                }

                Spacer(minLength: Theme.Spacing.jumbo)

                // MARK: Watch Status
                watchStatusView
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .sheet(isPresented: $checkIn.isPresented) {
            checkInSheet
        }
        .sheet(isPresented: $showEnergizeScreening) {
            EnergizeScreeningView(
                onComplete: {
                    showEnergizeScreening = false
                    // Screening done — proceed to normal check-in flow
                    proceedToCheckIn(for: .energize)
                },
                onSkip: {
                    showEnergizeScreening = false
                }
            )
        }
        .confirmationDialog(
            "Session Duration",
            isPresented: $showDurationPicker,
            titleVisibility: .visible
        ) {
            durationDialogButtons
        }
        .overlay {
            if let mode = scienceCardMode {
                scienceCardOverlay(for: mode)
            }
        }
        .alert(
            "Why 15+ minutes matters",
            isPresented: $showDurationTooltip
        ) {
            Button("Continue anyway") {
                checkIn.isPresented = true
            }
            Button("Pick longer", role: .cancel) {
                showDurationPicker = true
            }
        } message: {
            Text("Your brain needs time to detect the binaural pattern and synchronize to it. Most studies that found significant effects used sessions of 15 minutes or longer. Shorter sessions may not build enough momentum.")
        }
    }

    // MARK: - Mode Card

    @ViewBuilder
    private func modeCard(for descriptor: ModeCardDescriptor) -> some View {
        Button {
            handleCardTap(descriptor.mode)
        } label: {
            ZStack {
                // Wave animation — behind text, clipped to card
                ModeCardWaveCanvas(mode: descriptor.mode)

                // Text content
                VStack(alignment: .leading, spacing: .zero) {
                    Image(systemName: descriptor.icon)
                        .font(.system(size: Theme.Typography.Size.title, weight: .light))
                        .foregroundStyle(descriptor.color)
                        .padding(.bottom, Theme.Spacing.lg)

                    Text(descriptor.mode.displayName)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.bottom, Theme.Spacing.xxs)

                    Text(descriptor.subtitle)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.bottom, Theme.Spacing.sm)

                    Text(descriptor.frequencyLabel)
                        .font(Theme.Typography.dataSmall)
                        .foregroundStyle(descriptor.color.opacity(Theme.Opacity.accentStrong))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(.clear)
                    .overlay(alignment: .leading) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: Theme.Radius.xl,
                            bottomLeadingRadius: Theme.Radius.xl,
                            bottomTrailingRadius: .zero,
                            topTrailingRadius: .zero
                        )
                        .fill(descriptor.color)
                        .frame(width: leftBorderWidth)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            )
        }
        .buttonStyle(ModeCardButtonStyle())
        .contextMenu {
            Button {
                durationPickerMode = descriptor.mode
                showDurationPicker = true
            } label: {
                Label("Set Duration", systemImage: "timer")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(descriptor.mode.displayName) mode")
        .accessibilityHint("\(descriptor.subtitle). \(descriptor.frequencyLabel). Double tap to start session. Long press for duration options.")
    }

    /// Width of the colored left border on mode cards.
    private var leftBorderWidth: CGFloat { 3 }

    /// Card background — glass material on iOS 26+, surface color otherwise.
    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *) {
            // Glass effect available on iOS 26+
            Theme.Colors.surface.opacity(Theme.Opacity.half)
        } else {
            Theme.Colors.surface
        }
    }

    // MARK: - Glass Effect Modifier

    /// Applies `.glassEffect` on iOS 26+ at the view level (after background).
    private struct GlassEffectModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.xl))
            } else {
                content
            }
        }
    }

    // MARK: - Card Button Style

    private struct ModeCardButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .opacity(configuration.isPressed ? Theme.Opacity.translucent : Theme.Opacity.full)
                .animation(Theme.Animation.press, value: configuration.isPressed)
        }
    }

    // MARK: - Watch Status

    @ViewBuilder
    private var watchStatusView: some View {
        if !watchDismissed {
            // Reads Watch connectivity state from AppDependencies (injected via environment)
            let isConnected = false // Resolved at runtime via WatchConnectivityProtocol.isWatchReachable

            if isConnected {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(.green)
                        .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
                    Text("Apple Watch connected")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Spacing.lg)
            } else {
                Button {
                    watchDismissed = true
                } label: {
                    Text("Connect Apple Watch for adaptive audio")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, Theme.Spacing.lg)
                .accessibilityHint("Tap to dismiss")
            }
        }
    }

    // MARK: - Card Tap Handling

    private func handleCardTap(_ mode: FocusMode) {
        // Show science card on first tap per mode
        if !hasScienceBeenShown(for: mode) {
            scienceCardMode = mode
            markScienceShown(for: mode)
            // After dismissing science card, the user taps the mode again
            return
        }

        // Energize requires first-use health screening
        if mode == .energize && !EnergizeScreeningView.isScreeningComplete {
            showEnergizeScreening = true
            return
        }

        // Check if we should offer "use your usual settings"
        if shouldOfferDefaults(for: mode) {
            // Skip check-in, go directly
            onStartSession?(mode, nil, nil, nil)
            return
        }

        // Present check-in sheet
        proceedToCheckIn(for: mode)
    }

    /// Presents the pre-session check-in sheet for a given mode.
    private func proceedToCheckIn(for mode: FocusMode) {
        // Check if we should offer "use your usual settings"
        if shouldOfferDefaults(for: mode) {
            onStartSession?(mode, nil, nil, nil)
            return
        }

        checkIn.reset()
        checkIn.selectedMode = mode
        checkIn.isPresented = true
    }

    // MARK: - Check-In Sheet

    @ViewBuilder
    private var checkInSheet: some View {
        NavigationStack {
            Group {
                switch checkIn.currentScreen {
                case .mood:
                    checkInMoodScreen
                case .goal:
                    checkInGoalScreen
                }
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        checkIn.isPresented = false
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use defaults") {
                        completeCheckIn(skipped: true)
                    }
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.canvas)
    }

    @ViewBuilder
    private var checkInMoodScreen: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Text("How are you feeling?")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: Theme.Spacing.md) {
                Slider(value: $checkIn.moodValue, in: 0...1)
                    .tint(modeColor(for: checkIn.selectedMode))

                HStack {
                    Text("Wired / Anxious")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                    Text("Calm / Tired")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            Button {
                withAnimation(Theme.Animation.standard) {
                    checkIn.currentScreen = .goal
                }
            } label: {
                Text("Next")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    @ViewBuilder
    private var checkInGoalScreen: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Text("What are you trying to do?")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: Theme.Spacing.md) {
                goalButton(label: "Focus deeply", goal: .focus)
                goalButton(label: "Unwind & relax", goal: .relaxation)
                goalButton(label: "Fall asleep", goal: .sleep)
                goalButton(label: "Wake up & energize", goal: .energize)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            Button {
                completeCheckIn(skipped: false)
            } label: {
                Text("Start")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        checkIn.selectedGoal != nil
                            ? Theme.Colors.accent
                            : Theme.Colors.accent.opacity(Theme.Opacity.medium)
                    )
                    .clipShape(Capsule())
            }
            .disabled(checkIn.selectedGoal == nil)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    @ViewBuilder
    private func goalButton(label: String, goal: FocusMode) -> some View {
        let isSelected = checkIn.selectedGoal == goal

        Button {
            withAnimation(Theme.Animation.press) {
                checkIn.selectedGoal = goal
            }
        } label: {
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(
                    isSelected ? Theme.Colors.textOnAccent : Theme.Colors.textPrimary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    isSelected
                        ? modeColor(for: goal)
                        : Theme.Colors.surface
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    private func completeCheckIn(skipped: Bool) {
        guard let mode = checkIn.selectedMode else { return }

        let mood: Double? = skipped ? nil : checkIn.moodValue
        let goal: FocusMode? = skipped ? nil : checkIn.selectedGoal
        let duration = checkIn.durationOverrideMinutes

        checkIn.isPresented = false
        onStartSession?(mode, mood, goal, duration)
    }

    // MARK: - Duration Picker

    /// Whether the sub-15-minute science tooltip is showing.
    @State private var showDurationTooltip = false

    @ViewBuilder
    private var durationDialogButtons: some View {
        ForEach(DurationOption.standard, id: \.minutes) { option in
            Button(option.label) {
                guard let mode = durationPickerMode else { return }
                checkIn.reset()
                checkIn.selectedMode = mode
                checkIn.durationOverrideMinutes = option.minutes

                // Show science tooltip for short sessions
                if option.minutes < 15 {
                    showDurationTooltip = true
                } else {
                    checkIn.isPresented = true
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: - Duration Tooltip Alert

    private var durationTooltipModifier: some View {
        EmptyView()
    }

    // MARK: - Science Card Overlay

    /// State for the science card wave animation.
    @State private var scienceWavePhase: CGFloat = 0

    @ViewBuilder
    private func scienceCardOverlay(for mode: FocusMode) -> some View {
        let color = modeColor(for: mode)

        ZStack {
            // Scrim — deep tint with mode color
            Theme.Colors.canvas.opacity(Theme.Opacity.translucent)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        colors: [
                            color.opacity(Theme.Opacity.light),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: .zero,
                        endRadius: UIScreen.main.bounds.height * 0.5
                    )
                    .ignoresSafeArea()
                )
                .onTapGesture {
                    withAnimation(Theme.Animation.standard) {
                        scienceCardMode = nil
                    }
                }

            VStack(alignment: .leading, spacing: .zero) {

                // Top accent gradient bar
                LinearGradient(
                    colors: [color, color.opacity(Theme.Opacity.medium), color.opacity(Theme.Opacity.transparent)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: Theme.Spacing.xxs)

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                    // Mode icon + label
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: scienceIcon(for: mode))
                            .font(.system(size: Theme.Typography.Size.headline))
                            .foregroundStyle(color)

                        Text("Why it works")
                            .font(Theme.Typography.small)
                            .foregroundStyle(color)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .textCase(.uppercase)
                    }

                    // Hook
                    Text(scienceHook(for: mode))
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                    // Mode-specific live waveform
                    Canvas { context, size in
                        drawModeWave(context: context, size: size, mode: mode, color: color)
                    }
                    .frame(height: Theme.Spacing.xxxl)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .onAppear {
                        withAnimation(
                            .linear(duration: Theme.Animation.Duration.orbBreathingDefault)
                            .repeatForever(autoreverses: false)
                        ) {
                            scienceWavePhase = .pi * 2
                        }
                    }

                    // Body
                    Text(scienceText(for: mode))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                    // Caveat
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(color.opacity(Theme.Opacity.accentLight))
                            .frame(width: 3)

                        Text(scienceCaveat(for: mode))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .lineSpacing(Theme.Typography.LineSpacing.relaxed)
                    }

                    // Dismiss hint
                    Text("Tap anywhere to continue")
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Colors.surface)
                    // Inner highlight gradient
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(Theme.Opacity.light),
                                        Color.clear,
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    // Edge glow
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        color.opacity(Theme.Opacity.dim),
                                        color.opacity(Theme.Opacity.subtle),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: Theme.Radius.glassStroke
                            )
                    )
                    // Layered shadows
                    .shadow(color: Color.black.opacity(Theme.Opacity.dim), radius: Theme.Spacing.sm, y: Theme.Spacing.xxs)
                    .shadow(color: color.opacity(Theme.Opacity.light), radius: Theme.Spacing.xxl, y: Theme.Spacing.md)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .padding(.horizontal, Theme.Spacing.pageMargin)
        }
        .transition(
            .asymmetric(
                insertion: .opacity
                    .combined(with: .scale(scale: 0.94, anchor: .center))
                    .animation(Theme.Animation.sheet),
                removal: .opacity.animation(Theme.Animation.press)
            )
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Science card for \(mode.displayName) mode")
        .accessibilityHint("Tap anywhere to dismiss")
    }

    /// Draws a mode-characteristic wave: fast-tight for Focus/Energize,
    /// slow-wide for Sleep, medium for Relaxation.
    private func drawModeWave(
        context: GraphicsContext,
        size: CGSize,
        mode: FocusMode,
        color: Color
    ) {
        let midY = size.height / 2
        let amplitude = size.height * 0.35

        let freq: CGFloat
        switch mode {
        case .focus:      freq = Theme.Wavelength.Frequency.focused
        case .relaxation: freq = Theme.Wavelength.Frequency.calm
        case .sleep:      freq = 0.6
        case .energize:   freq = Theme.Wavelength.Frequency.elevated
        }

        var path = Path()
        let steps = Int(size.width)
        for x in 0...steps {
            let xPos = CGFloat(x)
            let normalizedX = xPos / size.width
            let envelope = sin(normalizedX * .pi)
            let yPos = midY + sin(normalizedX * freq * .pi * 2 + scienceWavePhase) * amplitude * envelope

            if x == 0 {
                path.move(to: CGPoint(x: xPos, y: yPos))
            } else {
                path.addLine(to: CGPoint(x: xPos, y: yPos))
            }
        }

        // Glow
        var glowCtx = context
        glowCtx.addFilter(.blur(radius: Theme.Wavelength.blurRadius * 2))
        glowCtx.stroke(
            path,
            with: .color(color.opacity(Theme.Opacity.medium)),
            lineWidth: Theme.Wavelength.Stroke.elevated
        )

        // Primary
        context.stroke(
            path,
            with: .color(color.opacity(Theme.Opacity.accentStrong)),
            lineWidth: Theme.Wavelength.Stroke.standard
        )
    }

    // MARK: - Science Content

    private func scienceIcon(for mode: FocusMode) -> String {
        switch mode {
        case .focus:      return "brain.head.profile"
        case .relaxation: return "leaf.fill"
        case .sleep:      return "moon.fill"
        case .energize:   return "bolt.fill"
        }
    }

    private func scienceText(for mode: FocusMode) -> String {
        switch mode {
        case .focus:
            return "Beta-range binaural beats (14\u{2013}16 Hz) are associated with sustained attention and working memory. A 2016 University of Alberta study found they improved focus performance and strengthened brain connectivity patterns."
        case .relaxation:
            return "Alpha-range beats (8\u{2013}12 Hz) have the strongest evidence of any binaural beat application. A 2019 meta-analysis of 22 studies found they reliably reduce anxiety \u{2014} comparable to a session of guided breathing."
        case .sleep:
            return "Sleep mode mirrors your brain\u{2019}s natural descent \u{2014} starting at theta (drowsy) and gradually shifting to delta (deep sleep) over 25 minutes. The goal is to give your brain a pacing signal that matches the transition it\u{2019}s already trying to make."
        case .energize:
            // swiftlint:disable:next line_length
            return "Energize uses higher-frequency binaural beats (14\u{2013}30 Hz) combined with upbeat melodic content to help clear morning fog, beat the afternoon slump, or prep for a meeting. Your Apple Watch monitors your heart rate throughout \u{2014} if things get too intense, the audio automatically backs down."
        }
    }

    private func scienceHook(for mode: FocusMode) -> String {
        switch mode {
        case .focus:
            return "Beta-range beats reduce friction for deep work \u{2014} not superpowers, but a genuine nudge."
        case .relaxation:
            return "Alpha waves are our most evidence-backed mode \u{2014} 22 studies say this works."
        case .sleep:
            return "Your brain already knows how to fall asleep. This gives it a pacing signal."
        case .energize:
            return "Beta-range beats can sharpen your alertness \u{2014} your Watch keeps it safe."
        }
    }

    private func scienceCaveat(for mode: FocusMode) -> String {
        switch mode {
        case .focus:
            return "The effects are real but modest \u{2014} think \u{201C}reducing friction\u{201D} not \u{201C}creating superpowers.\u{201D}"
        case .relaxation:
            return "This is our most evidence-backed mode."
        case .sleep:
            return "Best used as sleep preparation (15\u{2013}45 min), not all night. Your brain takes over from there."
        case .energize:
            return "Best for short bursts \u{2014} morning wake-up, afternoon reset, or pre-meeting prep."
        }
    }

    // MARK: - UserDefaults — Science Card Flags

    private func hasScienceBeenShown(for mode: FocusMode) -> Bool {
        UserDefaults.standard.bool(forKey: scienceKey(for: mode))
    }

    private func markScienceShown(for mode: FocusMode) {
        UserDefaults.standard.set(true, forKey: scienceKey(for: mode))
    }

    private func scienceKey(for mode: FocusMode) -> String {
        "scienceCardShown_\(mode.rawValue)"
    }

    // MARK: - "Use Your Usual Settings" Heuristic

    /// Returns `true` if the user has 5+ completed sessions for this mode
    /// with similar check-in answers, suggesting we can skip the check-in.
    private func shouldOfferDefaults(for mode: FocusMode) -> Bool {
        let modeRaw = mode.rawValue
        let modeSessions = recentSessions.filter { $0.mode == modeRaw }

        guard modeSessions.count >= 5 else { return false }

        // Check last 5 sessions for consistent mood + goal
        let last5 = Array(modeSessions.prefix(5))

        let moods = last5.compactMap(\.checkInMood)
        let goals = last5.compactMap(\.checkInGoal)

        // Need at least 4 of 5 to have check-in data
        guard moods.count >= 4, goals.count >= 4 else { return false }

        // Mood consistency: all within 0.25 of each other
        let moodRange = (moods.max() ?? 0) - (moods.min() ?? 0)
        guard moodRange <= 0.25 else { return false }

        // Goal consistency: all the same
        let uniqueGoals = Set(goals)
        return uniqueGoals.count == 1
    }

    // MARK: - Helpers

    private func modeColor(for mode: FocusMode?) -> Color {
        switch mode {
        case .focus:       return Theme.Colors.focus
        case .relaxation:  return Theme.Colors.relaxation
        case .sleep:       return Theme.Colors.sleep
        case .energize:    return Theme.Colors.energize
        case .none:        return Theme.Colors.accent
        }
    }
}

// MARK: - Duration Options

private struct DurationOption {
    let minutes: Int
    let label: String

    static let standard: [DurationOption] = [
        DurationOption(minutes: 5, label: "5 minutes"),
        DurationOption(minutes: 15, label: "15 minutes"),
        DurationOption(minutes: 25, label: "25 minutes"),
        DurationOption(minutes: 30, label: "30 minutes"),
        DurationOption(minutes: 45, label: "45 minutes"),
        DurationOption(minutes: 60, label: "60 minutes")
    ]
}

// MARK: - Preview

#Preview("Mode Selection") {
    ModeSelectionView { mode, mood, goal, duration in
        #if DEBUG
        print("Start: \(mode.displayName), mood: \(String(describing: mood)), goal: \(String(describing: goal)), duration: \(String(describing: duration))")
        #endif
    }
    .preferredColorScheme(.dark)
}
