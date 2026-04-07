// Theme.swift
// BioNaural
//
// Single source of truth for all design tokens.
// Every color, spacing, font, duration, frequency, and threshold in the app
// references this file. No hardcoded values anywhere else.

import BioNauralShared
import SwiftUI
import UIKit

// MARK: - Theme

enum Theme {
    // No instances — access everything via nested enums and static members.
}

// MARK: - Colors

extension Theme {

    enum Colors {

        // MARK: Foundation — The Dark Field

        /// Near-black with blue undertone. Primary background.
        static let canvas = Color(adaptive: Hex.canvasDark, light: Hex.canvasLight)

        /// Cards, sheets, elevated surfaces.
        static let surface = Color(adaptive: Hex.surfaceDark, light: Hex.surfaceLight)

        /// Active states, pressed cards.
        static let surfaceRaised = Color(adaptive: Hex.surfaceRaisedDark, light: Hex.surfaceRaisedLight)

        /// Subtle separators (use sparingly).
        static let divider = Color(adaptive: Hex.dividerDark, light: Hex.dividerLight)

        // MARK: Text

        /// Soft white, never pure #FFF. Primary text.
        static let textPrimary = Color(adaptive: Hex.textPrimaryDark, light: Hex.textPrimaryLight)

        /// Secondary labels, metadata — 55% opacity on textPrimary base.
        static var textSecondary: Color {
            Color(adaptive: Hex.textPrimaryDark, light: Hex.textPrimaryLight)
                .opacity(Opacity.textSecondary)
        }

        /// Hints, disabled, timestamps — 30% opacity on textPrimary base.
        static var textTertiary: Color {
            Color(adaptive: Hex.textPrimaryDark, light: Hex.textPrimaryLight)
                .opacity(Opacity.textTertiary)
        }

        /// Text rendered on accent-colored backgrounds.
        static let textOnAccent = Color.white

        // MARK: Accent — Periwinkle

        /// Primary CTAs, selected states, the Orb's default color.
        static let accent = Color(adaptive: Hex.accentDark, light: Hex.accentLight)

        /// Page-level background tint (5% opacity).
        static var accentWash: Color {
            Color(adaptive: Hex.accentDark, light: Hex.accentLight)
                .opacity(Theme.Opacity.subtle)
        }

        /// Borders, secondary fills (15% opacity).
        static var accentLight: Color {
            Color(adaptive: Hex.accentDark, light: Hex.accentLight)
                .opacity(Theme.Opacity.accentLight)
        }

        /// Prominent indicators (60% opacity).
        static var accentStrong: Color {
            Color(adaptive: Hex.accentDark, light: Hex.accentLight)
                .opacity(Theme.Opacity.accentStrong)
        }

        /// CGColor for accent — used by EventKit calendar color.
        static var accentCGColor: CGColor {
            UIColor(
                red: CGFloat((Hex.accentDark >> 16) & 0xFF) / 255.0,
                green: CGFloat((Hex.accentDark >> 8) & 0xFF) / 255.0,
                blue: CGFloat(Hex.accentDark & 0xFF) / 255.0,
                alpha: 1.0
            ).cgColor
        }

        // MARK: Mode Colors

        /// Focus — Indigo. Inward, cerebral, deep concentration.
        static let focus = Color(hex: Hex.focus)
        /// Relaxation — Soft teal. Calm, steady, parasympathetic.
        static let relaxation = Color(hex: Hex.relaxation)
        /// Sleep — Muted violet. Expansive, still, descending.
        static let sleep = Color(hex: Hex.sleep)

        /// Sleep session tint — warm red-amber used to shift the session
        /// screen into a circadian-friendly palette during sleep mode.
        static let sleepTint = Color(hex: Hex.sleepTint)

        /// Energize — Amber-gold. Uplifting, activating, sympathetic drive.
        static let energize = Color(adaptive: Hex.energizeDark, light: Hex.energizeLight)

        // MARK: Biometric Signal Colors

        /// Cool teal — low HR, high HRV, relaxed.
        static let signalCalm = Color(hex: Hex.signalCalm)
        /// Accent periwinkle — optimal focus range.
        static let signalFocus = Color(hex: Hex.signalFocus)
        /// Warm gold — rising HR, increasing intensity.
        static let signalElevated = Color(hex: Hex.signalElevated)
        /// Soft coral — high HR, max effort.
        static let signalPeak = Color(hex: Hex.signalPeak)

        // MARK: Feature Accent Colors

        /// Morning brief card background tint.
        static var morningBriefTint: Color {
            Color(adaptive: Hex.accentDark, light: Hex.accentLight)
                .opacity(Opacity.subtle)
        }

        /// Success/confirmation green for saved states.
        static let confirmationGreen = Color(hex: Hex.confirmationGreen)

        /// Warning amber for stress indicators.
        static let stressWarning = Color(hex: Hex.stressWarning)

        /// Critical red for high-stress indicators.
        static let stressCritical = Color(hex: Hex.stressCritical)

        // MARK: Hex Constants

        /// Raw hex values for programmatic use (Metal shaders, Dynamic Island
        /// tint, unit tests). The adaptive `Color` properties above should be
        /// preferred for all SwiftUI usage.
        enum Hex {
            // Surfaces — dark
            static let canvasDark: UInt = 0x080C15
            static let surfaceDark: UInt = 0x111520
            static let surfaceRaisedDark: UInt = 0x1A1F2E
            static let dividerDark: UInt = 0x1E2336
            static let textPrimaryDark: UInt = 0xE2E6F0
            static let accentDark: UInt = 0x6E7CF7

            // Surfaces — light
            static let canvasLight: UInt = 0xF4F4F8
            static let surfaceLight: UInt = 0xFFFFFF
            static let surfaceRaisedLight: UInt = 0xEDEDF2
            static let dividerLight: UInt = 0x2A2A3A // slightly visible on light bg
            static let textPrimaryLight: UInt = 0x1A1A2E
            static let accentLight: UInt = 0x5563D6

            // Mode colors
            static let focus: UInt = 0x5B6ABF
            static let relaxation: UInt = 0x4EA8A6
            static let sleep: UInt = 0x9080C4
            static let sleepTint: UInt = 0xC47040
            static let energize: UInt = 0xF5A623
            static let energizeDark: UInt = 0xF5A623
            static let energizeLight: UInt = 0xD4891A

            // Biometric signal colors
            static let signalCalm: UInt = 0x4EA8A6
            static let signalFocus: UInt = 0x6E7CF7
            static let signalElevated: UInt = 0xD4954A
            static let signalPeak: UInt = 0xD46A5A

            // Feature accent colors
            static let confirmationGreen: UInt = 0x4EA87A
            static let stressWarning: UInt = 0xD4954A
            static let stressCritical: UInt = 0xD46A5A
        }
    }
}

// MARK: - Opacity

extension Theme {

    enum Opacity {
        static let transparent: Double = 0.0
        static let minimal: Double = 0.04
        static let subtle: Double = 0.05
        static let light: Double = 0.10
        static let accentLight: Double = 0.15
        static let dim: Double = 0.20
        static let medium: Double = 0.30
        static let half: Double = 0.50
        static let accentStrong: Double = 0.60
        static let translucent: Double = 0.60
        static let full: Double = 1.0

        // Semantic aliases — tuned for dark canvas (#080C15).
        // Higher than typical because text on near-black needs more luminance.
        static let textSecondary: Double = 0.65
        static let textTertiary: Double = 0.40
        static let canvasRadialWash: Double = 0.05
        static let accentWash: Double = 0.08
        static let sleepDimmed: Double = 0.02

        // Glass fills — per Apple Liquid Glass HIG, max 0.45
        static let glassFill: Double = 0.12
        static let glassStroke: Double = 0.20
        static let glassInteractive: Double = 0.18
        static let glassBar: Double = 0.15
    }
}

// MARK: - Typography

extension Theme {

    enum Typography {

        // MARK: Satoshi Family

        /// Satoshi font name constants. The variable font must be bundled
        /// in the app target and declared in Info.plist under UIAppFonts.
        private enum FontName {
            static let regular = "SatoshiVariable-Regular"
            static let medium = "SatoshiVariable-Medium"
            static let bold = "SatoshiVariable-Bold"
            static let light = "SatoshiVariable-Light"
        }

        // MARK: Satoshi Styles
        //
        // Weight hierarchy creates clear visual tiers:
        //   Light (display) → Medium (title) → Bold (headline) → Regular (body/caption) → Medium (small)
        //
        // Light at 40pt is airy and premium — "a dark room with one perfect light."
        // Bold at 20pt punches through for card hooks and section headers.
        // Regular is the workhorse for reading text.
        // Medium at 11pt keeps tiny labels legible.

        /// Hero text — session mode name, section heroes.
        /// Regular weight at 36pt reads clearly while still feeling premium.
        static var display: Font { satoshi(.regular, size: 36, relativeTo: .largeTitle) }

        /// Screen headers, primary section titles.
        static var title: Font { satoshi(.medium, size: 28, relativeTo: .title) }

        /// Carousel card titles — unified size across all card types.
        static var cardTitle: Font { satoshi(.medium, size: 24, relativeTo: .title2) }

        /// Card hooks, section headers that need visual punch.
        static var headline: Font { satoshi(.bold, size: 20, relativeTo: .headline) }

        /// Primary content, descriptions, science body text.
        static var body: Font { satoshi(.regular, size: 17, relativeTo: .body) }

        /// Card subtitles, secondary descriptions. Bridges body and caption.
        static var callout: Font { satoshi(.regular, size: 15, relativeTo: .callout) }

        /// Labels, metadata, study references. Medium weight for legibility
        /// at this size on dark backgrounds.
        static var caption: Font { satoshi(.medium, size: 13, relativeTo: .caption) }

        /// Tertiary info, badges, timestamps. Bold weight ensures
        /// legibility at small size on dark canvas.
        static var small: Font { satoshi(.bold, size: 11, relativeTo: .caption2) }

        // MARK: SF Mono Styles (Data / Timer)

        static var timer: Font {
            Font.system(size: 36, weight: .light, design: .monospaced)
                .monospacedDigit()
        }

        static var data: Font {
            Font.system(size: 22, weight: .medium, design: .monospaced)
                .monospacedDigit()
        }

        static var dataSmall: Font {
            Font.system(size: 15, weight: .medium, design: .monospaced)
                .monospacedDigit()
        }

        // MARK: Raw Point Sizes (for contexts needing CGFloat)

        enum Size {
            static let display: CGFloat = 36
            static let title: CGFloat = 28
            static let headline: CGFloat = 20
            static let body: CGFloat = 17
            static let callout: CGFloat = 15
            static let caption: CGFloat = 13
            static let small: CGFloat = 11
            static let timer: CGFloat = 36
            static let data: CGFloat = 22
            static let dataSmall: CGFloat = 15
        }

        // MARK: Tracking (letter spacing)

        enum Tracking {
            /// Uppercase labels — generous spacing for legibility at small sizes
            static let uppercase: CGFloat = 1.5
            /// Display text (28pt+) — slight openness
            static let display: CGFloat = 0.5
            /// Body text — use system default
            static let body: CGFloat = 0.0
            /// Timer / data readouts
            static let data: CGFloat = 0.8
        }

        // MARK: Line Spacing

        enum LineSpacing {
            /// Default interface text — no additional spacing
            static let standard: CGFloat = 0.0
            /// Longer-form content (session summary descriptions)
            static let relaxed: CGFloat = 4.0
        }

