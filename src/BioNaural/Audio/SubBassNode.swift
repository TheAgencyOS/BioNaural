// SubBassNode.swift
// BioNaural
//
// AVAudioSourceNode that synthesises a mono sub-bass sine wave in real time.
// Follows the same lock-free atomic pattern as BinauralBeatNode: the render
// closure captures only value types and atomic references — no class instances,
// no ARC traffic, no locks, no allocations on the audio thread.
//
// Used exclusively in Energize mode to add physical low-end presence (30-80 Hz)
// that SoundFont samples cannot reproduce. Frequency is driven by the bass
// track's MIDI notes via AudioParameters.subBassFrequency.

import AVFoundation
import Atomics

/// Factory that creates a configured `AVAudioSourceNode` producing a mono
/// sub-bass sine wave with per-sample amplitude smoothing.
public enum SubBassNode {

    // MARK: - Node Factory

    /// Creates an `AVAudioSourceNode` that renders a sine-wave sub-bass
    /// oscillator. Frequency and amplitude are read from `AudioParameters`
    /// atomics each render call — zero allocation, lock-free.
    ///
    /// - Parameters:
    ///   - parameters: Shared parameter store. The MIDI player writes
    ///     `subBassFrequency` and `subBassAmplitude`; this node reads them.
    ///   - sampleRate: The engine's hardware sample rate.
    /// - Returns: A configured source node ready to attach to the engine.
    public static func makeNode(
        parameters: AudioParameters,
        sampleRate: Double
    ) -> AVAudioSourceNode {

        // Capture atomic refs (no ARC overhead beyond initial retain)
        let atomicFreq    = parameters.atomicSubBassFrequency
        let atomicAmp     = parameters.atomicSubBassAmplitude
        let atomicEnabled = parameters.atomicSubBassEnabled
        let atomicPlaying = parameters.atomicIsPlaying

        // Mutable render state
        var phase: Double = 0.0
        var smoothedFreq: Double = 40.0
        var smoothedAmp: Double = 0.0

        // Pre-computed constants
        let twoPi = 2.0 * Double.pi
        let invSR = 1.0 / sampleRate

        // Smoothing coefficients from Theme tokens
        let freqAlpha = 1.0 - exp(-1.0 / (Theme.Audio.SubBass.smoothingTimeConstant * sampleRate))
        let ampAlpha  = 1.0 - exp(-1.0 / (Theme.Audio.SubBass.attackSeconds * sampleRate))
        let maxAmp    = Theme.Audio.SubBass.maxAmplitude

        // Mono format (sub-bass is summed to both channels at output)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!

        let node = AVAudioSourceNode(format: format) { (
            _: UnsafeMutablePointer<ObjCBool>,
            _: UnsafePointer<AudioTimeStamp>,
            frameCount: AVAudioFrameCount,
            audioBufferList: UnsafeMutablePointer<AudioBufferList>
        ) -> OSStatus in

            // Bail silently if not playing or sub-bass is disabled
            guard atomicPlaying.load(ordering: .relaxed),
                  atomicEnabled.load(ordering: .relaxed) else {
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buf in abl {
                    if let data = buf.mData {
                        memset(data, 0, Int(buf.mDataByteSize))
                    }
                }
                smoothedAmp = 0.0
                return noErr
            }

            // Read targets from atomics (once per render call)
            let targetFreq = Double(bitPattern: atomicFreq.load(ordering: .relaxed))
            let targetAmp  = Double(bitPattern: atomicAmp.load(ordering: .relaxed))

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let ptr = abl[0].mData?.assumingMemoryBound(to: Float32.self) else {
                return noErr
            }

            let frames = Int(frameCount)

            for i in 0..<frames {
                // Per-sample exponential smoothing
                smoothedFreq += freqAlpha * (targetFreq - smoothedFreq)
                smoothedAmp  += ampAlpha  * (targetAmp  - smoothedAmp)

                // Pure sine oscillator
                let sample = sin(phase * twoPi)

                // Output with amplitude clamped to max
                let gain = min(smoothedAmp * maxAmp, maxAmp)
                ptr[i] = Float32(sample * gain)

                // Advance phase
                phase += smoothedFreq * invSR
                if phase >= 1.0 { phase -= 1.0 }
            }

            return noErr
        }

        return node
    }
}
