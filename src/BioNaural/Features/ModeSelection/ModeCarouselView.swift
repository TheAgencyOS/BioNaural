// ModeCarouselView.swift
// BioNaural
//
// Premium carousel for mode selection. Swipeable cards with Aurora Drift
// wave animation, science flip reveal, and frequency-accurate waveforms.
// All values from Theme tokens. Native SwiftUI + Canvas rendering.

import SwiftUI
import BioNauralShared

// MARK: - ModeCarouselView

/// Contextual recommendation data passed from the home screen.
struct CarouselRecommendation {
    let mode: FocusMode
    let reason: String
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    let isWatchConnected: Bool
}

struct ModeCarouselView: View {

    let recommendation: CarouselRecommendation?
    let onStartSession: (FocusMode) -> Void

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let modes: [FocusMode] = [.focus, .relaxation, .sleep]
    private let cardSpacing: CGFloat = Theme.Spacing.lg

    /// Total card count: recommendation (if present) + 4 mode cards.
    private var totalCards: Int {
        (recommendation != nil ? 1 : 0) + modes.count
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            carouselArea
            pageDots
        }
    }

    // MARK: - Carousel

    private var carouselArea: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - (Theme.Spacing.pageMargin * 2)
            let totalCardWidth = cardWidth + cardSpacing
            let leadingPadding = Theme.Spacing.pageMargin

            HStack(spacing: cardSpacing) {
                // Card 0: Recommendation (if present)
                if let recommendation {
                    RecommendationCarouselCard(
                        recommendation: recommendation,
                        isActive: currentIndex == 0,
                        onPlay: { onStartSession(recommendation.mode) }
                    )
                    .frame(width: cardWidth)
                }

                // Mode cards
                ForEach(Array(modes.enumerated()), id: \.element) { index, mode in
                    let cardIndex = (recommendation != nil ? 1 : 0) + index
                    ModeCarouselCard(
                        mode: mode,
                        isActive: cardIndex == currentIndex,
                        onPlay: { onStartSession(mode) }
                    )
                    .frame(width: cardWidth)
                }
            }
            .padding(.leading, leadingPadding)
            .offset(x: -CGFloat(currentIndex) * totalCardWidth + dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = Theme.Carousel.dragThreshold
                        withAnimation(Theme.Carousel.snapAnimation) {
                            isDragging = false
                            if value.translation.width < -threshold, currentIndex < totalCards - 1 {
                                currentIndex += 1
                            } else if value.translation.width > threshold, currentIndex > 0 {
                                currentIndex -= 1
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: Theme.Carousel.cardHeight)
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            withAnimation(Theme.Carousel.snapAnimation) {
                switch direction {
                case .increment:
                    if currentIndex < totalCards - 1 { currentIndex += 1 }
                case .decrement:
                    if currentIndex > 0 { currentIndex -= 1 }
                @unknown default: break
                }
            }
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<totalCards, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Theme.Colors.accent : Theme.Colors.divider)
                    .frame(
                        width: index == currentIndex ? Theme.Spacing.xxl : Theme.Spacing.sm,
                        height: Theme.Spacing.sm
                    )
                    .onTapGesture {
                        withAnimation(Theme.Carousel.snapAnimation) {
                            currentIndex = index
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Recommendation Carousel Card

/// The "For You" card — matches the mode card design language with a
/// large display heading, the Orb as the hero visual, info button that
/// flips to show the recommendation reasoning, and play button.
private struct RecommendationCarouselCard: View {

    let recommendation: CarouselRecommendation
    let isActive: Bool
    let onPlay: () -> Void

    @State private var isFlipped = false

    private var modeColor: Color { Color.modeColor(for: recommendation.mode) }

    var body: some View {
        ZStack {
            // Front face
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: Theme.Carousel.flipPerspective
                )

            // Back face
            cardBack
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: Theme.Carousel.flipPerspective
                )
        }
        .frame(height: Theme.Carousel.cardHeight)
        .scaleEffect(isActive ? 1.0 : Theme.Carousel.inactiveScale)
        .opacity(isActive ? 1.0 : Theme.Carousel.inactiveOpacity)
        .onChange(of: isActive) { _, active in
            if !active && isFlipped {
                withAnimation(Theme.Carousel.flipAnimation) {
                    isFlipped = false
                }
            }
        }
    }

    private func toggleFlip() {
        withAnimation(Theme.Carousel.flipAnimation) {
            isFlipped.toggle()
        }
    }

    // MARK: - Card Front

    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(cardGradient)

            // Brand wave signature — four converging waves, recommended mode glows.
            // Only render when active to avoid off-screen 30 FPS Canvas overhead.
            Group {
                if isActive {
                    BrandWaveCanvas(highlightedMode: recommendation.mode)
                }
            }
            .frame(height: Theme.Carousel.cardHeight * Theme.Carousel.auroraHeightRatio)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))

            // Content overlay
            VStack(alignment: .leading, spacing: 0) {
                // Top: heading + info button
                HStack(alignment: .top) {
                    Text("Your Signal")
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Colors.textPrimary, Theme.Colors.textSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(Theme.Typography.Tracking.display)

                    Spacer()

                    infoButton
                }

                Spacer()

                // Bottom: mode + duration + play
                HStack {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: recommendation.mode.systemImageName)
                            .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                            .foregroundStyle(modeColor)

                        Text(recommendation.mode.displayName)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("\u{2022}")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Text("\(recommendation.mode.defaultDurationMinutes) min")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    playButton
                }
            }
            .padding(Theme.Spacing.xxl + Theme.Spacing.xs)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .carouselCardGlass()
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(modeColor.opacity(Theme.ModeCard.ambientGlowOpacity))
                .blur(radius: Theme.ModeCard.ambientGlowBlurRadius)
        )
    }

    // MARK: - Card Back (Recommendation Explanation)

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(cardGradient)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                HStack {
                    Text("Why this suggestion")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Button { toggleFlip() } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                            Circle()
                                .strokeBorder(Color.white.opacity(Theme.Opacity.light), lineWidth: Theme.Radius.glassStroke)
                                .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                            Image(systemName: "xmark")
                                .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close explanation")
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    explanationRow(
                        icon: "clock.fill",
                        title: "Time of day",
                        detail: timeOfDayExplanation
                    )

                    explanationRow(
                        icon: recommendation.mode.systemImageName,
                        title: recommendation.mode.displayName,
                        detail: recommendation.mode.cardDescription
                    )

                    if recommendation.isWatchConnected {
                        explanationRow(
                            icon: "applewatch",
                            title: "Biometrics",
                            detail: biometricExplanation
                        )
                    }
                }

                Spacer()

                HStack {
                    Text(recommendation.mode.frequencyLabel)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .tracking(Theme.Typography.Tracking.uppercase)
                        .textCase(.uppercase)

                    Spacer()

                    playButton
                }
            }
            .padding(Theme.Spacing.xxl + Theme.Spacing.xs)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .carouselCardGlass()
    }

    // MARK: - Explanation Row

    private func explanationRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                .foregroundStyle(modeColor)
                .frame(width: Theme.Spacing.xxl)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineSpacing(Theme.Typography.LineSpacing.relaxed)
            }
        }
    }

    private var timeOfDayExplanation: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case Constants.Circadian.morningStart..<Constants.Circadian.peakStart:
            return "Morning hours. Your cortisol is naturally high — activation builds on this."
        case Constants.Circadian.peakStart..<Constants.Circadian.middayStart:
            return "Peak cognitive window. Your prefrontal cortex is at its sharpest."
        case Constants.Circadian.middayStart..<Constants.Circadian.afternoonStart:
            return "Post-lunch period. Adenosine levels rise — focus helps counteract the dip."
        case Constants.Circadian.afternoonStart..<Constants.Circadian.eveningStart:
            return "Afternoon. Sustained beta entrainment supports deep work."
        case Constants.Circadian.eveningStart..<Constants.Circadian.nightStart:
            return "Evening. Your body is transitioning toward parasympathetic dominance."
        default:
            return "Night. Melatonin is rising — theta and delta frequencies align with your circadian rhythm."
        }
    }

    private var biometricExplanation: String {
        var parts: [String] = []
        if let hr = recommendation.restingHR {
            parts.append("Resting HR \(Int(hr)) BPM")
        }
        if let hrv = recommendation.hrv {
            parts.append("HRV \(Int(hrv)) ms")
        }
        if let sleep = recommendation.sleepHours {
            parts.append(String(format: "%.1f hrs sleep", sleep))
        }
        return parts.isEmpty ? "Biometric data is being collected." : parts.joined(separator: " . ")
    }

    // MARK: - Info Button

    private var infoButton: some View {
        Button { toggleFlip() } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                Circle()
                    .strokeBorder(Color.white.opacity(Theme.Opacity.light), lineWidth: Theme.Radius.glassStroke)
                    .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                Image(systemName: "info")
                    .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Why this suggestion")
    }

    // MARK: - Signal Metrics (3-column)

    /// Three contextual metrics in an evenly-spaced strip.
    /// Follows the MetricCardView spacing pattern (sm between elements,
    /// lg vertical padding) adapted for inline card use.
    private var signalMetrics: some View {
        HStack(spacing: 0) {
            primaryMetricColumn
                .frame(maxWidth: .infinity)

            secondaryMetricColumn
                .frame(maxWidth: .infinity)

            metricColumn(
                icon: "clock",
                value: "\(recommendation.mode.defaultDurationMinutes)",
                unit: "min",
                tint: Theme.Colors.textTertiary
            )
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var primaryMetricColumn: some View {
        switch recommendation.mode {
        case .focus, .energize:
            metricColumn(
                icon: "heart.fill",
                value: "\(Int(recommendation.restingHR ?? Constants.HealthDefaults.restingHR))",
                unit: "BPM",
                tint: modeColor
            )
        case .relaxation:
            metricColumn(
                icon: "waveform.path.ecg",
                value: "\(Int(recommendation.hrv ?? Constants.HealthDefaults.hrv))",
                unit: "ms",
                tint: modeColor
            )
        case .sleep:
            metricColumn(
                icon: "moon.fill",
                value: String(format: "%.1f", recommendation.sleepHours ?? Constants.HealthDefaults.sleepHours),
                unit: "hrs",
                tint: modeColor
            )
        }
    }

    @ViewBuilder
    private var secondaryMetricColumn: some View {
        switch recommendation.mode {
        case .focus, .energize:
            metricColumn(
                icon: "waveform.path.ecg",
                value: "\(Int(recommendation.hrv ?? Constants.HealthDefaults.hrv))",
                unit: "ms",
                tint: Theme.Colors.textTertiary
            )
        case .relaxation:
            metricColumn(
                icon: "heart.fill",
                value: "\(Int(recommendation.restingHR ?? Constants.HealthDefaults.restingHR))",
                unit: "BPM",
                tint: Theme.Colors.textTertiary
            )
        case .sleep:
            metricColumn(
                icon: "heart.fill",
                value: "\(Int(recommendation.restingHR ?? Constants.HealthDefaults.restingHR))",
                unit: "BPM",
                tint: Theme.Colors.textTertiary
            )
        }
    }

    /// Single metric column matching MetricCardView spacing conventions.
    /// Uses Theme.Spacing.sm (8pt) between elements, caption-sized icons,
    /// dataSmall for values, small for units.
    private func metricColumn(icon: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                .foregroundStyle(tint.opacity(Theme.Opacity.half))

            Text(value)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(unit)
                .font(Theme.Typography.small)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button(action: onPlay) {
            ZStack {
                // Ambient glow behind the button
                Circle()
                    .fill(modeColor.opacity(Theme.Opacity.medium))
                    .blur(radius: Theme.Spacing.lg)
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)

                // Main button circle
                Circle()
                    .fill(modeColor.opacity(Theme.Opacity.accentStrong))
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)

                Image(systemName: "play.fill")
                    .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .offset(x: Theme.Interaction.playIconOffset)
            }
            .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
        }
        .buttonStyle(CardPressStyle())
        .playButtonGlass(modeColor: modeColor)
        .accessibilityLabel("Begin \(recommendation.mode.displayName) session")
    }

    // MARK: - Gradient

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                modeColor.opacity(Theme.Opacity.accentLight),
                Theme.Colors.surface.opacity(Theme.Opacity.translucent),
                Theme.Colors.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Carousel Card

