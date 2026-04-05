// StandByWidget.swift
// BioNauralWidgets
//
// StandBy-optimized widget for the always-on bedside display.
// Large, glanceable layout with the Orb, a start label, and
// last session time. Dark background optimized for OLED StandBy mode.

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

    var lastModeColorHex: UInt {
        switch lastModeName {
        case "focus":       return WidgetConstants.ModeHex.focus
        case "relaxation":  return WidgetConstants.ModeHex.relaxation
        case "sleep":       return WidgetConstants.ModeHex.sleep
        default:            return WidgetConstants.ModeHex.accent
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
                .containerBackground(
                    WidgetConstants.Colors.canvas,
                    for: .widget
                )
        }
        .configurationDisplayName("BioNaural StandBy")
        .description("Start a session from StandBy mode.")
        .supportedFamilies(standByFamilies)
    }

    /// Supported widget families including StandBy-appropriate sizes.
    /// `.accessoryRectangular` is used for Smart Stack / StandBy contexts.
    /// `.systemLarge` provides the full StandBy-optimized layout.
    private var standByFamilies: [WidgetFamily] {
        [.systemLarge, .accessoryRectangular]
    }
}

// MARK: - StandBy Widget View

struct StandByWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: StandByEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            standByLargeView
        }
    }

    // MARK: - Large StandBy Layout

    /// Full StandBy-optimized view: Orb + Start label + last session.
    /// Dark background for OLED efficiency.
    private var standByLargeView: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            VStack(spacing: WidgetConstants.Spacing.xxl) {
                Spacer()

                // Large Orb representation
                ZStack {
                    // Outer bloom
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    orbColor
                                        .opacity(WidgetConstants.Opacity.subtle),
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
                                    orbColor
                                        .opacity(WidgetConstants.Opacity.accentLight),
                                    orbColor
                                        .opacity(WidgetConstants.Opacity.subtle),
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

                    // Core orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    orbColor
                                        .opacity(WidgetConstants.Opacity.accentStrong),
                                    orbColor
                                        .opacity(WidgetConstants.Opacity.medium),
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
                }

                // "Start" label
                Text("Start")
                    .font(WidgetConstants.Fonts.headline)
                    .foregroundStyle(WidgetConstants.Colors.textPrimary)
                    .tracking(WidgetConstants.Tracking.uppercase)
                    .textCase(.uppercase)

                // Last session time ago
                if let timeAgo = entry.lastSessionTimeAgo {
                    Text("Last session \(timeAgo)")
                        .font(WidgetConstants.Fonts.small)
                        .foregroundStyle(WidgetConstants.Colors.textTertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Accessory Rectangular (Smart Stack / StandBy secondary)

    private var accessoryRectangularView: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            HStack(spacing: WidgetConstants.Spacing.sm) {
                Circle()
                    .fill(orbColor)
                    .frame(
                        width: WidgetConstants.StandBy.accessoryOrbSize,
                        height: WidgetConstants.StandBy.accessoryOrbSize
                    )

                VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xxs) {
                    Text("BioNaural")
                        .font(WidgetConstants.Fonts.caption)
                        .fontWeight(.medium)

                    if let timeAgo = entry.lastSessionTimeAgo {
                        Text(timeAgo)
                            .font(WidgetConstants.Fonts.small)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Start session")
                            .font(WidgetConstants.Fonts.small)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var orbColor: Color {
        Color(hex: entry.lastModeColorHex)
    }
}

// MARK: - Previews

#Preview("StandBy Large", as: .systemLarge) {
    StandByWidget()
} timeline: {
    StandByEntry.placeholder
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    StandByWidget()
} timeline: {
    StandByEntry.placeholder
}
