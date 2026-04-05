// Constants.swift
// BioNaural
//
// App-wide constants that are not design tokens (those live in Theme).
// Covers session limits, monetization gates, Pomodoro timing, calibration,
// and adaptive engine thresholds. Referenced by name everywhere — no magic
// numbers in feature code.

import Foundation
import BioNauralShared

// MARK: - Constants

enum Constants {

    // MARK: Free Tier Limits

    /// Maximum sessions allowed per day on the free tier.
    static let freeSessionsPerDay = 3

    // MARK: Session Duration

    /// Minimum session length the UI will allow (minutes).
    static let minimumSessionMinutes = 5

    /// Maximum session length the UI will allow (minutes).
    static let maxSessionMinutes = 120

    /// Default session duration per mode (minutes).
    ///
    /// Focus defaults to a single Pomodoro block, Relaxation to a short
    /// recovery, and Sleep to a full wind-down arc.
    static let defaultSessionMinutes: [FocusMode: Int] = [
        .focus: 25,
        .relaxation: 15,
        .sleep: 30
    ]

    // MARK: Pomodoro

    /// Standard Pomodoro focus block (minutes).
    static let pomodoroFocusMinutes = 25

    /// Standard Pomodoro short break (minutes).
    static let pomodoroBreakMinutes = 5

    /// Default number of focus/break cycles before a long break.
    static let defaultPomodoroCycles = 4

    // MARK: Calibration

    /// Duration of the biometric calibration flow (seconds).
    ///
    /// Two minutes of resting data to establish baseline HR and HRV.
    static let calibrationDurationSeconds = 120

    // MARK: Adaptive Engine Thresholds

    /// Seconds of missing biometric data before the engine treats the
    /// signal as dropped and falls back to time-based adaptation.
    static let dataDropoutThresholdSeconds: TimeInterval = 10.0

    /// Seconds of neutral (no significant trend) biometric data before
    /// the engine applies a gentle drift toward the mode's target range.
    static let neutralDriftDurationSeconds: TimeInterval = 60.0

    /// Minimum seconds between melodic layer changes.
    ///
    /// Prevents frequent crossfades that would feel like track-switching
    /// rather than natural musical evolution (3 minutes).
    static let melodicChangeIntervalSeconds: TimeInterval = 180.0

    // MARK: Check-In UX

    /// After this many sessions with similar check-in responses, the app
    /// offers to remember the user's settings ("Use your usual settings?").
    static let checkInSkipThreshold = 5

    // MARK: Circadian Recommendation

    /// Hour boundaries for time-of-day mode suggestions.
    enum Circadian {
        static let morningStart = 5
        static let peakStart = 9
        static let middayStart = 12
        static let afternoonStart = 14
        static let eveningStart = 17
        static let nightStart = 20
        static let lateNightStart = 22

        /// How far ahead to look for high/critical stress events (4 hours).
        static let stressorLookaheadSeconds: TimeInterval = 4 * 60 * 60

        /// Minimum gap duration (minutes) to show the free window card.
        static let minimumFreeWindowMinutes: Int = 15
    }

    // MARK: Biometric Thresholds (Recommendation Engine)

    /// HRV below this value (ms) is considered low for recommendation purposes.
    static let lowHRVThreshold: Double = 35.0

    /// Sleep below this many hours triggers "poor sleep" recommendations.
    static let poorSleepHoursThreshold: Double = 6.0

    /// Default lookback window for health data averages (days).
    static let healthAverageDays: Int = 7

    // MARK: Insights Display

    /// Number of sparkline data points in the impact chart.
    static let sparklineDataPointCount = 10

    /// Number of recent sessions to show in trend mini cards.
    static let trendDataPointCount = 7

    /// Number of weeks to show in the sessions-per-week chart.
    static let trendWeekCount = 4

    /// Maximum sessions shown before "See All" button appears.
    static let historyPreviewLimit = 5

    /// Minimum sessions with HR data before showing impact insight.
    static let impactInsightMinSessions = 3

    /// Minimum HR delta (BPM) before showing impact insight text.
    static let impactInsightMinDelta = 2

    /// Minimum biometric trend delta before showing trend arrow.
    static let trendDeltaThreshold: Double = 1.0

    /// Impact score thresholds for color coding.
    enum ImpactScore {
        static let goodThreshold: Double = 0.6
        static let moderateThreshold: Double = 0.4
    }

    // MARK: Session Duration Defaults

    /// Default session durations per mode (minutes).
    enum SessionDuration {
        static let focusDefault = 25
        static let relaxationDefault = 15
        static let sleepDefault = 30
        static let energizeDefault = 15

        static let focusOptions = [15, 25, 45, 60, 90]
        static let relaxationOptions = [10, 15, 20, 30]
        static let sleepOptions = [20, 30, 45, 60, 90]
        static let energizeOptions = [10, 15, 20, 30]
    }

    // MARK: Health Population Defaults

    /// Healthy-adult population averages — displayed when no personal data exists.
    enum HealthDefaults {
        static let restingHR: Double = 68
        static let hrv: Double = 42
        static let sleepHours: Double = 7.5
    }

