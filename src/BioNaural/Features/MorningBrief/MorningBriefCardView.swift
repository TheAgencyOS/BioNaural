// MorningBriefCardView.swift
// BioNaural
//
// Compact morning brief card for embedding in the Home tab. Shows the
// greeting, a one-line prescription, and a quick-start button. Tapping
// the card body expands to the full MorningBriefView.

import SwiftUI
import BioNauralShared

// MARK: - MorningBriefCardView

struct MorningBriefCardView: View {

    let brief: MorningBrief
    let onTap: () -> Void
    let onQuickStart: (FocusMode, Int) -> Void

    // MARK: - Derived

    private var modeColor: Color {
        Color.modeColor(for: brief.suggestedMode)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            modeIndicator
            prescriptionLabel
            Spacer(minLength: 0)
            quickStartButton
        }
        .padding(Theme.Spacing.lg)
        .premiumCard(glowColor: Color.modeColor(for: brief.suggestedMode))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Morning brief: \(brief.prescriptionText)")
        .accessibilityHint("Tap to view full morning brief")
    }

    // MARK: - Mode Indicator

    private var modeIndicator: some View {
        Image(systemName: brief.suggestedMode.systemImageName)
            .font(.system(size: Theme.Typography.Size.caption))
            .foregroundStyle(modeColor)
            .frame(
                width: Theme.Spacing.xxxl,
                height: Theme.Spacing.xxxl
            )
            .background(
                modeColor.opacity(Theme.Opacity.light),
                in: Circle()
            )
    }

    // MARK: - Prescription Label

    private var prescriptionLabel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(brief.greeting)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)

            Text(brief.prescriptionText)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Quick Start Button

    private var quickStartButton: some View {
        Button {
            onQuickStart(brief.suggestedMode, brief.suggestedDurationMinutes)
        } label: {
            Text("Start")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .background(modeColor, in: Capsule())
        .buttonStyle(.plain)
        .accessibilityLabel("Quick start \(brief.suggestedMode.displayName) session")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Morning Brief Card") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()

        MorningBriefCardView(
            brief: .preview,
            onTap: {},
            onQuickStart: { _, _ in }
        )
        .padding(.horizontal, Theme.Spacing.pageMargin)
    }
}
#endif
