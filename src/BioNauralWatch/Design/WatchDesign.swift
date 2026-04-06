// WatchDesign.swift
// BioNauralWatch
//
// Centralized design tokens for the Watch companion app. All visual values
// (colors, spacing, typography, animation, layout) live here. No hardcoded
// values in view code. Mirrors relevant iPhone Theme.swift tokens, scaled
// for the wrist.

import SwiftUI
import BioNauralShared

// MARK: - WatchDesign

enum WatchDesign {

    // MARK: - Colors

    enum Colors {
        /// Deep-water near-black canvas. Matches iPhone Theme.Colors.canvas.
        static let canvas = Color(hex: 0x080C15)
        /// Slightly raised surface for cards. Matches Theme.Colors.surface.
        static let surface = Color(hex: 0x111520)
        /// Raised surface variant.
        static let surfaceRaised = Color(hex: 0x1A1F2E)
        /// Primary accent — periwinkle. Matches Theme.Colors.accent.
        static let accent = Color(hex: 0x6E7CF7)
        /// Divider / border color base.
        static let divider = Color.white

        // Mode Colors
        static let focus = Color(hex: 0x5B6ABF)
        static let relaxation = Color(hex: 0x4EA8A6)
        static let sleep = Color(hex: 0x9080C4)
        static let energize = Color(hex: 0xF5A623)

        // Biometric Signal Colors
        static let signalCalm = Color(hex: 0x4EA8A6)
        static let signalFocused = Color(hex: 0x6E7CF7)
        static let signalElevated = Color(hex: 0xD4954A)
        static let signalPeak = Color(hex: 0xD46A5A)

        // Text
        static let textPrimary = Color(hex: 0xE2E6F0)
        static let textSecondary = Color(hex: 0xE2E6F0).opacity(0.55)
        static let textTertiary = Color(hex: 0xE2E6F0).opacity(0.30)

        // Feedback
        static let destructive = Color(hex: 0xFF3B30)

        /// Returns the mode-specific accent color.
        static func modeColor(for mode: FocusMode) -> Color {
            switch mode {
            case .focus:       return focus
            case .relaxation:  return relaxation
            case .sleep:       return sleep
            case .energize:    return energize
            }
        }

        /// Returns the biometric state signal color.
        static func signalColor(for state: BiometricState) -> Color {
            switch state {
            case .calm:     return signalCalm
            case .focused:  return signalFocused
            case .elevated: return signalElevated
            case .peak:     return signalPeak
            }
        }
    }

    // MARK: - Opacity

    enum Opacity {
        /// Glass card fill opacity.
        static let glassFill: Double = 0.08
        /// Glass card stroke opacity.
        static let glassStroke: Double = 0.12
        /// Mode label during session.
        static let modeLabel: Double = 0.5
        /// AOD mode label.
        static let aodModeLabel: Double = 0.35
        /// AOD timer.
        static let aodTimer: Double = 0.40
        /// AOD static line.
        static let aodLine: Double = 0.15
        /// Tap-reveal wave dim.
        static let revealWaveDim: Double = 0.30
        /// Biometric pill background.
        static let pillBackground: Double = 0.12
        /// Quick mode icon background.
        static let quickModeBackground: Double = 0.15
        /// Sleep progressive dimming floor.
        static let sleepDimFloor: Double = 0.25
        /// Paused dashed line.
        static let pausedLine: Double = 0.20
        /// Unfilled learning dot.
        static let unfillledDot: Double = 0.3
        /// Learning label cold start.
        static let learningLabelCold: Double = 0.6
        /// Learning label warm (learning stage).
        static let learningLabelWarm: Double = 0.8
        /// Confidence label (confident stage).
        static let confidenceLabel: Double = 0.8
        /// Divider thin line.
        static let dividerThin: Double = 0.06
        /// Session background base.
        static let sessionBackground: Double = 0.08
        /// Session background energize mode.
        static let sessionBackgroundEnergize: Double = 0.14
        /// BPM unit label.
        static let bpmUnit: Double = 0.5
        /// Breathing circle fill.
        static let breatheCircleFill: Double = 0.3
        /// Breathing text label.
        static let breatheText: Double = 0.4
        /// Minimum timer opacity during sleep dimming (always legible).
        static let sleepTimerFloor: Double = 0.35
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let xxl: CGFloat = 16
        static let xxxl: CGFloat = 20
    }

