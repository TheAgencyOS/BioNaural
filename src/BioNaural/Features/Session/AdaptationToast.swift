// AdaptationToast.swift
// BioNaural
//
// A compact, non-blocking toast notification shown during a session when
// the adaptive engine makes a frequency adjustment. Unlike
// AdaptationInsightOverlay (the full first-time card), this toast is for
// subsequent adaptations — brief, informative, auto-dismissing.
//
// Appears near the top of the session screen, shows for 4 seconds,
// then fades out. Tappable to dismiss early.
// All values from Theme tokens. No hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - AdaptationToast

struct AdaptationToast: View {

    // MARK: - Input

    let message: String
    let mode: FocusMode
    let onDismiss: () -> Void

    // MARK: - State

    @State private var appeared = false
    @State private var autoDismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    /// Duration the toast remains visible before auto-dismissing.
    /// Uses the safety banner dismiss duration minus 1 second for a snappier feel.
    private static let displayDuration: Double = Theme.Animation.Duration.safetyBannerDismiss - 1.0

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Mode-colored dot
            Circle()
                .fill(modeColor)
                .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)

            // Message text
            Text(message)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            modeColor.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: appeared ? .zero : -Theme.Spacing.md)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(Theme.Animation.standard) {
                    appeared = true
                }
            }

            // Auto-dismiss after display duration
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.displayDuration))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
        .onTapGesture {
            autoDismissTask?.cancel()
            dismiss()
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityHint("Tap to dismiss")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private var modeColor: Color { Color.modeColor(for: mode) }

    private func dismiss() {
        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(Theme.Animation.press) {
                onDismiss()
            }
        }
    }
}

// MARK: - Message Generation

extension AdaptationToast {

    /// Generates a natural-language toast message from adaptation data.
    ///
    /// - Parameters:
    ///   - mode: The current session mode.
    ///   - oldFrequency: The beat frequency before the adaptation.
    ///   - newFrequency: The beat frequency after the adaptation.
    ///   - heartRate: The current heart rate, if available.
    ///   - previousHeartRate: The heart rate before the change, if available.
    /// - Returns: A concise, human-readable description of the adaptation.
    static func message(
        mode: FocusMode,
        oldFrequency: Double,
        newFrequency: Double,
        heartRate: Double?,
        previousHeartRate: Double?
    ) -> String {

        let frequencyDropped = newFrequency < oldFrequency
        let hrDelta = heartRateDelta(current: heartRate, previous: previousHeartRate)

        switch mode {
        case .focus:
            return focusMessage(frequencyDropped: frequencyDropped, hrDelta: hrDelta)
        case .relaxation:
            return relaxationMessage(frequencyDropped: frequencyDropped, hrDelta: hrDelta)
        case .sleep:
            return sleepMessage(
                frequencyDropped: frequencyDropped,
                newFrequency: newFrequency
            )
        case .energize:
            return energizeMessage(
                frequencyDropped: frequencyDropped,
                newFrequency: newFrequency,
                mode: mode
            )
        }
    }

    // MARK: - Per-Mode Messages

    private static func focusMessage(
        frequencyDropped: Bool,
        hrDelta: Int?
    ) -> String {
        if let delta = hrDelta {
            if delta < 0 {
                // HR dropped
                return "Heart rate dropped \(abs(delta)) bpm. Deepening focus."
            } else if delta > 0 {
                // HR rising
                return "HR rising. Easing frequency to help you settle."
            }
        }
        // No HR data or no meaningful change — use frequency direction
        if frequencyDropped {
            return "Deepening focus frequency."
        }
        return "Adjusting focus to match your state."
    }

    private static func relaxationMessage(
        frequencyDropped: Bool,
        hrDelta: Int?
    ) -> String {
        if let delta = hrDelta, delta > 3 {
            return "Stress spike detected. Holding steady."
        }
        if frequencyDropped {
            return "Settling into alpha range."
        }
        return "Gently adjusting to keep you relaxed."
    }

    private static func sleepMessage(
        frequencyDropped: Bool,
        newFrequency: Double
    ) -> String {
        // Delta range is 1-4 Hz
        if newFrequency <= 4.0 {
            return "Descending toward delta."
        }
        if frequencyDropped {
            return "Still winding down. Gentle theta hold."
        }
        return "Holding steady as you drift off."
    }

    private static func energizeMessage(
        frequencyDropped: Bool,
        newFrequency: Double,
        mode: FocusMode
    ) -> String {
        let ceiling = mode.frequencyRange.upperBound
        // Close to the top of the energize range
        if newFrequency >= ceiling - 2.0 {
            return "Approaching ceiling. Easing back."
        }
        if !frequencyDropped {
            return "Energy building. Frequency rising."
        }
        return "Recalibrating energy level."
    }

    // MARK: - Utilities

    /// Returns the rounded integer heart rate delta, or nil if data is unavailable.
    private static func heartRateDelta(
        current: Double?,
        previous: Double?
    ) -> Int? {
        guard let current, let previous else { return nil }
        let delta = Int(round(current - previous))
        // Only report meaningful changes
        guard abs(delta) >= 2 else { return nil }
        return delta
    }
}

// MARK: - Preview

#Preview("Focus — HR Drop") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            AdaptationToast(
                message: AdaptationToast.message(
                    mode: .focus,
                    oldFrequency: 14.0,
                    newFrequency: 13.2,
                    heartRate: 68,
                    previousHeartRate: 74
                ),
                mode: .focus,
                onDismiss: {}
            )
            .padding(.top, Theme.Spacing.jumbo)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Relaxation — Settling") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            AdaptationToast(
                message: AdaptationToast.message(
                    mode: .relaxation,
                    oldFrequency: 10.0,
                    newFrequency: 9.2,
                    heartRate: nil,
                    previousHeartRate: nil
                ),
                mode: .relaxation,
                onDismiss: {}
            )
            .padding(.top, Theme.Spacing.jumbo)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Sleep — Delta Descent") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            AdaptationToast(
                message: AdaptationToast.message(
                    mode: .sleep,
                    oldFrequency: 5.0,
                    newFrequency: 3.5,
                    heartRate: 58,
                    previousHeartRate: 60
                ),
                mode: .sleep,
                onDismiss: {}
            )
            .padding(.top, Theme.Spacing.jumbo)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Energize — Rising") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            AdaptationToast(
                message: AdaptationToast.message(
                    mode: .energize,
                    oldFrequency: 18.0,
                    newFrequency: 22.0,
                    heartRate: 82,
                    previousHeartRate: 76
                ),
                mode: .energize,
                onDismiss: {}
            )
            .padding(.top, Theme.Spacing.jumbo)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Energize — Ceiling") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        VStack {
            AdaptationToast(
                message: AdaptationToast.message(
                    mode: .energize,
                    oldFrequency: 27.0,
                    newFrequency: 29.0,
                    heartRate: nil,
                    previousHeartRate: nil
                ),
                mode: .energize,
                onDismiss: {}
            )
            .padding(.top, Theme.Spacing.jumbo)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
