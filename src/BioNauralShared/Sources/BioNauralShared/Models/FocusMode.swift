import Foundation

/// The four primary session modes supported by BioNaural.
///
/// Each mode defines the binaural beat frequency range, carrier frequency range,
/// and sensible defaults derived from neuroscience research. Color names are
/// resolved by the platform-specific Theme system — this enum only stores the
/// semantic token string.
///
/// - `focus`: Sustained attention and deep work. Low-beta entrainment (12-20 Hz).
/// - `relaxation`: Parasympathetic activation and stress recovery. Alpha range (7-12 Hz).
/// - `sleep`: Sleep-onset preparation. Theta-to-delta ramp (1-8 Hz).
/// - `energize`: Alertness and activation. Beta to high-beta entrainment (14-30 Hz).
public enum FocusMode: String, Codable, CaseIterable, Identifiable, Sendable {

    case focus
    case relaxation
    case sleep
    case energize

    // MARK: - Identifiable

    public var id: String { rawValue }

    // MARK: - Display

    /// A human-readable name suitable for UI labels.
    public var displayName: String {
        switch self {
        case .focus:       return "Focus"
        case .relaxation:  return "Relaxation"
        case .sleep:       return "Sleep"
        case .energize:    return "Energize"
        }
    }

    // MARK: - Frequency Configuration

    /// The binaural beat frequency range (Hz) used during adaptive sessions.
    ///
    /// These ranges are derived from the literature:
    /// - Focus: low-beta 12-20 Hz (Beauchene et al., 2016; Garcia-Argibay, 2019).
    /// - Relaxation: alpha 7-12 Hz (Isik et al., 2017; Palaniappan et al., 2015).
    /// - Sleep: theta-to-delta 1-8 Hz (Abeln et al., 2014; Jirakittayakorn, 2017).
    /// - Energize: beta to high-beta 14-30 Hz (increased alertness and activation).
    public var frequencyRange: ClosedRange<Double> {
        switch self {
        case .focus:       return 12.0...20.0
        case .relaxation:  return 7.0...12.0
        case .sleep:       return 1.0...8.0
        case .energize:    return 14.0...30.0
        }
    }

    /// The carrier (base) frequency range (Hz) for each mode.
    ///
    /// Higher carriers are used for Focus (brighter perception), lower for Sleep
    /// (warmer, more soothing). The adaptive engine selects within this range
    /// based on user preferences and biometric state.
    ///
    /// - Focus: 300-450 Hz
    /// - Relaxation: 150-250 Hz
    /// - Sleep: 100-200 Hz
    /// - Energize: 400-600 Hz (brighter, more alert perception)
    public var carrierFrequencyRange: ClosedRange<Double> {
        switch self {
        case .focus:       return 300.0...450.0
        case .relaxation:  return 150.0...250.0
        case .sleep:       return 100.0...200.0
        case .energize:    return 400.0...600.0
        }
    }

    /// The default binaural beat frequency (Hz) used at session start before
    /// adaptation takes over.
    ///
    /// - Focus: 15 Hz (center of evidence-supported beta range).
    /// - Relaxation: 10 Hz (brain's natural resting alpha peak).
    /// - Sleep: 6 Hz (theta onset, per theta-to-delta protocol).
    /// - Energize: 20 Hz (mid-beta for alertness and activation).
    public var defaultBeatFrequency: Double {
        switch self {
        case .focus:       return 15.0
        case .relaxation:  return 10.0
        case .sleep:       return 6.0
        case .energize:    return 20.0
        }
    }

    /// The default carrier frequency (Hz) used at session start.
    ///
    /// - Focus: 375 Hz (midpoint of carrier range).
    /// - Relaxation: 200 Hz (midpoint of carrier range).
    /// - Sleep: 150 Hz (warm, soothing center per Sleep science doc).
    /// - Energize: 500 Hz (midpoint of carrier range, bright and alert).
    public var defaultCarrierFrequency: Double {
        switch self {
        case .focus:       return 375.0
        case .relaxation:  return 200.0
        case .sleep:       return 150.0
        case .energize:    return 500.0
        }
    }

    // MARK: - Theming

    /// The semantic color token name for this mode.
    ///
    /// This string is resolved by the platform-specific Theme/design token system
    /// into an actual color value. It is never used to construct a color directly.
    public var colorName: String {
        switch self {
        case .focus:       return "focusAccent"
        case .relaxation:  return "relaxationAccent"
        case .sleep:       return "sleepAccent"
        case .energize:    return "energizeAccent"
        }
    }

    /// The SF Symbol name used for mode icons throughout the UI.
    public var systemImageName: String {
        switch self {
        case .focus:       return "brain.head.profile"
        case .relaxation:  return "leaf.fill"
        case .sleep:       return "moon.fill"
        case .energize:    return "bolt.fill"
        }
    }

    /// A short descriptive subtitle shown beneath the mode name on cards.
    public var subtitle: String {
        switch self {
        case .focus:       return "Sustained attention"
        case .relaxation:  return "Calm & de-stress"
        case .sleep:       return "Wind-down to rest"
        case .energize:    return "Wake up & activate"
        }
    }

    /// A human-readable label describing the brainwave frequency band.
    public var frequencyLabel: String {
        switch self {
        case .focus:       return "Beta 14\u{2013}16 Hz"
        case .relaxation:  return "Alpha 8\u{2013}11 Hz"
        case .sleep:       return "Theta\u{2192}Delta 6\u{2192}2 Hz"
        case .energize:    return "Beta 14\u{2013}30 Hz"
        }
    }
}
