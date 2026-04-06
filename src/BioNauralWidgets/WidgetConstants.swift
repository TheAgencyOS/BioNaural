// WidgetConstants.swift
// BioNauralWidgets
//
// Design tokens for the widget extension target. These mirror the main
// app's Theme values so widgets render consistently without importing
// the full Theme system. All values are derived from DesignLanguage.md
// and Theme.swift — no hardcoded magic numbers.
//
// When Theme.swift values change, update these in parallel.

import SwiftUI

// MARK: - WidgetConstants

enum WidgetConstants {

    // MARK: - App Group

    /// App Group identifier shared between the main app and widget extension
    /// for SwiftData container access.
    static let appGroupIdentifier = "group.com.bionaural.shared"

    /// SwiftData store file name within the shared App Group container.
    static let sharedStoreName = "BioNaural.store"

    // MARK: - Mode Hex Values

    /// Raw hex values for mode colors — mirrors Theme.Colors.Hex.
    enum ModeHex {
        /// Focus — Indigo (#5B6ABF)
        static let focus: UInt = 0x5B6ABF
        /// Relaxation — Soft teal (#4EA8A6)
        static let relaxation: UInt = 0x4EA8A6
        /// Sleep — Muted violet (#9080C4)
        static let sleep: UInt = 0x9080C4
        /// Energize — Amber-gold (#F5A623)
        static let energize: UInt = 0xF5A623
        /// Primary accent — Periwinkle (#6E7CF7)
        static let accent: UInt = 0x6E7CF7
        /// Signal calm — Cool teal (#4EA8A6)
        static let signalCalm: UInt = 0x4EA8A6
    }

    // MARK: - Colors

    /// Resolved SwiftUI Colors for widget backgrounds and text.
    /// Dark mode only — widgets always render on the dark canvas.
    enum Colors {
        /// Near-black with blue undertone — primary background.
        static let canvas = Color(hex: 0x080C15)
        /// Cards, elevated surfaces.
        static let surface = Color(hex: 0x111520)
        /// Elevated active states.
        static let surfaceRaised = Color(hex: 0x1A1F2E)
        /// Soft white, never pure #FFF.
        static let textPrimary = Color(hex: 0xE2E6F0)
        /// Secondary labels — 65% opacity on textPrimary base.
        static let textSecondary = Color(hex: 0xE2E6F0).opacity(0.65)
        /// Hints, tertiary info — 40% opacity.
        static let textTertiary = Color(hex: 0xE2E6F0).opacity(0.40)
        /// Cool teal for HR indicator.
        static let signalCalm = Color(hex: ModeHex.signalCalm)
    }

    // MARK: - Opacity

    /// Opacity tokens mirroring Theme.Opacity.
    enum Opacity {
        static let minimal: Double = 0.04
        static let subtle: Double = 0.05
        static let light: Double = 0.10
        static let glassFill: Double = 0.12
        static let accentLight: Double = 0.15
        static let glassStroke: Double = 0.20
        static let medium: Double = 0.30
        static let half: Double = 0.50
        static let accentStrong: Double = 0.60
        static let textSecondary: Double = 0.65
    }

    // MARK: - Spacing

