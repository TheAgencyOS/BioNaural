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
        // The app handles navigation via the URL scheme set by openAppWhenRun.
        // The mode parameter is read by the app's intent handler on launch.
        return .result()
    }
}

/// Parameter type for session mode selection in AppIntents.
enum SessionModeParameter: String, AppEnum {
    case focus
    case relaxation
    case sleep

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Session Mode"
    }

    static var caseDisplayRepresentations: [SessionModeParameter: DisplayRepresentation] {
        [
            .focus: "Focus",
            .relaxation: "Relaxation",
            .sleep: "Sleep"
        ]
    }

    var displayName: String {
        switch self {
        case .focus:       return "Focus"
        case .relaxation:  return "Relaxation"
        case .sleep:       return "Sleep"
        }
    }

    var colorHex: UInt {
        switch self {
        case .focus:       return WidgetConstants.ModeHex.focus
        case .relaxation:  return WidgetConstants.ModeHex.relaxation
        case .sleep:       return WidgetConstants.ModeHex.sleep
        }
    }

    var iconName: String {
        switch self {
        case .focus:       return "circle.circle.fill"
        case .relaxation:  return "wind"
        case .sleep:       return "moon.fill"
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
        // Refresh every 30 minutes to keep "time ago" label reasonably fresh.
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

    /// Creates a ModelContainer using the shared App Group container URL.
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
        default:            return WidgetConstants.ModeHex.accent
        }
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
                .containerBackground(
                    WidgetConstants.Colors.canvas,
                    for: .widget
                )
        }
        .configurationDisplayName("BioNaural")
        .description("Quick-launch sessions and view recent activity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry View (routes to size-specific layout)

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

/// Orb circle in mode color + "Start Focus" label. Tap to start session.
struct SmallWidgetView: View {

    let entry: SessionSummaryEntry

    var body: some View {
        Button(intent: StartSessionIntent(mode: .focus)) {
            VStack(spacing: WidgetConstants.Spacing.md) {
                Spacer()

                // Orb representation — radial gradient circle
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: WidgetConstants.ModeHex.focus)
                                        .opacity(WidgetConstants.Opacity.half),
                                    Color(hex: WidgetConstants.ModeHex.focus)
                                        .opacity(WidgetConstants.Opacity.accentLight),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: WidgetConstants.SmallWidget.orbRadius
                            )
                        )
                        .frame(
                            width: WidgetConstants.SmallWidget.orbDiameter,
                            height: WidgetConstants.SmallWidget.orbDiameter
                        )

                    // Core bright center
                    Circle()
                        .fill(
                            Color(hex: WidgetConstants.ModeHex.focus)
                                .opacity(WidgetConstants.Opacity.accentStrong)
                        )
                        .frame(
                            width: WidgetConstants.SmallWidget.orbCoreDiameter,
                            height: WidgetConstants.SmallWidget.orbCoreDiameter
                        )
                }
                .accessibilityHidden(true)

                Text("Start Focus")
                    .font(WidgetConstants.Fonts.caption)
                    .foregroundStyle(WidgetConstants.Colors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start Focus session")
        .accessibilityHint("Opens BioNaural and starts a Focus session")
    }
}

// MARK: - Medium Widget

/// Three mode pills + last session summary.
struct MediumWidgetView: View {

    let entry: SessionSummaryEntry

    private let modes: [SessionModeParameter] = [.focus, .relaxation, .sleep]

    var body: some View {
        HStack(spacing: WidgetConstants.Spacing.md) {
            // Left: mode pills
            VStack(spacing: WidgetConstants.Spacing.sm) {
                ForEach(modes, id: \.rawValue) { mode in
                    Button(intent: StartSessionIntent(mode: mode)) {
                        modePill(mode)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(mode.displayName) session")
                    .accessibilityHint("Opens BioNaural and starts a \(mode.displayName) session")
                }
            }
            .frame(maxWidth: .infinity)

            // Right: last session summary
            VStack(alignment: .leading, spacing: WidgetConstants.Spacing.xs) {
                Text("Last Session")
                    .font(WidgetConstants.Fonts.small)
                    .foregroundStyle(WidgetConstants.Colors.textTertiary)
                    .textCase(.uppercase)

                if let session = entry.lastSession {
                    HStack(spacing: WidgetConstants.Spacing.xxs) {
                        Circle()
                            .fill(Color(hex: session.modeColorHex))
                            .frame(
                                width: WidgetConstants.MediumWidget.sessionDotSize,
                                height: WidgetConstants.MediumWidget.sessionDotSize
                            )

                        Text(session.displayModeName)
                            .font(WidgetConstants.Fonts.caption)
                            .foregroundStyle(WidgetConstants.Colors.textPrimary)
                    }

                    Text(session.formattedDuration)
                        .font(WidgetConstants.Fonts.data)
                        .foregroundStyle(WidgetConstants.Colors.textPrimary)
                        .monospacedDigit()

                    Text(session.timeAgo)
                        .font(WidgetConstants.Fonts.small)
                        .foregroundStyle(WidgetConstants.Colors.textTertiary)
                } else {
                    Text("No sessions yet")
                        .font(WidgetConstants.Fonts.caption)
                        .foregroundStyle(WidgetConstants.Colors.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WidgetConstants.Spacing.xs)
        }
        .padding(.horizontal, WidgetConstants.Spacing.sm)
    }

    // MARK: - Mode Pill

    @ViewBuilder
    private func modePill(_ mode: SessionModeParameter) -> some View {
        HStack(spacing: WidgetConstants.Spacing.sm) {
            Image(systemName: mode.iconName)
                .font(WidgetConstants.Fonts.dataSmall)
                .foregroundStyle(Color(hex: mode.colorHex))
                .accessibilityHidden(true)

            Text(mode.displayName)
                .font(WidgetConstants.Fonts.caption)
                .foregroundStyle(WidgetConstants.Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WidgetConstants.Spacing.md)
        .padding(.vertical, WidgetConstants.Spacing.sm)
        .background(
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.lg,
                style: .continuous
            )
            .fill(WidgetConstants.Colors.surface)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WidgetConstants.Radius.lg,
                style: .continuous
            )
            .strokeBorder(
                Color(hex: mode.colorHex)
                    .opacity(WidgetConstants.Opacity.accentLight),
                lineWidth: WidgetConstants.MediumWidget.pillBorderWidth
            )
        )
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
