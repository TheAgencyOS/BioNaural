# SoundFont Synthesis for BioNaural — Technical Research

## Executive Summary

BioNaural's melodic layer currently plays pre-recorded audio files selected by the SoundSelector. This works for v1 but has fundamental limitations: finite variety, large bundle size, and no ability to generate music that truly responds to biometric state in real-time.

The solution is **real-time MIDI + SoundFont synthesis** — a generative MIDI engine creates note events driven by biometrics, and an SF2 renderer turns those into audio. This gives infinite melodic variety from ~15MB of SoundFont files, replaces hundreds of MB of recordings, and enables the melodic layer to be as adaptive as the binaural layer already is.

**Chosen renderer: SF2Lib** (MIT, Swift Package, built for iOS, full modulator support, already shipping on the App Store).

**Timeline: v1.5** — after v1 launches with file-based sounds and feedback logging.

---

## The Problem with File-Based Melodic Audio

### Current Architecture (v1)

```
SoundSelector (rules) → picks SoundIDs → MelodicLayer → AVAudioPlayerNode (plays .m4a/.wav files)
```

### Limitations

| Problem | Impact |
|---------|--------|
| **Finite library** | Users hear repeats after 10-20 sessions. Staleness kills retention. |
| **Large bundle** | 50-100 audio files × 2-5MB each = 100-500MB. App Store download size matters. |
| **Coarse adaptation** | Can only switch between whole files (10-15s crossfade). Can't change individual notes in response to a HR spike. |
| **Key/tempo lock** | Each file has a fixed key and tempo. SoundSelector must filter for compatibility, reducing the candidate pool. |
| **Scaling cost** | Adding variety means recording/licensing more files. Linear cost for linear improvement. |

### What We Want

```
GenerativeMIDI (biometric-driven) → note events → SF2 Renderer → audio → AVAudioEngine mixer
```

- **Note-level adaptation** — a single note can respond to a biometric state change
- **Infinite variety** — algorithmic composition never repeats exactly
- **Tiny bundle** — 10-17MB of SoundFont files replaces 100-500MB of recordings
- **Key freedom** — Tonic's ScaleMapper provides valid pitches, no key-compatibility filtering needed
- **Density control** — calm = sparse notes, elevated = denser, peak = simplified

---

## SpessaSynth — Inspiration, Not Implementation

### What It Is

| Field | Value |
|-------|-------|
| **URL** | https://github.com/spessasus/SpessaSynth |
| **Core lib** | https://github.com/spessasus/spessasynth_core |
| **Stars** | 328 (app), 42 (core) |
| **License** | Apache-2.0 |
| **Language** | TypeScript |
| **Last commit** | April 4, 2026 |

SpessaSynth is a real-time SoundFont2/SF3/DLS MIDI synthesizer written in TypeScript. It runs in the browser via WebAudio API. The core library (`spessasynth_core`) is platform-agnostic — it handles SF2 parsing, MIDI parsing, and synthesis math without browser dependencies. The full app includes a GUI player, visualizer, karaoke renderer, and SF2 editor.

### Why It Matters

SpessaSynth proves the concept works: load a SoundFont, receive MIDI events, render audio in real-time. The architecture — parser + synthesis engine + audio output — is exactly what BioNaural needs. The quality is excellent (full SF2 spec compliance including generators, modulators, envelopes, and filters).

### Why We Can't Use It

| Blocker | Detail |
|---------|--------|
| **JavaScript only** | No native iOS/Swift port. The synthesis engine is TypeScript. |
| **WKWebView conflict** | Embedding it via WKWebView creates two audio stacks (WebAudio + AVAudioEngine) that can't share a graph. No precise mixing, no synchronization with the binaural layer. |
| **Background audio** | WebAudio in WKWebView suspends when the app backgrounds. BioNaural sessions run 25-90 minutes in background. Non-starter. |
| **App Store** | Apple rejects apps that are "primarily web wrappers." |
| **Latency** | WebAudio adds buffer latency on top of the JS→native bridge. |

