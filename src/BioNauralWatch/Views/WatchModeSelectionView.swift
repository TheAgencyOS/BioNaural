// WatchModeSelectionView.swift
// BioNauralWatch
//
// Mode picker for the Watch home screen. Three large tappable cards
// with Digital Crown scrolling. Tap starts a session; long press
// reveals a duration picker.

import SwiftUI
import BioNauralShared

struct WatchModeSelectionView: View {

    @Environment(WatchSessionManager.self) private var sessionManager

    /// The mode currently highlighted by Digital Crown scroll.
    @State private var selectedModeIndex: Double = 0

    /// Whether the duration picker sheet is presented.
    @State private var showDurationPicker: Bool = false

    /// The mode for which the duration picker was invoked.
    @State private var durationPickerMode: FocusMode = .focus

    /// Duration selected via the picker (minutes).
    @State private var selectedDuration: Int = WatchLayout.durationPickerDefault

    private let modes = FocusMode.allCases

    var body: some View {
        VStack(spacing: WatchLayout.innerSpacing) {
            ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                modeCard(mode, isHighlighted: index == Int(selectedModeIndex))
                    .onTapGesture {
                        sessionManager.startSession(mode: mode, durationMinutes: nil)
                    }
                    .onLongPressGesture {
                        durationPickerMode = mode
                        selectedDuration = WatchLayout.durationPickerDefault
                        showDurationPicker = true
                    }
                    .accessibilityLabel("\(mode.displayName) mode")
                    .accessibilityHint("Tap to start a \(mode.displayName) session. Long press to choose duration")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .focusable()
        .digitalCrownRotation(
            $selectedModeIndex,
            from: 0.0,
            through: Double(modes.count - 1),
            by: 1.0,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .sheet(isPresented: $showDurationPicker) {
            durationPickerSheet
        }
    }

    // MARK: - Mode Card

    private func modeCard(_ mode: FocusMode, isHighlighted: Bool) -> some View {
        HStack(spacing: WatchLayout.cardPadding) {
            Image(systemName: mode.watchIconName)
                .font(.system(size: WatchLayout.modeIconSize))
                .foregroundStyle(mode.watchColor)
                .accessibilityHidden(true)

            Text(mode.displayName)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, WatchLayout.modeCardVerticalPadding)
        .padding(.horizontal, WatchLayout.modeCardHorizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: WatchLayout.modeCardCornerRadius)
                .fill(isHighlighted ? mode.watchColor.opacity(0.2) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: WatchLayout.modeCardCornerRadius)
                        .strokeBorder(
                            isHighlighted ? mode.watchColor.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }

    // MARK: - Duration Picker Sheet

    private var durationPickerSheet: some View {
        VStack(spacing: WatchLayout.sectionSpacing) {
            Text("\(durationPickerMode.displayName) Duration")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(durationPickerMode.watchColor)

            Picker("Minutes", selection: $selectedDuration) {
                ForEach(
                    stride(
                        from: WatchLayout.durationPickerRange.lowerBound,
                        through: WatchLayout.durationPickerRange.upperBound,
                        by: WatchLayout.durationPickerStep
                    ).map { $0 },
                    id: \.self
                ) { minutes in
                    Text("\(minutes) min")
                        .tag(minutes)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Session duration")
            .accessibilityHint("Selects the session length in minutes")

            Button {
                showDurationPicker = false
                sessionManager.startSession(
                    mode: durationPickerMode,
                    durationMinutes: selectedDuration
                )
            } label: {
                Text("Start")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(durationPickerMode.watchColor)
            .accessibilityLabel("Start \(durationPickerMode.displayName) session")
            .accessibilityHint("Begins a \(selectedDuration) minute \(durationPickerMode.displayName) session")
        }
        .padding(.horizontal, WatchLayout.horizontalPadding)
    }
}
