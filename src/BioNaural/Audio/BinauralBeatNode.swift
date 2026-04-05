// BinauralBeatNode.swift
// BioNaural
//
// AVAudioSourceNode that synthesises a binaural beat in real time.
// The render closure captures ONLY value types and atomic references —
// no class instances, no ARC traffic, no locks, no allocations.

import AVFoundation
import Atomics

/// Factory that creates a configured `AVAudioSourceNode` producing a
/// stereo binaural beat with harmonic layering, LFO modulation, and
/// gentle carrier drift.
public enum BinauralBeatNode {

    // MARK: - Format

    /// Stereo, non-interleaved, 32-bit float at the hardware sample rate.
    public static func makeFormat(sampleRate: Double) -> AVAudioFormat {
        AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!
    }

    // MARK: - Node Factory

    // Creates an `AVAudioSourceNode` wired to the given `AudioParameters`.
    //
    // - Important: The returned closure captures **only** the atomic
    //   references (value-type wrappers around `ManagedAtomicStorage`)
    //   and local mutable state. No class pointers cross the real-time
    //   boundary.
    // swiftlint:disable:next function_body_length
    public static func makeNode(
        parameters: AudioParameters,
        sampleRate: Double
    ) -> AVAudioSourceNode {

        // -- Capture atomic refs (reference-semantic but no ARC overhead
        //    beyond the initial retain of the underlying allocation) -------
        let atomicBase      = parameters.atomicBaseFrequency
        let atomicBeat      = parameters.atomicBeatFrequency
        let atomicAmp       = parameters.atomicAmplitude
        let atomicCarrier   = parameters.atomicCarrierFrequency
        let atomicBinaural  = parameters.atomicBinauralVolume
        let atomicPlaying   = parameters.atomicIsPlaying

        // -- Mutable render state (captured by the closure) ----------------
        var phaseLeft: Double = 0.0
        var phaseRight: Double = 0.0

        // Harmonic phase accumulators
        var phaseLeft2: Double = 0.0
        var phaseRight2: Double = 0.0
        var phaseLeft3: Double = 0.0
        var phaseRight3: Double = 0.0

        // Smoothed values (converge toward target each sample)
        var smoothedFreqLeft: Double = 200.0
        var smoothedFreqRight: Double = 210.0
        var smoothedAmplitude: Double = 0.0

        // LFO phase accumulators (three unsynchronised LFOs)
        var lfoPhase1: Double = 0.0
        var lfoPhase2: Double = 0.37   // offset so they don't start aligned
        var lfoPhase3: Double = 0.71

        // Carrier drift state — slow random walk
        var driftValue: Double = 0.0
        var driftVelocity: Double = 0.0
        var driftCounter: UInt32 = 0

        // Pre-computed constants
        let twoPi          = 2.0 * Double.pi
        let invSampleRate  = 1.0 / sampleRate

        // Harmonic gains (linear) — from Theme.Audio tokens
        let harm2Gain = pow(10.0, Theme.Audio.Harmonics.secondGainDB / 20.0)   // -8 dB
        let harm3Gain = pow(10.0, Theme.Audio.Harmonics.thirdGainDB / 20.0)    // -14 dB

        // LFO depths (linear amplitude multiplier range)
        let lfoDepth = pow(10.0, Theme.Audio.LFO.depthDB / 20.0) - 1.0        // ±2 dB

        // LFO rates — from Theme.Audio tokens
        let lfoRate1 = Theme.Audio.LFO.rate1
        let lfoRate2 = Theme.Audio.LFO.rate2
        let lfoRate3 = Theme.Audio.LFO.rate3

        // Drift limits — from Theme.Audio tokens
        let maxDrift = Theme.Audio.CarrierDrift.maxHz

        // Smoothing coefficients — derived from Theme.Audio time constants
        // alpha = 1 - exp(-1 / (smoothingTime * sampleRate))
        let freqSmoothing = 1.0 - exp(-1.0 / (Theme.Audio.frequencySmoothingTime * sampleRate))
        let ampSmoothing  = 1.0 - exp(-1.0 / (Theme.Audio.amplitudeSmoothingTime * sampleRate))

        // Normalization factor (constant for the life of the node)
        let normFactor = 1.0 / (1.0 + harm2Gain + harm3Gain)

        // Drift parameters — snapshot from Theme tokens (value types)
        let driftAccel          = Theme.Audio.CarrierDrift.accel
        let driftMeanReversion  = Theme.Audio.CarrierDrift.meanReversion
        let driftDamping        = Theme.Audio.CarrierDrift.damping
        let driftUpdateInterval = UInt32(sampleRate * Theme.Audio.CarrierDrift.updateInterval)

        // Simple deterministic pseudo-random: xorshift32 state
        var rngState: UInt32 = 0xDEAD_BEEF

        // ---- Render closure ---------------------------------------------
        // swiftlint:disable closure_parameter_position
        let node = AVAudioSourceNode(
            format: makeFormat(sampleRate: sampleRate)
        ) { (
            _: UnsafeMutablePointer<ObjCBool>,
            _: UnsafePointer<AudioTimeStamp>,
            frameCount: AVAudioFrameCount,
            audioBufferList: UnsafeMutablePointer<AudioBufferList>
        ) -> OSStatus in
        // swiftlint:enable closure_parameter_position

            // If not playing, fill silence and bail.
            guard atomicPlaying.load(ordering: .relaxed) else {
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buf in abl {
                    if let data = buf.mData {
                        memset(data, 0, Int(buf.mDataByteSize))
                    }
                }
                // Reset smoothed amplitude so next start ramps from zero
                smoothedAmplitude = 0.0
                return noErr
            }

            // Read targets from atomics (one load per render call, not per sample)
            let targetBase     = Double(bitPattern: atomicBase.load(ordering: .relaxed))
            let targetBeat     = Double(bitPattern: atomicBeat.load(ordering: .relaxed))
            let targetAmp      = Double(bitPattern: atomicAmp.load(ordering: .relaxed))
            let targetCarrier  = Double(bitPattern: atomicCarrier.load(ordering: .relaxed))
            let binauralVol    = Double(bitPattern: atomicBinaural.load(ordering: .relaxed))

            // Derive per-ear target frequencies.
            // Carrier may have drift applied; beat difference is always exact.
            let carrierBase     = targetCarrier + driftValue
            let targetFreqLeft  = carrierBase
            let targetFreqRight = carrierBase + targetBeat

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let leftPtr  = abl[0].mData?.assumingMemoryBound(to: Float32.self),
                  let rightPtr = abl[1].mData?.assumingMemoryBound(to: Float32.self)
            else {
                return noErr
            }

            let frames = Int(frameCount)

            for i in 0 ..< frames {

                // --- Exponential smoothing --------------------------------
                smoothedFreqLeft  += freqSmoothing * (targetFreqLeft  - smoothedFreqLeft)
                smoothedFreqRight += freqSmoothing * (targetFreqRight - smoothedFreqRight)
                smoothedAmplitude += ampSmoothing  * (targetAmp       - smoothedAmplitude)

                // --- Phase increments -------------------------------------
                let incLeft  = smoothedFreqLeft  * invSampleRate
                let incRight = smoothedFreqRight * invSampleRate

                // --- Fundamental (sine) -----------------------------------
                let sinLeft  = sin(phaseLeft  * twoPi)
                let sinRight = sin(phaseRight * twoPi)

                // --- 2nd harmonic (-8 dB) — triangle wave character -------
                let sin2Left  = sin(phaseLeft2  * twoPi)
                let sin2Right = sin(phaseRight2 * twoPi)

                // --- 3rd harmonic (-14 dB) — triangle wave character ------
                let sin3Left  = sin(phaseLeft3  * twoPi)
                let sin3Right = sin(phaseRight3 * twoPi)

                // --- Composite waveform -----------------------------------
                let harm2L: Double = harm2Gain * sin2Left
                let harm3L: Double = harm3Gain * sin3Left
                let harm2R: Double = harm2Gain * sin2Right
                let harm3R: Double = harm3Gain * sin3Right
                let rawLeft: Double  = sinLeft  + harm2L + harm3L
                let rawRight: Double = sinRight + harm2R + harm3R

                // --- LFO amplitude modulation (3 unsynchronised LFOs) -----
                let lfo1: Double = lfoDepth * sin(lfoPhase1 * twoPi)
                let lfo2: Double = lfoDepth * sin(lfoPhase2 * twoPi)
                let lfo3: Double = lfoDepth * sin(lfoPhase3 * twoPi)
                let lfo: Double = 1.0 + lfo1 + lfo2 + lfo3

                // --- Final sample -----------------------------------------
                let gain: Double = smoothedAmplitude * binauralVol * normFactor * lfo

                leftPtr[i]  = Float32(rawLeft  * gain)
                rightPtr[i] = Float32(rawRight * gain)

                // --- Advance phases (with wrap to avoid precision loss) ----
                phaseLeft  += incLeft
                phaseRight += incRight
                if phaseLeft  >= 1.0 { phaseLeft  -= 1.0 }
                if phaseRight >= 1.0 { phaseRight -= 1.0 }

                phaseLeft2  += incLeft  * 2.0
                phaseRight2 += incRight * 2.0
                if phaseLeft2  >= 1.0 { phaseLeft2  -= 1.0 }
                if phaseRight2 >= 1.0 { phaseRight2 -= 1.0 }

                phaseLeft3  += incLeft  * 3.0
                phaseRight3 += incRight * 3.0
                if phaseLeft3  >= 1.0 { phaseLeft3  -= 1.0 }
                if phaseRight3 >= 1.0 { phaseRight3 -= 1.0 }

                // LFO phases
                lfoPhase1 += lfoRate1 * invSampleRate
                lfoPhase2 += lfoRate2 * invSampleRate
                lfoPhase3 += lfoRate3 * invSampleRate
                if lfoPhase1 >= 1.0 { lfoPhase1 -= 1.0 }
                if lfoPhase2 >= 1.0 { lfoPhase2 -= 1.0 }
                if lfoPhase3 >= 1.0 { lfoPhase3 -= 1.0 }
            }

            // --- Carrier drift update (once per render call) --------------
            // Update every ~50 ms worth of frames to keep cost low.
            driftCounter &+= frameCount
            if driftCounter >= driftUpdateInterval {
                driftCounter = 0

                // xorshift32 PRNG — no allocation, no lock
                rngState ^= rngState &<< 13
                rngState ^= rngState &>> 17
                rngState ^= rngState &<< 5

                // Map to [-1, 1]
                let rand = Double(Int32(bitPattern: rngState)) / Double(Int32.max)

                // Brownian-style walk with mean reversion
                driftVelocity += driftAccel * rand
                driftVelocity -= driftMeanReversion * driftValue
                driftVelocity *= driftDamping

                driftValue += driftVelocity

                // Clamp to ± maxDrift
                if driftValue >  maxDrift { driftValue =  maxDrift; driftVelocity = 0 }
                if driftValue < -maxDrift { driftValue = -maxDrift; driftVelocity = 0 }
            }

            return noErr
        }

        return node
    }
}
