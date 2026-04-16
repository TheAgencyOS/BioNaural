// DrumHumanizer.swift
// BioNaural — v3 Composing Core
//
// GrooVAE-inspired drum humanization. The 2019 Magenta "Learning to
// Groove" model (Gillick et al., ICML 2019) takes a quantized drum
// grid and outputs humanized microtiming offsets + velocity variation
// learned from ~13 hours of pro drummers. Shipping the real model on
// iOS is a TF1→Core ML conversion rabbit hole for what is ultimately
// ±15 ms of timing drift and some position-based velocity shaping.
//
// This file reproduces the *audible* behavior in pure Swift using
// the published behavioral features from the paper:
//
//   - Per-voice stability: kick/bass drum hits are tight, snares
//     drag slightly, closed hi-hats are the loosest, shakers stay
//     in the pocket.
//   - Metric velocity curve: strong beats (1, 3) full velocity,
//     weak beats (2, 4) slightly softer, off-beats softer still
//     with more random variation.
//   - Per-bar consistency: microtiming within a single bar uses a
//     deterministic seeded generator so the same bar doesn't jitter
//     differently on each iteration. Different bars use different
//     seeds so the piece feels human, not robotic.
//
// It does NOT reproduce ghost-note generation (the paper's "tap to
// drums" mode) because our atoms already define their own ghost
// positions and we don't want surprise notes appearing.
//
// Operates kit-agnostic: classifies each MIDI note into a voice
// category (kick / snare-mid / hat-high / shaker) from the resolver's
// mapping of sparseKit / congas / tabla notes, then applies the
// category's humanization profile.

import Foundation

public enum DrumHumanizer {

    // MARK: - Voice categories

    private enum Voice {
        case kick     // steady, tight
        case snare    // slight backbeat drag
        case hat      // loose, most variation
        case shaker   // tight, quiet
    }

    /// Classify a MIDI percussion note into a voice category. Covers
    /// all three kits produced by WeirdnessResolver (sparseKit,
    /// congas, tabla) — the humanization profile applies by *role*
    /// of the hit, not by literal instrument.
    private static func voice(for pitch: UInt8) -> Voice {
        switch pitch {
        // Kick / bass tier
        case 36,       // Bass Drum 1 (sparseKit)
             41,       // Low Floor Tom (tabla bayan)
             64:       // Low Conga
            return .kick

        // Snare / mid tier
        case 38,       // Acoustic Snare (sparseKit)
             37,       // Side Stick (sparseKit)
             47,       // Low-Mid Tom (tabla tin)
             65,       // High Timbale (tabla slap)
             63:       // Open High Conga
            return .snare

        // Hat / high tier
        case 42,       // Closed Hi-Hat (sparseKit)
             46,       // Open Hi-Hat
             62,       // Mute High Conga
             60,       // High Bongo
             45:       // Low Tom
            return .hat

        // Shaker / extras
        case 70:       // Maracas
            return .shaker

        default:
            return .snare
        }
    }

    // MARK: - Humanization profiles
    //
    // Microtiming in PPQN ticks (480 per quarter). These numbers are
    // hand-tuned to match the order of magnitude reported in the
    // GrooVAE paper: kicks ±3 ticks, snares +6/+12 drag, hats ±10
    // ticks of Gaussian-ish variation, shakers tight.
    //
    // Velocity multipliers are applied *after* PatternBuilder's
    // phrase density envelope so humanization reads as a
    // micro-variation on top of the macro-level breath.

    private struct Profile {
        let maxTimingOffset: Int      // absolute tick range for random jitter
        let biasTimingOffset: Int     // directional push (positive = drag)
        let velocityJitter: Double    // ±fraction of base velocity
        let velocityFloor: Double     // minimum multiplier after jitter
    }

    private static func profile(for voice: Voice) -> Profile {
        // Timing offsets sized for trip-hop feel. At 480 PPQN and
        // ~80 BPM, 1 tick ≈ 1.6 ms. The old values (±3 kick, ±6
        // snare) were barely perceptible. Real trip-hop drummers
        // have 10-30 ms of timing drift — that's ±8 to ±18 ticks.
        // The snare drag bias (+10) puts the backbeat behind the
        // beat, which is THE trip-hop signature.
        switch voice {
        case .kick:
            return Profile(maxTimingOffset: 8,  biasTimingOffset: 0, velocityJitter: 0.06, velocityFloor: 0.88)
        case .snare:
            return Profile(maxTimingOffset: 14, biasTimingOffset: 10, velocityJitter: 0.10, velocityFloor: 0.80)
        case .hat:
            return Profile(maxTimingOffset: 18, biasTimingOffset: 0, velocityJitter: 0.15, velocityFloor: 0.70)
        case .shaker:
            return Profile(maxTimingOffset: 8,  biasTimingOffset: 0, velocityJitter: 0.12, velocityFloor: 0.65)
        }
    }

