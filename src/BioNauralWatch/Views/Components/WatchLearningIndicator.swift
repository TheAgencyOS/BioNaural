// WatchLearningIndicator.swift
// BioNauralWatch
//
// Shows the user's learning progression — from coldStart dots through
// to the "Tuned to you" confident ring. Driven entirely by
// WatchLearningProfile and WatchDesign tokens.

import SwiftUI
import BioNauralShared

// MARK: - WatchLearningIndicator

struct WatchLearningIndicator: View {

    // MARK: - Inputs

    /// The user's current learning profile (drives stage and dot count).
    let profile: WatchLearningProfile

    // MARK: - Body

    var body: some View {
        switch profile.learningStage {
        case .coldStart, .learning:
            dotsView
        case .confident:
            confidentView
        }
    }

    // MARK: - Dots View (coldStart / learning)

    private var dotsView: some View {
        HStack(spacing: WatchDesign.Layout.learningDotSpacing) {
            ForEach(0..<WatchDesign.Learning.totalDots, id: \.self) { index in
                Circle()
                    .fill(WatchDesign.Colors.accent)
                    .opacity(index < profile.filledDots ? 1.0 : WatchDesign.Opacity.unfillledDot)
                    .frame(
                        width: WatchDesign.Layout.learningDotSize,
                        height: WatchDesign.Layout.learningDotSize
                    )
            }

            Text(dotsLabel)
                .font(.system(size: WatchDesign.Typography.learningLabelSize))
                .foregroundStyle(WatchDesign.Colors.accent.opacity(dotsLabelOpacity))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Learning progress, \(profile.filledDots) of \(WatchDesign.Learning.totalDots)")
    }

    // MARK: - Confident View

    private var confidentView: some View {
        HStack(spacing: WatchDesign.Layout.learningDotSpacing) {
            ZStack {
                Circle()
                    .stroke(WatchDesign.Colors.accent, lineWidth: WatchDesign.Layout.learningRingStrokeWidth)
                    .frame(
                        width: WatchDesign.Layout.learningRingSize,
                        height: WatchDesign.Layout.learningRingSize
                    )

                Circle()
                    .fill(WatchDesign.Colors.accent)
                    .frame(
                        width: WatchDesign.Layout.learningRingDotRadius * 2,
                        height: WatchDesign.Layout.learningRingDotRadius * 2
                    )
            }

            Text("Tuned to you")
                .font(.system(size: WatchDesign.Typography.learningLabelSize))
                .foregroundStyle(WatchDesign.Colors.accent.opacity(WatchDesign.Opacity.confidenceLabel))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tuned to you, \(profile.totalSessions) sessions completed")
    }

    // MARK: - Label Helpers

    private var dotsLabel: String {
        profile.learningStage == .coldStart
            ? "Learning your rhythm"
            : "\(profile.totalSessions) sessions in"
    }

    private var dotsLabelOpacity: Double {
        profile.learningStage == .coldStart ? WatchDesign.Opacity.learningLabelCold : WatchDesign.Opacity.learningLabelWarm
    }
}

// MARK: - Preview

#Preview("Learning - Cold Start") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        WatchLearningIndicator(profile: WatchLearningProfile())
    }
}

#Preview("Learning - In Progress") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        var profile = WatchLearningProfile()
        let _ = { profile.totalSessions = 12 }()
        WatchLearningIndicator(profile: profile)
    }
}

#Preview("Learning - Confident") {
    ZStack {
        WatchDesign.Colors.canvas.ignoresSafeArea()
        var profile = WatchLearningProfile()
        let _ = { profile.totalSessions = 25 }()
        WatchLearningIndicator(profile: profile)
    }
}
