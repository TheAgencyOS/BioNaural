// MorningBriefGenerator.swift
// BioNaural
//
// Aggregates HealthKit, Calendar, and UserModel data to produce a
// personalized morning brief card. All processing on-device.
// Actor-based for thread safety.

import Foundation
import BioNauralShared

// MARK: - MorningBrief

public struct MorningBrief: Codable, Sendable, Identifiable {
    public let id: UUID
    public let generatedAt: Date

    // Health context
    public let sleepHours: Double?
    public let sleepQuality: String?       // "good", "fair", "poor"
    public let restingHRDelta: Double?     // +/- from 7-day average
    public let hrvTrend: String?           // "rising", "stable", "declining"

    // Calendar context
    public let upcomingStressors: [BriefStressor]
    public let meetingCount: Int
    public let firstFreeWindow: DateInterval?

    // Recommendation
    public let suggestedMode: FocusMode
    public let suggestedDurationMinutes: Int
    public let suggestedAmbientTag: String?
    public let suggestedCarrierFrequency: Double?
    public let contextTrackID: UUID?       // if a study/context track is relevant

    // Copy
    public let greeting: String
    public let bodyText: String
    public let prescriptionText: String
    public let confidence: Double          // 0-1

    // Day pattern
    public let dayOfWeekPattern: String?   // e.g. "Historically your hardest focus day"
}

// MARK: - BriefStressor

public struct BriefStressor: Codable, Sendable, Identifiable {
    public let id: String
    public let eventTitle: String
    public let startDate: Date
    public let stressLevel: String         // StressLevel rawValue
    public let prepReady: Bool             // whether a context track exists for this
}

// MARK: - BriefConfig

/// All thresholds for morning brief generation. No hardcoded values.
public enum BriefConfig {
    static let poorSleepThreshold: Double = 6.0
    static let fairSleepThreshold: Double = 7.0
    static let elevatedHRDeltaThreshold: Double = 3.0
    static let decliningHRVThreshold: Double = -5.0
    static let risingHRVThreshold: Double = 5.0
    static let highMeetingDayThreshold: Int = 4
    static let calendarLookaheadHours: Int = 14
    static let defaultGreetingHour: Int = 6
    static let eveningGreetingHour: Int = 17
    static let minimumSessionMinutes: Int = 8
    static let maximumSessionMinutes: Int = 25
}

// MARK: - Protocol

/// Generation interface for producing personalized morning brief cards
/// from aggregated health, calendar, and user-model data.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
public protocol MorningBriefGeneratorProtocol: AnyObject, Sendable {

    /// Generates a complete morning brief by pulling all data sources
    /// and synthesizing a personalized card.
    func generateBrief() async -> MorningBrief
}

// MARK: - MorningBriefGenerator

