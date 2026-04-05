# BioNaural — AVAudioEngine & Real-Time Audio Synthesis

> How to generate binaural beats programmatically on iOS with zero latency and no clicks.

---

## Architecture: The Audio Graph

```
AVAudioSourceNode (binaural generator)
    → AVAudioUnitReverb (optional ambience)
    → AVAudioMixerNode (engine.mainMixerNode)
    → AVAudioOutputNode (engine.outputNode → headphones)
```

**Key node: `AVAudioSourceNode`** (iOS 13+). You provide a render callback that fills audio buffers on demand. The engine calls this on the real-time audio thread.

---

## The Render Callback

```swift
let sourceNode = AVAudioSourceNode(format: stereoFormat) { isSilence, timestamp, frameCount, outputData in
    let abl = UnsafeMutableAudioBufferListPointer(outputData)
    let leftPtr = abl[0].mData!.assumingMemoryBound(to: Float32.self)   // Left channel
    let rightPtr = abl[1].mData!.assumingMemoryBound(to: Float32.self)  // Right channel
    
    for frame in 0..<Int(frameCount) {
        leftPtr[frame] = /* left sample (-1.0 to 1.0) */
        rightPtr[frame] = /* right sample (-1.0 to 1.0) */
    }
    return noErr
}
```

**Format:** Non-interleaved stereo Float32 at 44100 or 48000 Hz. `abl[0]` = left, `abl[1]` = right. Always pass the format explicitly to avoid surprises.

---

## Generating Binaural Beats: Phase Accumulator

A binaural beat = two slightly different frequencies, one per ear. Use a phase accumulator per channel to avoid floating-point drift over long sessions:

```swift
var phaseL: Double = 0.0
var phaseR: Double = 0.0
let baseFreq: Double = 200.0    // Hz (carrier)
let beatFreq: Double = 10.0     // Hz (binaural difference)
let sampleRate: Double = 44100.0

// Per sample:
let leftSample = amplitude * sin(2.0 * .pi * phaseL)
let rightSample = amplitude * sin(2.0 * .pi * phaseR)

phaseL += baseFreq / sampleRate
phaseR += (baseFreq + beatFreq) / sampleRate
if phaseL >= 1.0 { phaseL -= 1.0 }  // Wrap to [0, 1)
if phaseR >= 1.0 { phaseR -= 1.0 }
```

**Use `Double` for phase accumulators.** `Float` (32-bit) loses precision after hours of playback. `Double` (64-bit) is stable for days.

---

## Smooth Parameter Changes (No Clicks)

### The Problem
Abrupt frequency or amplitude changes cause clicks/pops — discontinuities in the waveform.

### The Solution: Per-Sample Exponential Smoothing

```swift
// Smoothing coefficients — use Theme.Audio tokens, never hardcode
// Theme.Audio.amplitudeSmoothingTime = 0.005 (5ms)
// Theme.Audio.frequencySmoothingTime = 0.020 (20ms)
let ampSmoothing = 1.0 - exp(-1.0 / (Theme.Audio.amplitudeSmoothingTime * sampleRate))
let freqSmoothing = 1.0 - exp(-1.0 / (Theme.Audio.frequencySmoothingTime * sampleRate))

// Per sample in render callback:
currentAmplitude += (targetAmplitude - currentAmplitude) * ampSmoothing
currentBaseFreq += (targetBaseFreq - currentBaseFreq) * freqSmoothing
```

**Why frequency changes are inherently safe:** The phase accumulator is continuous — changing the increment (frequency) doesn't cause a discontinuity. Only the rate of phase advance changes. Amplitude changes DO need ramping.

---

## Thread Safety: The Real-Time Audio Thread

The render callback runs on a **real-time thread** with a strict deadline (~11.6ms at 512 frames/44100 Hz).

### Forbidden on the Audio Thread

| Operation | Why |
|-----------|-----|
| Memory allocation (`malloc`, object creation) | May lock |
| Objective-C messaging (`objc_msgSend`) | May trigger autorelease/retain |
| Swift ARC (retain/release of class instances) | May allocate or lock |
| Locks (`NSLock`, `pthread_mutex`, `DispatchSemaphore`) | Priority inversion |
| File I/O, networking, `print()` | Unbounded latency |
| Dispatch queues (`DispatchQueue.sync/async`) | May allocate/lock |

### Allowed
- Arithmetic (Int, Float, Double)
- `sin()`, `cos()` (C math functions)
- Atomic loads/stores
- Raw pointer read/write to pre-allocated buffers

### Safe Parameter Passing: Atomics

