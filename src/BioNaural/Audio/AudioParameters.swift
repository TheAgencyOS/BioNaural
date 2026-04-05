// AudioParameters.swift
// BioNaural
//
// Thread-safe parameter store for real-time audio rendering.
// Uses ManagedAtomic<UInt64> to pass Double values lock-free between
// the main thread and the audio render thread.

import Atomics
import Foundation

/// Thread-safe parameter store bridging the main thread and the real-time
/// audio render thread. Every mutable parameter is backed by a
/// `ManagedAtomic<UInt64>` so that reads and writes are lock-free and
/// allocation-free — safe for use on the audio render callback.
public final class AudioParameters: @unchecked Sendable {

    // MARK: - Atomic Backing Storage

    private let _baseFrequency   = ManagedAtomic<UInt64>(Theme.Audio.Neutral.carrierFrequency.bitPattern)
    private let _beatFrequency   = ManagedAtomic<UInt64>(Theme.Audio.Neutral.beatFrequency.bitPattern)
    private let _amplitude       = ManagedAtomic<UInt64>(0.0.bitPattern)
    private let _carrierFrequency = ManagedAtomic<UInt64>(Theme.Audio.Neutral.carrierFrequency.bitPattern)
    private let _ambientVolume   = ManagedAtomic<UInt64>(0.0.bitPattern)
    private let _melodicVolume   = ManagedAtomic<UInt64>(0.0.bitPattern)
    private let _binauralVolume  = ManagedAtomic<UInt64>(1.0.bitPattern)
    private let _isPlaying       = ManagedAtomic<Bool>(false)

    // Stem volume targets — set by BiometricStemMixer, read by StemAudioLayer.
    private let _stemPadsVolume    = ManagedAtomic<UInt64>(1.0.bitPattern)
    private let _stemTextureVolume = ManagedAtomic<UInt64>(1.0.bitPattern)
    private let _stemBassVolume    = ManagedAtomic<UInt64>(1.0.bitPattern)
    private let _stemRhythmVolume  = ManagedAtomic<UInt64>(Double(Theme.Audio.StemMix.defaultRhythmVolume).bitPattern)

    // MARK: - Public Computed Properties (Main Thread ↔ Render Thread)

    /// Base frequency for the left ear carrier (Hz).
    public var baseFrequency: Double {
        get { Double(bitPattern: _baseFrequency.load(ordering: .relaxed)) }
        set { _baseFrequency.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Beat frequency — the perceptual binaural difference (Hz).
    public var beatFrequency: Double {
        get { Double(bitPattern: _beatFrequency.load(ordering: .relaxed)) }
        set { _beatFrequency.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Master amplitude envelope [0…1].
    public var amplitude: Double {
        get { Double(bitPattern: _amplitude.load(ordering: .relaxed)) }
        set { _amplitude.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Carrier frequency — may differ from baseFrequency when drift is
    /// applied by the render callback (Hz).
    public var carrierFrequency: Double {
        get { Double(bitPattern: _carrierFrequency.load(ordering: .relaxed)) }
        set { _carrierFrequency.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume of the ambient layer [0…1].
    public var ambientVolume: Double {
        get { Double(bitPattern: _ambientVolume.load(ordering: .relaxed)) }
        set { _ambientVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume of the melodic layer [0…1].
    public var melodicVolume: Double {
        get { Double(bitPattern: _melodicVolume.load(ordering: .relaxed)) }
        set { _melodicVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume of the binaural beat layer [0…1].
    public var binauralVolume: Double {
        get { Double(bitPattern: _binauralVolume.load(ordering: .relaxed)) }
        set { _binauralVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Transport state — true while the engine should render audio.
    public var isPlaying: Bool {
        get { _isPlaying.load(ordering: .relaxed) }
        set { _isPlaying.store(newValue, ordering: .relaxed) }
    }

    // MARK: - Stem Volume Properties

    /// Volume target for the pads stem [0…1].
    public var stemPadsVolume: Double {
        get { Double(bitPattern: _stemPadsVolume.load(ordering: .relaxed)) }
        set { _stemPadsVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume target for the texture stem [0…1].
    public var stemTextureVolume: Double {
        get { Double(bitPattern: _stemTextureVolume.load(ordering: .relaxed)) }
        set { _stemTextureVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume target for the bass stem [0…1].
    public var stemBassVolume: Double {
        get { Double(bitPattern: _stemBassVolume.load(ordering: .relaxed)) }
        set { _stemBassVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Volume target for the rhythm stem [0…1].
    public var stemRhythmVolume: Double {
        get { Double(bitPattern: _stemRhythmVolume.load(ordering: .relaxed)) }
        set { _stemRhythmVolume.store(newValue.bitPattern, ordering: .relaxed) }
    }

    /// Convenience: read all stem volumes as a `StemVolumeTargets` snapshot.
    public var stemVolumeTargets: StemVolumeTargets {
        StemVolumeTargets(
            pads: Float(stemPadsVolume),
            texture: Float(stemTextureVolume),
            bass: Float(stemBassVolume),
            rhythm: Float(stemRhythmVolume)
        )
    }

    /// Convenience: write all stem volumes from a `StemVolumeTargets`.
    public func applyStemVolumes(_ targets: StemVolumeTargets) {
        stemPadsVolume = Double(targets.pads)
        stemTextureVolume = Double(targets.texture)
        stemBassVolume = Double(targets.bass)
        stemRhythmVolume = Double(targets.rhythm)
    }

    // MARK: - Render-Thread Accessors (Atomic References)

    /// Direct atomic references for capture by the render closure.
    /// The render callback must capture *these structs* — never `self`.
    public var atomicBaseFrequency: ManagedAtomic<UInt64> { _baseFrequency }
    public var atomicBeatFrequency: ManagedAtomic<UInt64> { _beatFrequency }
    public var atomicAmplitude: ManagedAtomic<UInt64> { _amplitude }
    public var atomicCarrierFrequency: ManagedAtomic<UInt64> { _carrierFrequency }
    public var atomicBinauralVolume: ManagedAtomic<UInt64> { _binauralVolume }
    public var atomicIsPlaying: ManagedAtomic<Bool> { _isPlaying }

    // MARK: - Initializer

    public init() {}
}