/// Aggregates all data sources to produce a personalized morning brief.
///
/// Dependencies are injected via init for testability. The generator pulls
/// HealthKit data, classifies calendar events, fetches session recommendations,
/// and synthesizes everything into a single `MorningBrief` card.
public actor MorningBriefGenerator: MorningBriefGeneratorProtocol {

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol
    private let calendarService: CalendarServiceProtocol
    private let calendarClassifier: CalendarEventClassifier
    private let userModelBuilder: UserModelBuilder?

    // MARK: - Init

    public init(
        healthKitService: HealthKitServiceProtocol,
        calendarService: CalendarServiceProtocol,
        calendarClassifier: CalendarEventClassifier,
        userModelBuilder: UserModelBuilder?
    ) {
        self.healthKitService = healthKitService
        self.calendarService = calendarService
        self.calendarClassifier = calendarClassifier
        self.userModelBuilder = userModelBuilder
    }

    // MARK: - Public API

    /// Generates a complete morning brief by pulling all data sources
    /// and synthesizing a personalized card.
    public func generateBrief() async -> MorningBrief {
        let now = Date()

        // 1. Pull HealthKit data in parallel.
        async let sleepData = healthKitService.lastNightSleep()
        async let latestHR = healthKitService.latestRestingHR()
        async let averageHR = healthKitService.averageRestingHR(days: 7)
        async let latestHRV = healthKitService.latestHRV()
        async let averageHRV = healthKitService.averageHRV(days: 7)

        let sleep = await sleepData
        let currentHR = await latestHR
        let avgHR = await averageHR
        let currentHRV = await latestHRV
        let avgHRV = await averageHRV

        // 2. Pull today's calendar events and classify them.
        let todayEvents = await calendarService.todaysEvents()
        let classifiedEvents = await calendarClassifier.classifyBatch(todayEvents)
        let stressors = await calendarClassifier.upcomingStressors(
            from: todayEvents,
            within: BriefConfig.calendarLookaheadHours
        )

        // 3. Get session recommendation from UserModelBuilder.
        let recommendation = await userModelBuilder?.sessionRecommendation()
            ?? SessionRecommendation(
                suggestedMode: .focus,
                suggestedDuration: 1500,
                moodPrediction: nil,
                soundPreferenceOverrides: [:],
                reasoning: "Default recommendation (no user model available)",
                confidence: 0.0
            )

        // 4. Synthesize all signals.

        // (a) Greeting based on time of day.
        let greeting = buildGreeting(at: now)

        // (b) Sleep quality.
        let sleepHours = sleep?.hours
        let sleepQuality = determineSleepQuality(hours: sleepHours)

        // (c) HR trend (delta from 7-day average).
        let hrDelta = computeHRDelta(current: currentHR, average: avgHR)

        // (d) HRV trend.
        let hrvTrendLabel = determineHRVTrend(current: currentHRV, average: avgHRV)

        // (e) Upcoming stressors as BriefStressor values.
        let briefStressors = stressors.map { event in
            BriefStressor(
                id: event.id,
                eventTitle: event.title,
                startDate: event.startDate,
                stressLevel: event.stressLevel.rawValue,
                prepReady: false // context track lookup below may override
            )
        }

        // (f) First free window.
        let freeWindow = await calendarService.nextFreeWindow(
            minimumMinutes: BriefConfig.minimumSessionMinutes
        )

        // (g) Meeting count (non-all-day, non-BioNaural events).
        let meetingCount = todayEvents.filter { !$0.isAllDay && !$0.isBioNauralSession }.count

        // (h) Suggested mode and duration from recommendation.
        let suggestedMode = recommendation.suggestedMode
        let rawDurationMinutes = Int(recommendation.suggestedDuration / 60)
        let suggestedDuration = clampDuration(rawDurationMinutes)

        // (i) Ambient tag from sound preference overrides (highest-weighted tag).
        let suggestedAmbientTag = recommendation.soundPreferenceOverrides
            .max(by: { $0.value < $1.value })?.key

        // (j) Carrier frequency from suggested mode defaults.
        let suggestedCarrier = suggestedMode.defaultCarrierFrequency

        // (k) Context track matching — check stressors for keyword matches.
        // This is a placeholder for future ContextTrack store integration.
        let contextTrackID: UUID? = nil

        // (l) Body text combining health + calendar context.
        let bodyText = buildBodyText(
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            hrDelta: hrDelta,
            hrvTrend: hrvTrendLabel,
            meetingCount: meetingCount,
            stressors: briefStressors,
            freeWindow: freeWindow,
            suggestedMode: suggestedMode
        )

        // (m) Prescription text.
        let prescriptionText = buildPrescriptionText(
            mode: suggestedMode,
            durationMinutes: suggestedDuration,
            ambientTag: suggestedAmbientTag
        )

        // (n) Confidence from data availability.
        let confidence = computeConfidence(
            sleepHours: sleepHours,
            hrDelta: hrDelta,
            hrvTrend: hrvTrendLabel,
            meetingCount: meetingCount,
            recommendationConfidence: recommendation.confidence
        )

        // (o) Day-of-week pattern.
        let dayPattern = buildDayOfWeekPattern(at: now)

        return MorningBrief(
            id: UUID(),
            generatedAt: now,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            restingHRDelta: hrDelta,
            hrvTrend: hrvTrendLabel,
            upcomingStressors: briefStressors,
            meetingCount: meetingCount,
            firstFreeWindow: freeWindow,
            suggestedMode: suggestedMode,
            suggestedDurationMinutes: suggestedDuration,
            suggestedAmbientTag: suggestedAmbientTag,
            suggestedCarrierFrequency: suggestedCarrier,
            contextTrackID: contextTrackID,
            greeting: greeting,
            bodyText: bodyText,
            prescriptionText: prescriptionText,
            confidence: confidence,
            dayOfWeekPattern: dayPattern
        )
    }

    // MARK: - Greeting

    private func buildGreeting(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < BriefConfig.defaultGreetingHour {
            return "Good evening"
        } else if hour < 12 {
            return "Good morning"
        } else if hour < BriefConfig.eveningGreetingHour {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    // MARK: - Sleep Quality

    private func determineSleepQuality(hours: Double?) -> String? {
        guard let hours else { return nil }
        if hours < BriefConfig.poorSleepThreshold {
            return "poor"
        } else if hours < BriefConfig.fairSleepThreshold {
            return "fair"
        } else {
            return "good"
        }
    }

    // MARK: - HR Delta

    private func computeHRDelta(current: Double?, average: Double?) -> Double? {
        guard let current, let average else { return nil }
        return current - average
    }

    // MARK: - HRV Trend

    private func determineHRVTrend(current: Double?, average: Double?) -> String? {
        guard let current, let average else { return nil }
        let delta = current - average
        if delta >= BriefConfig.risingHRVThreshold {
            return "rising"
        } else if delta <= BriefConfig.decliningHRVThreshold {
            return "declining"
        } else {
            return "stable"
        }
    }

    // MARK: - Duration Clamping

    private func clampDuration(_ minutes: Int) -> Int {
        min(max(minutes, BriefConfig.minimumSessionMinutes), BriefConfig.maximumSessionMinutes)
    }

    // MARK: - Body Text

    private func buildBodyText(
        sleepHours: Double?,
        sleepQuality: String?,
        hrDelta: Double?,
        hrvTrend: String?,
        meetingCount: Int,
        stressors: [BriefStressor],
        freeWindow: DateInterval?,
        suggestedMode: FocusMode
    ) -> String {
        var sentences: [String] = []

        // Sleep context sentence.
        if let hours = sleepHours, let quality = sleepQuality {
            let hoursFormatted = String(format: "%.1f", hours)
            switch quality {
            case "poor":
                var sleepSentence = "Rough night — \(hoursFormatted) hrs"
                if let delta = hrDelta, delta > BriefConfig.elevatedHRDeltaThreshold {
                    sleepSentence += ", and your resting HR is elevated"
                }
                sleepSentence += "."
                sentences.append(sleepSentence)
            case "fair":
                sentences.append("Decent sleep at \(hoursFormatted) hrs, but not your best.")
            case "good":
                var goodSentence = "Solid sleep at \(hoursFormatted) hrs"
                if hrvTrend == "rising" {
                    goodSentence += ", HRV trending up"
                }
                goodSentence += "."
                sentences.append(goodSentence)
            default:
                break
            }
        }

        // HRV-only sentence if no sleep context was added but HRV data exists.
        if sleepHours == nil, let trend = hrvTrend {
            switch trend {
            case "declining":
                sentences.append("Your HRV is trending down — consider a lighter start.")
            case "rising":
                sentences.append("HRV is on the rise. Your body is recovering well.")
            default:
                break
            }
        }

        // HR delta sentence (only if not already covered in sleep sentence).
        if sleepQuality != "poor", let delta = hrDelta, delta > BriefConfig.elevatedHRDeltaThreshold {
            sentences.append("Resting HR is \(String(format: "+%.0f", delta)) BPM above your average.")
        }

        // Calendar context sentence.
        if meetingCount >= BriefConfig.highMeetingDayThreshold {
            if let window = freeWindow {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let windowTime = formatter.string(from: window.start)
                sentences.append(
                    "\(meetingCount) meetings today. Save deep work for the \(windowTime) gap."
                )
            } else {
                sentences.append(
                    "\(meetingCount) meetings packed in. Squeeze in short sessions between blocks."
                )
            }
        } else if !stressors.isEmpty {
            let first = stressors[0]
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let time = formatter.string(from: first.startDate)
            if first.stressLevel == StressLevel.critical.rawValue
                || first.stressLevel == StressLevel.high.rawValue {
                sentences.append("\(first.eventTitle) at \(time). Prep with a session beforehand.")
            }
        }

        // Mode suggestion if we still have room.
        if sentences.count < 3 {
            switch suggestedMode {
            case .focus:
                if sleepQuality == "good" || sleepQuality == nil {
                    sentences.append("You're primed for a long Focus session.")
                } else {
                    sentences.append("Start with Relaxation before your first deep work block.")
                }
            case .relaxation:
                sentences.append("A Relaxation session will help reset before the day ramps up.")
            case .sleep:
                sentences.append("Wind-down mode — your body is signaling it needs rest.")
            case .energize:
                sentences.append("An Energize session could sharpen your start today.")
            }
        }

        // Cap at 3 sentences. Calm, direct, no exclamation marks.
        let capped = Array(sentences.prefix(3))
        return capped.joined(separator: " ")
    }

    // MARK: - Prescription Text

    private func buildPrescriptionText(
        mode: FocusMode,
        durationMinutes: Int,
        ambientTag: String?
    ) -> String {
        var parts: [String] = []
        parts.append("\(mode.displayName) for \(durationMinutes) min")

        if let tag = ambientTag {
            parts.append("with \(tag)")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Confidence

    /// Computes brief confidence from data availability.
    /// Each signal contributes a weight; the total is normalized to 0-1.
    private func computeConfidence(
        sleepHours: Double?,
        hrDelta: Double?,
        hrvTrend: String?,
        meetingCount: Int,
        recommendationConfidence: Double
    ) -> Double {
        // Weight each data source by its contribution to brief quality.
        var available: Double = 0
        let totalSources: Double = 5

        if sleepHours != nil { available += 1 }
        if hrDelta != nil { available += 1 }
        if hrvTrend != nil { available += 1 }
        if meetingCount > 0 { available += 1 }

        // Recommendation confidence contributes the final source.
        available += recommendationConfidence

        return min(available / totalSources, 1.0)
    }

    // MARK: - Day of Week Pattern

    /// Returns a day-of-week insight if the user model has enough data.
    /// Currently returns a static pattern based on common weekday observations.
    /// Will be enriched once CalendarPatternLearner data is available.
    private func buildDayOfWeekPattern(at date: Date) -> String? {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)

        // Weekday names for contextual patterns.
        // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        switch dayOfWeek {
        case 2: // Monday
            return "Mondays tend to be transition days — ease into focus."
        case 4: // Wednesday
            return "Midweek energy dip is common. Prioritize your best block."
        case 6: // Friday
            return "End-of-week fatigue is real. Shorter, sharper sessions work best."
        default:
            return nil
        }
    }
}
