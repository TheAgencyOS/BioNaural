// LockScreenWidget.swift
// BioNauralWidgets
//
// Lock Screen widgets for all three accessory families.
// Circular: miniature orb with multi-layer bloom — the app's signature visual.
// Rectangular: orb + last session info or quick-launch prompt.
// Inline: mode icon + session status text.
// All tap to launch the app into a Focus session.

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import BioNauralShared

// MARK: - Lock Screen Timeline Provider

struct LockScreenProvider: TimelineProvider {

    typealias Entry = LockScreenEntry

    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
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

    private func fetchEntry() -> LockScreenEntry {
        guard let container = sharedModelContainer() else {
            return LockScreenEntry(date: .now, lastSession: nil)
        }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let session = try? context.fetch(descriptor).first
        let summary: LockScreenSessionSummary? = session.map { s in
            LockScreenSessionSummary(
                modeName: s.mode,
                durationSeconds: s.durationSeconds,
                endDate: s.endDate ?? s.startDate
            )
        }

        return LockScreenEntry(date: .now, lastSession: summary)
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

// MARK: - Lock Screen Entry

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let lastSession: LockScreenSessionSummary?

    static var placeholder: LockScreenEntry {
        LockScreenEntry(
            date: .now,
            lastSession: LockScreenSessionSummary(
                modeName: "focus",
                durationSeconds: 2895,
                endDate: Date(timeIntervalSinceNow: -3600)
            )
        )
    }
}

struct LockScreenSessionSummary {
    let modeName: String
    let durationSeconds: Int
    let endDate: Date

    var displayModeName: String {
        modeName.capitalized
    }

    var shortModeName: String {
        switch modeName {
        case "relaxation": return "Relax"
        default: return modeName.capitalized
        }
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        if minutes < 1 { return "<1m" }
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 { return "\(hours)h" }
            return "\(hours)h\(remaining)m"
        }
        return "\(minutes)m"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: .now)
    }

    var modeIconName: String {
        switch modeName {
        case "focus":       return "scope"
        case "relaxation":  return "wind"
        case "sleep":       return "moon.fill"
        case "energize":    return "bolt.fill"
        default:            return "scope"
        }
    }
}

// MARK: - Widget Definition

struct LockScreenWidget: Widget {

    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LockScreenProvider()
        ) { entry in
            LockScreenEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("BioNaural")
        .description("Quick access to BioNaural from your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Entry View Router

struct LockScreenEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: LockScreenEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            CircularView(entry: entry)
        }
    }
}

// MARK: - Accessory Circular

/// Miniature multi-layer orb — the app's visual signature on the Lock Screen.
/// Three concentric rings: outer bloom, core glow, bright center point.
struct CircularView: View {

    let entry: LockScreenEntry

    var body: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            ZStack {
                // Outer bloom ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(WidgetConstants.LockScreenAccessory.outerRingOpacity),
                                .white.opacity(WidgetConstants.LockScreenAccessory.outerRingOpacity * 0.3),
                                .white.opacity(WidgetConstants.LockScreenAccessory.outerRingOpacity)
                            ],
                            center: .center
                        ),
                        lineWidth: WidgetConstants.LockScreenAccessory.outerRingStroke
                    )
                    .frame(
                        width: WidgetConstants.LockScreenAccessory.outerRingDiameter,
                        height: WidgetConstants.LockScreenAccessory.outerRingDiameter
                    )

                // Mid glow — radial gradient fill
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(WidgetConstants.LockScreenAccessory.midGlowOpacity),
                                .white.opacity(WidgetConstants.LockScreenAccessory.midGlowOpacity * 0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: WidgetConstants.LockScreenAccessory.midGlowDiameter / 2
                        )
                    )
                    .frame(
                        width: WidgetConstants.LockScreenAccessory.midGlowDiameter,
                        height: WidgetConstants.LockScreenAccessory.midGlowDiameter
                    )

                // Core — solid bright circle
                Circle()
                    .fill(.white.opacity(WidgetConstants.LockScreenAccessory.coreOpacity))
                    .frame(
                        width: WidgetConstants.LockScreenAccessory.coreDiameter,
                        height: WidgetConstants.LockScreenAccessory.coreDiameter
                    )

                // Hotspot — bright center point
                Circle()
                    .fill(.white.opacity(WidgetConstants.LockScreenAccessory.hotspotOpacity))
                    .frame(
                        width: WidgetConstants.LockScreenAccessory.hotspotDiameter,
                        height: WidgetConstants.LockScreenAccessory.hotspotDiameter
                    )
            }
        }
        .buttonStyle(.plain)
        .widgetAccentable()
        .accessibilityLabel("Start BioNaural Focus session")
    }
}

// MARK: - Accessory Rectangular

/// Orb + session info or launch prompt. Two-column layout with
/// mini orb on the left and text hierarchy on the right.
struct RectangularView: View {

    let entry: LockScreenEntry

    var body: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            HStack(spacing: WidgetConstants.Spacing.sm) {
                // Mini orb with bloom
                ZStack {
                    // Bloom halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(WidgetConstants.LockScreenAccessory.rectOrbBloomOpacity),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: WidgetConstants.LockScreenAccessory.rectOrbBloomSize / 2
                            )
                        )
                        .frame(
                            width: WidgetConstants.LockScreenAccessory.rectOrbBloomSize,
                            height: WidgetConstants.LockScreenAccessory.rectOrbBloomSize
                        )

                    // Core orb
                    Circle()
                        .fill(.white.opacity(WidgetConstants.LockScreenAccessory.rectOrbCoreOpacity))
                        .frame(
                            width: WidgetConstants.LockScreenAccessory.rectOrbSize,
                            height: WidgetConstants.LockScreenAccessory.rectOrbSize
                        )

                    // Hotspot
                    Circle()
                        .fill(.white.opacity(WidgetConstants.LockScreenAccessory.hotspotOpacity))
                        .frame(width: 3, height: 3)
                }
                .frame(
                    width: WidgetConstants.LockScreenAccessory.rectOrbBloomSize,
                    height: WidgetConstants.LockScreenAccessory.rectOrbBloomSize
                )

                // Text column
                VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xxs) {
                    Text("BioNaural")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .widgetAccentable()

                    if let session = entry.lastSession {
                        HStack(spacing: WidgetConstants.Spacing.xxs) {
                            Image(systemName: session.modeIconName)
                                .font(.system(size: 10, weight: .semibold))

                            Text("\(session.shortModeName) · \(session.formattedDuration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(session.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Tap to start a session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open BioNaural")
    }
}

// MARK: - Accessory Inline

/// Single-line: mode icon + status text. Compact and informative.
struct InlineView: View {

    let entry: LockScreenEntry

    var body: some View {
        if let session = entry.lastSession {
            Label {
                Text("\(session.shortModeName) · \(session.formattedDuration) \(session.timeAgo)")
            } icon: {
                Image(systemName: session.modeIconName)
            }
            .accessibilityLabel("Last BioNaural session: \(session.displayModeName), \(session.formattedDuration)")
        } else {
            Label {
                Text("BioNaural — Start a session")
            } icon: {
                Image(systemName: "scope")
            }
        }
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    LockScreenWidget()
} timeline: {
    LockScreenEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    LockScreenEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    LockScreenWidget()
} timeline: {
    LockScreenEntry.placeholder
}