    // MARK: - Metric velocity curve

    /// Velocity multiplier as a function of position within the bar.
    /// Beat 1 and beat 3 get 1.00, beats 2 and 4 get 0.94, off-8ths
    /// get 0.86, 16ths get 0.80. Reproduces the characteristic
    /// "strong-weak-medium-weak" pop-rock accent shape that GrooVAE
    /// learned from its training corpus.
    private static func metricVelocityMultiplier(positionInBar: Int, ticksPerQuarter: Int) -> Double {
        let quarter = ticksPerQuarter
        let eighth = quarter / 2
        let sixteenth = quarter / 4
        let beat = positionInBar / quarter
        let withinBeat = positionInBar % quarter

        if withinBeat == 0 {
            // Downbeat. Beat 1 and 3 stronger than 2 and 4.
            return (beat == 0 || beat == 2) ? 1.00 : 0.94
        }
        if withinBeat == eighth {
            return 0.86                      // off-8th
        }
        if withinBeat == sixteenth || withinBeat == 3 * sixteenth {
            return 0.80                      // 16th
        }
        return 0.90
    }

    // MARK: - Public API

    /// Humanize a sorted list of drum MPNotes. Returns a new list
    /// with adjusted positions and velocities. Safe to call with
    /// non-drum notes (they'll be left alone if the classification
    /// lands on .snare with trivial offsets) — but the intended
    /// call site is buildMP's drum-track path only.
    ///
    /// - Parameters:
    ///   - notes: the drum notes to humanize, post density envelope.
    ///   - loopLengthTicks: total loop length so positions stay
    ///     in range after humanization.
    ///   - ticksPerBar: ticks per bar in the pattern (default 1920).
    ///   - seed: seed for the internal deterministic RNG so the
    ///     same MusicPattern humanizes identically on each build.
    public static func humanize(
        notes: [MPNote],
        loopLengthTicks: Int,
        ticksPerBar: Int = 1920,
        seed: UInt64 = 0xC0FFEE
    ) -> [MPNote] {
        guard !notes.isEmpty else { return notes }

        var rng = SplitMix64(seed: seed)
        var out: [MPNote] = []
        out.reserveCapacity(notes.count)

        let ticksPerQuarter = ticksPerBar / 4

        for note in notes {
            let voiceCategory = voice(for: note.pitch)
            let p = profile(for: voiceCategory)

            // Per-bar seed mix so different bars vary subtly but the
            // bar index is stable across regenerations (humanizer is
            // called with the same input seed every time).
            let barIndex = note.positionTicks / ticksPerBar
            rng.advance(by: UInt64(bitPattern: Int64(note.positionTicks * 31 + Int(note.pitch) * 7 + barIndex * 101)))

            // Microtiming: bias + symmetric jitter, clamped so the
            // note doesn't slide off the grid edges.
            let jitter = rng.nextInt(in: -p.maxTimingOffset...p.maxTimingOffset)
            let bias = p.biasTimingOffset
            var newTick = note.positionTicks + bias + jitter
            newTick = max(0, min(loopLengthTicks - 1, newTick))

            // Metric velocity curve applied to the position within
            // the bar (NOT the jittered position — we want the
            // accent structure to reflect the intended grid).
            let posInBar = note.positionTicks % ticksPerBar
            let metric = metricVelocityMultiplier(positionInBar: posInBar, ticksPerQuarter: ticksPerQuarter)

            // Random velocity jitter within the voice's allowed band.
            let jitterFraction = rng.nextDouble(in: -p.velocityJitter...p.velocityJitter)
            let multiplier = max(p.velocityFloor, min(1.05, metric + jitterFraction))
            let shaped = Double(note.velocity) * multiplier
            let newVelocity = UInt8(max(1, min(127, Int(shaped.rounded()))))

            out.append(MPNote(
                pitch: note.pitch,
                velocity: newVelocity,
                positionTicks: newTick,
                lengthTicks: note.lengthTicks
            ))
        }

        return out.sorted { $0.positionTicks < $1.positionTicks }
    }
}

// MARK: - Small seeded RNG

/// A minimal SplitMix64 implementation so DrumHumanizer can be
/// deterministic without pulling in a full `RandomNumberGenerator`
/// wrapper. Good enough for humanization jitter; not cryptographic.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    mutating func advance(by value: UInt64) {
        state = state &+ value
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(span))
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let u = Double(next() >> 11) / Double(UInt64(1) << 53)
        return range.lowerBound + u * (range.upperBound - range.lowerBound)
    }
}
