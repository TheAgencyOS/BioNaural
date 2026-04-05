# SpessaSynth & SoundFont Synthesis — Research for BioNaural

## TL;DR

SpessaSynth itself is a **JavaScript/TypeScript web synthesizer** — it cannot run natively on iOS and embedding it via WKWebView would conflict with our AVAudioEngine pipeline. **However, the concept it proves is exactly what BioNaural should adopt:** replace the fixed melodic audio file library with real-time MIDI + SoundFont synthesis for infinite variety.

The right path is **not** SpessaSynth. It's **AVAudioUnitSampler** — Apple's built-in SF2 renderer that drops directly into our existing AVAudioEngine graph with zero dependencies.

---

## What Is SpessaSynth?

| Field | Value |
|-------|-------|
| **URL** | https://github.com/spessasus/SpessaSynth |
| **Core lib** | https://github.com/spessasus/spessasynth_core |
| **Stars** | 328 (app), 42 (core) |
| **License** | Apache-2.0 |
| **Language** | TypeScript |
| **Last commit** | April 4, 2026 — actively maintained |
| **Demo** | https://spessasus.github.io/SpessaSynth/ |

A real-time SoundFont2/SF3/DLS MIDI synthesizer and editor. Parses SF2 files, renders audio via WebAudio API, includes reverb/chorus/delay effects. Full SF2 spec support with generators, modulators, envelopes, and filters. Quality is on par with FluidSynth.

**Three components:**
- `spessasynth_core` — Platform-agnostic: SF2 parsing, MIDI parsing, synthesis engine
- `spessasynth_lib` — Browser wrapper (AudioWorklet/WebWorker rendering)
- `SpessaSynth` — Full GUI app (player, visualizer, karaoke, editor)

## Why NOT SpessaSynth for BioNaural

1. **JavaScript only** — no native iOS/Swift port exists
2. **WKWebView embedding** would create two separate audio stacks (WebAudio + AVAudioEngine) that can't share a graph — no precise mixing/sync
3. **iOS background audio** via WKWebView is unreliable (WebAudio suspends when app backgrounds)
4. **App Store risk** — reviewers reject apps that are "primarily web wrappers"
5. **Loses AVAudioEngine advantages** — low-latency pipeline, audio session control, spatial audio

## What We Should Do Instead

### The Concept: Generative MIDI → SoundFont → Audio

Replace fixed melodic audio files with:
1. **Generative MIDI engine** — algorithmically creates note events based on session mode, biometric state, and Tonic scale mapping
2. **SoundFont renderer** — converts MIDI notes to audio in real-time using sampled instruments
3. **Result:** Infinite melodic variety, smaller app size, biometric-reactive music

### Option A: AVAudioUnitSampler (RECOMMENDED — v1.5)

Apple's built-in SoundFont player. **Zero additional dependencies.**

```swift
let sampler = AVAudioUnitSampler()
engine.attach(sampler)
engine.connect(sampler, to: melodicMixerNode, format: nil)

// Load a SoundFont
try sampler.loadSoundBankInstrument(
    at: soundFontURL,
    program: 0,       // instrument (e.g., 0 = piano, 48 = strings)
    bankMSB: 0x79,    // GM bank
    bankLSB: 0
)

// Send notes programmatically
sampler.startNote(60, withVelocity: 80, onChannel: 0)  // Middle C
sampler.stopNote(60, onChannel: 0)
```

| Aspect | Detail |
|--------|--------|
| **Integration** | Drops into existing AVAudioEngine graph as a standard node |
| **SF2 support** | Yes (native). No SF3 (compressed). |
| **Latency** | ~5ms with 256-frame buffer — imperceptible for generative playback |
| **CPU** | Under 3% for 8-voice polyphony on A14+ |
| **API** | `startNote()`, `stopNote()`, `sendMIDIEvent()`, `sendProgramChange()` |
| **Quality** | Good for ambient/melodic textures. Not all SF2 modulators supported. |
| **SoundFont size** | 10-20 MB bundled (2-4 curated presets: pad, piano, strings, bells) |

