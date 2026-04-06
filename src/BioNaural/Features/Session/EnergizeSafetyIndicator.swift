// EnergizeSafetyIndicator.swift
// BioNaural
//
// Small shield icon for the session screen nav bar during Energize mode.
// Shows real-time safety status with color and animation cues.
// All colors from Theme.Colors. No hardcoded values.

import SwiftUI

// MARK: - EnergizeSafetyIndicator

struct EnergizeSafetyIndicator: View {

    let safetyStatus: SafetyStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    enum SafetyStatus {
        case safe
        case caution
        case critical
    }

    var body: some View {
        Image(systemName: "shield.fill")
            .font(.system(size: Theme.Typography.Size.headline))
            .foregroundStyle(statusColor)
            .scaleEffect(pulseScale)
            .animation(pulseAnimation, value: isPulsing)
            .onAppear {
                if shouldAnimate {
                    isPulsing = true
                }
            }
            .onChange(of: safetyStatus) {
                isPulsing = false
                if shouldAnimate {
                    // Reset pulse cycle when status changes
                    isPulsing = true
                }
            }
            .onChange(of: reduceMotion) {
                if reduceMotion {
                    isPulsing = false
                } else if shouldAnimate {
                    isPulsing = true
                }
            }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityRemoveTraits(.isImage)
    }

    // MARK: - Status Color

    private var statusColor: Color {
        switch safetyStatus {
        case .safe:
            return Theme.Colors.signalCalm
        case .caution:
            return Theme.Colors.stressWarning
        case .critical:
            return Theme.Colors.stressCritical
        }
    }

    // MARK: - Pulse Animation

    private var shouldAnimate: Bool {
        guard !reduceMotion else { return false }
        switch safetyStatus {
        case .safe, .caution:
            return true
        case .critical:
            return false
        }
    }

    private var pulseScale: CGFloat {
        guard shouldAnimate else { return 1.0 }
        return isPulsing ? 1.05 : 1.0
    }

    private var pulseAnimation: Animation? {
        guard shouldAnimate else { return nil }
        switch safetyStatus {
        case .safe:
            return .easeInOut(duration: Theme.Animation.Duration.orbBreathingMin).repeatForever(autoreverses: true)
        case .caution:
            return .easeInOut(duration: Theme.Animation.Duration.orbBloomPulse).repeatForever(autoreverses: true)
        case .critical:
            return nil
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch safetyStatus {
        case .safe:
            return "Safety status: all clear"
        case .caution:
            return "Safety status: caution, adjusting audio"
        case .critical:
            return "Safety status: critical, reducing intensity"
        }
    }
}

// MARK: - Previews

#Preview("Safe") {
    NavigationStack {
        Color.clear
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EnergizeSafetyIndicator(safetyStatus: .safe)
                }
            }
    }
    .preferredColorScheme(.dark)
}

#Preview("Caution") {
    NavigationStack {
        Color.clear
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EnergizeSafetyIndicator(safetyStatus: .caution)
                }
            }
    }
    .preferredColorScheme(.dark)
}

#Preview("Critical") {
    NavigationStack {
        Color.clear
            .background(Theme.Colors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EnergizeSafetyIndicator(safetyStatus: .critical)
                }
            }
    }
    .preferredColorScheme(.dark)
}

#Preview("All States") {
    HStack(spacing: Theme.Spacing.xxl) {
        EnergizeSafetyIndicator(safetyStatus: .safe)
        EnergizeSafetyIndicator(safetyStatus: .caution)
        EnergizeSafetyIndicator(safetyStatus: .critical)
    }
    .padding(Theme.Spacing.xxxl)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