SpessaSynth is the reference for what good SoundFont synthesis looks like. The implementation path for iOS is native.

---

## SF2 Renderer Evaluation

### Candidates Tested

Four options exist for SoundFont rendering on iOS. We evaluated each on spec compliance, license, integration effort, sound quality for ambient content, and production reliability.

### 1. AVAudioUnitSampler (Apple Built-in)

Apple's wrapper around the Core Audio `kAudioUnitSubType_Sampler` Audio Unit.

```swift
let sampler = AVAudioUnitSampler()
engine.attach(sampler)
engine.connect(sampler, to: mixerNode, format: nil)
try sampler.loadSoundBankInstrument(at: sf2URL, program: 0, bankMSB: 0x79, bankLSB: 0)
sampler.startNote(60, withVelocity: 80, onChannel: 0)
```

**Known bugs (documented by developers and Apple Forums):**

- **Crashes on malformed SF2 files.** Unrecoverable — takes the entire app process down. No try/catch protection. Source: Brad Howes (SoundFonts app developer), Apple Developer Forums.
- **Corrupted audio after interruption.** Phone calls, Siri, and other apps taking the audio session produce garbage audio from the sampler. The only fix is fully reloading the SoundFont, which blocks the calling thread and introduces an audible gap. For a 45-minute focus session, this is unacceptable.
- **Audio doubles on route change (iPhone only).** Plugging or unplugging headphones causes the sampler to stack duplicate output. Each route change adds another copy. Root cause: hardware sample rate mismatch (48kHz speaker vs 44.1kHz headphones). Workaround: listen for `AVAudioSession.routeChangeNotification`, wait ~100ms, reinitialize the sampler. Does not occur on iPad.
- **State reset on dynamic node reconnection.** Reconnecting effect nodes in the AVAudioEngine graph while the sampler plays triggers internal `CleanupMemory()` / `InitializeMemory()` calls that reset the sampler to its default sine wave preset, losing the loaded instrument.
- **Synchronous loading, no async API.** `loadSoundBankInstrument(at:program:bankMSB:bankLSB:)` blocks the calling thread. Apple provides no async variant. No official guidance on thread safety.
- **128-voice hard limit on iOS.** When reached, new notes are silently dropped — no voice stealing. Configurable only via undocumented AudioUnit property ID 4104.
- **iOS 18 audio session regressions.** `AVAudioSession` reports incorrect sample rates and restricts buffer sizes, indirectly impacting sampler reliability.
- **Documentation is abysmal.** Two Tech Notes from 2012 (TN2283, TN2331). WWDC videos covering it have been removed. Most knowledge comes from reverse engineering.

**Verdict: Too fragile for BioNaural.** A focus app that runs 25-90 minute background sessions cannot tolerate crashes on SF2 load, corrupted audio on phone calls, or audio doubling on headphone changes. These aren't edge cases — they're normal usage patterns.

### 2. TinySoundFont

| Field | Value |
|-------|-------|
| **URL** | https://github.com/schellingb/TinySoundFont |
| **Stars** | 801 |
| **License** | MIT |
| **Language** | Single C header (`tsf.h`, ~2,079 lines) |
| **Last commit** | July 2025 |

Renders SF2 SoundFonts to raw PCM float buffers. Integration is trivial — one `#include`, one `#define TSF_IMPLEMENTATION`. Renders in an audio callback via `tsf_render_float()`. Binary impact: ~50-80KB.

**What works:**
- Loads SF2 files, plays notes, renders to float buffers
- Pre-allocatable voice pool (`tsf_set_max_voices`) eliminates malloc on the render path
- `tsf_copy()` shares one SoundFont across multiple playback instances
- Thread-safe with pre-allocation

