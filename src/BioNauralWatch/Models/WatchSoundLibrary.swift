// WatchSoundLibrary.swift
// BioNauralWatch
//
// Maps each FocusMode to bundled audio asset filenames for the ambient and
// melodic layers. Returns nil when assets are not yet bundled — the audio
// engine handles nil gracefully by skipping the layer.
//
// Planned assets per mode:
//
// Focus:
//   - Ambient: pink noise (gentle high-frequency roll-off, reduces distraction)
//   - Melodic: minimal pad (sparse, non-distracting harmonic texture)
//
// Relaxation:
//   - Ambient: ocean waves (rhythmic, parasympathetic activation)
//   - Melodic: warm pad (rich, enveloping harmonic wash)
//
// Sleep:
//   - Ambient: brown noise (deep low-frequency rumble, masks environmental sound)
//   - Melodic: deep drone (sustained, ultra-low harmonic bed)
//
// Energize:
//   - Ambient: white noise (broadband, alertness-promoting)
//   - Melodic: rhythmic pad (pulsing texture that reinforces beta entrainment)

import Foundation
import BioNauralShared

enum WatchSoundLibrary {

    /// Returns the bundle asset filename for the ambient texture layer, or nil
    /// if the asset is not yet bundled.
    ///
    /// - Parameter mode: The active focus mode.
    /// - Returns: Asset filename (without extension) or nil.
    static func ambientAssetName(for mode: FocusMode) -> String? {
        // Assets not yet bundled. When ready, return the filename per mode:
        //   .focus       -> "ambient_pink_noise"
        //   .relaxation  -> "ambient_ocean_waves"
        //   .sleep       -> "ambient_brown_noise"
        //   .energize    -> "ambient_white_noise"
        return nil
    }

    /// Returns the bundle asset filename for the melodic layer, or nil if the
    /// asset is not yet bundled.
    ///
    /// - Parameter mode: The active focus mode.
    /// - Returns: Asset filename (without extension) or nil.
    static func melodicAssetName(for mode: FocusMode) -> String? {
        // Assets not yet bundled. When ready, return the filename per mode:
        //   .focus       -> "melodic_minimal_pad"
        //   .relaxation  -> "melodic_warm_pad"
        //   .sleep       -> "melodic_deep_drone"
        //   .energize    -> "melodic_rhythmic_pad"
        return nil
    }
}
