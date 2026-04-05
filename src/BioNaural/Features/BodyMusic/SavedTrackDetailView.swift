// SavedTrackDetailView.swift
// BioNaural
//
// Detail view for a single saved Body Music track. Shows the track's
// audio parameters, adaptation visualization, biometric context,
// and actions (replay, favorite, rename, delete).
// All values from Theme tokens. Native SwiftUI throughout.

import SwiftUI
import SwiftData
import BioNauralShared

// MARK: - SavedTrackDetailView

struct SavedTrackDetailView: View {

    // MARK: - Input

    let track: SavedTrack

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var showDeleteConfirmation = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var contentAppeared = false

    // MARK: - Layout

    private let adaptationChartHeight: CGFloat = Theme.Spacing.mega + Theme.Spacing.jumbo + Theme.Spacing.sm

    // MARK: - Computed

    private var trackModeColor: Color {
        track.focusMode.map { Color.modeColor(for: $0) } ?? Theme.Colors.accent
    }

    private var decodedSnapshots: [AdaptationSnapshot] {
        guard let data = track.adaptationTimeline else { return [] }
        return BodyMusicRecorder.decodeTimeline(data)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xxl) {
                heroSection
                adaptationSection
                audioParametersCard
                biometricCard
                statsCard
                actionsSection
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.bottom, Theme.Spacing.jumbo)
        }
        .background(atmosphericBackground)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Track", isPresented: $showRenameAlert) {
            TextField("Track name", text: $renameText)
            Button("Save") {
                guard !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                track.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for this track.")
        }
        .confirmationDialog(
            "Delete Track",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(track)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(track.name)\". This action cannot be undone.")
        }
        .onAppear {
            renameText = track.name
            guard !reduceMotion else {
                contentAppeared = true
                return
            }
            withAnimation(Theme.Animation.standard) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [
                    trackModeColor.opacity(Theme.Opacity.canvasRadialWash),
                    Color.clear
                ],
                center: .top,
                startRadius: .zero,
                endRadius: Theme.Spacing.mega * Theme.Spacing.xxs
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Static orb — mode-colored radial gradient
            staticOrb
                .frame(width: Theme.Spacing.mega, height: Theme.Spacing.mega)

            Text(track.name)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.md) {
                Label(
                    Self.dateFormatter.string(from: track.dateSaved),
                    systemImage: "calendar"
                )

                Label(
                    track.formattedDuration,
                    systemImage: "clock"
                )
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
        .staggeredFadeIn(index: 0, isVisible: contentAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var staticOrb: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            let gradient = Gradient(colors: [
                trackModeColor,
                trackModeColor.opacity(Theme.Opacity.transparent)
            ])
            let shading = GraphicsContext.Shading.radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: radius
            )

            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Ellipse().path(in: rect), with: shading)
        }
    }

    private var heroAccessibilityLabel: String {
        let mode = track.focusMode?.displayName ?? track.mode.capitalized
        return "\(track.name), \(mode), \(track.formattedDuration)"
    }

    // MARK: - Adaptation Visualization

    @ViewBuilder
    private var adaptationSection: some View {
        sectionContainer(title: "Adaptation Timeline", icon: "chart.xyaxis.line") {
            if decodedSnapshots.count >= 2 {
                AdaptationChartView(
                    snapshots: decodedSnapshots,
                    modeColor: trackModeColor,
                    height: adaptationChartHeight
                )
            } else {
                Text("No adaptation data recorded")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.lg)
            }
        }
        .staggeredFadeIn(index: 1, isVisible: contentAppeared)
    }

    // MARK: - Audio Parameters Card

    private var audioParametersCard: some View {
        sectionContainer(title: "Audio Parameters", icon: "waveform") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                parameterRow(
                    label: "Beat Frequency",
                    value: String(
                        format: "%.1f \u{2192} %.1f Hz",
                        track.beatFrequencyStart,
                        track.beatFrequencyEnd
                    )
                )

                parameterRow(
                    label: "Carrier Frequency",
                    value: String(format: "%.0f Hz", track.carrierFrequency)
                )

                if let ambientID = track.ambientBedID {
                    parameterRow(
                        label: "Ambient Bed",
                        value: formatSoundID(ambientID)
                    )
                }

                if !track.melodicLayerIDs.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Melodic Layers")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        FlowLayout(spacing: Theme.Spacing.sm) {
                            ForEach(track.melodicLayerIDs, id: \.self) { layerID in
                                Text(formatSoundID(layerID))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(Theme.Colors.surfaceRaised)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                                                lineWidth: Theme.Radius.glassStroke
                                            )
                                    )
                            }
                        }
                    }
                }
            }
        }
        .staggeredFadeIn(index: 2, isVisible: contentAppeared)
    }

    // MARK: - Biometric Card

    @ViewBuilder
    private var biometricCard: some View {
        if let hr = track.averageHeartRate {
            sectionContainer(title: "Biometrics", icon: "heart.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text("\(Int(hr))")
                            .font(Theme.Typography.data)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("BPM avg")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Text("Your body's signature for this session")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .staggeredFadeIn(index: 3, isVisible: contentAppeared)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        sectionContainer(title: "Stats", icon: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                parameterRow(
                    label: "Play Count",
                    value: "\(track.playCount)"
                )

                parameterRow(
                    label: "Date Saved",
                    value: Self.fullDateFormatter.string(from: track.dateSaved)
                )
            }
        }
        .staggeredFadeIn(index: 4, isVisible: contentAppeared)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Replay button
            Button {
                // Replay action — handled by parent navigation or ViewModel
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "play.fill")
                    Text("Replay This Track")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Replay this track")

            // Favorite toggle
            Button {
                withAnimation(Theme.Animation.standard) {
                    track.isFavorite.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    Text(track.isFavorite ? "Unfavorite" : "Favorite")
                }
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent.opacity(Theme.Opacity.accentLight))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.accent.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(track.isFavorite ? "Remove from favorites" : "Add to favorites")

            // Rename button
            Button {
                renameText = track.name
                showRenameAlert = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "pencil")
                    Text("Rename")
                }
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent.opacity(Theme.Opacity.accentLight))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.accent.opacity(Theme.Opacity.glassStroke),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename track")

            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.signalPeak)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.signalPeak.opacity(Theme.Opacity.light))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(
                            Theme.Colors.signalPeak.opacity(Theme.Opacity.dim),
                            lineWidth: Theme.Radius.glassStroke
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete track")
        }
        .staggeredFadeIn(index: 5, isVisible: contentAppeared)
    }

    // MARK: - Section Container

    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Typography.Size.caption))
                    .foregroundStyle(Theme.Colors.accent)

                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(
                    Theme.Colors.divider.opacity(Theme.Opacity.glassStroke),
                    lineWidth: Theme.Radius.glassStroke
                )
        )
    }

    // MARK: - Parameter Row

    private func parameterRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.Typography.dataSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Helpers

    private func formatSoundID(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()
}