**What doesn't work for us:**
- **No modulator support.** Header explicitly states "NOT YET IMPLEMENTED." Developer has stated no plans to implement them. Modulators are what make pads and strings sound expressive — velocity-to-filter-cutoff, LFO-to-pitch, envelope-to-amplitude shaping. Without them, ambient presets sound flat and static.
- **Weak low-pass filter.** Filter state doesn't carry correctly across render calls, introducing noise. Acknowledged as a TODO in the source.
- **No chorus/reverb effect sends.** SF2 generators for chorus and reverb send levels are read but not processed. Pads lose their built-in spaciousness.
- **No SF3 support.** Uncompressed SF2 only.

**Verdict: Adequate for prototyping, insufficient for production ambient music.** The missing modulators are the dealbreaker. For a piano app playing individual notes, TinySoundFont is fine. For ambient pads and evolving string textures that rely on modulators for their character, the sound quality gap is audible and material.

### 3. FluidSynth

| Field | Value |
|-------|-------|
| **URL** | https://github.com/FluidSynth/fluidsynth |
| **Stars** | 2,335 |
| **License** | LGPL-2.1 |
| **Language** | C |
| **Last commit** | April 4, 2026 |

The gold standard SF2/SF3 synthesizer. Full spec compliance, built-in reverb and chorus, high-quality interpolation. Used in MuseScore, ScummVM, and hundreds of music apps. Official iOS xcframework builds exist in the CI pipeline.

**Pros:**
- ~100% SF2 spec compliance including all modulators
- SF3 support (Ogg Vorbis compressed — 125MB SF2 → ~15MB SF3)
- Excellent audio quality
- Battle-tested across platforms for 20+ years

**The LGPL problem:**

FluidSynth's own wiki states: *"It is questionable whether iOS and the App Store can fulfil the requirements of the LGPL."*

LGPL requires that end users can replace the LGPL library with a modified version. On iOS, users cannot swap dynamic frameworks in a signed app bundle. FluidSynth's FAQ says you must either:
1. Treat it as GPL (open-source your entire app), or
2. Accept legal ambiguity

Many iOS apps ship LGPL code via dynamic frameworks (`.framework` bundles), arguing this technically satisfies the requirement. The FSF has not explicitly blessed this interpretation.

**Verdict: Best sound quality, but LGPL is a non-starter for a closed-source iOS app.** We are not willing to open-source BioNaural or accept unresolved legal risk for the App Store.

### 4. SF2Lib (CHOSEN)

| Field | Value |
|-------|-------|
| **URL** | https://github.com/bradhowes/SF2Lib |
| **Stars** | 11 |
| **License** | MIT |
| **Language** | C++17/23 with Swift Package Manager integration |
| **Last commit** | March 2026 |
| **Author** | Brad Howes (developer of "SoundFonts" and "SoundFontsPlus" on the App Store) |

A SoundFont2 synthesizer built specifically for iOS because AVAudioUnitSampler kept crashing the author's app. Uses Apple's Accelerate framework for DSP. Available as a Swift Package.

**Why SF2Lib wins:**

| Feature | Detail |
|---------|--------|
| **Full modulator support** | All SF2 v2 modulators implemented. This is what TinySoundFont is missing. Pads and strings sound as the SoundFont author intended — expressive, evolving, alive. |
| **Accelerate DSP** | Uses Apple's vDSP and SIMD for sample interpolation, envelope computation, and filter processing. Optimized for iPhone/iPad silicon. |
| **Three-bus output** | Dry + chorus send + reverb send. We connect our own AVAudioEngine reverb/chorus on the send busses. This matches the SF2 spec's effect routing exactly. |
| **No allocations on render path** | Voice pool is pre-allocated. Safe for audio callbacks. No malloc, no ARC, no locks in the render block. |
| **MIT license** | Zero legal concerns. Fork freely. |
| **Already shipping** | "SoundFonts" and "SoundFontsPlus" on the App Store use this library. Production-proven on real devices with real users. |
| **Swift Package** | `dependencies: [.package(url: "https://github.com/bradhowes/SF2Lib", ...)]` |
| **Performance** | 96 simultaneous voices rendered in ~0.27s for 1 second of audio at 48kHz with cubic interpolation. BioNaural's ambient layer will use 4-8 voices. |