private struct ModeCarouselCard: View {

    let mode: FocusMode
    let isActive: Bool
    let onPlay: () -> Void

    @State private var isFlipped = false

    private var modeColor: Color { Color.modeColor(for: mode) }

    var body: some View {
        ZStack {
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: Theme.Carousel.flipPerspective
                )

            ScienceFlipView(mode: mode, onClose: { toggleFlip() })
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: Theme.Carousel.flipPerspective
                )
        }
        .frame(height: Theme.Carousel.cardHeight)
        .scaleEffect(isActive ? 1.0 : Theme.Carousel.inactiveScale)
        .opacity(isActive ? 1.0 : Theme.Carousel.inactiveOpacity)
        .onChange(of: isActive) { _, active in
            if !active && isFlipped {
                withAnimation(Theme.Carousel.flipAnimation) {
                    isFlipped = false
                }
            }
        }
    }

    private func toggleFlip() {
        withAnimation(Theme.Carousel.flipAnimation) {
            isFlipped.toggle()
        }
    }

    // MARK: - Card Front

    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(cardGradient)

            if isActive {
                AuroraDriftCanvas(mode: mode)
                    .frame(height: Theme.Carousel.cardHeight * Theme.Carousel.auroraHeightRatio)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
            }

            VStack {
                HStack {
                    Spacer()
                    infoButton
                }
                Spacer()
            }
            .padding(Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: 0) {
                Text(mode.displayName)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tracking(Theme.Typography.Tracking.display)

                Spacer()

                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    Text(mode.cardDescription)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(Theme.Typography.LineSpacing.relaxed)

                    HStack {
                        Text(mode.bandLabel)
                            .font(Theme.Typography.small)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .tracking(Theme.Typography.Tracking.uppercase)
                            .textCase(.uppercase)

                        Spacer()

                        playButton
                    }
                }
            }
            .padding(Theme.Spacing.xxl + Theme.Spacing.xs)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous))
        .carouselCardGlass()
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sheet, style: .continuous)
                .fill(modeColor.opacity(Theme.ModeCard.ambientGlowOpacity))
                .blur(radius: Theme.ModeCard.ambientGlowBlurRadius)
        )
    }

    // MARK: - Gradient

    private var cardGradient: LinearGradient {
        let tint: Color = modeColor
        return LinearGradient(
            colors: [
                tint.opacity(Theme.Opacity.accentLight),
                Theme.Colors.surface.opacity(Theme.Opacity.translucent),
                Theme.Colors.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Info Button

    private var infoButton: some View {
        Button { toggleFlip() } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                Circle()
                    .strokeBorder(Color.white.opacity(Theme.Opacity.light), lineWidth: Theme.Radius.glassStroke)
                    .frame(width: Theme.Spacing.xxl, height: Theme.Spacing.xxl)

                Image(systemName: "info")
                    .font(.system(size: Theme.Typography.Size.small, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Learn about the science")
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button(action: onPlay) {
            ZStack {
                // Ambient glow behind the button
                Circle()
                    .fill(modeColor.opacity(Theme.Opacity.medium))
                    .blur(radius: Theme.Spacing.lg)
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)

                // Main button circle
                Circle()
                    .fill(modeColor.opacity(Theme.Opacity.accentStrong))
                    .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)

                Image(systemName: "play.fill")
                    .font(.system(size: Theme.Typography.Size.body, weight: .medium))
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .offset(x: Theme.Interaction.playIconOffset) // optical centering
            }
            .frame(width: Theme.Spacing.jumbo, height: Theme.Spacing.jumbo)
        }
        .buttonStyle(CardPressStyle())
        .playButtonGlass(modeColor: modeColor)
        .accessibilityLabel("Begin \(mode.displayName) listening")
    }
}

// MARK: - Card Press Style

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Interaction.pressScale : 1.0)
            .opacity(configuration.isPressed ? Theme.Interaction.pressOpacity : 1.0)
            .animation(Theme.Animation.press, value: configuration.isPressed)
    }
}