        // MARK: Private Helpers

        private enum SatoshiWeight {
            case light, regular, medium, bold
        }

        /// Builds a Satoshi Font with Dynamic Type scaling via `relativeTo`.
        private static func satoshi(
            _ weight: SatoshiWeight,
            size: CGFloat,
            relativeTo textStyle: Font.TextStyle
        ) -> Font {
            let name: String
            switch weight {
            case .light: name = FontName.light
            case .regular: name = FontName.regular
            case .medium: name = FontName.medium
            case .bold: name = FontName.bold
            }
            return .custom(name, size: size, relativeTo: textStyle)
        }
    }
}

// MARK: - Spacing

extension Theme {

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let jumbo: CGFloat = 48
        static let mega: CGFloat = 64

        /// Standard page margin.
        static let pageMargin: CGFloat = 20
    }
}

// MARK: - Layout

extension Theme {

    /// Screen-level layout constants. Replaces `UIScreen.main` usage
    /// with a safe estimate. For precise sizing, prefer `GeometryReader`.
    enum Layout {
        /// Estimated screen width for radial gradient sizing and layout
        /// calculations where GeometryReader is impractical.
        /// Uses the key window scene's bounds when available, falling
        /// back to 393pt (iPhone 15 Pro logical width).
        @MainActor static var screenEstimate: CGFloat {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else {
                return 393
            }
            return scene.screen.bounds.width
        }
    }
}

// MARK: - Radius

extension Theme {

    enum Radius {
        /// Tiny radius for decorative elements (legend dots, phase segments).
        static let xs: CGFloat = 2
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let card: CGFloat = 24
        static let sheet: CGFloat = 32

        /// Full-round (capsule) — use `Capsule()` or `.infinity` depending on context.
        static let fullRound: CGFloat = .infinity

        /// Decorative line height for legend indicators.
        static let legendStroke: CGFloat = 1.5
        /// Height for thin progress/phase segment bars.
        static let segmentHeight: CGFloat = 3

        /// Hairline stroke for glass fallback borders.
        static let glassStroke: CGFloat = 1.0
    }
}

// MARK: - Animation

extension Theme {

    enum Animation {

        // MARK: Spring Presets

        static var press: SwiftUI.Animation {
            AnimationConstants.resolve(
                .spring(duration: Duration.press, bounce: Bounce.press)
            )
        }

        static var standard: SwiftUI.Animation {
            AnimationConstants.resolve(
                .spring(duration: Duration.standard, bounce: Bounce.standard)
            )
        }

        static var sheet: SwiftUI.Animation {
            AnimationConstants.resolve(
                .spring(duration: Duration.sheet, bounce: Bounce.sheet)
            )
        }

        // MARK: Orb Animations

        static var orbBreathing: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: Duration.orbBreathingDefault)
                    .repeatForever(autoreverses: true)
            )
        }

        static func orbBreathing(cycleDuration: Double) -> SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: cycleDuration)
                    .repeatForever(autoreverses: true)
            )
        }

        static var orbAdaptation: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: Duration.orbAdaptation)
            )
        }

        static var orbEntrance: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeIn(duration: Duration.orbEntrance)
            )
        }

        static var orbExit: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeOut(duration: Duration.orbExit)
            )
        }

        static var orbBloomPulse: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: Duration.orbBloomPulse)
            )
        }

        // MARK: Premium Transition Presets

        /// Bloom transition for session start (card to Orb).
        static var sessionTransition: SwiftUI.Animation {
            Spring.sessionTransition
        }

        /// Staggered card fade-in for lists and grids.
        static func staggeredFadeIn(index: Int) -> SwiftUI.Animation {
            AnimationConstants.resolve(
                .spring(duration: Duration.standard, bounce: Bounce.standard)
                    .delay(Double(index) * Duration.staggerDelay)
            )
        }

        /// Shimmer loading sweep animation.
        static var shimmerCycle: SwiftUI.Animation {
            AnimationConstants.resolve(
                .linear(duration: Duration.shimmerCycle)
                    .repeatForever(autoreverses: false)
            )
        }

        /// Breathing glow animation for suggested cards.
        static var breathingGlow: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: Duration.breathingGlowCycle)
                    .repeatForever(autoreverses: true)
            )
        }

        /// Rolling number transition.
        static var rollingNumber: SwiftUI.Animation {
            AnimationConstants.resolve(
                .spring(duration: Duration.rollingNumber, bounce: Bounce.standard)
            )
        }

        // MARK: Session Data Reveal

        static var dataReveal: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeOut(duration: Duration.dataReveal)
            )
        }

        static var dataHide: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeIn(duration: Duration.dataHide)
            )
        }

        // MARK: Wavelength Animations

        static var waveAdaptation: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeInOut(duration: Duration.waveAdaptation)
            )
        }

        static var waveEntrance: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeIn(duration: Duration.waveEntrance)
            )
        }

        static var waveExit: SwiftUI.Animation {
            AnimationConstants.resolve(
                .easeOut(duration: Duration.waveExit)
            )
        }

        // MARK: Duration Constants

        enum Duration {
            // Springs
            static let press: Double = 0.12
            static let standard: Double = 0.25
            static let sheet: Double = 0.35

            // Orb
            static let orbBreathingMin: Double = 4.0
            static let orbBreathingMax: Double = 6.0
            static let orbBreathingDefault: Double = 5.0
            static let orbAdaptation: Double = 4.0
            static let orbAdaptationMin: Double = 3.0
            static let orbAdaptationMax: Double = 5.0
            static let orbEntrance: Double = 1.5
            static let orbExit: Double = 2.0
            static let orbBloomPulse: Double = 2.0

            // Wavelength
            static let waveScrollSpeed: CGFloat = 20 // pts per second
            static let waveAdaptation: Double = 4.0
            static let waveAdaptationMin: Double = 3.0
            static let waveAdaptationMax: Double = 5.0
            static let waveEntrance: Double = 1.0
            static let waveExit: Double = 1.5

            // Interaction
            static let tapToRevealDismiss: Double = 3.0

            // Session
            static let sleepAutoDim: Double = 30.0
            static let melodicUpdateCheckMin: Double = 180.0  // 3 minutes
            static let melodicUpdateCheckMax: Double = 300.0  // 5 minutes
            static let dataReveal: Double = 0.3
            static let dataHide: Double = 0.5

            // Health tab live refresh
            static let healthRefreshInterval: Double = 3.0

            // Safety UI
            /// Auto-dismiss duration for subtle safety banners (seconds).
            static let safetyBannerDismiss: Double = 5.0

            // Premium Transitions
            /// Total duration for the session start bloom transition.
            static let sessionTransition: Double = 0.6
            /// Per-card stagger delay for list fade-in animations.
            static let staggerDelay: Double = 0.08
            /// Full cycle duration for the shimmer loading sweep.
            static let shimmerCycle: Double = 1.5
            /// Breathing glow expand/contract cycle duration.
            static let breathingGlowCycle: Double = 4.0
            /// Duration for rolling number transitions.
            static let rollingNumber: Double = 0.35
            /// Auto-retry delay for network error states (seconds).
            static let autoRetryDelay: Double = 8.0

            // Morning Brief
            static let morningBriefEntrance: Double = 0.5
            static let morningBriefCardReveal: Double = 0.3

            // Context Tracks
            static let flowStateStepTransition: Double = 0.35

            // Body Music
            static let adaptationWaveDrawSpeed: Double = 2.0  // seconds to draw full wave
        }

        // MARK: Bounce Constants

        enum Bounce {
            static let press: Double = 0.0
            static let standard: Double = 0.0
            static let sheet: Double = 0.15
            /// Slight overshoot for session transition bloom.
            static let sessionTransition: Double = 0.20
        }

        // MARK: Spring Presets (raw values)

        enum Spring {
            /// Snappy spring with subtle overshoot for the session start bloom.
            static var sessionTransition: SwiftUI.Animation {
                AnimationConstants.resolve(
                    .spring(duration: Duration.sessionTransition, bounce: Bounce.sessionTransition)
                )
            }

            /// Gentle spring for staggered card reveals.
            static var staggeredReveal: SwiftUI.Animation {
                AnimationConstants.resolve(
                    .spring(duration: Duration.standard, bounce: Bounce.standard)
                )
            }
        }

        // MARK: Orb Scale Constants

        enum OrbScale {
            static let breathingMin: CGFloat = 0.95
            static let breathingMax: CGFloat = 1.05
            static let restingFraction: CGFloat = 0.25 // 25% of screen width
            static let peakFraction: CGFloat = 0.40     // 40% of screen width
        }

        // MARK: Frequency-Synced Visualization

        /// Constants for deriving visual animation timing from the live
        /// beat frequency. The Orb and Wavelength use these to create
        /// mathematically accurate visualizations synced to the audio.
        enum FrequencySync {
            /// Numerator for inverse-proportional Orb cycle duration:
            /// `cycleDuration = scaleFactor / beatFrequency`, clamped.
            /// At 10 Hz → 4.0s, 15 Hz → 2.67s, 20 Hz → 2.0s.
            static let orbScaleFactor: Double = 40.0
            /// Minimum Orb breathing cycle duration (seconds).
            /// Prevents seizure-risk flashing at high beat frequencies.
            static let orbCycleDurationMin: Double = 1.0
            /// Maximum Orb breathing cycle duration (seconds).
            /// Prevents imperceptibly slow motion at very low beat frequencies.
            static let orbCycleDurationMax: Double = 8.0
            /// Divisor for mapping beat frequency to visible wave cycles:
            /// `cycleCount = beatFrequency / waveScaleFactor`.
            /// At 10 Hz → 2.0 cycles, 15 Hz → 3.0, 30 Hz → 6.0.
            static let waveScaleFactor: Double = 5.0
            /// Minimum visible wave cycles across screen width.
            static let waveCycleCountMin: CGFloat = 0.5
            /// Maximum visible wave cycles across screen width.
            static let waveCycleCountMax: CGFloat = 7.0
        }
    }
}

// MARK: - Audio

extension Theme {

    enum Audio {

        // MARK: Fallback Sample Rate

        /// Universal fallback sample rate when hardware reports invalid (Hz).
        static let fallbackSampleRate: Double = 44100.0

        // MARK: Per-Sample Smoothing

        /// Amplitude envelope smoothing time in seconds (per-sample exponential).
        static let amplitudeSmoothingTime: Double = 0.005
        /// Frequency parameter smoothing time in seconds (per-sample exponential).
        static let frequencySmoothingTime: Double = 0.020

        // MARK: Reverb

        /// Wet/dry mix percentage for the global reverb send.
        static let reverbWetDryMix: Float = 15.0

        // MARK: Harmonics (Triangle Wave Character)

        enum Harmonics {
            /// 2nd harmonic gain relative to fundamental (dB).
            static let secondGainDB: Double = -8.0
            /// 3rd harmonic gain relative to fundamental (dB).
            static let thirdGainDB: Double = -14.0
        }

        // MARK: LFO Amplitude Modulation

        enum LFO {
            /// Three unsynchronised LFO rates (Hz).
            static let rate1: Double = 0.07
            static let rate2: Double = 0.13
            static let rate3: Double = 0.29
            /// Depth of each LFO in dB (peak deviation from unity).
            static let depthDB: Double = 2.0
        }

        // MARK: Carrier Drift