### Option B: TinySoundFont (Fallback if Apple's quality is insufficient)

| Field | Value |
|-------|-------|
| **URL** | https://github.com/schellingb/TinySoundFont |
| **Stars** | 801 |
| **License** | MIT |
| **Language** | Single C header file (`tsf.h`) |

Renders SF2 to raw PCM buffers — exactly how our binaural layer works. Integrate via bridging header, feed output into AVAudioSourceNode. More control than Apple's sampler but no built-in effects.

### Option C: FluidSynth (Nuclear option)

| Field | Value |
|-------|-------|
| **URL** | https://github.com/FluidSynth/fluidsynth |
| **Stars** | 2,335 |
| **License** | LGPL-2.1 (⚠️ dynamic linking required) |

Gold standard SF2/SF3 renderer. Full spec compliance, built-in effects. Can compile for iOS but LGPL complicates App Store distribution. Only consider if AVAudioUnitSampler + TinySoundFont both fall short.

### Reference Implementation

**bradhowes/SoundFonts** (83 stars, MIT) — Complete iOS app demonstrating SF2 + AVAudioUnitSampler + MIDI. Pure Swift. AUv3 extension. Study this.

## How This Fits BioNaural's Architecture

### Current (v1): File-based melodic layer
```
SoundSelector → picks SoundIDs → MelodicLayer plays AVAudioPlayerNodes
```

### Future (v1.5+): Generative MIDI melodic layer
```
ScaleMapper (Tonic) → valid pitches for mode/biometric state
     ↓
GenerativeMIDI → note events (pitch, velocity, timing, duration)
     ↓
AVAudioUnitSampler (SF2) → real-time audio
     ↓
MelodicMixer → existing AVAudioEngine graph
```

**ScaleMapper already exists** (built today with Tonic). It provides `validFrequencies(for:biometricState:)`. The generative MIDI engine would:
- Pick from those valid frequencies based on mode-specific rules
- Control note density from biometric state (calm = sparse, elevated = denser)
- Manage voice leading (smooth transitions between notes)
- Respect the adaptive algorithm's slew rate limiting

### SoundFont Budget

| Preset | Approx Size | Use Case |
|--------|-------------|----------|
| Ambient pad | 3-5 MB | Focus, Relaxation |
| Warm piano | 3-5 MB | Focus, Sleep |
| Gentle strings | 3-5 MB | Relaxation, Sleep |
| Bright bells | 1-2 MB | Energize |
| **Total** | **10-17 MB** | All four modes |

This replaces potentially hundreds of MB of pre-recorded audio files with 10-17 MB of SoundFonts + a generative MIDI engine that produces infinite variety.

## Decision

| Question | Answer |
|----------|--------|
| Should we use SpessaSynth? | **No** — JS only, can't integrate with AVAudioEngine |
| Should we adopt SoundFont synthesis? | **Yes** — for v1.5, replaces file-based melodic layer |
| Which renderer? | **AVAudioUnitSampler** first (zero deps), TinySoundFont as fallback |
| When? | **v1.5** — after v1 launches with file-based sounds + feedback logging |
| Does this conflict with existing architecture? | **No** — drops into the existing AVAudioEngine graph |
| Does ScaleMapper (Tonic) help? | **Yes** — it provides the pitch palette for the generative MIDI engine |

## Key Risks

1. **AVAudioUnitSampler click/pop on preset changes** — mitigate by crossfading between two sampler instances
2. **SoundFont quality variance** — must curate/test SoundFonts carefully, not just grab GeneralMIDI banks
3. **Generative composition quality** — rule-based MIDI generation needs careful design to avoid sounding robotic (v1.5 ML can learn from user preferences)
4. **Bundle size** — 10-17 MB of SoundFonts is acceptable but monitor total app size
