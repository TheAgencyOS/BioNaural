// CustomComposition.swift
// BioNaural
//
// SwiftData model storing a user-created sound composition.
// Each composition captures the full audio recipe: brain state,
// soundscape, melodic preferences, reverb, volume mix, and
// session settings. Played back by configuring the AudioEngine
// from these saved values.

import Foundation
import SwiftData
import BioNauralShared

/// A saved custom sound composition created in the Compose tab.
///
/// Stores every parameter needed to reconstruct the audio layers:
/// binaural beat configuration (brain state + frequencies), ambient
/// soundscape (base + detail texture), melodic layer preferences
/// (instruments + character), reverb depth, volume balance, and
/// session settings (duration, adaptive toggle).
@Model
public final class CustomComposition {

    // MARK: - Identity

    /// Unique composition identifier.
    @Attribute(.unique)
    public var id: UUID

    /// User-assigned name (auto-generated default from selections).
    public var name: String

    /// Creation timestamp.
    public var createdDate: Date

    /// Most recent playback timestamp. `nil` if never played.
    public var lastPlayedDate: Date?

    // MARK: - Brain State (Step 1)

    /// The focus mode raw value (focus, relaxation, sleep, energize).
    public var brainState: String

    /// Binaural beat frequency in Hz (default from mode, fine-tunable).
    public var beatFrequency: Double

    /// Carrier frequency in Hz.
    public var carrierFrequency: Double

    // MARK: - Soundscape (Step 2)

    /// Base ambient bed filename (e.g. "rain", "ocean"). `nil` = silence.
    public var ambientBedName: String?

    /// Detail texture overlay filename (e.g. "thunder", "birdsong"). `nil` = none.
    public var detailTextureName: String?

    // MARK: - Melodic Layer (Step 3)

    /// Selected instrument raw values from the `Instrument` enum.
    public var instruments: [String]

    /// Spectral brightness preference. `0.0` = warm, `1.0` = bright.
    public var brightness: Double

    /// Melodic density preference. `0.0` = sparse, `1.0` = dense.
    public var density: Double

    // MARK: - Space & Mix (Step 4)

    /// Reverb wet/dry mix percentage (5-75).
    public var reverbWetDry: Float

    /// Binaural beat volume (0-1).
    public var binauralVolume: Double

    /// Ambient soundscape volume (0-1).
    public var ambientVolume: Double

    /// Melodic layer volume (0-1).
    public var melodicVolume: Double

    // MARK: - Session Settings (Step 5)

    /// Session duration in minutes.
    public var durationMinutes: Int

    /// Whether the session adapts to biometrics via Apple Watch.
    public var isAdaptive: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        createdDate: Date = Date(),
        lastPlayedDate: Date? = nil,
        brainState: String,
        beatFrequency: Double,
        carrierFrequency: Double,
        ambientBedName: String? = nil,
        detailTextureName: String? = nil,
        instruments: [String],
        brightness: Double = 0.5,
        density: Double = 0.3,
        reverbWetDry: Float = 15.0,
        binauralVolume: Double = 0.5,
        ambientVolume: Double = 0.7,
        melodicVolume: Double = 0.55,
        durationMinutes: Int = 25,
        isAdaptive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.lastPlayedDate = lastPlayedDate
        self.brainState = brainState
        self.beatFrequency = beatFrequency
        self.carrierFrequency = carrierFrequency
        self.ambientBedName = ambientBedName
        self.detailTextureName = detailTextureName
        self.instruments = instruments
        self.brightness = brightness
        self.density = density
        self.reverbWetDry = reverbWetDry
        self.binauralVolume = binauralVolume
        self.ambientVolume = ambientVolume
        self.melodicVolume = melodicVolume
        self.durationMinutes = durationMinutes
        self.isAdaptive = isAdaptive
    }

    // MARK: - Convenience

    /// The brain state as a typed `FocusMode` enum value.
    public var focusMode: FocusMode? {
        FocusMode(rawValue: brainState)
    }
}