    // MARK: - Typography

    enum Typography {
        // Watch-scaled font sizes
        static let modeLabelSize: CGFloat = 11
        static let suggestionTitleSize: CGFloat = 13
        static let confidentTitleSize: CGFloat = 15
        static let contextSize: CGFloat = 9.5
        static let learningLabelSize: CGFloat = 9
        static let startButtonSize: CGFloat = 13
        static let quickModeLabelSize: CGFloat = 7
        static let todaySummarySize: CGFloat = 9
        static let timerSize: CGFloat = 13
        static let revealHRSize: CGFloat = 36
        static let revealUnitSize: CGFloat = 11
        static let revealStateSize: CGFloat = 10
        static let breatheLabelSize: CGFloat = 8
        static let pausedLabelSize: CGFloat = 11
        static let postHeaderSize: CGFloat = 9
        static let postDurationSize: CGFloat = 28
        static let postModeSize: CGFloat = 10
        static let postMetricLabelSize: CGFloat = 7.5
        static let postMetricValueSize: CGFloat = 14
        static let feedbackIconSize: CGFloat = 16
        static let pillHRSize: CGFloat = 9
        static let aodTimerSize: CGFloat = 22
        static let aodModeSize: CGFloat = 9
        static let volumeIndicatorSize: CGFloat = 9

        /// Mode label letter spacing.
        static let modeLabelTracking: CGFloat = 1.5
        /// Paused label letter spacing.
        static let pausedLabelTracking: CGFloat = 2.0
        /// Header label letter spacing.
        static let headerTracking: CGFloat = 1.0
        /// Metric label letter spacing.
        static let metricLabelTracking: CGFloat = 0.6
    }

    // MARK: - Layout

    enum Layout {
        /// Horizontal page margin.
        static let horizontalPadding: CGFloat = 4
        /// Section spacing in idle view.
        static let sectionSpacing: CGFloat = 12
        /// Inner spacing within components.
        static let innerSpacing: CGFloat = 4
        /// Card padding.
        static let cardPadding: CGFloat = 10
        /// Card corner radius.
        static let cardCornerRadius: CGFloat = 12
        /// Quick-mode icon size.
        static let quickModeIconSize: CGFloat = 28
        /// Quick-mode icon corner radius.
        static let quickModeCornerRadius: CGFloat = 8
        /// Quick-mode icon font size.
        static let quickModeIconFontSize: CGFloat = 13
        /// Quick-mode row gap.
        static let quickModeGap: CGFloat = 14
        /// Start button corner radius.
        static let startButtonCornerRadius: CGFloat = 12
        /// Start button vertical padding.
        static let startButtonVerticalPadding: CGFloat = 10
        /// Glass pill corner radius.
        static let glassPillCornerRadius: CGFloat = 20
        /// Glass pill horizontal padding.
        static let glassPillHorizontalPadding: CGFloat = 14
        /// Glass pill vertical padding.
        static let glassPillVerticalPadding: CGFloat = 7
        /// Glass pill control spacing.
        static let glassPillControlSpacing: CGFloat = 12
        /// Control button diameter.
        static let controlButtonSize: CGFloat = 30
        /// Glass pill bottom offset from screen edge.
        static let glassPillBottomOffset: CGFloat = 18
        /// Feedback button size.
        static let feedbackButtonSize: CGFloat = 36
        /// Feedback button spacing.
        static let feedbackButtonSpacing: CGFloat = 16
        /// Post-session metric grid gap.
        static let metricGridGap: CGFloat = 6
        /// Post-session metric cell padding.
        static let metricCellPadding: CGFloat = 8
        /// Post-session metric cell corner radius.
        static let metricCellCornerRadius: CGFloat = 10
        /// Learning dot size.
        static let learningDotSize: CGFloat = 4
        /// Learning dot spacing.
        static let learningDotSpacing: CGFloat = 3
        /// Learning ring size.
        static let learningRingSize: CGFloat = 16
        /// Learning ring inner dot radius.
        static let learningRingDotRadius: CGFloat = 2.5
        /// Learning ring stroke width.
        static let learningRingStrokeWidth: CGFloat = 1.5
        /// Biometric pill horizontal padding.
        static let biometricPillHPadding: CGFloat = 8
        /// Biometric pill vertical padding.
        static let biometricPillVPadding: CGFloat = 3
        /// Biometric pill corner radius.
        static let biometricPillCornerRadius: CGFloat = 10
        /// Duration picker range (minutes).
        static let durationPickerMin: Int = 5
        static let durationPickerMax: Int = 60
        static let durationPickerStep: Int = 5
        static let durationPickerDefault: Int = 15
        /// Breathing indicator circle size.
        static let breatheCircleSize: CGFloat = 14
        /// Background gradient end radius.
        static let backgroundGradientEndRadius: CGFloat = 200
        /// Ambient glow blur radius behind suggestion card.
        static let suggestionGlowBlur: CGFloat = 20
    }

