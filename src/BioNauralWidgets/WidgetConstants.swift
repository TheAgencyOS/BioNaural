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
        /// Soft white, never pure #FFF.
        static let textPrimary = Color(hex: 0xE2E6F0)
        /// Secondary labels — 55% opacity on textPrimary base.
        static let textSecondary = Color(hex: 0xE2E6F0).opacity(0.55)
        /// Hints, tertiary info — 30% opacity.
        static let textTertiary = Color(hex: 0xE2E6F0).opacity(0.30)
        /// Cool teal for HR indicator.
        static let signalCalm = Color(hex: ModeHex.signalCalm)
    }

    // MARK: - Opacity

    /// Opacity tokens mirroring Theme.Opacity.
    enum Opacity {
        static let subtle: Double = 0.05
        static let accentLight: Double = 0.15
        static let medium: Double = 0.30
        static let half: Double = 0.50
        static let accentStrong: Double = 0.60
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
        static let uppercase: CGFloat = 1.0
        static let data: CGFloat = 0.5
    }

    // MARK: - Fonts

    /// Font definitions mirroring Theme.Typography for widget contexts.
    /// Uses SF Mono for data/timer and system font for labels (Satoshi
    /// requires custom font registration in the widget extension bundle).
    enum Fonts {
        /// Session timer — SF Mono Light 32pt (matches Theme.Typography.timer).
        static let timer: Font = .system(
            size: 32,
            weight: .light,
            design: .monospaced
        )
        /// Data readout — SF Mono Regular 20pt.
        static let data: Font = .system(
            size: 20,
            weight: .regular,
            design: .monospaced
        )
        /// Small data — SF Mono Regular 14pt.
        static let dataSmall: Font = .system(
            size: 14,
            weight: .regular,
            design: .monospaced
        )
        /// Headline — Medium 20pt.
        static let headline: Font = .system(size: 20, weight: .medium)
        /// Caption — Regular 13pt.
        static let caption: Font = .system(size: 13, weight: .regular)
        /// Small — Medium 11pt.
        static let small: Font = .system(size: 11, weight: .medium)
    }

    // MARK: - Dynamic Island

    enum DynamicIsland {
        /// Compact leading orb size (8pt per DesignLanguage.md).
        static let compactOrbSize: CGFloat = 8
        /// Minimal presentation orb size.
        static let minimalOrbSize: CGFloat = 8
        /// Expanded orb size (24pt per DesignLanguage.md).
        static let expandedOrbSize: CGFloat = 24
        /// Inset fraction for the solid core inside the bloom orb circle.
        static let orbInsetFraction: CGFloat = 0.2
    }

    // MARK: - Lock Screen

    enum LockScreen {
        /// Thin vertical bar width.
        static let barWidth: CGFloat = 3
        /// Bar height.
        static let barHeight: CGFloat = 36
        /// Small orb playing indicator size.
        static let orbSize: CGFloat = 12
    }

    // MARK: - Small Widget

    enum SmallWidget {
        /// Orb outer diameter (bloom boundary).
        static let orbDiameter: CGFloat = 80
        /// Orb outer radius for gradient.
        static let orbRadius: CGFloat = 40
        /// Bright core diameter.
        static let orbCoreDiameter: CGFloat = 24
    }

    // MARK: - Medium Widget

    enum MediumWidget {
        /// Session mode indicator dot size.
        static let sessionDotSize: CGFloat = 6
        /// Mode pill border width.
        static let pillBorderWidth: CGFloat = 0.5
    }

    // MARK: - StandBy Widget

    enum StandBy {
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
        /// Accessory rectangular orb dot size.
        static let accessoryOrbSize: CGFloat = 12
    }

    // MARK: - Timeline

    enum Timeline {
        /// Minutes between widget timeline refreshes.
        static let refreshIntervalMinutes = 30
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