        enum CarrierDrift {
            /// Maximum drift from nominal carrier (Hz).
            static let maxHz: Double = 1.5
            /// Random acceleration applied per drift update.
            static let accel: Double = 0.003
            /// Mean-reversion coefficient pulling drift toward zero.
            static let meanReversion: Double = 0.05
            /// Velocity damping per drift update.
            static let damping: Double = 0.98
            /// Seconds between drift updates (~50 ms).
            static let updateInterval: Double = 0.05
        }

        // MARK: Fade Durations

        enum Fade {
            /// Amplitude ramp-to-zero duration before engine stop (seconds).
            static let stopDuration: TimeInterval = 0.1
        }

        // MARK: Slew Rate Limits

        enum SlewRate {
            /// Maximum beat frequency change in Hz per second.
            static let beatFrequencyMax: Double = 0.3
            /// Maximum carrier frequency change in Hz per second.
            static let carrierFrequencyMax: Double = 2.0
            /// Maximum amplitude change per second [0..1].
            static let amplitudeMax: Double = 0.02
            /// Maximum ambient level change per second [0..1].
            static let ambientLevelMax: Double = 0.03
            /// Maximum melodic level change per second [0..1].
            static let melodicLevelMax: Double = 0.03
            /// Maximum harmonic content change per second [0..1].
            static let harmonicContentMax: Double = 0.02
        }

        // MARK: EMA Alphas (Biometric Smoothing)

        enum EMA {
            /// Fast EMA alpha — responsive (~2.5s effective window).
            static let fast: Double = 0.4
            /// Slow EMA alpha — stable (~10s effective window).
            static let slow: Double = 0.1
        }

        // MARK: Mode Defaults

        enum ModeDefaults {

            enum Focus {
                static let carrierFrequencyMin: Double = 300
                static let carrierFrequencyMax: Double = 450
                static let carrierFrequencyInitial: Double = 375
                static let beatFrequencyMin: Double = 6
                static let beatFrequencyMax: Double = 18
                static let beatFrequencyInitial: Double = 14
                static let sigmoidSteepness: Double = 6.0
                static let sigmoidMidpoint: Double = 0.4
            }

            enum Relaxation {
                static let carrierFrequencyMin: Double = 150
                static let carrierFrequencyMax: Double = 250
                static let carrierFrequencyInitial: Double = 200
                static let beatFrequencyMin: Double = 8
                static let beatFrequencyMax: Double = 12
                static let beatFrequencyInitial: Double = 10
                static let sigmoidSteepness: Double = 4.0
                static let sigmoidMidpoint: Double = 0.4
            }

            enum Sleep {
                static let carrierFrequencyMin: Double = 100
                static let carrierFrequencyMax: Double = 200
                static let carrierFrequencyInitial: Double = 150
                static let beatFrequencyStart: Double = 6
                static let beatFrequencyEnd: Double = 2
                /// HR_normalized midpoint above which sleep descent is slowed.
                static let elevationMidpoint: Double = 0.5
                /// Scale factor mapping HR above midpoint to 0-1 range.
                static let elevationScale: Double = 2.0
                /// How much the elevation factor blends back toward start freq.
                static let elevationBlendFactor: Double = 0.5
                /// Duration over which the sleep ramp completes, in seconds.
                static let rampDuration: Double = 25 * 60 // 25 minutes
            }

            /// Energize: beta-range entrainment with POSITIVE feedback.
            /// HR rising → beat frequency rises (opposite of Focus).
            enum Energize {
                static let carrierFrequencyMin: Double = 400
                static let carrierFrequencyMax: Double = 600
                static let carrierFrequencyInitial: Double = 500
                static let beatFrequencyMin: Double = 14
                static let beatFrequencyMax: Double = 30
                static let beatFrequencyInitial: Double = 20
                /// Positive sigmoid: higher steepness drives quicker ramp-up.
                static let sigmoidSteepness: Double = 5.0
                /// Midpoint shifted right — response kicks in above 50% HR range.
                static let sigmoidMidpoint: Double = 0.5
            }
        }

        // MARK: Safety — Energize Guardrails

        /// Hard limits that protect the user during Energize sessions.
        /// The adaptive engine MUST respect these ceilings and will
        /// auto-transition to cool-down or terminate when breached.
        enum Safety {
            /// Maximum BPM above the user's resting HR before throttling.
            static let hrCeilingAboveBaseline: Double = 15.0
            /// Absolute HR hard stop — session ends immediately.
            static let hrHardStopBPM: Double = 130.0
            /// Fraction of age-predicted max HR (220 - age) triggering hard stop.
            static let hrHardStopFractionOfMax: Double = 0.75
            /// Minimum RMSSD (ms) — below this HRV floor, session auto-cools.
            static let hrvFloor: Double = 20.0
            /// Fractional HRV crash threshold (30% drop from session baseline).
            static let hrvCrashThreshold: Double = 0.30
            /// Maximum allowed HR acceleration (BPM per 60 seconds).
            static let hrRateOfChangeLimit: Double = 5.0
            /// Maximum Energize session length (minutes).
            static let maxSessionMinutes: Double = 30.0
            /// Mandatory cool-down ramp at session end (minutes).
            static let coolDownMinutes: Double = 5.0
            /// Warm-up ramp at session start (minutes).
            static let warmUpMinutes: Double = 3.0
            /// End of ramp phase (minutes from session start).
            /// Adaptive engine engages at warmUp end, ramp continues to this mark.
            static let rampPhaseEndMinutes: Double = 8.0
            /// Minimum cool-down duration when user taps stop (minutes).
            /// Even forced stop plays at least this much cool-down.
            static let minimumForcedCoolDownMinutes: Double = 2.0
            /// Warm-up start beat frequency — alpha range (Hz).
            static let warmUpStartFrequency: Double = 10.0
            /// Warm-up end beat frequency — low beta (Hz).
            static let warmUpEndFrequency: Double = 14.0
            /// Target beta range lower bound (Hz) — biometric-driven during ramp/sustain.
            static let targetBetaMin: Double = 18.0
            /// Target beta range upper bound (Hz) — biometric-driven during ramp/sustain.
            static let targetBetaMax: Double = 25.0
            /// Resting frequency target at end of cool-down (Hz).
            static let coolDownRestingFrequency: Double = 8.0
            /// Melodic layer BPM lower bound during sustain phase.
            static let sustainMelodicBPMMin: Double = 120.0
            /// Melodic layer BPM upper bound during sustain phase.
            static let sustainMelodicBPMMax: Double = 130.0
        }

        // MARK: Sleep Detection

        /// Thresholds for detecting sleep onset during Sleep-mode sessions.
        /// When sustained low HR + calm state is detected, the session
        /// auto-stops with a graceful audio fade.
        enum SleepDetection {
            /// Absolute HR ceiling (BPM) — HR must stay below this to count
            /// toward sleep detection. Conservative default for most adults.
            static let hrCeilingBPM: Double = 55.0

            /// Duration (seconds) the user must remain in calm state with
            /// HR below `hrCeilingBPM` before triggering auto-stop.
            /// 3 minutes = 180 seconds.
            static let sustainedCalmDurationSeconds: TimeInterval = 180.0
        }

        // MARK: Control System

        enum Control {
            /// Proportional gain for feedback controller.
            static let kp: Double = 0.1
            /// Feedforward gain for feedback controller.
            static let kff: Double = 0.5
            /// Carrier modulation range driven by HR trend.
            static let carrierTrendModulation: Double = 50
            /// Carrier trend divisor for tanh mapping.
            static let carrierTrendDivisor: Double = 5.0
        }

        // MARK: Amplitude Mapping

        enum Amplitude {
            /// Binaural amplitude range (dB-derived linear).
            static let binauralMin: Double = 0.25  // ~ -12 dB
            static let binauralMax: Double = 0.50  // ~ -6 dB
            /// Ambient texture level range.
            static let ambientAtCalm: Double = 0.8
            static let ambientAtPeak: Double = 0.3
            /// Default binaural volume multiplier [0...1].
            static let defaultBinauralVolume: Double = 1.0
        }

        // MARK: Trend Detection

        enum TrendDetection {
            /// Deadband in BPM — trend magnitudes below this are "stable".
            static let deadband: Double = 2.0
            /// Acceleration threshold for artifact/sudden-event flagging.
            static let accelerationThreshold: Double = 5.0
        }

        // MARK: Artifact Rejection

        enum ArtifactRejection {
            /// Maximum BPM change from last smoothed value before a sample
            /// is rejected as a motion artifact.
            static let thresholdBPM: Double = 30.0
        }

        // MARK: State Classification Hysteresis

        enum Hysteresis {
            static let band: Double = 0.03
            static let minDwellTime: Double = 5.0 // seconds
        }

        // MARK: HR Normalization Zones

        enum HRZone {
            static let calmMax: Double = 0.20
            static let focusedMax: Double = 0.45
            static let elevatedMax: Double = 0.70
            // Peak: 0.70 – 1.00
        }

        // MARK: Control Loop

        enum ControlLoop {
            /// Tick interval in seconds (10 Hz).
            static let intervalSeconds: TimeInterval = 0.1
        }

        // MARK: Data Dropout

        enum DataDropout {
            /// Seconds without data before freezing current parameters.
            static let freezeTimeoutSeconds: TimeInterval = 10.0
            /// Seconds without data before drifting toward neutral.
            static let driftTimeoutSeconds: TimeInterval = 60.0
        }

        // MARK: Neutral Defaults (used during data loss)

        enum Neutral {
            static let beatFrequency: Double = 10.0
            static let carrierFrequency: Double = 400.0
            static let amplitude: Double = 0.5
            static let ambientLevel: Double = 0.5
            static let melodicLevel: Double = 0.5
            static let harmonicContent: Double = 0.3
        }

        // MARK: Population Defaults (first session, no history)

        enum PopulationDefaults {
            /// Default resting heart rate (BPM).
            static let restingHR: Double = 72.0
            /// Default max heart rate (BPM) when age is unknown.
            static let maxHR: Double = 185.0
        }

        // MARK: Physiological Validation

        /// Hard bounds for rejecting implausible heart rate readings.
        /// Values outside this range are sensor noise, motion artifacts,
        /// or initialization transients — never real human heart rates.
        enum PhysiologicalRange {
            /// Minimum plausible resting heart rate (BPM).
            static let hrMin: Double = 30.0
            /// Maximum plausible heart rate (BPM).
            static let hrMax: Double = 220.0
        }

        // MARK: Secondary Mappings

        enum SecondaryMapping {
            /// Binaural amplitude = base + scale * (1 - (2*hr - 1)^2)
            static let binauralAmplitudeBase: Double = 0.3
            static let binauralAmplitudeScale: Double = 0.5
            /// Ambient level = base - scale * HR_normalized
            static let ambientLevelBase: Double = 0.8
            static let ambientLevelScale: Double = 0.5
            /// Harmonic content = base + scale * HR_normalized
            static let harmonicContentBase: Double = 0.1
            static let harmonicContentScale: Double = 0.6

            /// Melodic level: focus/relaxation base + inverted-parabola scale
            static let melodicFocusBase: Double = 0.4
            static let melodicFocusScale: Double = 0.4
            /// Melodic level: sleep base - fade scale
            static let melodicSleepBase: Double = 0.6
            static let melodicSleepScale: Double = 0.3
            /// Melodic level: energize base + inverted-parabola scale
            static let melodicEnergizeBase: Double = 0.5
            static let melodicEnergizeScale: Double = 0.3
        }