    // MARK: Session UI

    /// Stepper increment for session duration (minutes).
    static let durationStepMinutes: Double = 5

    /// Minimum press duration for screen lock/unlock gesture (seconds).
    static let screenLockPressDuration: TimeInterval = 1.0

    // MARK: Soundscape Presets

    /// Available ambient soundscape bed names and their display labels.
    enum Soundscape {
        static let rain = "rain"
        static let wind = "wind"
        static let pinkNoise = "pink_noise"

        /// Ordered list of presets for the session soundscape menu.
        static let presets: [(bedName: String, displayName: String)] = [
            (rain, "Rain · Warm Pad"),
            (wind, "Wind · Subtle Drone"),
            (pinkNoise, "Pink Noise · Bright Pad")
        ]
    }

    // MARK: Wave Zone Layout

    /// Visual multipliers for the session wave zone layout.
    enum WaveZone {
        /// Glow radial gradient end radius multiplier relative to orb size.
        static let glowEndRadiusMultiplier: CGFloat = 1.5
        /// Glow frame width multiplier relative to orb size.
        static let glowFrameWidthMultiplier: CGFloat = 3.0
        /// Ambient wave layer height multiplier relative to Theme.Spacing.mega.
        static let ambientHeightMultiplier: CGFloat = 2.2
        /// Melodic wave layer height multiplier relative to Theme.Spacing.mega.
        static let melodicHeightMultiplier: CGFloat = 1.6
        /// Binaural wave layer height multiplier relative to Theme.Spacing.mega.
        static let binauralHeightMultiplier: CGFloat = 1.1
        /// Ambient layer beat frequency divisor.
        static let ambientFrequencyDivisor: Double = 3.0
        /// Ambient layer minimum frequency floor (Hz).
        static let ambientFrequencyFloor: Double = 1.0
        /// Melodic layer beat frequency divisor.
        static let melodicFrequencyDivisor: Double = 1.5
        /// Melodic layer minimum frequency floor (Hz).
        static let melodicFrequencyFloor: Double = 2.0
    }

    // MARK: Orb Visual Constants

    /// Fractional multiplier for the elevated biometric state orb size.
    static let orbElevatedFractionMultiplier: CGFloat = 0.85

    /// Home screen Orb hero visual constants.
    enum OrbHero {
        /// Outer glow frame size multiplier relative to Theme.Spacing.mega.
        static let glowFrameMultiplier: CGFloat = 3.0
    }

    // MARK: Brainwave Band Boundaries (Hz)

    /// Frequency boundaries for brainwave band classification.
    enum BrainwaveBands {
        static let deltaCeiling: Double = 4.0
        static let thetaCeiling: Double = 8.0
        static let alphaCeiling: Double = 13.0
        static let betaCeiling: Double = 30.0
    }

    // MARK: Health Insights Display

    /// Configuration for calendar-health correlation UI.
    enum Insights {
        /// Maximum post-event impact cards shown on the Health screen.
        static let maxImpactCards: Int = 3

        /// Hours of HR history to fetch for event impact analysis.
        static let hrHistoryLookbackHours: Int = 4

        /// Number of HR data points for mini sparkline display.
        static let sparklinePointCount: Int = 8

        /// Maximum number of patterns to include in a forecast.
        static let maxForecastPatterns: Int = 3

        // MARK: Weekly Digest

        /// Maximum ranked events to include in the weekly digest.
        static let weeklyDigestMaxEvents: Int = 5

        /// HR delta (BPM) above baseline that qualifies as high-stress.
        static let highStressHRDelta: Double = 8.0

        /// HR delta (BPM) above baseline that qualifies as critical stress.
        static let criticalStressHRDelta: Double = 15.0

        /// HR delta (BPM) above baseline for moderate stress threshold.
        static let moderateStressHRDelta: Double = 4.0

        /// Maximum HR delta (BPM) used to normalize impact scores to 0-1.
        static let impactScoreNormalizationCeiling: Double = 20.0

        // MARK: Life Event Detection

        /// Number of days before and after today to scan for life events.
        static let lifeEventScanDaysRadius: Int = 3

        /// Hours of HR history to fetch for life event halo day data.
        static let lifeEventHRHistoryHours: Int = 168 // 7 days

        /// Keywords that indicate a life event when found in calendar event titles.
        static let lifeEventKeywords: [String: LifeEventCategoryMapping] = [
            "wedding": .social,
            "exam": .performance,
            "final": .performance,
            "move": .transition,
            "surgery": .health,
            "interview": .performance,
            "deadline": .deadline,
            "conference": .social,
            "travel": .social,
            "flight": .social,
            "presentation": .performance,
            "appointment": .health
        ]
    }

    /// Maps keyword matches to LifeEventCategory values.
    /// Kept in Constants so HealthView can map without importing the enum's raw values.
    enum LifeEventCategoryMapping: String {
        case deadline
        case performance
        case social
        case health
        case transition

        var category: LifeEventCategory {
            switch self {
            case .deadline:    return .deadline
            case .performance: return .performance
            case .social:      return .social
            case .health:      return .health
            case .transition:  return .transition
            }
        }
    }
}