// MARK: - Aurora Drift Canvas

/// Frequency-accurate sine wave renderer with color-shifting aurora effect.
/// Cycle count matches the mode's actual Hz range. All visual parameters
/// are decorative and do not affect frequency accuracy.
private struct AuroraDriftCanvas: View {

    let mode: FocusMode

    @State private var phase: Double = 0

    /// Visible wave cycles — derived from CardWave tokens scaled up for the
    /// larger carousel card. The carousel shows more detail than the compact
    /// home screen cards, so cycles are multiplied by a density factor.
    private var cycles: Double {
        let base: Double
        switch mode {
        case .focus:      base = Theme.CardWave.Cycles.focus
        case .relaxation: base = Theme.CardWave.Cycles.relaxation
        case .sleep:      base = Theme.CardWave.Cycles.sleep
        case .energize:   base = Theme.CardWave.Cycles.energize
        }
        // Carousel cards are wider than grid cards — scale cycles to fill.
        return base * Theme.CardWave.Cycles.carouselDensity
    }

    private var modeColor: Color { Color.modeColor(for: mode) }

    /// Aurora-specific color palettes per mode. These are rendering-tuned
    /// RGB values for the Canvas aurora effect — intentionally distinct from
    /// Theme.Colors mode colors (slightly shifted hues for visual richness).
    private enum AuroraPalette {
        typealias RGB = (r: Double, g: Double, b: Double)