        // MARK: - Ambient Layer

        /// Crossfade duration (seconds) when switching ambient beds.
        /// Also used for the ambient stop fade-out.
        static let ambientCrossfadeDuration: TimeInterval = 3.0

        /// Timer step interval (seconds) for crossfade envelopes.
        /// Shared by both ambient and melodic crossfade timers.
        /// ~30 fps update rate for smooth volume ramps.
        static let crossfadeStepInterval: TimeInterval = 1.0 / 30.0

        /// Supported audio file extensions for ambient beds, searched in order.
        static let supportedAmbientFileExtensions: [String] = ["caf", "aac", "m4a", "wav"]

        // MARK: - Melodic Layer

        /// Crossfade duration (seconds) when transitioning between melodic loops.
        /// Per Tech-MelodicLayer.md: 10-15 seconds. Slow enough to feel like
        /// natural musical evolution, not track-switching.
        static let melodicCrossfadeDuration: TimeInterval = 12.0

        /// Maximum number of concurrent melodic sounds the selector should return.
        static let melodicMaxConcurrentSounds: Int = 3

        // MARK: - Sound Library

        /// Filename (without extension) of the bundled sound catalog JSON.
        static let soundCatalogFileName: String = "sounds"

        /// File extension of the bundled sound catalog.
        static let soundCatalogFileExtension: String = "json"

        // MARK: - Sound Selection Ranges (per Mode)

        // Focus: moderate presence, masks distractions without itself distracting.
        static let focusEnergyRange: ClosedRange<Double> = 0.3...0.5
        static let focusBrightnessRange: ClosedRange<Double> = 0.3...0.5
        static let focusDensityRange: ClosedRange<Double> = 0.2...0.4

        // Relaxation: calming, not engaging.
        static let relaxEnergyRange: ClosedRange<Double> = 0.1...0.3
        static let relaxBrightnessRange: ClosedRange<Double> = 0.2...0.4
        static let relaxDensityRange: ClosedRange<Double> = 0.1...0.3

        // Sleep: barely there, approaching silence.
        static let sleepEnergyRange: ClosedRange<Double> = 0.0...0.2
        static let sleepBrightnessRange: ClosedRange<Double> = 0.0...0.2
        static let sleepDensityRange: ClosedRange<Double> = 0.0...0.1

        // Energize: HIGHEST energy and brightness of any mode.
        // Bright, driving, rhythmically active textures.
        static let energizeEnergyRange: ClosedRange<Double> = 0.5...0.8
        static let energizeBrightnessRange: ClosedRange<Double> = 0.5...0.8
        static let energizeDensityRange: ClosedRange<Double> = 0.3...0.6

        // MARK: - Energize Mode — Instrument, Scale, and Tempo Preferences

        /// Preferred instruments for Energize mode (rhythmic instruments).
        static let energizePreferredInstruments: Set<Instrument> = [.percussion, .piano, .guitar]

        /// Preferred musical scales for Energize mode.
        static let energizePreferredScales: Set<String> = ["major", "lydian"]

        /// Preferred tempo range for Energize mode (BPM).
        /// NOT arrhythmic — tempo matters for energy.
        static let energizeTempoRange: ClosedRange<Double> = 110...135

        // MARK: - Energize Mode — Biometric Adaptation Scoring

        /// When HR is rising (user is activating), MAINTAIN current energizing
        /// sounds — they are working. This weight rewards same-energy sounds.
        static let energizeRisingHRMaintainWeight: Double = 0.8

        /// When HR is falling (user is flagging), shift to HIGHER energy sounds
        /// to counteract the drop. This weight boosts high-energy candidates.
        static let energizeFallingHRBoostWeight: Double = 1.0

        /// During cool-down phase, shift to lower-energy sounds.
        /// Crossfade toward relaxation-adjacent content.
        static let energizeCoolDownEnergyTarget: Double = 0.3

        /// Score bonus for sounds matching preferred Energize instruments.
        static let energizeInstrumentBonus: Double = 0.3

        /// Score bonus for sounds matching preferred Energize scales.
        static let energizeScaleBonus: Double = 0.2

        /// Score bonus for sounds within the preferred Energize tempo range.
        static let energizeTempoBonus: Double = 0.25

        // MARK: - Sound Selection Scoring Weights

        /// Weight applied to instrument preference match in scoring.
        static let instrumentScoreWeight: Double = 1.0
        /// Weight applied to energy proximity in scoring.
        static let energyScoreWeight: Double = 1.5
        /// Weight applied to brightness proximity in scoring.
        static let brightnessScoreWeight: Double = 0.8
        /// Weight applied to density proximity in scoring.
        static let densityScoreWeight: Double = 0.8

        /// Default instrument preference weight when user has no explicit preference.
        static let defaultInstrumentWeight: Double = 0.5
        /// Default energy preference when user has no per-mode preference.
        static let defaultEnergyPreference: Double = 0.5

        /// Bonus added to a sound's score per session in which it produced
        /// good biometric outcomes.
        static let successBonusPerSession: Double = 0.05
        /// Maximum cumulative success bonus (prevents runaway favorites).
        static let successBonusCap: Double = 0.5

        /// Weight for biometric-alignment scoring (elevated state prefers calm sounds).
        static let biometricAlignmentWeight: Double = 0.6
        /// Weight for mood-alignment scoring (wired mood prefers calm sounds).
        static let moodAlignmentWeight: Double = 0.4

        // MARK: - Stem Audio Layer (AI-Generated Content)

        /// Tokens for the biometric-adaptive stem mixing system.
        /// Per-stem volumes are interpolated between biometric states
        /// using the HR_normalized value from the adaptation engine.
        enum StemMix {

            /// Exponential smoothing alpha for per-stem volume changes.
            /// 0.05 at 10 Hz update rate = ~200ms settling time.
            static let volumeSmoothingAlpha: Float = 0.05

            /// Update interval for stem volume adjustments (seconds).
            /// Matches the biometric control loop rate (10 Hz).
            static let updateInterval: TimeInterval = 0.1

            /// Crossfade duration when switching between stem packs (seconds).
            static let packCrossfadeDuration: TimeInterval = 8.0

            /// Ambient layer volume reduction when stems are active.
            /// Stems contain their own ambient texture, so the dedicated
            /// ambient bed is reduced to avoid muddiness.
            static let ambientVolumeWithStems: Double = 0.3

            // MARK: Focus Mode Stem Volumes

            enum Focus {
                static let calm     = StemVolumeTargets(pads: 0.8, texture: 0.7, bass: 0.6, rhythm: 0.4)
                static let focused  = StemVolumeTargets(pads: 0.9, texture: 0.5, bass: 0.7, rhythm: 0.3)
                static let elevated = StemVolumeTargets(pads: 1.0, texture: 0.3, bass: 0.7, rhythm: 0.1)
                static let peak     = StemVolumeTargets(pads: 1.0, texture: 0.2, bass: 0.5, rhythm: 0.0)
            }

            // MARK: Relaxation Mode Stem Volumes

            enum Relaxation {
                static let calm     = StemVolumeTargets(pads: 1.0, texture: 0.8, bass: 0.5, rhythm: 0.2)
                static let focused  = StemVolumeTargets(pads: 0.9, texture: 0.6, bass: 0.5, rhythm: 0.2)
                static let elevated = StemVolumeTargets(pads: 0.8, texture: 0.4, bass: 0.6, rhythm: 0.0)
                static let peak     = StemVolumeTargets(pads: 0.7, texture: 0.2, bass: 0.6, rhythm: 0.0)
            }

            // MARK: Sleep Mode Stem Volumes

            enum Sleep {
                static let calm     = StemVolumeTargets(pads: 0.6, texture: 0.4, bass: 0.8, rhythm: 0.0)
                static let focused  = StemVolumeTargets(pads: 0.5, texture: 0.3, bass: 0.7, rhythm: 0.0)
                static let elevated = StemVolumeTargets(pads: 0.4, texture: 0.2, bass: 0.6, rhythm: 0.0)
                static let peak     = StemVolumeTargets(pads: 0.3, texture: 0.1, bass: 0.5, rhythm: 0.0)
            }

            // MARK: Energize Mode Stem Volumes (Opposite Polarity)

            enum Energize {
                static let calm     = StemVolumeTargets(pads: 0.5, texture: 0.6, bass: 0.7, rhythm: 0.6)
                static let focused  = StemVolumeTargets(pads: 0.6, texture: 0.7, bass: 0.8, rhythm: 0.7)
                static let elevated = StemVolumeTargets(pads: 0.7, texture: 0.8, bass: 0.9, rhythm: 0.9)
                static let peak     = StemVolumeTargets(pads: 0.8, texture: 0.9, bass: 1.0, rhythm: 1.0)
            }

            // MARK: Defaults

            /// Default stem volume when no biometric data is available.
            /// Applied as the initial value before the first control loop tick.
            static let defaultFullVolume: Float = 1.0

            /// Default rhythm stem volume (slightly reduced from full).
            static let defaultRhythmVolume: Float = 0.8

            // MARK: Content Pack Storage

            /// Maximum local storage for downloaded content packs (MB).
            static let maxStorageMB: Int = 500

            /// Bytes per megabyte — named constant for storage calculations.
            static let bytesPerMB: Int64 = 1_048_576

            /// Minimum packs to retain per mode during LRU eviction.
            static let minPacksPerMode: Int = 1

            /// Simulated generation delay for mock service (seconds).
            static let mockGenerationDelaySeconds: TimeInterval = 2.0

            // MARK: Mock Defaults (Development)

            /// Default tag values for mock-generated content packs.
            enum MockDefaults {
                static let focusEnergy: Double = 0.4
                static let relaxEnergy: Double = 0.25
                static let sleepEnergy: Double = 0.1
                static let energizeEnergy: Double = 0.7
                static let focusBrightness: Double = 0.5
                static let sleepBrightness: Double = 0.2
                static let defaultWarmth: Double = 0.7
                static let defaultTempo: Double = 80
            }

            // MARK: Prompt Builder Thresholds

            /// Thresholds for SonicProfilePromptBuilder descriptor selection.
            enum PromptThresholds {
                static let warmthHigh: Double = 0.65
                static let warmthLow: Double = 0.35
                static let energyHigh: Double = 0.7
                static let energyLow: Double = 0.3
                static let densityHigh: Double = 0.7
                static let densityLow: Double = 0.3

                /// Default energy per mode when user has no preference.
                static let defaultFocusEnergy: Double = 0.4
                static let defaultRelaxEnergy: Double = 0.25
                static let defaultSleepEnergy: Double = 0.1
                static let defaultEnergizeEnergy: Double = 0.7
            }
        }
    }
}

// MARK: - Wavelength Visual Constants

extension Theme {

    enum Wavelength {
        /// Stroke width for the wavelength line.
        enum Stroke {
            static let standard: CGFloat = 2.5
            static let elevated: CGFloat = 3.0
            /// Energize — bolder stroke for warmer, more energetic feel.
            static let energize: CGFloat = 3.5
            /// Compact variant — thinner for mini player.
            static let compact: CGFloat = 1.5
        }

        /// Visual amplitude (vertical displacement in points).
        enum Amplitude {
            static let calm: CGFloat = 14
            static let focused: CGFloat = 22
            static let elevated: CGFloat = 30
            static let peak: CGFloat = 38