    // MARK: - Wavelength

    enum Wavelength {
        /// Wave vertical height allocation.
        static let height: CGFloat = 60
        /// Horizontal scroll speed (pts/sec). Matches iPhone card wave scroll.
        static let scrollSpeed: CGFloat = 15
        /// Frame rate for scroll animation. 30 FPS matches card wave rendering.
        static let frameRate: Double = 30
        /// Edge fade exponent for sine-based envelope. Matches card fadeExponent.
        static let edgeFadeExponent: Double = 1.0

        /// Wave amplitude by biometric state (pts).
        enum Amplitude {
            static let calm: CGFloat = 8
            static let focused: CGFloat = 14
            static let elevated: CGFloat = 20
            static let peak: CGFloat = 28
            static let energize: CGFloat = 30
            static let sleepDeep: CGFloat = 6
        }

        /// Wave cycle count per mode — matches carousel card wave densities.
        /// These are the canonical cycle counts derived from representative Hz / scale factor.
        enum ModeCycles {
            static let sleep: CGFloat = 1.0
            static let relaxation: CGFloat = 1.5
            static let focus: CGFloat = 2.5
            static let energize: CGFloat = 5.0
        }

        /// Wave cycle count by biometric state (fallback when no mode-locked cycles).
        enum CycleCount {
            static let calm: CGFloat = 1.5
            static let focused: CGFloat = 2.5
            static let elevated: CGFloat = 3.5
            static let peak: CGFloat = 5.0
            static let energize: CGFloat = 5.0
            static let sleepDeep: CGFloat = 0.8
        }

        /// Beat frequency to visible cycle count conversion.
        enum BeatToCycle {
            static let divisor: Double = 5.0
            static let min: CGFloat = 0.5
            static let max: CGFloat = 7.0
        }

        /// Color blend ratios for biometric state.
        enum BlendRatio {
            static let elevated: Double = 0.4
            static let peak: Double = 0.7
        }

        // MARK: Dual-Layer Rendering (Card Wave Style)

        /// Bloom layer — soft glow underneath the crisp line.
        enum Bloom {
            /// Stroke width for the bloom (glow) layer.
            static let strokeWidth: CGFloat = 3.5
            /// Opacity for the bloom layer.
            static let opacity: Double = 0.35
            /// Gaussian blur radius applied to bloom layer.
            static let blurRadius: CGFloat = 4
        }

        /// Crisp layer — sharp visible line on top of bloom.
        enum Crisp {
            /// Default stroke width for crisp layer.
            static let strokeWidth: CGFloat = 1.8
            /// Highlighted stroke width (elevated/peak states).
            static let highlightedStrokeWidth: CGFloat = 2.5
            /// Opacity for the crisp layer.
            static let opacity: Double = 0.55
        }

