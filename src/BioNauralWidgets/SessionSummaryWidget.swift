// SessionSummaryWidget.swift
// BioNauralWidgets
//
// Home screen widget providing quick-launch access to session modes and
// a summary of the most recent session. Uses AppIntents (iOS 17+) for
// interactive mode selection. Reads last session data from the shared
// SwiftData container via App Group.

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import BioNauralShared

// MARK: - App Intents

/// Intent to start a BioNaural session in a specific mode.
/// Used by interactive widget buttons to deep link into the app.
struct StartSessionIntent: AppIntent {

    static let title: LocalizedStringResource = "Start BioNaural Session"
    static let description: IntentDescription = "Starts a focus session in the selected mode."
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Mode")
    var mode: SessionModeParameter

    init() {
        self.mode = .focus
    }

    init(mode: SessionModeParameter) {
        self.mode = mode
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// Parameter type for session mode selection in AppIntents.
enum SessionModeParameter: String, AppEnum {
    case focus
    case relaxation
    case sleep
    case energize

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Session Mode"
    }

    static var caseDisplayRepresentations: [SessionModeParameter: DisplayRepresentation] {
        [
            .focus: "Focus",
            .relaxation: "Relaxation",
            .sleep: "Sleep",
            .energize: "Energize"
        ]
    }

    var displayName: String {
        switch self {
        case .focus:       return "Focus"
        case .relaxation:  return "Relax"
        case .sleep:       return "Sleep"
        case .energize:    return "Energize"
        }
    }

    var colorHex: UInt {
        switch self {
        case .focus:       return WidgetConstants.ModeHex.focus
        case .relaxation:  return WidgetConstants.ModeHex.relaxation
        case .sleep:       return WidgetConstants.ModeHex.sleep
        case .energize:    return WidgetConstants.ModeHex.energize
        }
    }

    var iconName: String {
        switch self {
        case .focus:       return "scope"
        case .relaxation:  return "wind"
        case .sleep:       return "moon.fill"
        case .energize:    return "bolt.fill"
        }
    }
}

// MARK: - Timeline Provider

struct SessionSummaryProvider: TimelineProvider {

    typealias Entry = SessionSummaryEntry

    func placeholder(in context: Context) -> SessionSummaryEntry {
        SessionSummaryEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionSummaryEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchLatestEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionSummaryEntry>) -> Void) {
        let entry = fetchLatestEntry()
        let refreshDate = Calendar.current.date(
            byAdding: .minute,
            value: WidgetConstants.Timeline.refreshIntervalMinutes,
            to: entry.date
        ) ?? entry.date
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchLatestEntry() -> SessionSummaryEntry {
        guard let container = sharedModelContainer() else {
            return SessionSummaryEntry(date: .now, lastSession: nil)
        }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let session = try? context.fetch(descriptor).first
        let summary: LastSessionSummary? = session.map { s in
            LastSessionSummary(
                modeName: s.mode,
                durationSeconds: s.durationSeconds,
                endDate: s.endDate ?? s.startDate
            )
        }

        return SessionSummaryEntry(date: .now, lastSession: summary)
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

// MARK: - Timeline Entry

struct SessionSummaryEntry: TimelineEntry {
    let date: Date
    let lastSession: LastSessionSummary?

    static var placeholder: SessionSummaryEntry {
        SessionSummaryEntry(
            date: .now,
            lastSession: LastSessionSummary(
                modeName: "focus",
                durationSeconds: 2895,
                endDate: Date(timeIntervalSinceNow: -3600)
            )
        )
    }
}

/// Lightweight summary of the most recent session for widget display.
struct LastSessionSummary {
    let modeName: String
    let durationSeconds: Int
    let endDate: Date

    var displayModeName: String {
        modeName.capitalized
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        if minutes < 1 { return "<1 min" }
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 { return "\(hours)h" }
            return "\(hours)h \(remaining)m"
        }
        return "\(minutes) min"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: .now)
    }

    var modeColorHex: UInt {
        switch modeName {
        case "focus":       return WidgetConstants.ModeHex.focus
        case "relaxation":  return WidgetConstants.ModeHex.relaxation
        case "sleep":       return WidgetConstants.ModeHex.sleep
        case "energize":    return WidgetConstants.ModeHex.energize
        default:            return WidgetConstants.ModeHex.accent
        }
    }

    var modeColor: Color {
        Color(hex: modeColorHex)
    }
}

// MARK: - Widget Definition

struct SessionSummaryWidget: Widget {