            /// Energize — higher amplitude, tighter oscillation.
            static let energize: CGFloat = 34

            /// Compact variant — scaled for mini player (~24pt strip).
            enum Compact {
                static let calm: CGFloat = 4
                static let focused: CGFloat = 6
                static let elevated: CGFloat = 8
                static let peak: CGFloat = 10
                static let energize: CGFloat = 9
            }
        }

        /// Approximate cycles across screen width.
        enum Frequency {
            static let calm: CGFloat = 1
            static let focused: CGFloat = 2
            static let elevated: CGFloat = 3.5
            static let peak: CGFloat = 5.5

            /// Energize — tighter waves (more cycles visible).
            static let energize: CGFloat = 4.5

            /// Sleep — slow, gentle wave.
            static let sleep: CGFloat = 0.6
        }

        /// Opacity for each biometric state.
        enum StateOpacity {
            static let calm: Double = 0.55
            static let focused: Double = 0.65
            static let elevated: Double = 0.70
            static let peak: Double = 0.75

            /// Energize — warm, prominent visibility.
            static let energize: Double = 0.70
        }

        /// Gaussian blur applied to the line for a soft-light look.
        static let blurRadius: CGFloat = 1.0

        /// Display-link frame rate for wavelength scroll animation (Hz).
        static let frameRate: Double = 60.0

        /// Blur radius for the compact (mini player) variant.
        static let compactBlurRadius: CGFloat = 0.5
    }
}

// MARK: - Mini Player Constants

extension Theme {

    enum MiniPlayer {
        /// Height of the wavelength strip inside the mini player.
        static let wavelengthHeight: CGFloat = 24
        /// Height of the active indicator dot.
        static let indicatorSize: CGFloat = 6
        /// Height of the waveform progress bar.
        static let waveformHeight: CGFloat = 20
        /// Vertical padding inside the mini player card.
        static let verticalPadding: CGFloat = 10
    }
}

// MARK: - Orb Visual Constants

extension Theme {

    enum Orb {
        /// Opacity by biometric state.
        enum StateOpacity {
            static let calm: Double = 0.20
            static let focused: Double = 0.30
            static let elevated: Double = 0.35
            static let peak: Double = 0.40
        }

        /// Pulse cycle duration by biometric state (seconds).
        enum PulseCycle {
            static let calm: Double = 6.0
            static let focused: Double = 4.0
            static let elevated: Double = 3.0
            static let peak: Double = 2.0

            /// Energize mode — faster pulse matching ~80 BPM cadence.
            static let energize: Double = 0.75
        }

        // MARK: Energize Visual Tokens

        /// Energize-specific orb visual parameters.
        enum Energize {
            /// Scale oscillation range -- slightly wider than other modes.
            static let scaleMin: CGFloat = 0.95
            static let scaleMax: CGFloat = 1.08

            // MARK: Particles (Rising Embers)

            /// Number of particles visible at any time (range).
            static let particleCountMin: Int = 15
            static let particleCountMax: Int = 25
            /// Lifetime per particle in seconds (range).
            static let particleLifetimeMin: Double = 2.0
            static let particleLifetimeMax: Double = 3.0
            /// Particle diameter in points (range).
            static let particleSizeMin: CGFloat = 2.0
            static let particleSizeMax: CGFloat = 4.0
            /// Base upward velocity in points per second.
            static let particleVelocityY: CGFloat = -40.0
            /// Maximum random horizontal drift in points per second.
            static let particleDriftX: CGFloat = 12.0
            /// Base spawn interval in seconds (adjusted by beat frequency).
            static let particleBaseSpawnInterval: Double = 0.12

            // MARK: Corona (Warm Glow)

            /// Scale oscillation range for the outer corona layer.
            static let coronaScaleMin: CGFloat = 1.0
            static let coronaScaleMax: CGFloat = 1.15
            /// Corona animation cycle duration in seconds.
            static let coronaCycleSeconds: Double = 2.0
            /// Corona opacity multiplier relative to orb opacity.
            static let coronaOpacityMultiplier: Double = 0.25

            // MARK: Color Shimmer

            /// Shimmer cycle duration in seconds (amber to gold micro-oscillation).
            static let shimmerCycleSeconds: Double = 3.0
            /// Gold color used as the shimmer target.
            static let shimmerGoldHex: UInt = 0xFFD700
        }
    }
}

// MARK: - Card Wave (Home Screen Mode Cards)

extension Theme {

    /// Visual tokens for the sine wave animation on home screen mode cards.
    /// Cycle counts are derived from each mode's representative Hz midpoint
    /// divided by a scale factor, matching the brand identity SVG.
    /// Dual-layer rendering: bloom (blurred, subtle) + crisp (sharp, prominent).
    enum CardWave {

        // MARK: Cycle Counts per Mode

        /// Visible sine wave cycles across card width.
        /// Derived from mode midpoint Hz: Sleep ~4 Hz, Relaxation ~9.5 Hz,
        /// Focus ~15 Hz, Energize ~24 Hz, each divided by scaleFactor.
        enum Cycles {
            /// Sleep (delta/theta) — slowest, widest wave. ~4 Hz / 4 = 1 cycle.
            static let sleep: Double = 1.0
            /// Relaxation (alpha) — gentle wave. ~9.5 Hz / 4 ≈ 1.5 cycles.
            static let relaxation: Double = 1.5
            /// Focus (beta) — medium frequency. ~15 Hz / 4 ≈ 2.5 cycles.
            static let focus: Double = 2.5
            /// Energize (high-beta/gamma) — tightest, fastest. ~24 Hz / 4 ≈ 5 cycles.
            static let energize: Double = 5.0
            /// Scale factor: Hz midpoint → visible cycles for compact grid cards.
            static let scaleFactor: Double = 4.0
            /// Density multiplier for carousel cards (wider canvas needs more cycles).
            /// Carousel shows base cycles * this factor.
            static let carouselDensity: Double = 6.0
        }

        // MARK: Amplitude

        /// Wave amplitude as a fraction of card height (0–1).
        /// Matches the SVG's proportional displacement (~12% of canvas).
        static let amplitudeFraction: CGFloat = 0.12

        // MARK: Bloom Layer (Soft Glow — SVG filter="waveSoft")

        enum Bloom {
            /// Stroke width for the blurred bloom layer.
            static let strokeWidth: CGFloat = 3.5
            /// Opacity of the bloom layer.
            static let opacity: Double = 0.35
            /// Gaussian blur radius applied to the bloom layer.
            static let blurRadius: CGFloat = 4.0
        }

        // MARK: Crisp Layer (Sharp Line — SVG primary stroke)

        enum Crisp {
            /// Stroke width for the sharp foreground line.
            static let strokeWidth: CGFloat = 1.8
            /// Opacity of the crisp layer.
            static let opacity: Double = 0.55
        }

        // MARK: Edge Envelope

        /// The edge fade uses a sine envelope: `sin(normalizedX * π)`.
        /// `fadeExponent` controls how quickly edges dissolve (higher = sharper).
        /// Matches the SVG's linearGradient edgeFade (12%–88% visible).
        static let fadeExponent: Double = 1.0

        // MARK: Animation

        /// Phase scroll speed in radians per second. Slow, graceful drift.
        static let scrollSpeed: Double = 0.4
        /// Target frame rate for TimelineView rendering.
        static let frameRate: Double = 30.0

        // MARK: Aurora Drift Render (Canvas internals)

        enum AuroraDrift {
            /// Pillar half-width (pts) for vertical glow bars behind wave peaks.
            static let pillarHalfWidth: CGFloat = 20
            /// Maximum number of blurred pillar rects per frame (performance cap).
            static let maxPillars: Int = 12
            /// Gaussian blur for pillar glow bars.
            static let pillarBlur: CGFloat = 25
            /// Gaussian blur for the undulating wash fill.
            static let washBlur: CGFloat = 16
            /// Edge overbleed (pts) — how far wave paths extend past canvas bounds.
            static let edgeOverbleed: CGFloat = 5
            /// Pixel stride for wave path sampling (pts per segment).
            static let sampleStride: CGFloat = 2
            /// Segment width for wave line rendering (pts).
            static let segmentWidth: CGFloat = 3

            // MARK: Amplitude & Phase

            /// Wave amplitude as a fraction of canvas height.
            static let amplitudeFraction: Double = 0.18
            /// Phase scroll speed multiplier (radians per second).
            static let phaseSpeed: Double = 0.8
            /// Color palette shift speed (cycles per second).
            static let colorShiftSpeed: Double = 0.04

            // MARK: Pillar Rendering

            /// Exponent applied to abs(waveVal) for pillar intensity falloff.
            static let intensityExponent: Double = 1.5
            /// Base opacity multiplied by intensity for each pillar.
            static let pillarOpacity: Double = 0.035
            /// Color offset per pillar index in palette space.
            static let colorOffsetPerPillar: Double = 0.12

            // MARK: Wash Fill

            /// Amplitude scale for the wash fill relative to main amplitude.
            static let washAmplitudeScale: Double = 0.9
            /// Phase scale for wash fill relative to main phase.
            static let washPhaseScale: Double = 0.7
            /// Fill opacity for the wash layer.
            static let washFillOpacity: Double = 0.025

            // MARK: Wave Line Passes (blur, opacity, lineWidth)

            /// Render passes for wave lines — outermost glow to innermost crisp.
            static let wavePasses: [(blur: CGFloat, opacity: Double, lineWidth: CGFloat)] = [
                (12, 0.045, 6), (5, 0.08, 2.5), (0, 0.28, 1.5), (0, 0.5, 0.7)
            ]

            // MARK: Wave Line Color

            /// Color time multiplier along the wave x-axis.
            static let colorTimeMultiplier: Double = 1.5

            // MARK: Harmonic Overlay

            /// Amplitude of the harmonic overtone relative to main amplitude.
            static let harmonicAmplitudeScale: Double = 0.1
            /// Frequency multiplier for the harmonic (relative to base cycles).
            static let harmonicFrequencyMultiplier: Double = 4.0
            /// Phase expression: ps * harmonicPhaseScale + harmonicPhaseOffset.
            static let harmonicPhaseScale: Double = 1.4
            /// Constant phase offset added to harmonic wave.
            static let harmonicPhaseOffset: Double = 0.8
            /// Stroke opacity for the harmonic line.
            static let harmonicStrokeOpacity: Double = 0.04
            /// Color time offset for harmonic vs. main wave (palette space).
            static let harmonicColorOffset: Double = 0.5
            /// Stroke width scale for harmonic relative to glassStroke.
            static let harmonicStrokeScale: Double = 0.5
        }
    }
}

// MARK: - Carousel

extension Theme {

    enum Carousel {
        /// Card dimensions for mode selection carousel.
        /// Width fills screen minus standard page margins on each side.
        /// Height maintains a 3:4 (width:height) aspect ratio.
        @MainActor static var cardWidth: CGFloat { Layout.screenEstimate - (Spacing.pageMargin * 2) }
        @MainActor static var cardHeight: CGFloat { cardWidth * 4 / 3 }
        /// Fraction of card height the aurora wave graphic occupies (centered).
        static let auroraHeightRatio: CGFloat = 0.4
        /// Minimum drag distance to trigger page change.
        static let dragThreshold: CGFloat = 60
        /// Background gradient end radius relative to screen height.
        static let gradientRadiusScale: CGFloat = 0.6

        // MARK: Card State