Use [swift-atomics](https://github.com/apple/swift-atomics) to pass parameters from the main thread to the render thread:

```swift
import Atomics

let targetFreqBits = ManagedAtomic<UInt64>(200.0.bitPattern)

// Main thread sets:
targetFreqBits.store(newFreq.bitPattern, ordering: .relaxed)

// Render thread reads:
let freq = Double(bitPattern: targetFreqBits.load(ordering: .relaxed))
```

Store `Double` as `UInt64` bit patterns since `ManagedAtomic` requires integer types. No locks, no allocations, no priority inversion.

---

## Complete Engine Architecture

```swift
final class BinauralBeatEngine {
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    
    // Atomic parameters (main thread writes, render thread reads)
    private let _baseFreq = ManagedAtomic<UInt64>(200.0.bitPattern)
    private let _beatFreq = ManagedAtomic<UInt64>(10.0.bitPattern)
    private let _amplitude = ManagedAtomic<UInt64>(0.5.bitPattern)
    private let _isPlaying = ManagedAtomic<Bool>(false)
    
    // Public API (main thread)
    var baseFrequency: Double {
        get { Double(bitPattern: _baseFreq.load(ordering: .relaxed)) }
        set { _baseFreq.store(newValue.bitPattern, ordering: .relaxed) }
    }
    var beatFrequency: Double { /* same pattern */ }
    var amplitude: Double { /* same pattern */ }
    
    func setup() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        
        let sampleRate = session.sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        // Capture atomics for render closure (no ARC in callback)
        let baseFreqRef = _baseFreq
        let beatFreqRef = _beatFreq
        let ampRef = _amplitude
        let playingRef = _isPlaying
        
        var phaseL: Double = 0, phaseR: Double = 0
        // Initial values from mode defaults — NEVER hardcode frequencies
        var curAmp: Double = 0
        var curBase: Double = Theme.Audio.modeDefaults[mode].carrierFrequency
        var curBeat: Double = Theme.Audio.modeDefaults[mode].beatFrequency
        let ampSmooth = 1.0 - exp(-1.0 / (Theme.Audio.amplitudeSmoothingTime * sampleRate))
        let freqSmooth = 1.0 - exp(-1.0 / (Theme.Audio.frequencySmoothingTime * sampleRate))
        
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, outputData in
            let targetBase = Double(bitPattern: baseFreqRef.load(ordering: .relaxed))
            let targetBeat = Double(bitPattern: beatFreqRef.load(ordering: .relaxed))
            let targetAmp = playingRef.load(ordering: .relaxed)
                ? Double(bitPattern: ampRef.load(ordering: .relaxed)) : 0.0
            
            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            let L = abl[0].mData!.assumingMemoryBound(to: Float32.self)
            let R = abl[1].mData!.assumingMemoryBound(to: Float32.self)
            
            for i in 0..<Int(frameCount) {
                curAmp += (targetAmp - curAmp) * ampSmooth
                curBase += (targetBase - curBase) * freqSmooth
                curBeat += (targetBeat - curBeat) * freqSmooth
                
                L[i] = Float(curAmp * sin(2.0 * .pi * phaseL))
                R[i] = Float(curAmp * sin(2.0 * .pi * phaseR))
                
                phaseL += curBase / sampleRate
                phaseR += (curBase + curBeat) / sampleRate
                if phaseL >= 1.0 { phaseL -= 1.0 }
                if phaseR >= 1.0 { phaseR -= 1.0 }
            }
            return noErr
        }
        
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = Theme.Audio.reverbWetDryMix  // 15 — defined in Theme, not hardcoded
        
        engine.attach(source)
        engine.attach(reverb)
        engine.connect(source, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }
    
    func start() throws {
        _isPlaying.store(true, ordering: .relaxed)
        if !engine.isRunning { try engine.start() }
    }
    
    func stop() {
        _isPlaying.store(false, ordering: .relaxed)
        // Let amplitude ramp to 0, then stop engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.engine.stop()
        }
    }
}
```

**Usage:** Set `baseFrequency`, `beatFrequency`, `amplitude` from any thread at any time. The render callback smoothly interpolates to the new values. No clicks, no locks, no latency.

---

## Layering Multiple Sound Sources

For ambient textures, noise beds, nature sounds alongside the binaural generator:

```
AVAudioSourceNode (binaural)  ──┐
AVAudioPlayerNode (ambient)   ──┤──→ AVAudioMixerNode ──→ Output
AVAudioSourceNode (noise)     ──┘
```

Each source connects to the mixer. Control volume per-source via amplitude in the render callback (not via mixer pan — pan applies stereo law that breaks channel isolation).

---

## Built-In Effects

| Effect | Use | Setup |
|--------|-----|-------|
| `AVAudioUnitReverb` | Spatial ambience for carriers | `.mediumHall` or `.cathedral`, wetDryMix 15-30% |
| `AVAudioUnitEQ` | Shape carrier tone (low-pass to warm it) | 2-band, lowPass at 500-800 Hz |
| `AVAudioUnitDelay` | Spatial depth | Subtle: 0.1-0.3s delay, 20-30% feedback |

**Caution with reverb:** Heavy reverb smears binaural beat perception. Use parallel processing (send only a portion of the carrier to reverb) to keep the dry binaural signal intact.

---

## Latency & Buffer Size

| Buffer (frames) | Latency @ 44100 Hz | Notes |
|-----------------|-------------------|-------|
| 128 | 2.9 ms | Aggressive, risk of glitches |
| 256 | 5.8 ms | Good balance |
| **512** | **11.6 ms** | **Recommended for binaural beats** |
| 1024 | 23.2 ms | Conservative, lowest CPU |

For binaural beats, latency is irrelevant (no instrument performance). 512 frames is ideal — low CPU, no glitch risk.

```swift
try session.setPreferredIOBufferDuration(0.012)  // ~512 frames
```

---

## Key Gotchas

1. **Engine stops on route change** (headphone plug/unplug). Observe `routeChangeNotification` and restart.
2. **Accessing `mainMixerNode` or `outputNode` initializes the audio session.** Configure `AVAudioSession` FIRST.
3. **`.playback` category ignores the silent switch** — audio plays even on silent. This is correct for binaural beats.
4. **AirPods Spatial Audio** can break binaural beats — set `outputNode.spatializationEnabled = false` (iOS 15+).
5. **Don't capture `self` (class) in the render closure** — causes ARC retain/release on the audio thread. Capture only atomics and value types.
6. **`sin()` performance** — 2 calls per sample × 44100 samples/sec = trivial for modern ARM. No optimization needed for 2 oscillators.
7. **Format mismatches crash at `engine.start()`** — use one consistent format everywhere.
8. **Amplitude ramp before stopping** — set amplitude to 0, wait for ramp, then stop engine. Prevents a pop.

---

## AVAudioSourceNode vs AUAudioUnit

| | AVAudioSourceNode | Custom AUAudioUnit |
|--|---|---|
| Complexity | Simple — one closure | Significant boilerplate |
| Parameter automation | Manual (atomics) | Built-in `AUParameterTree` |
| Reusability | Tied to engine instance | Packaged as AUv3 plugin |
| **Recommendation** | **Use this** | Overkill unless distributing as a plugin |

---

## Isochronic Tone Synthesis (v1.1+)

Isochronic tones reuse the same `AVAudioSourceNode` architecture — same render callback, same atomic parameter bridge, same phase accumulator pattern. The difference is the modulation strategy.

### How It Differs From Binaural

| | Binaural Beats | Isochronic Tones |
|--|---|---|
| Signal | Two continuous sine waves, slightly different frequencies, one per ear | Single carrier tone amplitude-modulated on/off at pulse rate |
| Stereo | Required — L and R channels differ | Not required — mono signal works through speakers |
| Modulation depth | ~3 dB (subtle) | ~50 dB (pronounced pulse) |
| Best frequencies | Low (delta, theta) | High (beta, gamma — 13+ Hz) |

### Render Callback Pattern

```swift
// Add to AudioParameters (atomics):
let _entrainmentMethod = ManagedAtomic<UInt8>(0)  // 0 = binaural, 1 = isochronic
let _pulseFreq = ManagedAtomic<UInt64>(10.0.bitPattern)

// In render callback — isochronic path:
var pulsePhase: Double = 0.0
let dutyCycle = 0.5  // from Theme.Audio, not hardcoded
let rampFraction = 0.15  // smooth edges, from Theme.Audio

for i in 0..<Int(frameCount) {
    // Carrier tone (same phase accumulator as binaural)
    let carrier = Float(curAmp * sin(2.0 * .pi * phaseL))
    
    // Pulse envelope: smooth on/off at pulse frequency
    let pulsePosition = pulsePhase.truncatingRemainder(dividingBy: 1.0)
    let envelope: Float
    if pulsePosition < rampFraction {
        envelope = Float(pulsePosition / rampFraction)  // ramp up
    } else if pulsePosition < dutyCycle - rampFraction {
        envelope = 1.0  // sustain
    } else if pulsePosition < dutyCycle {
        envelope = Float((dutyCycle - pulsePosition) / rampFraction)  // ramp down
    } else {
        envelope = 0.0  // silence
    }
    
    let sample = carrier * envelope
    L[i] = sample  // same signal both channels (mono-compatible)
    R[i] = sample
    
    phaseL += curBase / sampleRate
    pulsePhase += curPulse / sampleRate
    if phaseL >= 1.0 { phaseL -= 1.0 }
    if pulsePhase >= 1.0 { pulsePhase -= 1.0 }
}
```

### Key Implementation Notes

- **Same `AVAudioSourceNode`** — the render callback checks `entrainmentMethod` and branches between binaural (stereo split) and isochronic (amplitude modulation) paths
- **Same atomic parameter passing** — add `_entrainmentMethod` and `_pulseFreq` to `AudioParameters`
- **Same slew rate limiting** — pulse frequency changes at max 0.3 Hz/sec, same as binaural
- **Same per-sample exponential smoothing** — 5ms amplitude, 20ms frequency
- **Amplitude ramping is critical** — without smooth ramps at pulse edges, you get harsh clicks and spectral splatter. The `rampFraction` controls this.
- **Speaker mode**: isochronic tones work without headphones. When the system detects no headphones connected, it can suggest isochronic as the entrainment method (v1.1+)

### Why Not a Separate Node

Both binaural and isochronic are synthesized entrainment signals using the same carrier frequency and phase accumulator. Keeping them in one node avoids duplicate audio graph complexity and makes switching between methods a single atomic write.