    /// Spacing tokens mirroring Theme.Spacing (8pt grid).
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
    }

    // MARK: - Radius

    /// Corner radius tokens mirroring Theme.Radius.
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    // MARK: - Tracking

    /// Letter spacing tokens mirroring Theme.Typography.Tracking.
    enum Tracking {
        static let uppercase: CGFloat = 1.5
        static let display: CGFloat = 0.5
        static let data: CGFloat = 0.8
    }

    // MARK: - Fonts

    /// Font definitions mirroring Theme.Typography for widget contexts.
    /// Uses SF Mono for data/timer and system font for labels (Satoshi
    /// requires custom font registration in the widget extension bundle).
    enum Fonts {
        /// Display — Light 36pt for hero text.
        static let display: Font = .system(size: 36, weight: .light)
        /// Session timer — SF Mono Light 32pt (matches Theme.Typography.timer).
        static let timer: Font = .system(
            size: 32,
            weight: .light,
            design: .monospaced
        )
        /// Title — Medium 28pt.
        static let title: Font = .system(size: 28, weight: .medium)
        /// Data readout — SF Mono Medium 22pt.
        static let data: Font = .system(
            size: 22,
            weight: .medium,
            design: .monospaced
        )
        /// Headline — Bold 20pt.
        static let headline: Font = .system(size: 20, weight: .bold)
        /// Data small — SF Mono Medium 15pt.
        static let dataSmall: Font = .system(
            size: 15,
            weight: .medium,
            design: .monospaced
        )
        /// Callout — Regular 15pt.
        static let callout: Font = .system(size: 15, weight: .regular)
        /// Caption — Medium 13pt.
        static let caption: Font = .system(size: 13, weight: .medium)
        /// Small — Bold 11pt.
        static let small: Font = .system(size: 11, weight: .bold)
    }

    // MARK: - Small Widget

    enum SmallWidget {
        /// Outer bloom diameter — soft ambient wash.
        static let bloomDiameter: CGFloat = 110
        /// Outer bloom gradient end radius.
        static let bloomRadius: CGFloat = 55
        /// Mid glow diameter.
        static let midGlowDiameter: CGFloat = 64
        /// Mid glow gradient end radius.
        static let midGlowRadius: CGFloat = 32
        /// Bright core diameter.
        static let coreDiameter: CGFloat = 28
        /// Core gradient end radius.
        static let coreRadius: CGFloat = 14
        /// Inner bright point diameter.
        static let hotspotDiameter: CGFloat = 10
    }

    // MARK: - Medium Widget

    enum MediumWidget {
        /// Session mode indicator dot size.
        static let sessionDotSize: CGFloat = 8
        /// Mode pill border width.
        static let pillBorderWidth: CGFloat = 0.5
        /// Glass pill inner highlight opacity.
        static let pillHighlightOpacity: Double = 0.08
        /// Pill icon container size.
        static let pillIconSize: CGFloat = 28
        /// Pill icon corner radius.
        static let pillIconRadius: CGFloat = 8
        /// Summary section mini orb size.
        static let summaryOrbSize: CGFloat = 36
        /// Summary orb bloom size.
        static let summaryOrbBloomSize: CGFloat = 52
    }

    // MARK: - StandBy Widget

    enum StandBy {
        /// Outer ambient wash diameter — fills most of the widget.
        static let ambientWashDiameter: CGFloat = 280
        /// Ambient wash gradient end radius.
        static let ambientWashRadius: CGFloat = 140
        /// Outer bloom diameter.
        static let outerBloomDiameter: CGFloat = 200
        /// Outer bloom gradient end radius.
        static let outerBloomRadius: CGFloat = 100
        /// Mid bloom diameter.
        static let midBloomDiameter: CGFloat = 120
        /// Mid bloom gradient end radius.
        static let midBloomRadius: CGFloat = 60
        /// Core orb diameter.
        static let coreOrbDiameter: CGFloat = 56
        /// Core orb gradient end radius.
        static let coreOrbRadius: CGFloat = 28
        /// Inner hotspot diameter.
        static let hotspotDiameter: CGFloat = 18
        /// Accessory rectangular orb dot size.
        static let accessoryOrbSize: CGFloat = 14
        /// Wavelength decorative line height.
        static let wavelengthHeight: CGFloat = 24
        /// Wavelength horizontal inset.
        static let wavelengthInset: CGFloat = 48
        /// Wavelength stroke width.
        static let wavelengthStroke: CGFloat = 1.5
        /// Wavelength opacity.
        static let wavelengthOpacity: Double = 0.25
    }

    // MARK: - Lock Screen Accessory Widgets

    enum LockScreenAccessory {
        // Circular — multi-layer orb
        /// Outer ring diameter (fits within accessoryCircular bounds).
        static let outerRingDiameter: CGFloat = 48
        /// Outer ring angular gradient stroke width.
        static let outerRingStroke: CGFloat = 1.5
        /// Outer ring opacity.
        static let outerRingOpacity: Double = 0.40
        /// Mid glow diameter.
        static let midGlowDiameter: CGFloat = 32
        /// Mid glow opacity.
        static let midGlowOpacity: Double = 0.50
        /// Core solid circle diameter.
        static let coreDiameter: CGFloat = 14
        /// Core opacity.
        static let coreOpacity: Double = 0.70
        /// Bright hotspot diameter.
        static let hotspotDiameter: CGFloat = 5
        /// Hotspot opacity.
        static let hotspotOpacity: Double = 0.90

        // Rectangular — mini orb + text
        /// Rectangular orb core size.
        static let rectOrbSize: CGFloat = 14
        /// Rectangular orb bloom halo size.
        static let rectOrbBloomSize: CGFloat = 28
        /// Rectangular orb bloom opacity.
        static let rectOrbBloomOpacity: Double = 0.25
        /// Rectangular orb core opacity.
        static let rectOrbCoreOpacity: Double = 0.60
    }

    // MARK: - Nebula Background

    enum Nebula {
        /// Deep layer (furthest) — large, blurred blob.
        static let deepSize: CGFloat = 200
        static let deepBlur: CGFloat = 60
        static let deepOpacity: Double = 0.18

        /// Mid layer.
        static let midSize: CGFloat = 130
        static let midBlur: CGFloat = 40
        static let midOpacity: Double = 0.22

        /// Near layer (closest).
        static let nearSize: CGFloat = 80
        static let nearBlur: CGFloat = 25
        static let nearOpacity: Double = 0.15
    }

    // MARK: - Lock Screen Live Activity

    enum LockScreen {
        /// Thin vertical bar width.
        static let barWidth: CGFloat = 3
        /// Bar height.
        static let barHeight: CGFloat = 40
        /// Small orb playing indicator size.
        static let orbSize: CGFloat = 14
        /// Orb bloom behind playing indicator.
        static let orbBloomSize: CGFloat = 28
        /// Progress arc stroke width.
        static let progressStroke: CGFloat = 2.0
    }

    // MARK: - Dynamic Island

    enum DynamicIsland {
        /// Compact leading orb size.
        static let compactOrbSize: CGFloat = 10
        /// Minimal presentation orb size.
        static let minimalOrbSize: CGFloat = 10
        /// Expanded orb size.
        static let expandedOrbSize: CGFloat = 28
        /// Inset fraction for the solid core inside the bloom orb circle.
        static let orbInsetFraction: CGFloat = 0.2
        /// Expanded bottom wavelength height.
        static let wavelengthHeight: CGFloat = 16
        /// Expanded bottom wavelength stroke.
        static let wavelengthStroke: CGFloat = 1.2
    }

    // MARK: - Timeline

    enum Timeline {
        /// Minutes between widget timeline refreshes.
        static let refreshIntervalMinutes = 30
    }

    // MARK: - Wavelength Path

    /// Generates a sine-wave Path for decorative wavelength accents.
    /// - Parameters:
    ///   - width: Total path width.
    ///   - height: Peak-to-peak amplitude.
    ///   - cycles: Number of full sine cycles.
    /// - Returns: A SwiftUI Path representing the wave.
    static func wavelengthPath(
        width: CGFloat,
        height: CGFloat,
        cycles: CGFloat = 2.0
    ) -> Path {
        Path { path in
            let midY = height / 2
            let amplitude = height / 2
            let stepCount = Int(width)
            guard stepCount > 0 else { return }

            path.move(to: CGPoint(x: 0, y: midY))

            for step in 1...stepCount {
                let x = CGFloat(step)
                let normalizedX = x / width
                let y = midY + amplitude * sin(normalizedX * cycles * 2 * .pi)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

// MARK: - Color Hex Initializer (Widget Target)

/// Extension providing hex-based Color initialization for the widget target.
/// Mirrors the initializer in the main app's Theme.swift.
extension Color {
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
