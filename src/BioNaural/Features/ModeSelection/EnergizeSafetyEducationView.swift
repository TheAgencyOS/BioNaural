// EnergizeSafetyEducationView.swift
// BioNaural
//
// 3-panel swipeable safety education shown during the Energize screening flow.
// Explains real-time monitoring, automatic protection, and mandatory cool-down
// to build trust and differentiate from competitors.
// All text from Theme.Typography. All colors from Theme.Colors. No hardcoded values.

import SwiftUI

// MARK: - EnergizeSafetyEducationView

struct EnergizeSafetyEducationView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private let panels: [SafetyPanel] = [
        SafetyPanel(
            icon: "applewatch.radiowaves.left.and.right",
            iconColor: .energize,
            title: "BioNaural monitors your heart rate in real time",
            body: "During Energize sessions, your Apple Watch streams heart rate data every second. The adaptive engine watches for anything unusual."
        ),
        SafetyPanel(
            icon: "shield.checkered",
            iconColor: .signalCalm,
            title: "If anything looks off, we respond instantly",
            body: "Heart rate too high? We shift to calming frequencies. HRV dropping fast? We ease back. Seven independent safety systems protect you throughout."
        ),
        SafetyPanel(
            icon: "wind",
            iconColor: .accent,
            title: "Every session ends with a cool-down",
            body: "The last phase of every Energize session gradually brings your heart rate back to baseline. This isn't optional — it's built into the audio."
        ),
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            TabView(selection: $currentPage) {
                ForEach(Array(panels.enumerated()), id: \.offset) { index, panel in
                    panelView(panel)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(
                reduceMotion ? .identity : Theme.Animation.standard,
                value: currentPage
            )
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }

    // MARK: - Panel View

    @ViewBuilder
    private func panelView(_ panel: SafetyPanel) -> some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: panel.icon)
                    .font(.system(size: Theme.Typography.Size.display))
                    .foregroundStyle(panel.resolvedColor)
                    .accessibilityHidden(true)

                Text(panel.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(panel.body)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Panel Model

private struct SafetyPanel {

    let icon: String
    let iconColor: SafetyPanel.PanelColor
    let title: String
    let body: String

    enum PanelColor {
        case energize
        case signalCalm
        case accent
    }

    var resolvedColor: Color {
        switch iconColor {
        case .energize:
            return Theme.Colors.energize
        case .signalCalm:
            return Theme.Colors.signalCalm
        case .accent:
            return Theme.Colors.accent
        }
    }
}

// MARK: - Preview

#Preview("Safety Education") {
    EnergizeSafetyEducationView()
        .preferredColorScheme(.dark)
}

#Preview("Safety Education — Light") {
    EnergizeSafetyEducationView()
        .preferredColorScheme(.light)
}
