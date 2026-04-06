// StandByWidget.swift
// BioNauralWidgets
//
// StandBy-optimized widget for the always-on bedside display.
// Dramatic multi-layer orb with nebula-depth bloom, decorative
// wavelength accent, and premium typography. Dark background
// optimized for OLED StandBy mode.

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import BioNauralShared

// MARK: - StandBy Timeline Provider

struct StandByProvider: TimelineProvider {

    typealias Entry = StandByEntry

    func placeholder(in context: Context) -> StandByEntry {
        StandByEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StandByEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandByEntry>) -> Void) {
        let entry = fetchEntry()
        let refreshDate = Calendar.current.date(
            byAdding: .minute,
            value: WidgetConstants.Timeline.refreshIntervalMinutes,
            to: entry.date
        ) ?? entry.date
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchEntry() -> StandByEntry {
        guard let container = sharedModelContainer() else {
            return StandByEntry(date: .now, lastSessionEndDate: nil, lastModeName: nil)
        }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let session = try? context.fetch(descriptor).first
        return StandByEntry(
            date: .now,
            lastSessionEndDate: session?.endDate ?? session?.startDate,
            lastModeName: session?.mode
        )
    }

    private func sharedModelContainer() -> ModelContainer? {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetConstants.appGroupIdentifier)?
            .appending(path: WidgetConstants.sharedStoreName)
        else {
            return nil
        }

        let schema = Schema([FocusSession.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: false
        )

        return try? ModelContainer(for: schema, configurations: [configuration])
    }
}

// MARK: - StandBy Entry

struct StandByEntry: TimelineEntry {
    let date: Date
    let lastSessionEndDate: Date?
    let lastModeName: String?

    var lastSessionTimeAgo: String? {
        guard let endDate = lastSessionEndDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: .now)
    }

    var modeColor: Color {
        switch lastModeName {
        case "focus":       return Color(hex: WidgetConstants.ModeHex.focus)
        case "relaxation":  return Color(hex: WidgetConstants.ModeHex.relaxation)
        case "sleep":       return Color(hex: WidgetConstants.ModeHex.sleep)
        case "energize":    return Color(hex: WidgetConstants.ModeHex.energize)
        default:            return Color(hex: WidgetConstants.ModeHex.accent)
        }
    }

    static var placeholder: StandByEntry {
        StandByEntry(
            date: .now,
            lastSessionEndDate: Date(timeIntervalSinceNow: -7200),
            lastModeName: "focus"
        )
    }
}

// MARK: - StandBy Widget Definition

struct StandByWidget: Widget {

    let kind = "StandByWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: StandByProvider()
        ) { entry in
            StandByWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetConstants.Colors.canvas
                }
        }
        .configurationDisplayName("BioNaural StandBy")
        .description("Start a session from StandBy mode.")
        .supportedFamilies(standByFamilies)
    }

    private var standByFamilies: [WidgetFamily] {
        [.systemLarge]
    }
}

// MARK: - StandBy Widget View

struct StandByWidgetView: View {

    let entry: StandByEntry

    var body: some View {
        standByLargeView
    }

    // MARK: - Large StandBy Layout