        /// Scale applied to inactive (non-current) cards.
        static let inactiveScale: CGFloat = 0.9
        /// Opacity applied to inactive (non-current) cards.
        static let inactiveOpacity: Double = 0.35
        /// Perspective value for 3D card flip effect.
        static let flipPerspective: CGFloat = 0.4

        // MARK: Animations

        /// Spring animation for carousel snap (page change + drag settle).
        static var snapAnimation: SwiftUI.Animation { .spring(duration: 0.5, bounce: 0.12) }
        /// Spring animation for card flip (front ↔ back).
        static var flipAnimation: SwiftUI.Animation { .spring(duration: 0.6, bounce: 0.15) }
    }

    enum Interaction {
        /// Scale factor when a button/card is pressed.
        static let pressScale: CGFloat = 0.92
        /// Opacity when pressed (used for play buttons).
        static let pressOpacity: Double = 0.85
        /// Small optical offset for centered play icon (px).
        static let playIconOffset: CGFloat = 2
        /// Speed multiplier for ambient symbol pulse on mode icons (0.3 = subtle, slow).
        static let symbolPulseSpeed: Double = 0.3
    }
}

// MARK: - Shader Effect Tokens

extension Theme {

    enum Shader {

        enum WaterRipple {
            /// Ripple propagation speed (1.0 = normal).
            static let speed: Double = 3.0
            /// Distortion amplitude (0.0 = none, 5.0 = dramatic).
            static let strength: Double = 2.0
            /// Ripple ring density.
            static let frequency: Double = 10.0
            /// Maximum sample offset for distortion shader.
            static let maxSampleOffset: CGFloat = 10
        }

        enum OrganicNoise {
            /// Background noise brightness (0.0-1.0). Keep subtle.
            static let intensity: Double = 0.06
        }

        enum CircleGlow {
            /// Peak brightness of pulsing rings.
            static let brightness: Double = 0.8
            /// Ring expansion speed.
            static let speed: Double = 2.0
            /// Visible ring count.
            static let density: Double = 40.0
        }

        enum Shimmer {
            /// Sweep propagation speed (lower = slower ambient sweep).
            static let speed: Double = 0.3
            /// Width of the shimmer band (0.05-0.3).
            static let width: Double = 0.12
            /// Peak shimmer brightness.
            static let intensity: Double = 0.15
        }
    }

    enum Particles {
        /// Default birth rate for ambient session particles.
        static let ambientBirthRate: Double = 30.0
        /// Particle lifetime range (seconds).
        static let lifetimeMin: Double = 1.5
        static let lifetimeMax: Double = 3.0
        /// Particle size range (points).
        static let sizeMin: CGFloat = 4
        static let sizeMax: CGFloat = 12
        /// Blur radius applied to each particle.
        static let blurRadius: CGFloat = 3
        /// Halo frame multiplier relative to orb diameter.
        static let haloFrameMultiplier: CGFloat = 1.6
        /// Vortex emitter ellipse shape radius (normalized 0-1).
        static let emitterShapeRadius: Double = 0.3
        /// Base particle travel speed (normalized).
        static let speed: Double = 0.1
        /// Speed variation range (normalized).
        static let speedVariation: Double = 0.05
        /// Base particle size (normalized).
        static let size: Double = 0.3
        /// Particle size variation range (normalized).
        static let sizeVariation: Double = 0.4
        /// Particle size multiplier at end of life (fade-shrink).
        static let sizeMultiplierAtDeath: Double = 0.1
        /// Color ramp tail opacity for ambient particles.
        static let colorRampTailOpacity: Double = 0.3
        /// Orb size interpolation fraction for focused state.
        static let focusedSizeFraction: CGFloat = 0.33
        /// Orb size interpolation fraction for elevated state.
        static let elevatedSizeFraction: CGFloat = 0.66
        /// Delay before restarting breathing animation (seconds).
        static let breathingRestartDelay: TimeInterval = 0.05
        /// Birth rate multiplier per biometric state.
        static let calmMultiplier: Double = 0.6
        static let focusedMultiplier: Double = 1.0
        static let elevatedMultiplier: Double = 1.4
        static let peakMultiplier: Double = 1.8
    }

    enum HDRGlow {
        /// Glow intensity for the orb (0.0-1.0 for public GlowGetter target).
        static let orbIntensity: Double = 0.7
        /// Glow intensity during Energize mode (brighter).
        static let energizeIntensity: Double = 0.9
    }

    enum Health {
        /// Minimum completed sessions before showing real impact data.
        static let minimumScoredSessions: Int = 3

        /// Score thresholds for color coding (green / neutral / warning).
        static let scoreThresholdGood: Double = 0.6
        static let scoreThresholdFair: Double = 0.4

        /// Minimum HR/HRV delta before showing a trend arrow.
        static let trendDeltaThreshold: Double = 1.0

        /// Sleep stage bar segment spacing (points).
        static let stageBarSpacing: CGFloat = 2
        /// Minimum sleep stage bar segment width (points).
        static let stageBarMinSegmentWidth: CGFloat = 3

        /// Radial glow radius multiplier for accent card glows.
        static let cardGlowRadiusLarge: CGFloat = 3
        static let cardGlowRadiusMedium: CGFloat = 2

        /// Seed/demo values shown before the user has real session data.
        enum Seed {
            static let impactScore: Double = 0.73
            static let hrDeltaBPM: Int = 8
            static let sparkline: [Double] = [0.52, 0.58, 0.61, 0.65, 0.63, 0.70, 0.68, 0.73, 0.75, 0.73]
        }

        /// Fallback lookback period (days) when no recent readings exist.
        static let fallbackLookbackDays: Int = 7

        /// Fallback biometric values when no HealthKit data available.
        enum Defaults {
            static let restingHR: Double = 68
            static let hrv: Double = 42
            static let sleepHours: Double = 7.5
        }
    }

    enum Nebula {
        // Deep layer — largest, most blurred (furthest depth)
        static let deepSize: CGFloat = 360
        static let deepBlur: CGFloat = 90
        static let deepOpacity: Double = 0.28

        // Mid layer
        static let midSize: CGFloat = 240
        static let midBlur: CGFloat = 60
        static let midOpacity: Double = 0.30

        // Near layer — smallest, sharpest (closest depth)
        static let nearSize: CGFloat = 140
        static let nearBlur: CGFloat = 40
        static let nearOpacity: Double = 0.22

        // Film grain overlay opacity
        static let grainOpacity: Double = 0.12

        // Per-mode orb positions (0-1 normalized to screen)
        enum Sleep {
            static let x: CGFloat = 0.15
            static let y: CGFloat = 0.08
        }
        enum Energize {
            static let x: CGFloat = 0.88
            static let y: CGFloat = 0.75
            static let sizeRatio: CGFloat = 0.8
        }
        enum Focus {
            static let x: CGFloat = 0.30
            static let y: CGFloat = 0.45
        }
        enum Relaxation {
            static let x: CGFloat = 0.78
            static let y: CGFloat = 0.22
            static let sizeRatio: CGFloat = 0.75
        }
        enum Accent {
            static let x: CGFloat = 0.50
            static let y: CGFloat = 0.55
        }
    }

    // MARK: - Mode Card Visuals

    /// Tokens for the premium mode card treatment on the home screen.
    enum ModeCard {
        /// Ambient glow opacity beneath each card. Subtle — felt, not seen.
        static let ambientGlowOpacity: Double = 0.12
        /// Ambient glow blur radius (points).
        static let ambientGlowBlurRadius: CGFloat = 30
        /// Shadow color opacity for floating depth.
        static let shadowOpacity: Double = 0.15
        /// Shadow blur radius (points).
        static let shadowRadius: CGFloat = 20
        /// Shadow Y offset (points).
        static let shadowY: CGFloat = 8
        /// Left border gradient width — fades from mode color to transparent.
        static let borderGradientWidth: CGFloat = 12
        /// Scale on press for depth feel.
        static let pressedScale: CGFloat = 0.97
        /// Shadow radius when pressed (shrinks for "depress" effect).
        static let pressedShadowRadius: CGFloat = 8
        /// Shadow Y offset when pressed.
        static let pressedShadowY: CGFloat = 4
        /// Width of the colored accent bar on science caveat cards.
        static let caveatBarWidth: CGFloat = 3
        /// Scale for card entrance animation (0.95 = slight zoom-in on appear).
        static let entranceScale: CGFloat = 0.95
    }

    enum SF2 {
        /// Maximum simultaneous voices for the SF2 renderer.
        static let voiceCount: Int = 32

        /// Interval between generative note events (seconds).
        static let noteInterval: TimeInterval = 0.8

        /// Jitter applied to note interval for humanization (±seconds).
        static let noteIntervalJitter: TimeInterval = 0.3

        /// Note velocity range.
        static let velocityMin: UInt8 = 50
        static let velocityMax: UInt8 = 90

        /// Note duration range (seconds).
        static let durationMin: TimeInterval = 1.5
        static let durationMax: TimeInterval = 6.0

        /// Rest probability between phrases (0-1).
        static let restProbability: Double = 0.3

        /// Maximum concurrent notes (polyphony cap for generative layer).
        static let maxConcurrentNotes: Int = 4

        /// Volume fade-in duration when SF2 layer starts (seconds).
        static let fadeInDuration: TimeInterval = 3.0

        /// Volume fade-out duration when SF2 layer stops (seconds).
        static let fadeOutDuration: TimeInterval = 5.0

        /// Per-mode note density multipliers. Higher = more notes per beat.
        /// Energize needs much higher density for rhythmic, driving feel.
        enum Density {
            static let focus: Double = 1.0      // Steady, moderate
            static let relaxation: Double = 0.7 // Sparse, gentle
            static let sleep: Double = 0.3      // Very sparse
            static let energize: Double = 2.2   // Dense, driving rhythm
        }

        /// Per-mode note duration multipliers (applied to durationMin/Max).
        /// Sleep = long sustaining pads, Energize = short punchy melodic notes.
        enum DurationMultiplier {
            static let focus: Double = 1.0      // 1.5-6.0s (moderate sustain)
            static let relaxation: Double = 1.5 // 2.25-9.0s (flowing)
            static let sleep: Double = 2.5      // 3.75-15.0s (long pads)
            static let energize: Double = 0.3   // 0.45-1.8s (short, rhythmic, punchy)
        }

        /// SoundFont preset indices per mode (index into the loaded SF2 file).
        /// GM (General MIDI) program numbers for GeneralUser GS SoundFont.
        /// These select the instrument timbre for each mode.
        enum PresetIndex {
            // Focus: Electric Piano — clean, steady, non-distracting
            static let focusPad: Int = 4      // GM: Electric Piano 1 (Rhodes)
            // Relaxation: Warm Pad — spacious, floating, Lydian character
            static let relaxationStrings: Int = 89 // GM: Warm Pad
            // Sleep: Choir Pad — dark, enveloping, formless
            static let sleepPad: Int = 91     // GM: Pad 4 (Choir)
            // Energize: Sawtooth Lead — warm, full, musical (NOT Square Lead which is harsh)
            static let energizeBells: Int = 81 // GM: Sawtooth Lead (warm, usable for melodies)
            // Additional presets for layering
            static let strings: Int = 49      // GM: String Ensemble 1
            static let acousticPiano: Int = 0 // GM: Acoustic Grand Piano
            static let pad: Int = 88          // GM: New Age Pad
            // Bass: Electric Bass (finger) — round, musical bass tone
            static let bass: Int = 33         // GM: Electric Bass (finger)
        }

