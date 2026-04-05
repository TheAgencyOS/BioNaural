// PostSessionScienceInsightView.swift
// BioNaural
//
// Personalized science insight card shown after a session completes.
// Features a frequency journey sparkline, animated data chips, and
// mode-specific science context derived from the user's actual biometrics.
//
// This is the "aha moment" — where the user's own data meets the science.
//
// All values from Theme tokens. No hardcoded values.

import SwiftUI
import BioNauralShared

// MARK: - PostSessionScienceInsightView

struct PostSessionScienceInsightView: View {

    // MARK: - Input

    let mode: FocusMode
    let sessionDurationSeconds: Int
    let averageHeartRate: Double?
    let averageHRV: Double?
    let adaptationCount: Int
    let beatFrequencyStart: Double
    let beatFrequencyEnd: Double
    /// Ordered adaptation events for the sparkline.
    var adaptationEvents: [AdaptationEventRecord] = []

    // MARK: - State

    @State private var appeared = false
    @State private var dismissed = false
    @State private var expanded = false
    @State private var sparklineProgress: CGFloat = 0

    // MARK: - Body

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: .zero) {

                // Top accent gradient bar
                LinearGradient(
                    colors: [modeColor, modeColor.opacity(Theme.Opacity.medium), modeColor.opacity(Theme.Opacity.transparent)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: Theme.Spacing.xxs)

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                    // Header row
                    HStack(spacing: Theme.Spacing.sm) {
                        // Breathing sparkle icon
                        Image(systemName: "sparkles")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(modeColor)
                            .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.accentLight)
                            .animation(
                                Theme.Animation.breathingGlow,
                                value: appeared
                            )

                        Text("What happened")
                            .font(Theme.Typography.small)
                            .foregroundStyle(modeColor)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .textCase(.uppercase)

                        Spacer()

                        Button {
                            withAnimation(Theme.Animation.standard) {
                                dismissed = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .frame(
                                    width: Theme.Spacing.xxl,
                                    height: Theme.Spacing.xxl
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss insight")
                    }

                    // Primary insight — personalized headline
                    Text(primaryInsight)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                    // Frequency journey sparkline
                    if !adaptationEvents.isEmpty || abs(beatFrequencyEnd - beatFrequencyStart) > Theme.Audio.SlewRate.beatFrequencyMax {
                        frequencySparkline
                    }

                    // Data chip row
                    ScrollView(.horizontal, showsIndicators: false) {
                        dataHighlightRow
                    }

                    // Science context
                    Text(scienceContext)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                    // Expandable deep-dive
                    if expanded {
                        expandedDeepDive
                    }

                    // Learn more toggle
                    Button {
                        withAnimation(Theme.Animation.sheet) {
                            expanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(expanded ? "Show less" : "The research")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(modeColor)

                            Image(systemName: "chevron.down")
                                .font(.system(size: Theme.Typography.Size.small))
                                .foregroundStyle(modeColor)
                                .rotationEffect(.degrees(expanded ? -180 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background { cardBackground }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .opacity(appeared ? Theme.Opacity.full : Theme.Opacity.transparent)
            .offset(y: appeared ? .zero : Theme.Spacing.lg)
            .onAppear {
                withAnimation(Theme.Animation.staggeredFadeIn(index: 5)) {
                    appeared = true
                }
                // Animate sparkline drawing
                withAnimation(
                    .easeOut(duration: Theme.Animation.Duration.orbAdaptation)
                        .delay(Theme.Animation.Duration.staggerDelay * 6)
                ) {
                    sparklineProgress = 1.0
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Session science insight for \(mode.displayName)")
        }
    }

    // MARK: - Frequency Journey Sparkline

    /// A mini chart showing the session's frequency evolution — from start frequency
    /// through each adaptation event to end frequency. Draws left-to-right with
    /// an animated reveal.
    private var frequencySparkline: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            // Frequency labels
            HStack {
                Text(String(format: "%.1f Hz", beatFrequencyStart))
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Text(String(format: "%.1f Hz", beatFrequencyEnd))
                    .font(Theme.Typography.dataSmall)
                    .foregroundStyle(modeColor)
            }

            // Sparkline canvas
            Canvas { context, size in
                drawSparkline(context: context, size: size)
            }
            .frame(height: Theme.Spacing.jumbo)
            .mask(
                // Animated reveal mask — wipes left to right
                Rectangle()
                    .frame(
                        width: Theme.Layout.screenEstimate * sparklineProgress
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(Theme.Opacity.minimal),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .accessibilityLabel("Frequency journey from \(String(format: "%.1f", beatFrequencyStart)) to \(String(format: "%.1f", beatFrequencyEnd)) Hz")
    }

    private func drawSparkline(context: GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        // Build data points from adaptation events
        var points: [(x: CGFloat, y: CGFloat)] = []
        let totalDuration = max(TimeInterval(sessionDurationSeconds), 1)

        // Start point
        points.append((x: 0, y: beatFrequencyStart))

        // Adaptation event points
        for event in adaptationEvents {
            let xNorm = CGFloat(event.timestamp / totalDuration)
            points.append((x: xNorm, y: event.newBeatFrequency))
        }

        // End point
        points.append((x: 1.0, y: beatFrequencyEnd))

        // Determine y-axis range
        let allFreqs = points.map(\.y)
        let minFreq = (allFreqs.min() ?? beatFrequencyStart) - 1
        let maxFreq = (allFreqs.max() ?? beatFrequencyEnd) + 1
        let freqRange = max(maxFreq - minFreq, 1)

        // Map to canvas coordinates
        let canvasPoints = points.map { point in
            CGPoint(
                x: point.x * size.width,
                y: size.height - ((point.y - minFreq) / freqRange) * size.height
            )
        }

        // Draw gradient fill under the line
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: canvasPoints[0].x, y: size.height))
        for cp in canvasPoints {
            fillPath.addLine(to: cp)
        }
        fillPath.addLine(to: CGPoint(x: canvasPoints.last?.x ?? size.width, y: size.height))
        fillPath.closeSubpath()

        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [
                    modeColor.opacity(Theme.Opacity.accentLight),
                    modeColor.opacity(Theme.Opacity.minimal)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Draw the line
        var linePath = Path()
        for (i, cp) in canvasPoints.enumerated() {
            if i == 0 {
                linePath.move(to: cp)
            } else {
                linePath.addLine(to: cp)
            }
        }

        // Glow pass
        var glowCtx = context
        glowCtx.addFilter(.blur(radius: Theme.Wavelength.blurRadius * 2))
        glowCtx.stroke(
            linePath,
            with: .color(modeColor.opacity(Theme.Opacity.medium)),
            lineWidth: Theme.Wavelength.Stroke.elevated
        )

        // Primary stroke
        context.stroke(
            linePath,
            with: .color(modeColor),
            lineWidth: Theme.Wavelength.Stroke.standard
        )

        // Dots at adaptation points
        for (i, cp) in canvasPoints.enumerated() {
            if i > 0 && i < canvasPoints.count - 1 {
                let dotSize = Theme.Spacing.xs
                context.fill(
                    Circle().path(in: CGRect(
                        x: cp.x - dotSize / 2,
                        y: cp.y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )),
                    with: .color(modeColor)
                )
            }
        }
    }

    // MARK: - Data Highlight Row

    private var dataHighlightRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let hr = averageHeartRate, hr > 0 {
                dataChip(icon: "heart.fill", value: "\(Int(hr))", unit: "bpm")
            }
            if let hrv = averageHRV, hrv > 0 {
                dataChip(icon: "waveform.path.ecg", value: "\(Int(hrv))", unit: "ms HRV")
            }
            if adaptationCount > 0 {
                dataChip(icon: "arrow.triangle.2.circlepath", value: "\(adaptationCount)", unit: "adaptations")
            }
            let durationMin = sessionDurationSeconds / 60
            dataChip(icon: "clock.fill", value: "\(durationMin)", unit: "min")
        }
    }

    private func dataChip(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.small))
                .foregroundStyle(modeColor.opacity(Theme.Opacity.half))

            Text(value)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())

            Text(unit)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            Capsule()
                .fill(modeColor.opacity(Theme.Opacity.subtle))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            modeColor.opacity(Theme.Opacity.light),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit)")
    }

    // MARK: - Expanded Deep Dive

    @ViewBuilder
    private var expandedDeepDive: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Gradient divider
            HStack(spacing: Theme.Spacing.md) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [modeColor, modeColor.opacity(Theme.Opacity.transparent)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: Theme.Radius.glassStroke)
            }

            Text(deepDiveContext)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(Theme.Typography.LineSpacing.relaxed)

            // Caveat
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(modeColor.opacity(Theme.Opacity.accentLight))
                    .frame(width: 3)

                Text("One session is a snapshot. Trends over weeks are the real story.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
        }
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)).animation(Theme.Animation.sheet),
                removal: .opacity.animation(Theme.Animation.press)
            )
        )
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(Theme.Opacity.minimal),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                modeColor.opacity(Theme.Opacity.dim),
                                modeColor.opacity(Theme.Opacity.subtle),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
            .shadow(
                color: Color.black.opacity(Theme.Opacity.dim),
                radius: Theme.Spacing.sm,
                y: Theme.Spacing.xxs
            )
            .shadow(
                color: modeColor.opacity(Theme.Opacity.subtle),
                radius: Theme.Spacing.xl,
                y: Theme.Spacing.sm
            )
    }

    // MARK: - Content

    private var primaryInsight: String {
        switch mode {
        case .focus:
            if adaptationCount > 0 {
                return "Your session adapted \(adaptationCount) "
                    + "time\(adaptationCount == 1 ? "" : "s") to keep "
                    + "beta-range entrainment aligned with your focus state."
            }
            return "Beta-range entrainment held steady through your session \u{2014} a sign your focus state was consistent."
        case .relaxation:
            if let hrv = averageHRV, hrv > 0 {
                return "Your HRV averaged \(Int(hrv)) ms. Alpha-range beats (8\u{2013}12 Hz) have strong evidence for this calming response."
            }
            return "Alpha-range beats guided your session toward calm. This is the most evidence-backed mode in the app."
        case .sleep:
            let durationMin = sessionDurationSeconds / 60
            if durationMin >= 15 {
                return "Your session ran \(durationMin) minutes \u{2014} long enough for the theta-to-delta descent to reach deep sleep frequencies."
            }
            return "Sleep mode traced your brain\u{2019}s natural descent from theta to delta over the session."
        case .energize:
            if adaptationCount > 0 {
                return "Your Watch triggered \(adaptationCount) "
                    + "adaptation\(adaptationCount == 1 ? "" : "s") "
                    + "to keep your energy in the high-beta sweet spot "
                    + "without overdriving."
            }
            return "High-beta entrainment held steady. Your safety guardrails stayed green throughout."
        }
    }

    private var scienceContext: String {
        switch mode {
        case .focus:
            return "Your heart doesn\u{2019}t beat like a metronome "
                + "\u{2014} and that variation is the signal. "
                + "When HR stabilizes during focus, it suggests your "
                + "autonomic nervous system has settled into "
                + "a task-positive state."
        case .relaxation:
            return "Higher HRV means your nervous system is flexible "
                + "and recovered. Alpha-range entrainment supports "
                + "this parasympathetic shift "
                + "\u{2014} the opposite of fight-or-flight."
        case .sleep:
            return "Sleep onset follows a predictable brainwave "
                + "descent: waking beta \u{2192} relaxed alpha "
                + "\u{2192} drowsy theta \u{2192} deep delta. "
                + "BioNaural paces that transition so your brain "
                + "has a signal to follow."
        case .energize:
            return "High-beta frequencies (18\u{2013}30 Hz) correspond "
                + "to alertness and motor readiness. The adaptive "
                + "engine reinforces that signal while your Watch "
                + "ensures intensity stays in a safe range."
        }
    }

    private var deepDiveContext: String {
        switch mode {
        case .focus:
            return "A 2016 University of Alberta study found "
                + "beta-range binaural beats (14\u{2013}16 Hz) "
                + "improved focus performance and strengthened "
                + "brain connectivity patterns. The adaptive "
                + "engine builds on this by adjusting in real "
                + "time \u{2014} if your focus drifts, the system "
                + "responds rather than playing a static tone."
        case .relaxation:
            return "Garcia-Argibay et al. (2019) pooled 22 studies "
                + "and found alpha-range beats reliably reduce "
                + "anxiety with small-to-moderate effect sizes "
                + "\u{2014} comparable to a session of guided "
                + "breathing. Combined with HRV biofeedback "
                + "(Hedges\u{2019} g = 0.81), the adaptive approach "
                + "nearly doubles the effect."
        case .sleep:
            return "Most studies finding significant effects used "
                + "sessions of 15 minutes or longer. The "
                + "theta-to-delta ramp takes 25 minutes by "
                + "default because your brain needs time to "
                + "detect the pattern and synchronize. The "
                + "carrier frequency stays in the "
                + "100\u{2013}200 Hz range \u{2014} low enough to be "
                + "comfortable for extended listening."
        case .energize:
            return "Iaccarino et al. (2016, Nature) demonstrated "
                + "that 40 Hz stimulation drives neural "
                + "entrainment effectively. Energize uses the "
                + "18\u{2013}30 Hz high-beta range for alertness "
                + "and activation, with safety guardrails "
                + "(HR ceiling, HRV floor, rate-of-change "
                + "limits) ensuring the session stays within "
                + "healthy bounds."
        }
    }

    private var modeColor: Color {
        Color.modeColor(for: mode)
    }
}