    let kind = "SessionSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: SessionSummaryProvider()
        ) { entry in
            SessionSummaryEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetConstants.Colors.canvas
                }
        }
        .configurationDisplayName("BioNaural")
        .description("Quick-launch sessions and view recent activity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry View

struct SessionSummaryEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: SessionSummaryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

/// Premium small widget: multi-layer orb with nebula-depth bloom,
/// ambient mode-color wash, and refined typography.
struct SmallWidgetView: View {

    let entry: SessionSummaryEntry

    private var modeColor: Color {
        entry.lastSession?.modeColor ?? Color(hex: WidgetConstants.ModeHex.accent)
    }

    var body: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            ZStack {
                // Layer 1: Ambient radial wash — nebula-style depth
                ambientWash

                // Layer 2: Multi-layer orb
                orbLayers
                    .offset(y: -WidgetConstants.Spacing.sm)

                // Layer 3: Content overlay
                VStack(spacing: 0) {
                    Spacer()

                    // App identity — small, tucked at bottom
                    VStack(spacing: WidgetConstants.Spacing.xxs) {
                        Text("BioNaural")
                            .font(WidgetConstants.Fonts.caption)
                            .foregroundStyle(WidgetConstants.Colors.textPrimary)

                        Text("TAP TO START")
                            .font(WidgetConstants.Fonts.small)
                            .foregroundStyle(WidgetConstants.Colors.textTertiary)
                            .tracking(WidgetConstants.Tracking.uppercase)
                    }
                    .padding(.bottom, WidgetConstants.Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start Focus session")
        .accessibilityHint("Opens BioNaural and starts a Focus session")
    }

    // MARK: - Ambient Wash

    /// Subtle radial mode-color gradient filling the background.
    private var ambientWash: some View {
        RadialGradient(
            colors: [
                modeColor.opacity(WidgetConstants.Opacity.light),
                modeColor.opacity(WidgetConstants.Opacity.minimal),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 90
        )
    }

    // MARK: - Orb Layers

    /// Four-layer orb: outer bloom → mid glow → core → hotspot.
    private var orbLayers: some View {
        ZStack {
            // Outer bloom — soft, expansive wash
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity(WidgetConstants.Opacity.accentLight),
                            modeColor.opacity(WidgetConstants.Opacity.subtle),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.SmallWidget.bloomRadius
                    )
                )
                .frame(
                    width: WidgetConstants.SmallWidget.bloomDiameter,
                    height: WidgetConstants.SmallWidget.bloomDiameter
                )

            // Mid glow — concentrated luminance
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity(WidgetConstants.Opacity.medium),
                            modeColor.opacity(WidgetConstants.Opacity.accentLight),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.SmallWidget.midGlowRadius
                    )
                )
                .frame(
                    width: WidgetConstants.SmallWidget.midGlowDiameter,
                    height: WidgetConstants.SmallWidget.midGlowDiameter
                )

            // Core — solid presence
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity(WidgetConstants.Opacity.accentStrong),
                            modeColor.opacity(WidgetConstants.Opacity.medium),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.SmallWidget.coreRadius
                    )
                )
                .frame(
                    width: WidgetConstants.SmallWidget.coreDiameter,
                    height: WidgetConstants.SmallWidget.coreDiameter
                )

            // Hotspot — bright center point
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(WidgetConstants.Opacity.accentStrong),
                            modeColor.opacity(WidgetConstants.Opacity.half),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.SmallWidget.hotspotDiameter / 2
                    )
                )
                .frame(
                    width: WidgetConstants.SmallWidget.hotspotDiameter,
                    height: WidgetConstants.SmallWidget.hotspotDiameter
                )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Medium Widget

/// Premium medium widget: glass-morphism mode pills with colored icon
/// containers, rich session summary with mini orb accent.
struct MediumWidgetView: View {

    let entry: SessionSummaryEntry

    private let modes: [SessionModeParameter] = [.focus, .relaxation, .sleep, .energize]

    private var accentColor: Color {
        entry.lastSession?.modeColor ?? Color(hex: WidgetConstants.ModeHex.accent)
    }

    var body: some View {
        ZStack {
            // Ambient background wash
            RadialGradient(
                colors: [
                    accentColor.opacity(WidgetConstants.Opacity.subtle),
                    Color.clear
                ],
                center: .leading,
                startRadius: 0,
                endRadius: 200
            )

            HStack(spacing: WidgetConstants.Spacing.lg) {
                // Left: mode pills
                modeColumn
                    .frame(maxWidth: .infinity)

                // Divider
                RoundedRectangle(cornerRadius: WidgetConstants.Radius.sm, style: .continuous)
                    .fill(WidgetConstants.Colors.textTertiary.opacity(WidgetConstants.Opacity.accentLight))
                    .frame(width: 0.5)
                    .padding(.vertical, WidgetConstants.Spacing.xs)

                // Right: session summary
                summaryColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, WidgetConstants.Spacing.md)
        }
    }