// MARK: - AdaptationChartView

private struct AdaptationChartView: View {

    let snapshots: [AdaptationSnapshot]
    let modeColor: Color
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            guard snapshots.count >= 2,
                  let firstTimestamp = snapshots.first?.timestamp,
                  let lastTimestamp = snapshots.last?.timestamp,
                  lastTimestamp > firstTimestamp else { return }

            let frequencies = snapshots.map(\.beatFrequency)
            let minFreq = (frequencies.min() ?? 0)
            let maxFreq = (frequencies.max() ?? 1)
            let freqRange = maxFreq - minFreq
            let effectiveRange = freqRange > 0 ? freqRange : 1.0

            let timeRange = lastTimestamp - firstTimestamp
            let verticalPadding: CGFloat = Theme.Spacing.sm

            // Draw grid lines
            let gridLineCount = 3
            for i in 0...gridLineCount {
                let y = verticalPadding + CGFloat(i) / CGFloat(gridLineCount) * (size.height - verticalPadding * 2)
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: 0, y: y))
                gridLine.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    gridLine,
                    with: .color(Theme.Colors.divider.opacity(Theme.Opacity.subtle)),
                    style: StrokeStyle(lineWidth: Theme.Radius.glassStroke)
                )
            }

            // Draw frequency path
            var path = Path()
            for (index, snapshot) in snapshots.enumerated() {
                let x = CGFloat((snapshot.timestamp - firstTimestamp) / timeRange) * size.width
                let normalizedY = CGFloat((snapshot.beatFrequency - minFreq) / effectiveRange)
                let y = verticalPadding + (1.0 - normalizedY) * (size.height - verticalPadding * 2)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(modeColor),
                style: StrokeStyle(lineWidth: chartStrokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Draw fill under curve
            var fillPath = path
            let lastX = CGFloat((lastTimestamp - firstTimestamp) / timeRange) * size.width
            fillPath.addLine(to: CGPoint(x: lastX, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [
                        modeColor.opacity(Theme.Opacity.light),
                        modeColor.opacity(Theme.Opacity.transparent)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        .frame(height: height)
        .accessibilityLabel("Adaptation timeline showing beat frequency changes over the session")
    }

    private let chartStrokeWidth: CGFloat = Theme.Radius.legendStroke
}

// MARK: - FlowLayout

/// A simple wrapping horizontal layout for tag pills.
private struct FlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(subview.sizeThatFits(.unspecified))
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var totalSize: CGSize
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

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
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            totalSize: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}

// MARK: - Preview

#Preview("Saved Track Detail") {
    NavigationStack {
        SavedTrackDetailView(track: SavedTrack(
            sessionID: UUID(),
            name: "Morning Focus Flow",
            mode: FocusMode.focus.rawValue,
            durationSeconds: 1500,
            averageHeartRate: 68,
            beatFrequencyStart: 14,
            beatFrequencyEnd: 12,
            carrierFrequency: 375,
            ambientBedID: "rain_gentle",
            melodicLayerIDs: ["pad_warm", "piano_soft", "strings_ambient"],
            adaptationTimeline: BodyMusicRecorder.encodeTimeline([
                AdaptationSnapshot(timestamp: 0, beatFrequency: 14, carrierFrequency: 375, amplitude: 0.8, heartRate: 72),
                AdaptationSnapshot(timestamp: 60, beatFrequency: 13.5, carrierFrequency: 375, amplitude: 0.8, heartRate: 70),
                AdaptationSnapshot(timestamp: 180, beatFrequency: 13, carrierFrequency: 370, amplitude: 0.75, heartRate: 68),
                AdaptationSnapshot(timestamp: 360, beatFrequency: 12.5, carrierFrequency: 368, amplitude: 0.7, heartRate: 66),
                AdaptationSnapshot(timestamp: 600, beatFrequency: 12, carrierFrequency: 365, amplitude: 0.7, heartRate: 65),
                AdaptationSnapshot(timestamp: 900, beatFrequency: 12, carrierFrequency: 365, amplitude: 0.7, heartRate: 64),
                AdaptationSnapshot(timestamp: 1200, beatFrequency: 12.2, carrierFrequency: 367, amplitude: 0.72, heartRate: 66),
                AdaptationSnapshot(timestamp: 1500, beatFrequency: 12, carrierFrequency: 365, amplitude: 0.7, heartRate: 65)
            ]),
            playCount: 3,
            isFavorite: true
        ))
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SavedTrack.self, inMemory: true)
}

#Preview("Saved Track Detail — No Adaptation") {
    NavigationStack {
        SavedTrackDetailView(track: SavedTrack(
            sessionID: UUID(),
            name: "Quick Sleep Session",
            mode: FocusMode.sleep.rawValue,
            durationSeconds: 600,
            beatFrequencyStart: 6,
            beatFrequencyEnd: 3,
            carrierFrequency: 150,
            playCount: 0,
            isFavorite: false
        ))
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: SavedTrack.self, inMemory: true)
}