        /// Stroke width variants.
        enum Stroke {
            static let standard: CGFloat = 1.8
            static let elevated: CGFloat = 2.5
            static let energize: CGFloat = 2.5
            static let sleep: CGFloat = 1.2
            /// Dashed line for paused state.
            static let paused: CGFloat = 1.0
        }

        /// Wave opacity range (for crisp layer, bloom uses Bloom.opacity).
        enum WaveOpacity {
            static let calm: Double = 0.45
            static let focused: Double = 0.55
            static let elevated: Double = 0.60
            static let peak: Double = 0.65
            static let energize: Double = 0.70
            static let sleep: Double = 0.35
        }

        /// Catmull-Rom alpha for centripetal parameterization.
        static let catmullRomAlpha: CGFloat = 0.5

        /// Sample density — points per 2 pixels of width.
        static let sampleDensity: CGFloat = 2
    }

    // MARK: - Card Style

    /// Card visual tokens matching the iPhone carousel card design language.
    enum Card {
        /// Left accent stripe width (mode color gradient on leading edge).
        static let accentStripeWidth: CGFloat = 4
        /// Card corner radius (matches Watch screen natural radius).
        static let cornerRadius: CGFloat = 24
        /// Background gradient mode color opacity (top-left wash).
        static let gradientStartOpacity: Double = 0.15
        /// Background gradient surface midpoint opacity.
        static let gradientMidOpacity: Double = 0.50
        /// Ambient glow opacity behind card/screen.
        static let ambientGlowOpacity: Double = 0.12
        /// Ambient glow blur radius.
        static let ambientGlowBlur: CGFloat = 20
        /// Wave section height fraction (proportion of available space).
        static let waveSectionFraction: CGFloat = 0.40
    }

    // MARK: - Animation

    enum Animation {
        /// Tap-reveal fade in duration.
        static let revealFadeIn: Double = 0.3
        /// Tap-reveal hold duration.
        static let revealHold: Double = 3.0
        /// Tap-reveal fade out duration.
        static let revealFadeOut: Double = 0.5
        /// Post-feedback auto-dismiss delay.
        static let feedbackDismissDelay: Double = 2.0
        /// Volume indicator auto-hide delay.
        static let volumeIndicatorHide: Double = 1.5
        /// Digital Crown haptic detent (% increment).
        static let crownHapticDetent: Double = 0.10
        /// Spring bounce for press interactions.
        static let pressBounce: Double = 0.2
        /// Standard spring bounce.
        static let standardBounce: Double = 0.2
        /// Standard animation duration.
        static let standardDuration: Double = 0.25
        /// Sleep progressive dimming — opacity reduction per minute.
        static let sleepDimRatePerMinute: Double = 0.02
        /// Sleep dimming starts after this many minutes.
        static let sleepDimStartMinutes: Double = 5.0
        /// Staggered entrance animation delay per element.
        static let staggerDelay: Double = 0.08
        /// Entrance animation vertical offset.
        static let entranceOffset: CGFloat = 12

        /// Breathing indicator pulse duration (matches haptic cycle).
        static let breathePulseDuration: Double = 4.0
    }

    // MARK: - Audio

    enum Audio {
        /// Sample rate for audio engine.
        static let sampleRate: Double = 44100
        /// Buffer size in frames.
        static let bufferFrames: Int = 512
        /// Amplitude smoothing time constant (seconds).
        static let amplitudeSmoothingTime: Double = 0.005
        /// Frequency smoothing time constant (seconds).
        static let frequencySmoothingTime: Double = 0.020
        /// Initial amplitude for session start / reset.
        static let initialAmplitude: Double = 0.5
        /// Adaptation tick interval (seconds) — 10 Hz control loop.
        static let adaptationTickInterval: TimeInterval = 0.1
        /// Amplitude ramp duration before stop (seconds).
        static let stopRampDuration: Double = 0.5
        /// Pause ramp duration (seconds).
        static let pauseRampDuration: Double = 0.5