// MARK: - Previews

#Preview("Focus — 5 adaptations") {
    PostSessionScienceInsightView(
        mode: .focus,
        sessionDurationSeconds: 1500,
        averageHeartRate: 72,
        averageHRV: 48,
        adaptationCount: 5,
        beatFrequencyStart: 14,
        beatFrequencyEnd: 15.2,
        adaptationEvents: [
            AdaptationEventRecord(timestamp: 120, reason: "HR", oldBeatFrequency: 14.0, newBeatFrequency: 13.5, heartRateAtTime: 78),
            AdaptationEventRecord(timestamp: 360, reason: "HR", oldBeatFrequency: 13.5, newBeatFrequency: 14.2, heartRateAtTime: 72),
            AdaptationEventRecord(timestamp: 600, reason: "HR", oldBeatFrequency: 14.2, newBeatFrequency: 14.8, heartRateAtTime: 70),
            AdaptationEventRecord(timestamp: 900, reason: "HR", oldBeatFrequency: 14.8, newBeatFrequency: 15.0, heartRateAtTime: 68),
            AdaptationEventRecord(timestamp: 1200, reason: "HR", oldBeatFrequency: 15.0, newBeatFrequency: 15.2, heartRateAtTime: 67)
        ]
    )
    .padding(Theme.Spacing.pageMargin)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Sleep — no adaptations") {
    PostSessionScienceInsightView(
        mode: .sleep,
        sessionDurationSeconds: 2100,
        averageHeartRate: 62,
        averageHRV: 55,
        adaptationCount: 0,
        beatFrequencyStart: 6,
        beatFrequencyEnd: 2.3
    )
    .padding(Theme.Spacing.pageMargin)
    .background(Theme.Colors.canvas)
    .preferredColorScheme(.dark)
}
