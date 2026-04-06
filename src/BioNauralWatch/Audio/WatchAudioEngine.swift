// WatchAudioEngine.swift
// BioNauralWatch
//
// Simplified AVAudioEngine graph for watchOS binaural beat synthesis.
// Graph: AVAudioSourceNode (binaural) → AVAudioMixerNode → AVAudioOutputNode
//
// The render callback uses phase accumulators with per-sample exponential
// smoothing for glitch-free parameter transitions. No locks, no allocations,
// no ARC in the render path. Atomics are captured directly — never self.

import Atomics
import AVFoundation
import BioNauralShared
import OSLog

/// Manages the watchOS binaural beat audio graph.
///
/// The engine produces a stereo binaural beat by splitting a carrier
/// frequency into left/right ear components using `FrequencyMath.carrierSplit`.
/// Harmonics (2nd and 3rd) add warmth. All numeric constants come from
/// `WatchDesign.Audio` tokens.
@MainActor @Observable
final class WatchAudioEngine {

    // MARK: - Public Properties

    let parameters = WatchAudioParameters()
    private(set) var isPlaying = false

    // MARK: - Private State

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var fadeTimer: DispatchSourceTimer?

    private let logger = Logger(subsystem: "com.bionaural.watch", category: "audio")

    // MARK: - Initializer

    init() {}

    // MARK: - Transport

    /// Configures the audio session, builds the engine graph, and starts playback.
    ///
    /// - Parameter mode: The focus mode to configure default frequencies for.
    func start(mode: FocusMode) {
        // Cancel any pending fade timer from a previous session.
        fadeTimer?.cancel()
        fadeTimer = nil

        parameters.configure(for: mode)

        do {
            // Audio session — playback category for background audio.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            // Build the graph.
            let audioEngine = AVAudioEngine()
            let sampleRate = WatchDesign.Audio.sampleRate

            let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 2
            )!

            let source = makeBinauralSourceNode(sampleRate: sampleRate)
            self.sourceNode = source

            audioEngine.attach(source)
            audioEngine.connect(source, to: audioEngine.mainMixerNode, format: format)

            // Spatial Audio handling: on watchOS, spatial processing is
            // user-controlled via AirPods settings. No programmatic API
            // available on watchOS to disable it. The app warns users
            // during onboarding to disable Spatial Audio for binaural beats.

            audioEngine.prepare()
            try audioEngine.start()

            self.engine = audioEngine
            parameters.isPlaying = true
            isPlaying = true

            logger.info("Audio engine started for mode: \(mode.displayName)")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Ramps amplitude to zero and pauses the engine.
    func pause() {
        parameters.amplitude = 0.0
        parameters.isPlaying = false

        let rampDuration = WatchDesign.Audio.pauseRampDuration

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + rampDuration)
        timer.setEventHandler { [weak self] in
            self?.engine?.pause()
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.logger.info("Audio engine paused")
            }
        }
        fadeTimer?.cancel()
        fadeTimer = timer
        timer.resume()