    /// Full StandBy-optimized view: dramatic multi-layer orb with nebula
    /// bloom, decorative wavelength, and premium typography.
    private var standByLargeView: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            ZStack {
                // Layer 1: Deep ambient wash — nebula-style canvas tint
                nebulaWash

                // Layer 2: Multi-layer orb — the hero element
                orbStack
                    .offset(y: -WidgetConstants.Spacing.xxl)

                // Layer 3: Content overlay
                VStack(spacing: 0) {
                    Spacer()

                    // Decorative wavelength accent
                    wavelengthAccent
                        .padding(.bottom, WidgetConstants.Spacing.xl)

                    // Start label — elegant uppercase
                    Text("START")
                        .font(WidgetConstants.Fonts.title)
                        .foregroundStyle(WidgetConstants.Colors.textPrimary)
                        .tracking(WidgetConstants.Tracking.uppercase * 2)

                    // Mode hint
                    if let modeName = entry.lastModeName {
                        Text(modeName.capitalized)
                            .font(WidgetConstants.Fonts.caption)
                            .foregroundStyle(entry.modeColor.opacity(WidgetConstants.Opacity.textSecondary))
                            .tracking(WidgetConstants.Tracking.uppercase)
                            .textCase(.uppercase)
                            .padding(.top, WidgetConstants.Spacing.xxs)
                    }

                    // Last session time ago
                    if let timeAgo = entry.lastSessionTimeAgo {
                        Text("Last session \(timeAgo)")
                            .font(WidgetConstants.Fonts.small)
                            .foregroundStyle(WidgetConstants.Colors.textTertiary)
                            .padding(.top, WidgetConstants.Spacing.sm)
                    }

                    Spacer()
                        .frame(height: WidgetConstants.Spacing.xxl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nebula Wash

    /// Multi-layer radial gradient creating deep-space depth on the canvas.
    private var nebulaWash: some View {
        ZStack {
            // Deep layer — large, soft, off-center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.modeColor.opacity(WidgetConstants.Nebula.deepOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.Nebula.deepSize / 2
                    )
                )
                .frame(
                    width: WidgetConstants.Nebula.deepSize,
                    height: WidgetConstants.Nebula.deepSize
                )
                .blur(radius: WidgetConstants.Nebula.deepBlur)
                .offset(y: -WidgetConstants.Spacing.xxxl)

            // Mid layer — secondary color offset
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: WidgetConstants.ModeHex.accent)
                                .opacity(WidgetConstants.Nebula.midOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.Nebula.midSize / 2
                    )
                )
                .frame(
                    width: WidgetConstants.Nebula.midSize,
                    height: WidgetConstants.Nebula.midSize
                )
                .blur(radius: WidgetConstants.Nebula.midBlur)
                .offset(
                    x: WidgetConstants.Spacing.xxl,
                    y: -WidgetConstants.Spacing.jumbo
                )
        }
    }

    // MARK: - Orb Stack

    /// Five-layer orb: ambient wash → outer bloom → mid glow → core → hotspot.
    private var orbStack: some View {
        ZStack {
            // Ambient wash — barely perceptible, very large
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.modeColor.opacity(WidgetConstants.Opacity.subtle),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.StandBy.ambientWashRadius
                    )
                )
                .frame(
                    width: WidgetConstants.StandBy.ambientWashDiameter,
                    height: WidgetConstants.StandBy.ambientWashDiameter
                )

            // Outer bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.modeColor.opacity(WidgetConstants.Opacity.light),
                            entry.modeColor.opacity(WidgetConstants.Opacity.subtle),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.StandBy.outerBloomRadius
                    )
                )
                .frame(
                    width: WidgetConstants.StandBy.outerBloomDiameter,
                    height: WidgetConstants.StandBy.outerBloomDiameter
                )

            // Mid bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.modeColor.opacity(WidgetConstants.Opacity.medium),
                            entry.modeColor.opacity(WidgetConstants.Opacity.accentLight),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.StandBy.midBloomRadius
                    )
                )
                .frame(
                    width: WidgetConstants.StandBy.midBloomDiameter,
                    height: WidgetConstants.StandBy.midBloomDiameter
                )

            // Core orb — solid presence
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.modeColor.opacity(WidgetConstants.Opacity.accentStrong),
                            entry.modeColor.opacity(WidgetConstants.Opacity.medium),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.StandBy.coreOrbRadius
                    )
                )
                .frame(
                    width: WidgetConstants.StandBy.coreOrbDiameter,
                    height: WidgetConstants.StandBy.coreOrbDiameter
                )

            // Hotspot — bright white center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(WidgetConstants.Opacity.accentStrong),
                            entry.modeColor.opacity(WidgetConstants.Opacity.half),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.StandBy.hotspotDiameter / 2
                    )
                )
                .frame(
                    width: WidgetConstants.StandBy.hotspotDiameter,
                    height: WidgetConstants.StandBy.hotspotDiameter
                )
        }
        .accessibilityHidden(true)
    }

    // MARK: - Wavelength Accent

    /// Decorative sine-wave line in mode color, centered beneath the orb.
    private var wavelengthAccent: some View {
        GeometryReader { geo in
            let inset = WidgetConstants.StandBy.wavelengthInset
            let width = geo.size.width - inset * 2

            WidgetConstants.wavelengthPath(
                width: width,
                height: WidgetConstants.StandBy.wavelengthHeight,
                cycles: 2.5
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        entry.modeColor.opacity(WidgetConstants.StandBy.wavelengthOpacity),
                        entry.modeColor.opacity(WidgetConstants.StandBy.wavelengthOpacity),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: WidgetConstants.StandBy.wavelengthStroke
            )
            .offset(x: inset)
        }
        .frame(height: WidgetConstants.StandBy.wavelengthHeight)
    }

}

// MARK: - Previews

#Preview("StandBy Large", as: .systemLarge) {
    StandByWidget()
} timeline: {
    StandByEntry.placeholder
}