        static let focus: [RGB]      = [(71, 86, 171), (91, 106, 191), (110, 124, 247), (130, 115, 210), (91, 106, 191)]
        static let relaxation: [RGB]  = [(58, 148, 146), (78, 168, 166), (88, 190, 180), (68, 155, 170), (78, 168, 166)]
        static let sleep: [RGB]       = [(124, 108, 176), (144, 128, 196), (160, 140, 220), (130, 118, 190), (144, 128, 196)]
        static let energize: [RGB]    = [(225, 146, 15), (245, 166, 35), (255, 185, 60), (235, 155, 25), (245, 166, 35)]
    }

    /// Color palette for aurora shifting (mode-specific, muted tones)
    private var palette: [AuroraPalette.RGB] {
        switch mode {
        case .focus:      return AuroraPalette.focus
        case .relaxation: return AuroraPalette.relaxation
        case .sleep:      return AuroraPalette.sleep
        case .energize:   return AuroraPalette.energize
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / Theme.CardWave.frameRate)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawAurora(context: context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Color Helpers

    private func paletteColor(at t: Double, opacity: Double) -> Color {
        let count = Double(palette.count - 1)
        let idx = ((t.truncatingRemainder(dividingBy: count)) + count).truncatingRemainder(dividingBy: count)
        let i = Int(idx)
        let f = idx - Double(i)
        let a = palette[i]
        let b = palette[min(i + 1, palette.count - 1)]
        let r = (a.r + (b.r - a.r) * f) / 255
        let g = (a.g + (b.g - a.g) * f) / 255
        let bv = (a.b + (b.b - a.b) * f) / 255
        return Color(red: r, green: g, blue: bv).opacity(opacity)
    }

    // MARK: - Aurora Renderer

    private func drawAurora(context: GraphicsContext, size: CGSize, time: Double) {
        let W = size.width
        let H = size.height
        let centerY = H * 0.5
        let amplitude = H * Theme.CardWave.AuroraDrift.amplitudeFraction
        let ps = time * Theme.CardWave.AuroraDrift.phaseSpeed
        let colorTime = time * Theme.CardWave.AuroraDrift.colorShiftSpeed

        drawPillars(context: context, W: W, centerY: centerY, amplitude: amplitude, ps: ps, colorTime: colorTime)
        drawWash(context: context, W: W, H: H, centerY: centerY, amplitude: amplitude, ps: ps, colorTime: colorTime)
        drawWaveLines(context: context, W: W, centerY: centerY, amplitude: amplitude, ps: ps, colorTime: colorTime)
        drawHarmonic(context: context, W: W, centerY: centerY, amplitude: amplitude, ps: ps, colorTime: colorTime)
    }

    private func drawPillars(context: GraphicsContext, W: CGFloat, centerY: CGFloat, amplitude: CGFloat, ps: Double, colorTime: Double) {
        let totalPillars: Int = min(Int(cycles * 2), Theme.CardWave.AuroraDrift.maxPillars)
        let pillarH: CGFloat = amplitude * 2.5
        for i in 0..<totalPillars {
            let denom: Double = cycles * 2
            let peakT: Double = (Double(i) + 0.25) / denom
            let peakX: CGFloat = peakT * W
            let angle: Double = peakT * cycles * 2 * .pi + ps
            let waveVal: Double = sin(angle)
            let intensity: Double = pow(max(0, abs(waveVal)), Theme.CardWave.AuroraDrift.intensityExponent)
            let hw = Theme.CardWave.AuroraDrift.pillarHalfWidth
            let rect = CGRect(x: peakX - hw, y: centerY - pillarH * 0.5, width: hw * 2, height: pillarH)
            let op: Double = Theme.CardWave.AuroraDrift.pillarOpacity * intensity
            let color = paletteColor(at: colorTime + Double(i) * Theme.CardWave.AuroraDrift.colorOffsetPerPillar, opacity: op)
            var ctx = context
            ctx.addFilter(.blur(radius: Theme.CardWave.AuroraDrift.pillarBlur))
            ctx.fill(Path(rect), with: .color(color))
        }
    }

    private func drawWash(context: GraphicsContext, W: CGFloat, H: CGFloat, centerY: CGFloat, amplitude: CGFloat, ps: Double, colorTime: Double) {
        let ampScale: CGFloat = amplitude * Theme.CardWave.AuroraDrift.washAmplitudeScale
        let phaseScale: Double = ps * Theme.CardWave.AuroraDrift.washPhaseScale
        let freqBase: Double = cycles * 2 * .pi
        var washPath = Path()
        let ob = Theme.CardWave.AuroraDrift.edgeOverbleed
        let stride = Theme.CardWave.AuroraDrift.sampleStride
        for x in Swift.stride(from: -ob, through: W + ob, by: stride) {
            let tx: Double = x / W
            let angle: Double = tx * freqBase + phaseScale
            let y: CGFloat = centerY - ampScale * sin(angle)
            let pt = CGPoint(x: x, y: y)
            if x <= -ob + 1 { washPath.move(to: pt) } else { washPath.addLine(to: pt) }
        }
        washPath.addLine(to: CGPoint(x: W + ob, y: H))
        washPath.addLine(to: CGPoint(x: -ob, y: H))
        washPath.closeSubpath()
        let color = paletteColor(at: colorTime, opacity: Theme.CardWave.AuroraDrift.washFillOpacity)
        var ctx = context
        ctx.addFilter(.blur(radius: Theme.CardWave.AuroraDrift.washBlur))
        ctx.fill(washPath, with: .color(color))
    }

    private func drawWaveLines(context: GraphicsContext, W: CGFloat, centerY: CGFloat, amplitude: CGFloat, ps: Double, colorTime: Double) {
        let ob = Theme.CardWave.AuroraDrift.edgeOverbleed
        let step = Theme.CardWave.AuroraDrift.sampleStride
        let freqBase: Double = cycles * 2 * .pi
        let passes = Theme.CardWave.AuroraDrift.wavePasses
        // Use midpoint color for the entire wave — eliminates per-segment color allocation.
        let midColorT: Double = colorTime + 0.5 * Theme.CardWave.AuroraDrift.colorTimeMultiplier

        for pass in passes {
            var wavePath = Path()
            var isFirst = true
            for x in Swift.stride(from: -ob, through: W + ob, by: step) {
                let tx: Double = x / W
                let angle: Double = tx * freqBase + ps
                let y: CGFloat = centerY - amplitude * sin(angle)
                if isFirst {
                    wavePath.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    wavePath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            let color = paletteColor(at: midColorT, opacity: pass.opacity)
            var ctx = context
            if pass.blur > 0 { ctx.addFilter(.blur(radius: pass.blur)) }
            ctx.stroke(wavePath, with: .color(color), style: StrokeStyle(lineWidth: pass.lineWidth, lineCap: .round))
        }
    }

    private func drawHarmonic(context: GraphicsContext, W: CGFloat, centerY: CGFloat, amplitude: CGFloat, ps: Double, colorTime: Double) {
        let hAmp: CGFloat = amplitude * Theme.CardWave.AuroraDrift.harmonicAmplitudeScale
        let freqMult: Double = cycles * Theme.CardWave.AuroraDrift.harmonicFrequencyMultiplier
        let psMult: Double = ps * Theme.CardWave.AuroraDrift.harmonicPhaseScale + Theme.CardWave.AuroraDrift.harmonicPhaseOffset
        let ob = Theme.CardWave.AuroraDrift.edgeOverbleed
        let stride = Theme.CardWave.AuroraDrift.sampleStride
        var path = Path()
        for x in Swift.stride(from: -ob, through: W + ob, by: stride) {
            let tx: Double = x / W
            let angle: Double = tx * freqMult * .pi + psMult
            let y: CGFloat = centerY - hAmp * sin(angle)
            let pt = CGPoint(x: x, y: y)
            if x <= -ob + 1 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        let color = paletteColor(at: colorTime + Theme.CardWave.AuroraDrift.harmonicColorOffset, opacity: Theme.CardWave.AuroraDrift.harmonicStrokeOpacity)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: Theme.Radius.glassStroke * Theme.CardWave.AuroraDrift.harmonicStrokeScale))
    }
}

// MARK: - FocusMode Card Extensions

extension FocusMode {

    var bandLabel: String {
        switch self {
        case .focus:      return "Beta frequency"
        case .relaxation: return "Alpha frequency"
        case .sleep:      return "Theta–Delta"
        case .energize:   return "High-Beta"
        }
    }

    var cardDescription: String {
        switch self {
        case .focus:
            return "Sustained attention for deep work. Audio adapts as your body calms."
        case .relaxation:
            return "Calm & de-stress. Alpha waves guide your nervous system down."
        case .sleep:
            return "Wind-down to rest. Frequency descends as you drift off."
        case .energize:
            return "Wake up & activate. Uplifting arousal for your morning."
        }
    }
}

// MARK: - Preview

#Preview("Mode Carousel") {
    ZStack {
        Theme.Colors.canvas.ignoresSafeArea()
        ModeCarouselView(
            recommendation: CarouselRecommendation(
                mode: .focus,
                reason: "Peak cognitive hours — ideal for deep work.",
                restingHR: 64,
                hrv: 48,
                sleepHours: 7.2,
                isWatchConnected: true
            )
        ) { mode in
            print("Start: \(mode.displayName)")
        }
    }
    .preferredColorScheme(.dark)
}

// MARK: - Carousel Glass Modifier

private extension View {
    /// Applies Liquid Glass on iOS 26+ to carousel cards.
    /// Falls through to unmodified on earlier versions.
    func carouselCardGlass() -> some View {
        modifier(CarouselGlassModifier())
    }
}

private struct CarouselGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.sheet))
        } else {
            content
        }
    }
}

// MARK: - Play Button Glass Modifier

private extension View {
    /// Applies Liquid Glass to the play button on iOS 26+.
    /// Mode-tinted glass creates a translucent, refractive surface over
    /// the solid mode color — feels like a liquid droplet catching light.
    func playButtonGlass(modeColor: Color) -> some View {
        modifier(PlayButtonGlassModifier(modeColor: modeColor))
    }
}

private struct PlayButtonGlassModifier: ViewModifier {
    let modeColor: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.interactive().tint(modeColor),
                    in: .circle
                )
        } else {
            content
        }
    }
}