**Limitations:**

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Low star count (11)** | Small community, solo maintainer | MIT license — we can fork if needed. Code is well-tested with good coverage. |
| **No SF3 support** | Must use uncompressed SF2 files (larger than SF3) | Curate a focused set of 3-4 presets at ~3-5MB each = 10-17MB total. Acceptable. |
| **No built-in chorus/reverb DSP** | Effects not rendered internally | By design — routes to send busses. We apply AVAudioEngine's `AVAudioUnitReverb` and `AVAudioUnitDelay` on the send nodes. Gives us more control anyway. |
| **C++/Obj-C++ internals** | Debugging crosses language boundaries | Author has good test coverage. Swift-facing API is clean. |
| **Apple ecosystem only** | Uses AudioToolbox + Accelerate | Irrelevant — BioNaural is iOS-only. |

---

## Comparison Matrix

| Criteria | AVAudioUnitSampler | TinySoundFont | FluidSynth | SF2Lib |
|---|---|---|---|---|
| **License** | Apple (built-in) | MIT | LGPL-2.1 | MIT |
| **SF2 spec compliance** | Unknown (black box) | ~70% | ~100% | ~95% |
| **Modulator support** | Partial | None | Full | Full |
| **Pad/string quality** | Unpredictable | Flat/static | Excellent | Very good |
| **Integration effort** | Very low | Very low | Medium-high | Low (SPM) |
| **Binary cost** | 0 | ~50-80KB | ~2-5MB | ~300-500KB |
| **SF3 compressed** | No | No | Yes | No |
| **Render thread safe** | N/A | Yes (with pre-alloc) | Yes | Yes (no alloc) |
| **App Store risk** | None | None | Real (LGPL) | None |
| **iOS-optimized** | Yes (Apple) | No | Some | Heavy (Accelerate) |
| **Production-proven iOS** | Yes (buggy) | Unknown | Yes (with legal risk) | Yes (SoundFonts app) |
| **Crash risk** | High (malformed SF2) | Low | Low | Low |
| **Maintenance** | Apple's schedule | Occasional | Very active | Active (solo dev) |

---

## Architecture: How It Fits BioNaural

### Current Audio Graph (v1)

```
BinauralBeatNode (AVAudioSourceNode, phase accumulator)
    → binauralMixer
                        → mainMixer → outputNode
AmbienceLayer (AVAudioPlayerNode, file-based)
    → ambienceMixer
                        ↗
MelodicLayer (AVAudioPlayerNode, file-based)
    → melodicMixer
                        ↗
```

### Future Audio Graph (v1.5)

```
BinauralBeatNode (AVAudioSourceNode, phase accumulator)
    → binauralMixer
                        → mainMixer → outputNode
AmbienceLayer (AVAudioPlayerNode, file-based)
    → ambienceMixer
                        ↗
SF2Renderer (AVAudioSourceNode, SF2Lib)
    → melodicDryMixer ──────────────────↗
    → melodicChorusSend → AVAudioUnitDelay (chorus) → mainMixer
    → melodicReverbSend → AVAudioUnitReverb → mainMixer
```

The melodic layer changes from `AVAudioPlayerNode` playing files to `AVAudioSourceNode` rendering SF2Lib output. The three-bus architecture (dry + chorus + reverb) maps directly onto separate AVAudioEngine mixer nodes with effects.

### Signal Flow

```
ScaleMapper (Tonic)
    → valid pitches for current mode + biometric state
        ↓
GenerativeMIDIEngine
    → note events (pitch, velocity, timing, duration)
    → driven by: session mode, biometric state, HR trend, time-in-session
    → rules: note density, voice leading, rest patterns, phrase structure
        ↓
SF2Renderer (SF2Lib)
    → renders SF2 samples with envelopes, filters, modulators, LFOs
    → outputs float PCM to three busses (dry, chorus send, reverb send)
        ↓
AVAudioEngine mixer
    → mixed with binaural + ambient layers
    → output to speakers/headphones
```