        /// Per-mode MIDI octave ranges.
        /// Based on FunctionalMusicTheory.md research:
        /// - Focus: narrow mid-range for habituation (C3-G4)
        /// - Relaxation: warm mid range (C3-C5)
        /// - Sleep: low register (C2-C3), high notes activate alertness
        /// - Energize: wide range for drama (C3-C6)
        enum OctaveRange {
            static let focus: ClosedRange<Int> = 3...4
            static let relaxation: ClosedRange<Int> = 3...4
            static let sleep: ClosedRange<Int> = 2...3
            static let energize: ClosedRange<Int> = 3...6
        }

        /// Per-mode phrase lengths (notes before rest probability kicks in).
        /// Energize plays long continuous phrases for driving momentum.
        /// Sleep plays very short fragments with long silences.
        enum PhraseLength {
            static let focus: Int = 4       // 4-note phrases, steady
            static let relaxation: Int = 3  // 3-note phrases, gentle
            static let sleep: Int = 2       // 2-note fragments, sparse
            static let energize: Int = 8    // 8-note phrases, driving runs
        }

        /// Voice leading parameters.
        enum VoiceLeading {
            /// Probability of picking from nearest candidates vs. any candidate.
            static let nearProbability: Double = 0.7
            /// Number of nearest candidates to consider.
            static let nearCount: Int = 3
            /// Jitter range for first note selection (±semitones from center).
            static let firstNoteJitter: Int = 2
        }

        /// Per-biometric-state velocity offsets.
        enum VelocityOffset {
            static let calm: Int = -10
            static let focused: Int = 0
            static let elevated: Int = 5
            static let peak: Int = 10
        }

        /// Per-biometric-state density modifiers.
        enum BiometricDensity {
            static let calm: Double = 0.7
            static let focused: Double = 1.0
            static let elevated: Double = 1.2
            static let peak: Double = 0.8
        }

        /// Minimum interval floor between notes (seconds).
        static let minimumNoteInterval: TimeInterval = 0.1

        /// Bundled SoundFont resource name (without extension).
        static let resourceName: String = "BioNaural-Melodic"

        /// Bundled SoundFont file extension.
        static let resourceExtension: String = "sf2"

        /// Default neutral biometric values for initial sound selection.
        enum NeutralBiometrics {
            static let heartRate: Double = 70
            static let hrv: Double = 50
            /// Default minimum session length for calendar free window detection.
            static let defaultSessionMinutes: Int = 15
        }
    }
}

// MARK: - Feature Layout

extension Theme {

    /// Layout constants for the Morning Brief feature.
    enum MorningBrief {
        /// Maximum number of stressors shown in the brief card.
        static let maxVisibleStressors: Int = 3
        /// Height of the compact brief card on the home tab.
        static let compactCardHeight: CGFloat = 72
    }

    /// Layout constants for Sonic Memory feature.
    enum SonicMemory {
        /// Height of parameter visualization bars.
        static let parameterBarHeight: CGFloat = 6
        /// Maximum description length before truncation.
        static let maxDescriptionLength: Int = 200
        /// Number of example prompts shown during input.
        static let examplePromptCount: Int = 3
    }

    /// Layout constants for Context Tracks feature.
    enum ContextTracks {
        /// Maximum active Flow State tracks allowed.
        static let maxActiveFlowStateTracks: Int = 5
        /// Number of steps in the Flow State setup flow.
        static let setupStepCount: Int = 3
        /// Step indicator dot size.
        static let stepDotSize: CGFloat = 8
        /// Step indicator dot spacing.
        static let stepDotSpacing: CGFloat = 12
        /// Duration options for Flow State tracks (minutes).
        static let durationOptions: [Int] = [30, 60, 90, 120]
    }

    /// Layout constants for Body Music feature.
    enum BodyMusic {
        /// Height of the mini adaptation wave in library cards.
        static let miniWaveHeight: CGFloat = 32
        /// Height of the full adaptation wave in detail view.
        static let fullWaveHeight: CGFloat = 120
        /// Stroke width for the adaptation wave line.
        static let waveStrokeWidth: CGFloat = 1.5
        /// Stroke width for the full detail wave.
        static let fullWaveStrokeWidth: CGFloat = 2.0
    }

    /// Layout constants for the Pre-Event Session Card.
    enum PreEvent {
        /// Size of the orb in the pre-event card.
        static let orbSize: CGFloat = 80
    }

    /// Layout constants for Notification Settings.
    enum NotificationSettings {
        /// Pre-event notification timing options (minutes before event).
        static let prepTimingOptions: [Int] = [60, 90, 120]
    }
}

// MARK: - Sound DNA

extension Theme {

    /// Configuration tokens for Sound DNA audio feature extraction
    /// and Sonic Profile integration. All analysis parameters, normalization
    /// ranges, and learning rates are centralized here.
    enum SoundDNA {

        // MARK: Audio Capture

        /// Sample rate for captured audio (Hz).
        static let captureSampleRate: Double = 44100.0

        /// Duration of audio to capture for analysis (seconds).
        static let captureDurationSeconds: Double = 15.0

        /// FFT window size in samples.
        static let fftSize: Int = 4096

        /// Hop size between FFT windows in samples.
        static let fftHopSize: Int = 2048

        // MARK: Feature Normalization Ranges

        /// Expected spectral centroid range for normalization to [0, 1].
        /// Music typically falls between 500 Hz (dark) and 5000 Hz (bright).
        static let spectralCentroidRange: ClosedRange<Double> = 500.0...5000.0

        /// Expected RMS energy range for normalization (linear amplitude).
        static let rmsEnergyRange: ClosedRange<Double> = 0.001...0.5

        /// BPM detection range. Values outside this are discarded as errors.
        static let bpmDetectionRange: ClosedRange<Double> = 40.0...220.0

        /// Warmth is derived from the ratio of energy below this frequency
        /// to total energy. Higher ratio = warmer.
        static let warmthCutoffHz: Double = 1000.0

        /// Density is derived from spectral flatness.
        /// Flatness > this threshold = more dense/noise-like.
        static let densityFlatnessThreshold: Double = 0.3

        // MARK: Confidence Thresholds

        /// Confidence assigned to analysis of clean preview audio.
        static let previewAnalysisConfidence: Double = 0.85

        /// Confidence assigned to analysis of preprocessed mic audio.
        static let micAnalysisConfidence: Double = 0.55

        /// Minimum confidence required to integrate a sample into the profile.
        static let minimumIntegrationConfidence: Double = 0.3

        // MARK: Profile Integration

        /// Learning rate for integrating Sound DNA features into SoundProfile.
        /// Controls how much each new sample shifts existing preferences.
        static let profileLearningRate: Double = 0.25

        /// Maximum number of Sound DNA samples that contribute to the profile.
        /// Older samples beyond this count are still stored but don't affect
        /// current preferences (recency bias).
        static let maxActiveProfileSamples: Int = 10

        /// Weight decay applied to older samples. Each position further from
        /// the most recent sample multiplies by this factor.
        static let sampleRecencyDecay: Double = 0.85

        // MARK: ShazamKit

        /// Duration of audio to pass to ShazamKit for identification (seconds).
        /// Shorter than full capture — ShazamKit is fast.
        static let shazamMatchDurationSeconds: Double = 8.0

        // MARK: Preprocessing

        /// High-pass filter cutoff for mic capture noise reduction (Hz).
        static let highPassCutoffHz: Double = 80.0

        // MARK: Key Detection

        /// Minimum frequency for chromagram pitch class mapping (Hz).
        static let keyDetectionMinFreqHz: Double = 60.0

        /// Maximum frequency for chromagram pitch class mapping (Hz).
        static let keyDetectionMaxFreqHz: Double = 5000.0

        /// Krumhansl-Schmuckler major key profile (C through B).
        static let majorKeyProfile: [Double] = [
            6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
            2.52, 5.19, 2.39, 3.66, 2.29, 2.88
        ]

        /// Krumhansl-Schmuckler minor key profile (C through B).
        static let minorKeyProfile: [Double] = [
            6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
            2.54, 4.75, 3.98, 2.69, 3.34, 3.17
        ]

        // MARK: Tempo Detection

        /// Minimum number of onset strength frames required for tempo estimation.
        static let minOnsetFramesForTempo: Int = 4

        // MARK: Fallback Values

        /// Default spectral centroid when analysis fails (Hz).
        static let fallbackSpectralCentroidHz: Double = 1000.0

        /// Neutral default value for all normalized features [0-1].
        static let defaultFeatureValue: Double = 0.5

        // MARK: Feature Display

        /// Threshold below which a normalized feature is labeled "low".
        static let featureLabelLowThreshold: Double = 0.33

        /// Threshold above which a normalized feature is labeled "high".
        static let featureLabelHighThreshold: Double = 0.66

        /// Maximum number of Sonic Memories to display in Your Sound view.
        static let maxDisplayedSonicMemories: Int = 5

        // MARK: ShazamKit

        /// Timeout for ShazamKit identification attempt (seconds).
        static let shazamTimeoutSeconds: Double = 10.0

        // MARK: UI

        /// Duration of the listening animation cycle (seconds).
        static let listeningAnimationDuration: Double = 2.0

        /// Per-bar stagger delay in the listening animation (seconds).
        static let listeningAnimationBarDelay: Double = 0.15

        /// Delay before starting analysis after capture completes (seconds).
        static let analysisStartDelay: Double = 0.3
    }
}

// MARK: - Core Haptics

extension Theme {

    enum Haptics {

        // MARK: Engine

        /// Whether the haptic engine should reset on app foreground.
        static let resetOnForeground: Bool = true

        // MARK: Breathing Pattern (iPhone)

        /// Duration of one inhale-exhale haptic cycle (seconds).
        /// Matches standard resonant breathing (~5.5 breaths/min).
        static let breathingCycleDuration: TimeInterval = 11.0

        /// Inhale phase as a fraction of the breathing cycle.
        static let breathingInhaleRatio: Double = 0.4

        /// Number of haptic events during the inhale ramp-up.
        static let breathingInhaleTapCount: Int = 4

        /// Number of haptic events during the exhale ramp-down.
        static let breathingExhaleTapCount: Int = 5

        /// Haptic intensity at the peak of inhale (0...1).
        static let breathingPeakIntensity: Float = 0.7

        /// Haptic intensity at the trough of exhale (0...1).
        static let breathingTroughIntensity: Float = 0.15

        /// Haptic sharpness for breathing events (0...1).
        /// Lower = rounder, softer feel.
        static let breathingSharpness: Float = 0.3

        // MARK: Beat Pulse

        /// Intensity for the beat-synced transient pulse (0...1).
        static let beatPulseIntensity: Float = 0.5

        /// Sharpness for beat-synced transient (0...1).
        /// Higher = more percussive, more noticeable.
        static let beatPulseSharpness: Float = 0.6

        /// Duration of each beat pulse transient (seconds).
        static let beatPulseDuration: TimeInterval = 0.08

        // MARK: Session Events

        /// Intensity for the session-start haptic pattern (0...1).
        static let sessionStartIntensity: Float = 0.8

        /// Sharpness for the session-start pattern (0...1).
        static let sessionStartSharpness: Float = 0.5

        /// Duration of the session-start crescendo pattern (seconds).
        static let sessionStartDuration: TimeInterval = 0.6

        /// Intensity for the session-end success pattern (0...1).
        static let sessionEndIntensity: Float = 0.9

