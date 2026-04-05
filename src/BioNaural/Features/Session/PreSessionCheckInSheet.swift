// PreSessionCheckInSheet.swift
// BioNaural
//
// Pre-session check-in — half-sheet with mood selector, duration picker,
// and adaptive toggle. Quick two-section flow before every session.
// All values from Theme tokens. No hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - CheckInMood

/// Self-reported mood state captured before a session begins.
/// Maps to a 0.0...1.0 scale for the `checkInMood` field on FocusSession.
enum CheckInMood: String, CaseIterable, Sendable {

    case wired, stressed, neutral, calm, drowsy

    /// Human-readable label for display.
    var label: String {
        switch self {
        case .wired:    return "Wired"
        case .stressed: return "Stressed"
        case .neutral:  return "Neutral"
        case .calm:     return "Calm"
        case .drowsy:   return "Drowsy"
        }
    }

    /// SF Symbol icon representing the mood.
    var icon: String {
        switch self {
        case .wired:    return "bolt.fill"
        case .stressed: return "waveform.path"
        case .neutral:  return "minus.circle"
        case .calm:     return "leaf.fill"
        case .drowsy:   return "moon.fill"
        }
    }

    /// Normalized value on the arousal spectrum.
    /// 0.0 = most wired/activated, 1.0 = most drowsy/deactivated.
    var value: Double {
        switch self {
        case .wired:    return 0.0
        case .stressed: return 0.25
        case .neutral:  return 0.5
        case .calm:     return 0.75
        case .drowsy:   return 1.0
        }
    }
}

// MARK: - PreSessionCheckInSheet

struct PreSessionCheckInSheet: View {

    // MARK: - Inputs

    let mode: FocusMode
    let isWatchConnected: Bool
    let onStart: (_ mood: CheckInMood, _ durationMinutes: Int, _ isAdaptive: Bool) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var selectedMood: CheckInMood = .neutral
    @State private var selectedDuration: Int?
    @State private var isAdaptive: Bool = true

    // MARK: - Computed

    private var modeColor: Color { .modeColor(for: mode) }
    private var activeDuration: Int { selectedDuration ?? mode.defaultDurationMinutes }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.canvas
                .ignoresSafeArea()

            // Radial glow at top
            radialGlow

            // Content
            VStack(spacing: Theme.Spacing.xxl) {
                sheetHeader
                moodSection
                durationSection
                Spacer(minLength: Theme.Spacing.sm)
                beginButton
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.xxxl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.canvas)
    }

    // MARK: - Radial Glow

    private var radialGlow: some View {
        RadialGradient(
            colors: [
                modeColor.opacity(Theme.Opacity.canvasRadialWash),
                Color.clear
            ],
            center: .top,
            startRadius: .zero,
            endRadius: Theme.Spacing.mega * 4
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: mode.systemImageName)
                .font(Theme.Typography.headline)
                .foregroundStyle(modeColor)

            Text(mode.displayName)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.displayName) session")
    }

    // MARK: - Section 1: Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("How are you feeling?")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(CheckInMood.allCases, id: \.self) { mood in
                        moodCapsule(for: mood)
                    }
                }
            }
        }
    }

    private func moodCapsule(for mood: CheckInMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            withAnimation(reduceMotion ? .none : Theme.Animation.press) {
                selectedMood = mood
            }
        } label: {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: mood.icon)
                    .font(Theme.Typography.caption)

                Text(mood.label)
                    .font(Theme.Typography.caption)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(isSelected ? Theme.Colors.textOnAccent : Theme.Colors.textSecondary)
            .background(
                Capsule()
                    .fill(isSelected ? modeColor : Theme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        Theme.Colors.divider.opacity(isSelected ? Theme.Opacity.transparent : Theme.Opacity.glassStroke),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
            .scaleEffect(isSelected ? 1.0 : Theme.Animation.OrbScale.breathingMin)
            .animation(reduceMotion ? .none : Theme.Animation.press, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Section 2: Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Duration")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(mode.durationOptions, id: \.self) { minutes in
                        durationCapsule(for: minutes)
                    }
                }
            }

            // Adaptive toggle — only when Watch is connected
            if isWatchConnected {
                adaptiveToggle
            }
        }
    }

    private func durationCapsule(for minutes: Int) -> some View {
        let isSelected = activeDuration == minutes

        return Button {
            withAnimation(reduceMotion ? .none : Theme.Animation.press) {
                selectedDuration = minutes
            }
        } label: {
            Text("\(minutes) min")
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .foregroundStyle(isSelected ? Theme.Colors.textOnAccent : Theme.Colors.textSecondary)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.Colors.accent : Theme.Colors.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Theme.Colors.divider.opacity(isSelected ? Theme.Opacity.transparent : Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
                .scaleEffect(isSelected ? 1.0 : Theme.Animation.OrbScale.breathingMin)
                .animation(reduceMotion ? .none : Theme.Animation.press, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var adaptiveToggle: some View {
        HStack {
            Text("Adaptive")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Toggle("", isOn: $isAdaptive)
                .labelsHidden()
                .tint(modeColor)
        }
        .padding(.horizontal, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adaptive mode")
        .accessibilityValue(isAdaptive ? "On" : "Off")
        .accessibilityHint("Uses Apple Watch biometrics to adapt the session in real time")
    }

    // MARK: - Begin Button

    private var beginButton: some View {
        Button {
            onStart(selectedMood, activeDuration, isWatchConnected ? isAdaptive : false)
            dismiss()
        } label: {
            Text("Begin \(mode.displayName)")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(
                    Capsule()
                        .fill(modeColor)
                )
                .shadow(
                    color: modeColor.opacity(Theme.Opacity.medium),
                    radius: Theme.Radius.xl,
                    y: Theme.Spacing.xxs
                )
        }
        .buttonStyle(BeginButtonStyle())
        .accessibilityLabel("Begin \(mode.displayName) session")
        .accessibilityHint("\(activeDuration) minutes, \(selectedMood.label) mood\(isWatchConnected && isAdaptive ? ", adaptive" : "")")
    }
}

// MARK: - Begin Button Style

/// Press-scale button style matching the codebase pattern from CardPressStyle.
private struct BeginButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Interaction.pressScale : 1.0)
            .opacity(configuration.isPressed ? Theme.Interaction.pressOpacity : 1.0)
            .animation(
                reduceMotion ? .identity : Theme.Animation.press,
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Pre-Session Check-In — Focus") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PreSessionCheckInSheet(
                mode: .focus,
                isWatchConnected: true
            ) { mood, duration, isAdaptive in
                print("Start: \(mood.label), \(duration) min, adaptive: \(isAdaptive)")
            }
        }
        .preferredColorScheme(.dark)
}
#endif