### GenerativeMIDIEngine Design (High-Level)

The generative engine is NOT random note generation. It uses rules derived from music theory and biometric context:

| Parameter | Control Source | Range |
|-----------|---------------|-------|
| **Pitch palette** | ScaleMapper (Tonic) based on mode + biometric state | Mode-specific scales (pentatonic major for Focus, lydian for Relaxation, etc.) |
| **Note density** | Biometric state | Calm: 1-2 notes/bar, Focused: 2-4, Elevated: 4-6, Peak: 2-3 (simplify under stress) |
| **Note duration** | Session mode + beat frequency | Focus: long sustained (2-4 beats), Sleep: very long (4-8 beats), Energize: shorter (1-2 beats) |
| **Velocity** | HR trend | Falling HR: softer (50-70), Stable: medium (70-90), Rising: louder (80-100) |
| **Register** | Mode | Focus: mid (C3-C5), Relaxation: low-mid (C2-C4), Sleep: low (C2-C3), Energize: mid-high (C3-C6) |
| **Voice leading** | Interval rules | Prefer stepwise motion (2nds, 3rds). Leaps (5ths, octaves) only on biometric state transitions. |
| **Rest probability** | Biometric state | Calm: 40% rest between phrases, Elevated: 20%, Sleep: 60% |
| **Phrase length** | Time-in-session | Short phrases early (2-4 notes), longer phrases as session progresses (4-8 notes) |
| **SoundFont preset** | Mode | Focus: warm piano + pad, Relaxation: strings + pad, Sleep: pad only, Energize: bright piano + bells |

### SoundFont Budget

| Preset | Approx Size | Modes |
|--------|-------------|-------|
| Ambient pad (warm, evolving) | 3-5 MB | Focus, Relaxation, Sleep |
| Warm acoustic piano | 3-5 MB | Focus, Sleep |
| Gentle ensemble strings | 3-5 MB | Relaxation, Sleep |
| Bright bells / celesta | 1-2 MB | Energize |
| **Total** | **10-17 MB** | All four modes |

This replaces what would be 100-500 MB of pre-recorded audio files. The app download size drops significantly while melodic variety becomes effectively infinite.

### Migration Path

| Phase | Melodic Layer | What Changes |
|-------|--------------|--------------|
| **v1 (launch)** | File-based (AVAudioPlayerNode) | Ship with curated audio files. SoundSelector picks files. Feedback logging captures user preferences. |
| **v1.5 (3-6 months)** | SF2Lib + GenerativeMIDI | Replace file playback with real-time synthesis. SoundSelector protocol stays the same — the implementation behind it changes. GenerativeMIDIEngine consumes ScaleMapper output. |
| **v2+** | ML-driven composition | GenerativeMIDIEngine's rules are replaced/augmented by a Core ML contextual bandit trained on v1/v1.5 feedback data. The model learns which note patterns produce the best biometric outcomes per user. |

The `SoundSelectorProtocol` and `MelodicLayer` abstractions in v1 are designed for this swap. The interface doesn't change — only the implementation behind it.

---

## Integration Steps (v1.5)

### 1. Add SF2Lib dependency

```yaml
# project.yml
packages:
  SF2Lib:
    url: https://github.com/bradhowes/SF2Lib.git
    from: "latest"
```

### 2. Bundle SoundFont files

Add curated `.sf2` files to the app bundle under `Resources/SoundFonts/`. Each preset vetted for:
- Quality at low velocity (ambient playing is typically soft)
- Loop points (must loop cleanly for sustained notes)
- Modulator behavior (filter sweeps, LFO depth)
- File size (target 3-5MB per preset)

### 3. Create SF2RenderNode