        /// Harmonic levels relative to fundamental.
        enum Harmonics {
            /// 2nd harmonic level (dB below fundamental).
            static let second: Double = -8.0
            /// 3rd harmonic level (dB below fundamental).
            static let third: Double = -14.0
        }

        /// Dual-EMA smoothing alphas.
        enum EMA {
            /// Fast EMA alpha (~2.5s window). Matches Theme.Audio.EMA.fast.
            static let fast: Double = 0.4
            /// Slow EMA alpha (~10s window). Matches Theme.Audio.EMA.slow.
            static let slow: Double = 0.1
        }

        /// State classification hysteresis.
        enum Hysteresis {
            /// Band width for transition hysteresis.
            static let band: Double = 0.03
            /// Minimum dwell time (seconds) before accepting state transition.
            static let minDwellTime: TimeInterval = 5.0
            /// First session wider hysteresis band.
            static let firstSessionBand: Double = 0.05
        }

        /// Slew rate limits (max change per second).
        enum SlewRate {
            /// Beat frequency max change (Hz/sec).
            static let beatFrequency: Double = 0.3
            /// Carrier frequency max change (Hz/sec).
            static let carrierFrequency: Double = 2.0
            /// Amplitude max change (per second).
            static let amplitude: Double = 0.02
        }

        /// Proportional + feedforward control gains.
        enum Control {
            /// Proportional gain.
            static let kp: Double = 0.1
            /// Feedforward gain.
            static let kff: Double = 0.5
        }

        /// Default resting HR for first session (no history).
        static let defaultRestingHR: Double = 72
        /// Default max HR for first session (no age data).
        static let defaultMaxHR: Double = 185

        /// Data dropout handling.
        enum DataDropout {
            /// Seconds before starting drift to neutral.
            static let holdDuration: TimeInterval = 30
            /// Seconds over which to interpolate to neutral.
            static let driftDuration: TimeInterval = 60
            /// Neutral beat frequency target.
            static let neutralBeatFrequency: Double = 10.0
            /// Neutral amplitude target.
            static let neutralAmplitude: Double = 0.5
        }

        /// Sleep mode time-based ramp.
        enum SleepRamp {
            /// Starting beat frequency (Hz).
            static let startFrequency: Double = 6.0
            /// Ending beat frequency (Hz).
            static let endFrequency: Double = 2.0
            /// Total ramp duration (seconds).
            static let rampDuration: TimeInterval = 25 * 60
        }

        /// Sigmoid mapping parameters per mode.
        enum Mapping {
            enum Focus {
                static let beatMin: Double = 6.0
                static let beatMax: Double = 18.0
                static let steepness: Double = 6.0
                static let midpoint: Double = 0.4
            }
            enum Relaxation {
                static let beatMin: Double = 8.0
                static let beatMax: Double = 12.0
                static let steepness: Double = 4.0
                static let midpoint: Double = 0.4
            }
            enum Sleep {
                static let hrElevationBlendFactor: Double = 0.3
            }
            enum Energize {
                static let beatMin: Double = 10.0
                static let beatMax: Double = 30.0
                static let steepness: Double = 5.0
                static let midpoint: Double = 0.5
            }
        }

        /// Secondary parameter mappings.
        enum SecondaryMapping {
            /// Carrier modulation via trend: carrier_base + range * tanh(trend / divisor)
            static let carrierTrendRange: Double = 50.0
            static let carrierTrendDivisor: Double = 5.0
            /// Binaural amplitude parabola: base + scale * (1 - (2*hr - 1)^2)
            static let amplitudeBase: Double = 0.3
            static let amplitudeScale: Double = 0.5
            /// Ambient level: base - scale * hr_normalized
            static let ambientBase: Double = 0.8
            static let ambientScale: Double = 0.5
        }
    }

    // MARK: - Session