        isPlaying = false
    }

    /// Re-prepares and starts the engine, ramping amplitude back up.
    func resume() {
        guard let engine else {
            logger.warning("Resume called with no engine")
            return
        }

        do {
            engine.prepare()
            try engine.start()

            parameters.isPlaying = true
            parameters.amplitude = WatchDesign.Audio.initialAmplitude
            isPlaying = true

            logger.info("Audio engine resumed")
        } catch {
            logger.error("Failed to resume audio engine: \(error.localizedDescription)")
        }
    }

    /// Ramps amplitude to zero, waits, then stops and tears down the engine.
    func stop() {
        parameters.amplitude = 0.0

        let rampDuration = WatchDesign.Audio.stopRampDuration

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + rampDuration)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.parameters.isPlaying = false

            self.engine?.stop()

            // Tear down nodes.
            if let source = self.sourceNode, let eng = self.engine {
                eng.detach(source)
            }
            self.sourceNode = nil
            self.engine = nil

            DispatchQueue.main.async {
                self.isPlaying = false
                self.logger.info("Audio engine stopped")
            }
        }
        fadeTimer?.cancel()
        fadeTimer = timer
        timer.resume()
    }

    // MARK: - Binaural Source Node Factory

    /// Creates an `AVAudioSourceNode` that synthesises a stereo binaural beat.
    ///
    /// The closure captures ONLY atomic references and local mutable state.
    /// No class instances, no ARC traffic, no locks, no allocations.
    private nonisolated func makeBinauralSourceNode(
        sampleRate: Double
    ) -> AVAudioSourceNode {

        // Capture atomic refs — no ARC beyond initial retain of backing storage.
        let atomicBase    = parameters.atomicBaseFrequency
        let atomicBeat    = parameters.atomicBeatFrequency
        let atomicAmp     = parameters.atomicAmplitude
        let atomicPlaying = parameters.atomicIsPlaying

        // Mutable render state.
        var phaseLeft: Double = 0.0
        var phaseRight: Double = 0.0
        var phaseLeft2: Double = 0.0
        var phaseRight2: Double = 0.0
        var phaseLeft3: Double = 0.0
        var phaseRight3: Double = 0.0

        // Smoothed values (converge toward target each sample).
        let defaultCarrier = FocusMode.focus.defaultCarrierFrequency
        let defaultBeat = FocusMode.focus.defaultBeatFrequency
        var smoothedFreqLeft: Double = defaultCarrier - defaultBeat / 2.0
        var smoothedFreqRight: Double = defaultCarrier + defaultBeat / 2.0
        var smoothedAmplitude: Double = 0.0

        // Pre-computed constants.
        let twoPi = 2.0 * Double.pi
        let invSampleRate = 1.0 / sampleRate

        // Harmonic gains (linear) from WatchDesign.Audio.Harmonics tokens.
        let harm2Gain = pow(10.0, WatchDesign.Audio.Harmonics.second / 20.0)
        let harm3Gain = pow(10.0, WatchDesign.Audio.Harmonics.third / 20.0)

        // Smoothing coefficients from WatchDesign.Audio time constants.
        // alpha = 1 - exp(-1 / (smoothingTime * sampleRate))
        let freqSmoothing = 1.0 - exp(
            -1.0 / (WatchDesign.Audio.frequencySmoothingTime * sampleRate)
        )
        let ampSmoothing = 1.0 - exp(
            -1.0 / (WatchDesign.Audio.amplitudeSmoothingTime * sampleRate)
        )

        // Normalization to prevent clipping when harmonics sum constructively.
        let normFactor = 1.0 / (1.0 + harm2Gain + harm3Gain)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let node = AVAudioSourceNode(format: format) { (
            _: UnsafeMutablePointer<ObjCBool>,
            _: UnsafePointer<AudioTimeStamp>,
            frameCount: AVAudioFrameCount,
            audioBufferList: UnsafeMutablePointer<AudioBufferList>
        ) -> OSStatus in

            // If not playing, fill silence.
            guard atomicPlaying.load(ordering: .relaxed) else {
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buf in abl {
                    if let data = buf.mData {
                        memset(data, 0, Int(buf.mDataByteSize))
                    }
                }
                smoothedAmplitude = 0.0
                return noErr
            }

            // Read targets from atomics (once per render call, not per sample).
            let targetBase = Double(bitPattern: atomicBase.load(ordering: .relaxed))
            let targetBeat = Double(bitPattern: atomicBeat.load(ordering: .relaxed))
            let targetAmp  = Double(bitPattern: atomicAmp.load(ordering: .relaxed))

            // Derive per-ear target frequencies via FrequencyMath.carrierSplit.
            let split = FrequencyMath.carrierSplit(
                carrier: targetBase,
                beatFrequency: targetBeat
            )
            let targetFreqLeft = split.left
            let targetFreqRight = split.right

            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float32.self),
                  let rightPtr = abl[1].mData?.assumingMemoryBound(to: Float32.self)
            else {
                return noErr
            }

            let frames = Int(frameCount)

            for i in 0 ..< frames {

                // --- Exponential smoothing ------------------------------------
                smoothedFreqLeft  += freqSmoothing * (targetFreqLeft  - smoothedFreqLeft)
                smoothedFreqRight += freqSmoothing * (targetFreqRight - smoothedFreqRight)
                smoothedAmplitude += ampSmoothing  * (targetAmp       - smoothedAmplitude)

                // --- Phase increments ----------------------------------------
                let incLeft  = smoothedFreqLeft  * invSampleRate
                let incRight = smoothedFreqRight * invSampleRate

                // --- Fundamental (sine) --------------------------------------
                let sinLeft  = sin(phaseLeft  * twoPi)
                let sinRight = sin(phaseRight * twoPi)

                // --- 2nd harmonic --------------------------------------------
                let sin2Left  = sin(phaseLeft2  * twoPi)
                let sin2Right = sin(phaseRight2 * twoPi)

                // --- 3rd harmonic --------------------------------------------
                let sin3Left  = sin(phaseLeft3  * twoPi)
                let sin3Right = sin(phaseRight3 * twoPi)

                // --- Composite waveform --------------------------------------
                let rawLeft  = sinLeft  + harm2Gain * sin2Left  + harm3Gain * sin3Left
                let rawRight = sinRight + harm2Gain * sin2Right + harm3Gain * sin3Right

                // --- Final sample --------------------------------------------
                let gain = smoothedAmplitude * normFactor

                leftPtr[i]  = Float32(rawLeft  * gain)
                rightPtr[i] = Float32(rawRight * gain)

                // --- Advance phases (wrap to avoid precision loss) ------------
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
            }

            return noErr
        }

        return node
    }

    // MARK: - Cleanup

    nonisolated deinit {
        // Cleanup is handled by stop() being called before deallocation.
        // Timer and engine are managed by the actor.
    }
}