An `AVAudioSourceNode` that calls SF2Lib's render function in its audio callback. Accepts note-on/note-off commands via a lock-free ring buffer (same pattern as `AudioParameters` in the binaural layer).

### 4. Create GenerativeMIDIEngine

A Swift actor that:
- Reads current biometric state from `BiometricProcessor`
- Queries `ScaleMapper` for valid pitches
- Generates note events based on mode-specific rules
- Writes note commands to the ring buffer consumed by `SF2RenderNode`
- Runs on a timer (~100ms resolution, not audio-thread)

### 5. Wire into AVAudioEngine

Replace `MelodicLayer`'s `AVAudioPlayerNode` with `SF2RenderNode` + effect send nodes. The three-bus architecture (dry + chorus + reverb) requires three mixer connections.

### 6. A/B test

Ship both implementations behind a feature flag. Compare retention, session completion, and thumbs-up rates between file-based and generative melodic layers.

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **SF2Lib maintainer abandons project** | Low-medium | Medium | MIT license — fork and maintain. Code is well-structured with tests. |
| **Generative music sounds robotic** | Medium | High | Extensive rule tuning. Humanization (velocity variation, timing jitter). A/B test against file-based. Fall back to files if quality insufficient. |
| **SoundFont quality variance** | Medium | Medium | Curate and test every preset. Don't use random GM banks — commission or select specific high-quality presets. |
| **CPU budget on older devices** | Low | Medium | SF2Lib benchmarks at 96 voices in 0.27s. BioNaural uses 4-8 voices. 10x headroom. |
| **SF2 file licensing** | Medium | High | Use SoundFonts with clear licenses (CC0, MIT, or commercially licensed). Do not bundle copyrighted GM banks. |
| **User preference mismatch** | Medium | Medium | v1 feedback logging provides training data. v1.5 can A/B test. v2 ML model learns individual preferences. |

---

## Decision Record

| Question | Decision | Rationale |
|----------|----------|-----------|
| Use SpessaSynth? | **No** | JavaScript only, can't integrate with AVAudioEngine |
| Use AVAudioUnitSampler? | **No** | Crashes on bad SF2, corrupts on interruption, doubles on route change |
| Use TinySoundFont? | **No** (prototyping only) | No modulator support — pads sound flat |
| Use FluidSynth? | **No** | LGPL incompatible with closed-source iOS app |
| Use SF2Lib? | **Yes** | MIT, full modulators, iOS-optimized, production-proven, SPM |
| When? | **v1.5** | v1 ships file-based to validate product-market fit first |
| Does this require architecture changes? | **Minimal** | SoundSelectorProtocol stays. MelodicLayer implementation swaps. New GenerativeMIDIEngine + SF2RenderNode. |
| Does ScaleMapper (Tonic) help? | **Yes** | Already built. Provides the pitch palette for GenerativeMIDIEngine. |

---

## References

- [SpessaSynth](https://github.com/spessasus/SpessaSynth) — TypeScript SF2 synth, concept reference
- [SF2Lib](https://github.com/bradhowes/SF2Lib) — Chosen iOS SF2 renderer (MIT)
- [SoundFonts App](https://github.com/bradhowes/SoundFonts) — Reference iOS app using SF2Lib
- [TinySoundFont](https://github.com/schellingb/TinySoundFont) — Single-header C renderer (MIT)
- [FluidSynth](https://github.com/FluidSynth/fluidsynth) — Gold standard renderer (LGPL)
- [FluidSynth Licensing FAQ](https://github.com/FluidSynth/fluidsynth/wiki/LicensingFAQ) — LGPL on iOS
- [Infinum: AUSampler Missing Documentation](https://infinum.com/blog/ausampler-missing-documentation/) — AVAudioUnitSampler bugs
- [AudioKit Issue #1110](https://github.com/AudioKit/AudioKit/issues/1110) — Route change audio doubling
- [AudioKit Tonic](https://github.com/AudioKit/Tonic) — Music theory library (already integrated)
