// SessionArcPlanner.swift
// BioNaural — v3 Composing Core
//
// Session-level structure above the 8-bar MusicPattern loop. The v3
// pipeline regenerates patterns when biometrics change, but without
// a session-scale plan every session feels like the same 8 bars on
// repeat for 20 minutes. The arc planner schedules a sequence of
// phases across the whole session — sparser intro, fuller body,
// gradual outro — so the music actually travels somewhere.
//
// A phase is a normalized time window [startProgress, endProgress]
// with an intensity multiplier (0.3 = sparse, 1.0 = full, 1.1 = peak).
// CompositionPlanner reads the current phase's intensity and scales
// atom density + velocity when building the MusicPattern. Phase
// transitions happen at bar boundaries via the existing crossfade
// path, so the listener perceives musical evolution instead of
// sudden cuts.
//
// Design is deliberately conservative:
// - Sleep decelerates: start moderate, settle, near-silent drone.
// - Relax breathes: gentle in, immerse, gentle release.
// - Focus sustains: establish the groove, hold it, simplify at the end.
//
// All pure, no side effects.

import BioNauralShared
import Foundation

// MARK: - ArcPhase

public struct ArcPhase: Sendable, Hashable {

    /// Start of this phase as a fraction of total session length (0-1).
    public let startProgress: Double

    /// End of this phase as a fraction of total session length (0-1).
    public let endProgress: Double

    /// Overall intensity for the phase. Used as a multiplier on
    /// density, velocity, and atom-type variety at plan time.
    /// 0.3 → minimal, 0.7 → settled, 1.0 → full, 1.1 → peak.
    public let intensity: Double

    /// Human-readable label for debugging / telemetry.
    public let label: String

    public init(
        startProgress: Double,
        endProgress: Double,
        intensity: Double,
        label: String
    ) {
        self.startProgress = max(0.0, min(1.0, startProgress))
        self.endProgress = max(0.0, min(1.0, endProgress))
        self.intensity = max(0.0, min(1.5, intensity))
        self.label = label
    }

    public func contains(progress: Double) -> Bool {
        progress >= startProgress && progress < endProgress
    }
}

// MARK: - SessionArcPlanner

public enum SessionArcPlanner {

    /// Per-mode arc schedules. Each mode's phases cover the full
    /// [0, 1] session range without gaps or overlaps. Progress is
    /// wallclock-based (elapsed / total), not biometric.
    public static func phases(for mode: FocusMode) -> [ArcPhase] {
        switch mode {

        // MARK: Sleep — decelerate toward drone
        case .sleep:
            return [
                ArcPhase(startProgress: 0.00, endProgress: 0.25, intensity: 0.80, label: "settle"),
                ArcPhase(startProgress: 0.25, endProgress: 0.65, intensity: 0.55, label: "deepen"),
                ArcPhase(startProgress: 0.65, endProgress: 1.01, intensity: 0.30, label: "drone"),
            ]

        // MARK: Relax — gentle arc in and out
        case .relaxation:
            return [
                ArcPhase(startProgress: 0.00, endProgress: 0.20, intensity: 0.70, label: "breath-in"),
                ArcPhase(startProgress: 0.20, endProgress: 0.75, intensity: 1.00, label: "immerse"),
                ArcPhase(startProgress: 0.75, endProgress: 1.01, intensity: 0.60, label: "release"),
            ]

        // MARK: Focus — establish, sustain, simplify
        case .focus:
            return [
                ArcPhase(startProgress: 0.00, endProgress: 0.15, intensity: 0.75, label: "entry"),
                ArcPhase(startProgress: 0.15, endProgress: 0.85, intensity: 1.05, label: "sustain"),
                ArcPhase(startProgress: 0.85, endProgress: 1.01, intensity: 0.70, label: "outro"),
            ]

        // MARK: Energize — legacy, hidden from UI but kept for
        // data compatibility.
        case .energize:
            return [
                ArcPhase(startProgress: 0.00, endProgress: 0.15, intensity: 0.80, label: "entry"),
                ArcPhase(startProgress: 0.15, endProgress: 0.85, intensity: 1.10, label: "drive"),
                ArcPhase(startProgress: 0.85, endProgress: 1.01, intensity: 0.75, label: "outro"),
            ]
        }
    }

    /// Look up the phase containing a given progress value. Falls
    /// back to the first phase if progress is out of range (shouldn't
    /// happen in practice — we compute a clamped progress value).
    public static func phase(at progress: Double, for mode: FocusMode) -> ArcPhase {
        let clamped = max(0.0, min(1.0, progress))
        let all = phases(for: mode)
        for p in all where p.contains(progress: clamped) {
            return p
        }
        return all.last ?? ArcPhase(startProgress: 0, endProgress: 1, intensity: 1.0, label: "full")
    }
}
