// SonicProfilePromptBuilder.swift
// BioNaural
//
// Converts a user's SoundProfile preferences into natural language prompts
// for ACE-Step 1.5 audio generation. Each focus mode has a distinct base
// prompt, and the user's learned preferences (warmth, brightness, tempo,
// key, energy, density) modulate the prompt to produce personalized output.
//
// Example output:
//   "subtle ambient electronic texture, warm, moderate, 88 BPM, A minor,
//    sparse, no drums, no vocals, seamless loop"

import BioNauralShared
import Foundation

/// Builds natural language prompts for AI audio generation from
/// the user's learned `SoundProfile` preferences.
///
/// The builder is stateless — call `buildPrompt(profile:mode:)` with
/// the current profile and mode to get a prompt string suitable for
/// ACE-Step 1.5 or similar text-conditioned audio generation models.
public struct SonicProfilePromptBuilder {

    // MARK: - Public API

    /// Build a generation prompt for the given mode and user profile.
    ///
    /// - Parameters:
    ///   - profile: The user's learned sound preferences.
    ///   - mode: The target focus mode.
    /// - Returns: A natural language prompt string.
    public static func buildPrompt(
        profile: SoundProfile,
        mode: FocusMode
    ) -> String {
        var parts: [String] = []

        // Mode-specific base description.
        parts.append(modeBase(mode))

        // Warmth / brightness from Sound DNA.
        if let warmth = profile.warmthPreference {
            parts.append(warmthDescriptor(warmth))
        }

        // Energy level for this mode.
        let energy = profile.energyPreference[mode.rawValue] ?? defaultEnergy(for: mode)
        parts.append(energyDescriptor(energy))

        // Tempo affinity from Sound DNA.
        if let bpm = profile.tempoAffinity {
            parts.append("\(Int(bpm)) BPM")
        }

        // Key preference from Sound DNA.
        if let key = profile.keyPreference {
            let quality = modeKeyQuality(mode)
            parts.append("\(key) \(quality)")
        }

        // Density preference.
        parts.append(densityDescriptor(profile.densityPreference))

        // Mode-specific instrumentation suffix — enforces what's allowed per mode.
        // Sleep/Relaxation: ambient pads and nature only (no percussion, no rhythm).
        // Focus: minimal, subtle. Energize: full palette, rhythmic.
        parts.append(Theme.ModeInstrumentation.promptSuffix(for: mode))
        parts.append("seamless loop")

        return parts.joined(separator: ", ")
    }

    // MARK: - Mode Base Prompts

    /// Mode-specific base prompts encode the functional music theory research:
    /// each mode has distinct melodic characteristics, instrumental choices,
    /// and rhythmic behavior that serve the therapeutic purpose.
    private static func modeBase(_ mode: FocusMode) -> String {
        switch mode {
        case .focus:
            // Pentatonic major, C, 72 BPM, Rhodes piano, steady repeating patterns
            // Must habituate within 2-3 minutes — predictable, non-distracting
            return "gentle Rhodes electric piano with warm pad, pentatonic melody, steady minimal repeating pattern, lo-fi ambient study music"
        case .relaxation:
            // Lydian mode, G, 55 BPM, warm pad + strings, arch-shaped phrases
            // Floating quality from raised 4th degree, spacious reverb
            return "warm flowing pad with gentle chamber strings, Lydian floating quality, spacious reverb, slow harmonic movement, arch-shaped melodic phrases"
        case .sleep:
            // Pentatonic minor, F, 40 BPM, choir pad, descending contour
            // Extremely sparse, formless, low register only (C2-C3), no rhythm
            return "deep dark choir pad with descending pentatonic minor melody, extremely slow and sparse, low register, formless warm enveloping texture"
        case .energize:
            // Major/Mixolydian, D, 120 BPM, synth lead + tabla + bass
            // Driving rhythm, ascending melodic contour, wide dynamic range
            return "bright uplifting electronic track with tabla percussion and synth bass, driving rhythmic energy, ascending melodic synth lead, major key"
        }
    }

    // MARK: - Descriptor Helpers

    private static func warmthDescriptor(_ warmth: Double) -> String {
        if warmth > Theme.Audio.StemMix.PromptThresholds.warmthHigh { return "warm" }
        if warmth < Theme.Audio.StemMix.PromptThresholds.warmthLow { return "bright" }
        return "neutral"
    }

    private static func energyDescriptor(_ energy: Double) -> String {
        if energy < Theme.Audio.StemMix.PromptThresholds.energyLow { return "minimal" }
        if energy > Theme.Audio.StemMix.PromptThresholds.energyHigh { return "rich" }
        return "moderate"
    }

    private static func densityDescriptor(_ density: Double) -> String {
        if density < Theme.Audio.StemMix.PromptThresholds.densityLow { return "sparse" }
        if density > Theme.Audio.StemMix.PromptThresholds.densityHigh { return "dense" }
        return "evolving"
    }

    /// Returns the default key quality (major/minor) for a mode.
    /// Minor is preferred for calming modes; major for activation.
    private static func modeKeyQuality(_ mode: FocusMode) -> String {
        switch mode {
        case .focus:      return "minor"
        case .relaxation: return "minor"
        case .sleep:      return "minor"
        case .energize:   return "major"
        }
    }

    /// Returns the default energy level when the user has no per-mode preference.
    private static func defaultEnergy(for mode: FocusMode) -> Double {
        switch mode {
        case .focus:      return Theme.Audio.StemMix.PromptThresholds.defaultFocusEnergy
        case .relaxation: return Theme.Audio.StemMix.PromptThresholds.defaultRelaxEnergy
        case .sleep:      return Theme.Audio.StemMix.PromptThresholds.defaultSleepEnergy
        case .energize:   return Theme.Audio.StemMix.PromptThresholds.defaultEnergizeEnergy
        }
    }
}
