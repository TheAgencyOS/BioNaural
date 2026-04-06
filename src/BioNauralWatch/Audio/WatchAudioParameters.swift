// WatchAudioParameters.swift
// BioNauralWatch
//
// Lock-free atomic parameter store bridging the main thread and the
// audio render thread. Mirrors the iPhone's AudioParameters pattern,
// simplified for the watchOS binaural-only audio graph (no ambient/
// melodic layers). Every mutable parameter is backed by a
// ManagedAtomic<UInt64> (Doubles via bit patterns) or ManagedAtomic<Bool>
// so that reads and writes are lock-free and allocation-free — safe
// for use in the audio render callback.

import Atomics
import AVFoundation
import BioNauralShared

/// Thread-safe parameter store for the watchOS binaural beat engine.
///
/// - Main thread writes target values via computed properties.
/// - The render callback reads via direct atomic references (no ARC).
/// - All ordering is `.relaxed` — sufficient for single-writer scenarios
///   where stale reads are acceptable (the per-sample smoother converges).
public final class WatchAudioParameters: @unchecked Sendable {

    // MARK: - Atomic Backing Storage

    private let _baseFrequency = ManagedAtomic<UInt64>(
        FocusMode.focus.defaultCarrierFrequency.bitPattern
    )
    private let _beatFrequency = ManagedAtomic<UInt64>(
        FocusMode.focus.defaultBeatFrequency.bitPattern
    )
    private let _amplitude = ManagedAtomic<UInt64>(
        WatchDesign.Audio.initialAmplitude.bitPattern
    )
    private let _isPlaying = ManagedAtomic<Bool>(false)

    // MARK: - Public Computed Properties (Main Thread Read/Write)

    /// Carrier (base) frequency in Hz.
    public var baseFrequency: Double {
        get { Double(bitPattern: _baseFrequency.load(ordering: .relaxed)) }
        set { _baseFrequency.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Binaural beat frequency — the perceptual difference between ears (Hz).
    public var beatFrequency: Double {
        get { Double(bitPattern: _beatFrequency.load(ordering: .relaxed)) }
        set { _beatFrequency.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Master amplitude envelope [0.0 ... 1.0].
    public var amplitude: Double {
        get { Double(bitPattern: _amplitude.load(ordering: .relaxed)) }
        set { _amplitude.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Transport state — true while the engine should render audio.
    public var isPlaying: Bool {
        get { _isPlaying.load(ordering: .relaxed) }
        set { _isPlaying.store(newValue, ordering: .relaxed) }
    }

    // MARK: - Render-Thread Accessors (Atomic References)

    /// Direct atomic references for capture by the render closure.
    /// The render callback must capture *these* — never `self`.
    public var atomicBaseFrequency: ManagedAtomic<UInt64> { _baseFrequency }
    public var atomicBeatFrequency: ManagedAtomic<UInt64> { _beatFrequency }
    public var atomicAmplitude: ManagedAtomic<UInt64> { _amplitude }
    public var atomicIsPlaying: ManagedAtomic<Bool> { _isPlaying }

    // MARK: - Initializer

    public init() {}

    // MARK: - Mode Configuration

    /// Resets parameters to the defaults for the given focus mode.
    ///
    /// Called at session start before the adaptive engine takes over.
    /// Sets carrier and beat frequencies from `FocusMode` research-backed
    /// defaults, and resets amplitude to the initial level.
    public func configure(for mode: FocusMode) {
        baseFrequency = mode.defaultCarrierFrequency
        beatFrequency = mode.defaultBeatFrequency
        amplitude = WatchDesign.Audio.initialAmplitude
        isPlaying = false
    }
}
