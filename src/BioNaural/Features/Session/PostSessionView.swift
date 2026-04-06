// PostSessionView.swift
// BioNaural
//
// Post-session summary screen. Shown immediately after a session ends.
// Data speaks for itself — no congratulations, no "great job."
// All values from Theme tokens. Native SwiftUI throughout.

import SwiftUI

// MARK: - PostSessionView

struct PostSessionView: View {

    // MARK: - Input

    let session: FocusSession

    /// Callback when the user taps "Done" to return to mode selection.
    let onDismiss: () -> Void

    // MARK: - State

    @State private var thumbsRating: Int?
    @State private var showFeedbackTags = false
    @State private var selectedTags: Set<String> = []
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showSaveTrackConfirmation = false
    @State private var trackSaved = false
    @State private var savedTrackName: String = ""

    // MARK: Entrance Animation State

    @State private var headerVisible = false
    @State private var metricsVisible = false
    @State private var mapVisible = false
    @State private var scienceInsightVisible = false
    @State private var feedbackVisible = false
    @State private var bodyMusicVisible = false
    @State private var doneVisible = false
    @State private var shareVisible = false

    // MARK: Button Press State

    @State private var donePressed = false

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxxl) {
                headerSection
                metricGrid
                adaptationMapSection
                scienceInsightSection
                feedbackSection
                bodyMusicSaveSection
                doneButton
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.top, Theme.Spacing.mega)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .background(canvasBackground)
        .overlay(alignment: .topTrailing) {
            shareButton
                .padding(.top, Theme.Spacing.lg)
                .padding(.trailing, Theme.Spacing.pageMargin)
                .opacity(shareVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        }
        .sheet(isPresented: $showFeedbackTags) {
            feedbackTagsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .onAppear {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            savedTrackName = "\(session.focusMode?.displayName ?? session.mode) — \(formatter.string(from: Date()))"
            triggerEntranceSequence()
        }
    }

    // MARK: - Canvas Background

    private var canvasBackground: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [
                    modeColor.opacity(Theme.Opacity.canvasRadialWash),
                    Color.clear
                ],
                center: .top,
                startRadius: Theme.Spacing.mega,
                endRadius: Theme.Spacing.mega * Theme.Spacing.mega / Theme.Spacing.lg
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Entrance Animation

    private func triggerEntranceSequence() {
        withAnimation(Theme.Animation.staggeredFadeIn(index: 0)) {
            headerVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 2)) {
            metricsVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 4)) {
            mapVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 6)) {
            scienceInsightVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 8)) {
            feedbackVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 9)) {
            bodyMusicVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 10)) {
            doneVisible = true
        }
        withAnimation(Theme.Animation.staggeredFadeIn(index: 3)) {
            shareVisible = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Session complete")
                .font(Theme.Typography.caption)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)

            // Hero metric: duration
            Text(formattedDuration)
                .font(Theme.Typography.timer)
                .tracking(Theme.Typography.Tracking.data)
                .foregroundStyle(Theme.Colors.textPrimary)

            // Mode label
            Text(session.focusMode?.displayName ?? session.mode)
                .font(Theme.Typography.caption)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(modeColor)
        }
        .frame(maxWidth: .infinity)
        .opacity(headerVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: headerVisible ? .zero : Theme.Spacing.sm)
    }

    // MARK: - Metric Grid (2 columns)

    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.md),
                GridItem(.flexible(), spacing: Theme.Spacing.md)
            ],
            spacing: Theme.Spacing.md
        ) {
            metricCard(
                icon: "heart.fill",
                label: "Mean HR",
                value: formattedHeartRate,
                index: 0
            )

            metricCard(
                icon: "waveform.path.ecg",
                label: "Mean HRV",
                value: formattedHRV,
                index: 1
            )

            metricCard(
                icon: "arrow.triangle.2.circlepath",
                label: "Adaptations",
                value: "\(session.adaptationEvents.count)",
                index: 2
            )

            metricCard(
                icon: "clock.fill",
                label: "Peak Duration",
                value: formattedPeakDuration,
                index: 3
            )
        }
        .opacity(metricsVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: metricsVisible ? .zero : Theme.Spacing.sm)
    }

    private func metricCard(icon: String, label: String, value: String, index: Int) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(modeColor)

                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(value)
                .font(Theme.Typography.data)
                .tracking(Theme.Typography.Tracking.data)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.md)
        .background(glassCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Glass Card Background

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(
                        Theme.Colors.textOnAccent.opacity(Theme.Opacity.glassFill),
                        lineWidth: Theme.Radius.glassStroke
                    )
            )
    }

    // MARK: - Adaptation Map

    private var adaptationMapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Adaptation Map")
                .font(Theme.Typography.caption)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.leading, Theme.Spacing.xxs)

            AdaptationMapView(
                events: session.adaptationEvents,
                sessionDuration: session.duration,
                mode: session.focusMode ?? .focus
            )
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.horizontal, Theme.Spacing.md)
            .background(glassCard)
        }
        .opacity(mapVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: mapVisible ? .zero : Theme.Spacing.sm)
    }

    // MARK: - Science Insight

    private var scienceInsightSection: some View {
        PostSessionScienceInsightView(
            mode: session.focusMode ?? .focus,
            sessionDurationSeconds: session.durationSeconds,
            averageHeartRate: session.averageHeartRate,
            averageHRV: session.averageHRV,
            adaptationCount: session.adaptationEvents.count,
            beatFrequencyStart: session.beatFrequencyStart ?? (session.focusMode ?? .focus).defaultBeatFrequency,
            beatFrequencyEnd: session.beatFrequencyEnd ?? (session.focusMode ?? .focus).defaultBeatFrequency,
            adaptationEvents: session.adaptationEvents
        )
        .opacity(scienceInsightVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: scienceInsightVisible ? .zero : Theme.Spacing.sm)
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("How was the sound?")
                .font(Theme.Typography.caption)
                .tracking(Theme.Typography.Tracking.uppercase)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: Theme.Spacing.xl) {
                thumbsButton(value: 1, symbol: "hand.thumbsup.fill")
                thumbsButton(value: -1, symbol: "hand.thumbsdown.fill")
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: thumbsRating)
        }
        .opacity(feedbackVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: feedbackVisible ? .zero : Theme.Spacing.sm)
    }

    private func thumbsButton(value: Int, symbol: String) -> some View {
        let isSelected = thumbsRating == value

        return Button {
            withAnimation(Theme.Animation.press) {
                thumbsRating = value
            }

            if value == -1 {
                showFeedbackTags = true
            }
        } label: {
            Image(systemName: symbol)
                .font(Theme.Typography.headline)
                .foregroundStyle(
                    isSelected
                        ? modeColor
                        : Theme.Colors.textTertiary
                )
                .frame(
                    width: Theme.Spacing.jumbo + Theme.Spacing.sm,
                    height: Theme.Spacing.jumbo
                )
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? modeColor.opacity(Theme.Opacity.accentLight)
                                : Theme.Colors.surface
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? modeColor.opacity(Theme.Opacity.glassStroke)
                                        : Theme.Colors.textOnAccent.opacity(Theme.Opacity.glassFill),
                                    lineWidth: Theme.Radius.glassStroke
                                )
                        )
                )
                .scaleEffect(isSelected ? Theme.Animation.OrbScale.breathingMax : Theme.Opacity.full)
                .animation(Theme.Animation.press, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == 1 ? "Thumbs up" : "Thumbs down")
    }

    // MARK: - Feedback Tags Sheet

    private var feedbackTagsSheet: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Text("What didn't work?")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, Theme.Spacing.sm)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(FeedbackTag.allCases) { tag in
                    feedbackTagPill(tag: tag)
                }
            }

            Spacer()

            Button {
                showFeedbackTags = false
            } label: {
                Text("Done")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .fill(Theme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                                    .stroke(
                                        Theme.Colors.textOnAccent.opacity(Theme.Opacity.glassFill),
                                        lineWidth: Theme.Radius.glassStroke
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.pageMargin)
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }

    private func feedbackTagPill(tag: FeedbackTag) -> some View {
        let isSelected = selectedTags.contains(tag.rawValue)

        return Button {
            withAnimation(Theme.Animation.press) {
                if isSelected {
                    selectedTags.remove(tag.rawValue)
                } else {
                    selectedTags.insert(tag.rawValue)
                }
            }
        } label: {
            Text(tag.displayName)
                .font(Theme.Typography.caption)
                .foregroundStyle(
                    isSelected
                        ? modeColor
                        : Theme.Colors.textSecondary
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? modeColor.opacity(Theme.Opacity.accentLight)
                                : Theme.Colors.surface
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? modeColor.opacity(Theme.Opacity.glassStroke)
                                        : Theme.Colors.textOnAccent.opacity(Theme.Opacity.glassFill),
                                    lineWidth: Theme.Radius.glassStroke
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body Music Save

    @ViewBuilder
    private var bodyMusicSaveSection: some View {
        Group {
            if !trackSaved {
                Button {
                    showSaveTrackConfirmation = true
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: Theme.Typography.Size.caption, weight: .medium))
                            .foregroundStyle(Theme.Colors.accent)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text("Save to Body Music")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Text("Keep this session's unique sound")
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: Theme.Typography.Size.small))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .fill(Theme.Colors.surface)
                    )
                }
                .buttonStyle(.plain)
                .alert("Save Track", isPresented: $showSaveTrackConfirmation) {
                    TextField("Track name", text: $savedTrackName)
                    Button("Save") {
                        // Save will be wired to BodyMusicRecorder
                        trackSaved = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Save this session's audio parameters for replay.")
                }
            } else {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.signalCalm)
                    Text("Saved to Body Music")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(Theme.Spacing.lg)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .opacity(bodyMusicVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: bodyMusicVisible ? .zero : Theme.Spacing.sm)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareImage = ShareableMapGenerator.generate(
                events: session.adaptationEvents,
                sessionDuration: session.duration,
                mode: session.focusMode ?? .focus,
                format: .stories
            )
            showShareSheet = shareImage != nil
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                .background(
                    Circle()
                        .fill(Theme.Colors.surface)
                        .overlay(
                            Circle()
                                .stroke(
                                    Theme.Colors.textOnAccent.opacity(Theme.Opacity.glassFill),
                                    lineWidth: Theme.Radius.glassStroke
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share session map")
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            donePressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Animation.Duration.press) {
                onDismiss()
            }
        } label: {
            Text("Done")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(modeColor)
                )
                .scaleEffect(donePressed ? Theme.Animation.OrbScale.breathingMin : Theme.Opacity.full)
                .animation(Theme.Animation.press, value: donePressed)
        }
        .buttonStyle(.plain)
        .opacity(doneVisible ? Theme.Opacity.full : Theme.Opacity.transparent)
        .offset(y: doneVisible ? .zero : Theme.Spacing.sm)
    }

    // MARK: - Formatting

    private var formattedDuration: String {
        let total = session.durationSeconds
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedHeartRate: String {
        guard let hr = session.averageHeartRate else { return "--" }
        return "\(Int(hr)) bpm"
    }

    private var formattedHRV: String {
        guard let hrv = session.averageHRV else { return "--" }
        return "\(Int(hrv)) ms"
    }

    /// Computes the longest uninterrupted stretch between adaptations
    /// (the longest time the system held steady in one state).
    private var formattedPeakDuration: String {
        let events = session.adaptationEvents
        guard !events.isEmpty else {
            // No adaptations — the entire session was one continuous state.
            return formatSeconds(session.durationSeconds)
        }

        var longestGap: TimeInterval = 0

        for i in events.indices {
            let segmentEnd: TimeInterval = (i + 1 < events.count)
                ? events[i + 1].timestamp
                : session.duration
            let gap = segmentEnd - events[i].timestamp
            longestGap = max(longestGap, gap)
        }

        // Also consider the gap from session start to the first event.
        if let firstTimestamp = events.first?.timestamp {
            longestGap = max(longestGap, firstTimestamp)
        }

        return formatSeconds(Int(longestGap))
    }

    private func formatSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    // MARK: - Mode Color

    private var modeColor: Color {
        Color.modeColor(for: session.focusMode ?? .focus)
    }
}

// MARK: - FlowLayout

/// Horizontal wrapping layout for feedback tag pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - FeedbackTag

/// The fixed set of negative-feedback tags shown on thumbs-down.
private enum FeedbackTag: String, CaseIterable, Identifiable {
    case tooBusy = "Too busy"
    case tooQuiet = "Too quiet"
    case notMyStyle = "Not my style"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

/// Minimal UIKit wrapper for the native share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