    // MARK: - Mode Column

    private var modeColumn: some View {
        VStack(spacing: WidgetConstants.Spacing.xs) {
            ForEach(modes, id: \.rawValue) { mode in
                Button(intent: StartSessionIntent(mode: mode)) {
                    modePill(mode)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(mode.displayName) session")
            }
        }
    }

    // MARK: - Mode Pill

    @ViewBuilder
    private func modePill(_ mode: SessionModeParameter) -> some View {
        let color = Color(hex: mode.colorHex)

        HStack(spacing: WidgetConstants.Spacing.sm) {
            // Colored icon container
            ZStack {
                RoundedRectangle(
                    cornerRadius: WidgetConstants.MediumWidget.pillIconRadius,
                    style: .continuous
                )
                .fill(color.opacity(WidgetConstants.Opacity.accentLight))

                Image(systemName: mode.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(
                width: WidgetConstants.MediumWidget.pillIconSize,
                height: WidgetConstants.MediumWidget.pillIconSize
            )

            Text(mode.displayName)
                .font(WidgetConstants.Fonts.caption)
                .foregroundStyle(WidgetConstants.Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.trailing, WidgetConstants.Spacing.sm)
        .padding(.vertical, WidgetConstants.Spacing.xxs)
        .padding(.leading, WidgetConstants.Spacing.xxs)
        .background(
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.lg,
                style: .continuous
            )
            .fill(WidgetConstants.Colors.surface.opacity(WidgetConstants.Opacity.accentStrong))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.lg,
                style: .continuous
            )
            .strokeBorder(
                color.opacity(WidgetConstants.Opacity.light),
                lineWidth: WidgetConstants.MediumWidget.pillBorderWidth
            )
        )
    }

    // MARK: - Summary Column

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: WidgetConstants.Spacing.sm) {
            if let session = entry.lastSession {
                // Header
                Text("LAST SESSION")
                    .font(WidgetConstants.Fonts.small)
                    .foregroundStyle(WidgetConstants.Colors.textTertiary)
                    .tracking(WidgetConstants.Tracking.uppercase)

                // Mini orb + mode name
                HStack(spacing: WidgetConstants.Spacing.sm) {
                    miniOrb(color: session.modeColor)

                    VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xxs) {
                        Text(session.displayModeName)
                            .font(WidgetConstants.Fonts.caption)
                            .foregroundStyle(WidgetConstants.Colors.textPrimary)

                        Text(session.timeAgo)
                            .font(WidgetConstants.Fonts.small)
                            .foregroundStyle(WidgetConstants.Colors.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                // Duration — large data readout
                Text(session.formattedDuration)
                    .font(WidgetConstants.Fonts.data)
                    .foregroundStyle(session.modeColor)
                    .monospacedDigit()
                    .tracking(WidgetConstants.Tracking.data)

            } else {
                Spacer()

                // Empty state — mini orb + prompt
                VStack(spacing: WidgetConstants.Spacing.sm) {
                    miniOrb(color: Color(hex: WidgetConstants.ModeHex.accent))

                    Text("No sessions yet")
                        .font(WidgetConstants.Fonts.caption)
                        .foregroundStyle(WidgetConstants.Colors.textTertiary)

                    Text("Tap a mode to begin")
                        .font(WidgetConstants.Fonts.small)
                        .foregroundStyle(WidgetConstants.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .padding(.vertical, WidgetConstants.Spacing.xxs)
    }

    // MARK: - Mini Orb

    /// Small two-layer orb accent for the summary section.
    private func miniOrb(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(WidgetConstants.Opacity.accentLight),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.MediumWidget.summaryOrbBloomSize / 2
                    )
                )
                .frame(
                    width: WidgetConstants.MediumWidget.summaryOrbBloomSize,
                    height: WidgetConstants.MediumWidget.summaryOrbBloomSize
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(WidgetConstants.Opacity.accentStrong),
                            color.opacity(WidgetConstants.Opacity.medium),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: WidgetConstants.MediumWidget.summaryOrbSize / 2
                    )
                )
                .frame(
                    width: WidgetConstants.MediumWidget.summaryOrbSize,
                    height: WidgetConstants.MediumWidget.summaryOrbSize
                )

            // Bright center
            Circle()
                .fill(.white.opacity(WidgetConstants.Opacity.half))
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SessionSummaryWidget()
} timeline: {
    SessionSummaryEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    SessionSummaryWidget()
} timeline: {
    SessionSummaryEntry.placeholder
}