        /// Sharpness for the session-end pattern (0...1).
        static let sessionEndSharpness: Float = 0.4

        /// Duration of the session-end celebration pattern (seconds).
        static let sessionEndDuration: TimeInterval = 1.0

        // MARK: Adaptation Event

        /// Intensity for subtle adaptation-change haptic (0...1).
        static let adaptationIntensity: Float = 0.35

        /// Sharpness for adaptation-change haptic (0...1).
        static let adaptationSharpness: Float = 0.4

        // MARK: Button

        /// Intensity for button press haptic (0...1).
        static let buttonIntensity: Float = 0.5

        /// Sharpness for button press haptic (0...1).
        static let buttonSharpness: Float = 0.5
    }
}

// MARK: - Color Initializers

// MARK: - Supabase Configuration

extension Theme {

    enum Supabase {
        static let url = "https://nkqgenwbqtnqeqvmokdq.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rcWdlbndicXRucWVxdm1va2RxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0ODQ2NDksImV4cCI6MjA5MTA2MDY0OX0.cvpywlnuPPs4gU_YDFzkdo-8d0PzCSecaUwUiS-DGlU"
    }
}

// MARK: - Transition Coordinator Tokens

extension Theme {

    enum Transition {

        // MARK: Slew Rates (max parameter change per second)

        /// Maximum beat frequency change rate (Hz/sec). Default mode.
        static let beatFrequencySlewRate: Double = 0.3
        /// Halved slew rate for sleep mode during deep sleep.
        static let beatFrequencySlewRateSleep: Double = 0.15
        /// Maximum stem volume change rate per second (default).
        static let stemVolumeSlewRate: Float = 0.05
        /// Halved rate for sleep mode.
        static let stemVolumeSlewRateSleep: Float = 0.02
        /// Maximum carrier frequency change rate (Hz/sec).
        static let carrierFrequencySlewRate: Double = 5.0

        // MARK: Dwell Times

        /// Minimum seconds in a biometric state before triggering audio changes.
        static let minimumDwellSeconds: TimeInterval = 5.0
        /// Extended dwell for sleep mode — avoid false triggers.
        static let minimumDwellSecondsSleep: TimeInterval = 30.0
        /// Minimum gap between stem pack crossfade and MIDI register change.
        static let crossParameterGapSeconds: TimeInterval = 10.0

        // MARK: Smoothing

        /// Smoothstep duration for MIDI density transitions.
        static let midiDensitySmoothSeconds: TimeInterval = 3.0
        /// Exponential smoothing alpha for stem volumes (10Hz update rate).
        static let stemVolumeSmoothingAlpha: Float = 0.05
        /// Carrier frequency transition duration via tanh curve.
        static let carrierTransitionSeconds: TimeInterval = 4.0

        // MARK: Sleep Protections

        /// HR threshold above resting that defines "deep sleep" state.
        static let deepSleepHRThresholdAboveResting: Double = 5.0
        /// Duration of sustained low HR to confirm deep sleep.
        static let deepSleepConfirmationSeconds: TimeInterval = 300.0 // 5 min
        /// HR spike magnitude that triggers restlessness response.
        static let restlessnessHRSpike: Double = 15.0
        /// Cooldown after restless period before resuming normal adaptation.
        static let restlessCooldownSeconds: TimeInterval = 120.0 // 2 min

        // MARK: Crossfade Timing

        /// Stem pack crossfade duration (equal-power).
        static let stemPackCrossfadeSeconds: TimeInterval = 8.0
        /// Melodic content crossfade duration.
        static let melodicCrossfadeSeconds: TimeInterval = 12.0
        /// Minimum time a new state must persist before triggering content crossfade.
        static let contentCrossfadeDwellSeconds: TimeInterval = 30.0

        // MARK: Micro-Variation (Long Sessions)

        /// Period range for stem volume drift LFOs (seconds).
        static let volumeDriftPeriodMin: TimeInterval = 120.0
        static let volumeDriftPeriodMax: TimeInterval = 300.0
        /// Amplitude of stem volume drift (additive).
        static let volumeDriftAmplitude: Float = 0.05
        /// Interval between variation set crossfades during long sessions.
        static let variationCrossfadeIntervalSeconds: TimeInterval = 1200.0 // 20 min

        // MARK: Generation

        /// Default stem duration for ACE-STEP generation.
        static let defaultStemDurationSeconds: Int = 60
        /// Max wait time for generation job polling.
        static let maxGenerationWaitSeconds: Int = 300
        /// Polling interval for generation job status.
        static let generationPollIntervalSeconds: TimeInterval = 5.0
    }
}

// MARK: - Mode-Specific Instrumentation Rules

extension Theme {

    /// Governs which instruments, sounds, and textures are permitted
    /// per mode. The generation pipeline (ACE-STEP prompts), SoundSelector,
    /// and GenerativeMIDIEngine all consult these rules.
    enum ModeInstrumentation {

        // MARK: Sleep — Ambient pads and nature ONLY

        /// Sleep mode: warm pads, deep drones, nature textures.
        /// NO percussion, NO rhythmic elements, NO melodic instruments.
        static let sleepAllowedInstruments: Set<Instrument> = [.pad, .texture]
        static let sleepProhibitedInstruments: Set<Instrument> = [.percussion, .guitar, .bass, .piano]
        /// Sleep uses NO rhythm stem.
        static let sleepAllowRhythmStem: Bool = false
        /// Sleep: very dark, warm, formless textures only.
        static let sleepMaxBrightness: Double = 0.3
        static let sleepMaxDensity: Double = 0.2
        /// Sleep generation prompt suffix.
        static let sleepPromptSuffix = "no drums, no percussion, no rhythm, no melody, no vocals, formless, dark, warm"

        // MARK: Relaxation — Ambient pads, gentle strings, nature sounds

        /// Relaxation: warm pads, gentle strings, nature textures.
        /// NO percussion, NO driving rhythm, NO sharp transients.
        static let relaxationAllowedInstruments: Set<Instrument> = [.pad, .texture, .strings]
        static let relaxationProhibitedInstruments: Set<Instrument> = [.percussion, .guitar]
        static let relaxationAllowRhythmStem: Bool = false
        static let relaxationMaxBrightness: Double = 0.5
        static let relaxationMaxDensity: Double = 0.4
        static let relaxationPromptSuffix = "no drums, no percussion, no rhythm, no vocals, gentle, flowing, spacious"

        // MARK: Focus — Minimal, steady, can include subtle rhythm

        /// Focus: pads, subtle piano, light texture. Optional minimal rhythm.
        /// Percussion allowed but should be subtle (soft clicks, minimal hi-hat).
        static let focusAllowedInstruments: Set<Instrument> = [.pad, .texture, .piano, .percussion]
        static let focusProhibitedInstruments: Set<Instrument> = [] // None prohibited
        static let focusAllowRhythmStem: Bool = true
        static let focusMaxBrightness: Double = 0.7
        static let focusMaxDensity: Double = 0.6
        static let focusPromptSuffix = "steady, minimal, subtle, no vocals, clean, focused"

        // MARK: Energize — Full instrumentation, rhythmic, driving

        /// Energize: full palette including percussion, bass, guitar, piano.
        /// Tabla, drumset, bass guitar, electric guitar all welcome.
        static let energizeAllowedInstruments: Set<Instrument> = [
            .pad, .texture, .piano, .strings, .guitar, .bass, .percussion,
        ]
        static let energizeProhibitedInstruments: Set<Instrument> = [] // None prohibited
        static let energizeAllowRhythmStem: Bool = true
        static let energizeMaxBrightness: Double = 1.0
        static let energizeMaxDensity: Double = 1.0
        static let energizePromptSuffix = "rhythmic, driving, uplifting, energetic, no vocals"

        // MARK: Lookup Helpers

        /// Returns the set of allowed instruments for the given mode.
        static func allowedInstruments(for mode: FocusMode) -> Set<Instrument> {
            switch mode {
            case .sleep:       return sleepAllowedInstruments
            case .relaxation:  return relaxationAllowedInstruments
            case .focus:       return focusAllowedInstruments
            case .energize:    return energizeAllowedInstruments
            }
        }

        /// Returns instruments explicitly prohibited for the given mode.
        static func prohibitedInstruments(for mode: FocusMode) -> Set<Instrument> {
            switch mode {
            case .sleep:       return sleepProhibitedInstruments
            case .relaxation:  return relaxationProhibitedInstruments
            case .focus:       return focusProhibitedInstruments
            case .energize:    return energizeProhibitedInstruments
            }
        }

        /// Whether the rhythm stem should be included in stem packs for this mode.
        static func allowsRhythmStem(for mode: FocusMode) -> Bool {
            switch mode {
            case .sleep:       return sleepAllowRhythmStem
            case .relaxation:  return relaxationAllowRhythmStem
            case .focus:       return focusAllowRhythmStem
            case .energize:    return energizeAllowRhythmStem
            }
        }

        /// Maximum brightness for generated content in this mode.
        static func maxBrightness(for mode: FocusMode) -> Double {
            switch mode {
            case .sleep:       return sleepMaxBrightness
            case .relaxation:  return relaxationMaxBrightness
            case .focus:       return focusMaxBrightness
            case .energize:    return energizeMaxBrightness
            }
        }

        /// Maximum density for generated content in this mode.
        static func maxDensity(for mode: FocusMode) -> Double {
            switch mode {
            case .sleep:       return sleepMaxDensity
            case .relaxation:  return relaxationMaxDensity
            case .focus:       return focusMaxDensity
            case .energize:    return energizeMaxDensity
            }
        }

        /// Prompt suffix appended to ACE-STEP generation prompts for this mode.
        static func promptSuffix(for mode: FocusMode) -> String {
            switch mode {
            case .sleep:       return sleepPromptSuffix
            case .relaxation:  return relaxationPromptSuffix
            case .focus:       return focusPromptSuffix
            case .energize:    return energizePromptSuffix
            }
        }

        /// Nature sound categories allowed per mode.
        /// Sleep/Relaxation: flowing water, rain, wind, ocean.
        /// Focus: minimal (rain, white noise only).
        /// Energize: none (music is the texture).
        static func allowedNatureSounds(for mode: FocusMode) -> [String] {
            switch mode {
            case .sleep:
                return ["rain", "deep_rain", "ocean", "distant_thunder", "night_forest"]
            case .relaxation:
                return ["flowing_stream", "gentle_wind", "rain", "birdsong", "ocean"]
            case .focus:
                return ["soft_rain", "white_noise", "pink_noise"]
            case .energize:
                return [] // No nature sounds — music provides all texture
            }
        }

        /// Available genre options for the genre picker UI.
        static let genreOptions: [(id: String, label: String)] = [
            ("ambient", "Ambient"),
            ("lofi", "Lo-Fi"),
            ("rock", "Rock"),
            ("hiphop", "Hip Hop"),
            ("jazz", "Jazz"),
            ("blues", "Blues"),
            ("reggae", "Reggae"),
            ("classical", "Classical"),
            ("latin", "Latin"),
            ("electronic", "Electronic"),
        ]
    }
}

// MARK: - Color Initializers

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

    /// Creates an adaptive Color that resolves to `dark` hex in dark mode
    /// and `light` hex in light mode. Uses UIColor's trait-based resolution
    /// so the color updates automatically on appearance change.
    init(adaptive dark: UInt, light: UInt) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}