    enum Session {
        /// Heartbeat ping interval for connection health (seconds).
        static let heartbeatPingInterval: TimeInterval = 5
        /// Connection health timeout (seconds).
        static let connectionHealthTimeout: TimeInterval = 10
        /// Max HR sample buffer during disconnect.
        static let maxSampleBuffer: Int = 500
        /// HR validation range (BPM).
        static let hrMinValid: Double = 30
        static let hrMaxValid: Double = 220
        /// Artifact rejection threshold (BPM difference).
        static let artifactThresholdBPM: Double = 30
    }

    // MARK: - Breathing Haptics

    enum BreathingHaptics {
        /// Initial total cycle duration (inhale + exhale) in seconds.
        static let initialCycleDuration: TimeInterval = 10.0
        /// Target total cycle duration after full adaptation.
        static let targetCycleDuration: TimeInterval = 12.0
        /// Initial inhale phase duration in seconds.
        static let initialInhaleDuration: TimeInterval = 4.0
        /// Target inhale phase duration after full adaptation.
        static let targetInhaleDuration: TimeInterval = 5.0
        /// Initial exhale phase duration (initialCycle - initialInhale).
        static let initialExhaleDuration: TimeInterval = 6.0
        /// Target exhale phase duration (targetCycle - targetInhale).
        static let targetExhaleDuration: TimeInterval = 7.0
        /// Number of haptic taps per inhale phase.
        static let tapsPerInhale: Int = 4
        /// Seconds of sustained calm before auto-stopping breathing cues.
        static let sustainedCalmThreshold: TimeInterval = 60.0
        /// BPM drop for full adaptation (10 BPM = fully adapted).
        static let fullAdaptationDropBPM: Double = 10.0
    }

    // MARK: - Suggestion

    enum Suggestion {
        /// HR reserve threshold above which relaxation is suggested.
        static let hrReserveRelaxationThreshold: Double = 0.5
        /// HR reserve threshold below which energize is suggested.
        static let hrReserveEnergizeThreshold: Double = 0.15
        /// HR reserve thresholds for human-readable labels.
        static let hrLabelThresholds: [Double] = [0.15, 0.30, 0.50, 0.70]
        /// Hours of sleep below which poor sleep override triggers.
        static let poorSleepThreshold: Double = 6.0
    }

    // MARK: - Battery

    enum Battery {
        /// Battery level at which to warn before session.
        static let warningThreshold: Float = 0.20
        /// Battery level at which to block session start.
        static let blockThreshold: Float = 0.10
        /// Battery level below which to warn for long sessions.
        static let longSessionWarningThreshold: Float = 0.30
        /// Session duration considered "long" (minutes).
        static let longSessionMinutes: Int = 30
    }

    // MARK: - Learning

    enum Learning {
        /// Sessions per learning dot.
        static let sessionsPerDot: [Int] = [2, 9, 19, 34]
        /// Total number of learning dots.
        static let totalDots: Int = 5
        /// Sessions required for "Tuned to you" stage.
        static let confidentThreshold: Int = 20
        /// Sessions required for "Learning" stage.
        static let learningThreshold: Int = 3
    }
}

// MARK: - Color+Hex (watchOS)

extension Color {
    /// Creates a Color from a hex integer (e.g., 0x6E7CF7).
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - FocusMode Watch Display Extensions

extension FocusMode {
    /// SF Symbol icon name for each mode on Watch.
    var watchIconName: String {
        systemImageName
    }

    /// Mode-specific tint color for Watch UI.
    var watchColor: Color {
        WatchDesign.Colors.modeColor(for: self)
    }
}

// MARK: - BiometricState Watch Extensions

extension BiometricState {
    /// Signal color for this biometric state on Watch.
    var watchSignalColor: Color {
        WatchDesign.Colors.signalColor(for: self)
    }

    /// Display name for tap-to-reveal overlay.
    var watchDisplayName: String {
        switch self {
        case .calm:     return "Calm"
        case .focused:  return "Focused"
        case .elevated: return "Elevated"
        case .peak:     return "Peak"
        }
    }
}
